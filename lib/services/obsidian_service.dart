import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A single task parsed from an Obsidian markdown file.
class ObsidianTask {
  const ObsidianTask({
    required this.filePath,
    required this.fileName,
    required this.lineIndex,
    required this.rawLine,
    required this.title,
    required this.isChecked,
    required this.actualPomodoros,
    required this.expectedPomodoros,
    required this.blockRef,
  });

  final String filePath;
  final String fileName;
  final int lineIndex;
  final String rawLine;
  final String title;
  final bool isChecked;
  final int actualPomodoros;
  final int expectedPomodoros; // 0 = no target set

  // Stable ID for task_ref FK: sha1 of filePath + title (survives minor edits)
  final String blockRef;

  ObsidianTask copyWith({int? actualPomodoros}) => ObsidianTask(
        filePath: filePath,
        fileName: fileName,
        lineIndex: lineIndex,
        rawLine: rawLine,
        title: title,
        isChecked: isChecked,
        actualPomodoros: actualPomodoros ?? this.actualPomodoros,
        expectedPomodoros: expectedPomodoros,
        blockRef: blockRef,
      );
}

class ObsidianService extends ChangeNotifier {
  ObsidianService({required SharedPreferences prefs}) : _prefs = prefs {
    final saved = prefs.getString(_kVaultPath);
    if (saved != null && Directory(saved).existsSync()) {
      _vaultPath = saved;
      _startWatcher();
      _scanVault();
    }
  }

  static const _kVaultPath = 'obsidian_vault_path';

  // - [ ] task description [popcorn:: actual/expected]
  // - [x] completed task   [popcorn:: actual]
  // Using 'popcorn' instead of tomato to match the Popodoro design system.
  static final _taskRe = RegExp(
    r'^(\s*)-\s*\[([ xX])\]\s+(.+?)(?:\s*\[popcorn::\s*(\d+)(?:\/(\d+))?\])?$',
  );

  final SharedPreferences _prefs;

  String? _vaultPath;
  List<ObsidianTask> _tasks = [];
  StreamSubscription<FileSystemEvent>? _watcher;
  Timer? _debounce;

  String? get vaultPath => _vaultPath;
  bool get isConnected => _vaultPath != null;
  List<ObsidianTask> get tasks => List.unmodifiable(_tasks);
  List<ObsidianTask> get pendingTasks =>
      _tasks.where((t) => !t.isChecked).toList();

  // ── Vault management ──────────────────────────────────────────────────────────

  Future<void> connectVault(String path) async {
    if (!Directory(path).existsSync()) return;
    _vaultPath = path;
    await _prefs.setString(_kVaultPath, path);
    _startWatcher();
    await _scanVault();
    notifyListeners();
  }

  Future<void> disconnectVault() async {
    _watcher?.cancel();
    _watcher = null;
    _debounce?.cancel();
    _vaultPath = null;
    _tasks = [];
    await _prefs.remove(_kVaultPath);
    notifyListeners();
  }

  Future<void> refresh() => _scanVault();

  // ── File operations ────────────────────────────────────────────────────────────

  // Lets the user pick one or more .md files from the vault for a project.
  Future<List<String>> pickFiles() async {
    final path = _vaultPath;
    final results = await openFiles(
      initialDirectory: path,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Markdown', extensions: ['md']),
      ],
    );
    return results.map((f) => f.path).toList();
  }

  // Returns pending tasks from a list of specific file paths.
  Future<List<ObsidianTask>> tasksForFiles(List<String> filePaths) async {
    final results = <ObsidianTask>[];
    for (final path in filePaths) {
      results.addAll(await scanFile(path));
    }
    return results.where((t) => !t.isChecked).toList();
  }

  // Scans a single .md file and returns its tasks.
  Future<List<ObsidianTask>> scanFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return [];
    final lines = await file.readAsLines();
    return _parseLines(filePath, lines);
  }

  // Increments the [popcorn:: n] count for the task atomically.
  Future<void> incrementPomodoro(ObsidianTask task) async {
    final file = File(task.filePath);
    if (!file.existsSync()) return;

    final lines = await file.readAsLines();
    if (task.lineIndex >= lines.length) return;

    final line = lines[task.lineIndex];
    final newCount = task.actualPomodoros + 1;
    String newLine;

    if (task.expectedPomodoros > 0) {
      // Replace existing [popcorn:: n/m]
      newLine = line.replaceFirst(
        RegExp(r'\[popcorn::\s*\d+\/\d+\]'),
        '[popcorn:: $newCount/${task.expectedPomodoros}]',
      );
      // If no match (actual-only field), replace [popcorn:: n]
      if (newLine == line) {
        newLine = line.replaceFirst(
          RegExp(r'\[popcorn::\s*\d+\]'),
          '[popcorn:: $newCount]',
        );
      }
    } else if (task.actualPomodoros > 0) {
      newLine = line.replaceFirst(
        RegExp(r'\[popcorn::\s*\d+\]'),
        '[popcorn:: $newCount]',
      );
    } else {
      // No existing field — append it before any trailing whitespace
      newLine = '${line.trimRight()} [popcorn:: $newCount]';
    }

    lines[task.lineIndex] = newLine;
    await _writeAtomic(file, lines);

    // Update in-memory list without full rescan
    final idx = _tasks.indexWhere(
      (t) => t.filePath == task.filePath && t.lineIndex == task.lineIndex,
    );
    if (idx != -1) {
      _tasks[idx] = task.copyWith(actualPomodoros: newCount);
      notifyListeners();
    }
  }

  // Marks the task checkbox as done: - [ ] → - [x]
  Future<void> markTaskComplete(ObsidianTask task) async {
    final file = File(task.filePath);
    if (!file.existsSync()) return;

    final lines = await file.readAsLines();
    if (task.lineIndex >= lines.length) return;

    lines[task.lineIndex] = lines[task.lineIndex].replaceFirst('[ ]', '[x]');
    await _writeAtomic(file, lines);
    await _scanVault();
  }

  // ── Internal ──────────────────────────────────────────────────────────────────

  Future<void> _scanVault() async {
    final path = _vaultPath;
    if (path == null) return;

    final dir = Directory(path);
    if (!dir.existsSync()) return;

    final results = <ObsidianTask>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.md')) {
        // Skip hidden dirs (e.g. .obsidian, .git)
        if (_isHiddenPath(entity.path, path)) continue;
        try {
          results.addAll(await scanFile(entity.path));
        } catch (_) {
          // Skip unreadable files silently
        }
      }
    }

    _tasks = results;
    notifyListeners();
  }

  List<ObsidianTask> _parseLines(String filePath, List<String> lines) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    final tasks = <ObsidianTask>[];

    for (var i = 0; i < lines.length; i++) {
      final match = _taskRe.firstMatch(lines[i]);
      if (match == null) continue;

      final checked = match.group(2)!.toLowerCase() == 'x';
      final title = match.group(3)!.trim();
      final actual = int.tryParse(match.group(4) ?? '') ?? 0;
      final expected = int.tryParse(match.group(5) ?? '') ?? 0;

      final blockRef = _makeBlockRef(filePath, title);

      tasks.add(ObsidianTask(
        filePath: filePath,
        fileName: fileName.replaceAll('.md', ''),
        lineIndex: i,
        rawLine: lines[i],
        title: title,
        isChecked: checked,
        actualPomodoros: actual,
        expectedPomodoros: expected,
        blockRef: blockRef,
      ));
    }

    return tasks;
  }

  // SHA-1 of filePath+title, hex-encoded — stable even if line number shifts.
  String _makeBlockRef(String filePath, String title) {
    final bytes = utf8.encode('$filePath|$title');
    return sha1.convert(bytes).toString();
  }

  bool _isHiddenPath(String filePath, String vaultRoot) {
    final relative = filePath.substring(vaultRoot.length);
    return relative.split(Platform.pathSeparator).any(
          (segment) => segment.startsWith('.'),
        );
  }

  void _startWatcher() {
    _watcher?.cancel();
    final path = _vaultPath;
    if (path == null) return;

    _watcher = Directory(path)
        .watch(recursive: true)
        .where((e) => e.path.endsWith('.md'))
        .listen((_) {
      // Debounce rapid saves (e.g. Obsidian auto-save on every keystroke)
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), _scanVault);
    });
  }

  // Atomic write: write to .tmp then rename, preventing partial file writes.
  Future<void> _writeAtomic(File file, List<String> lines) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(lines.join('\n'));
    await tmp.rename(file.path);
  }

  @override
  void dispose() {
    _watcher?.cancel();
    _debounce?.cancel();
    super.dispose();
  }
}
