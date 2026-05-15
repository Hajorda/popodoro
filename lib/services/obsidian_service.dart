import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bookmark_service.dart';

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
    _restoreVault();
  }

  // ── Prefs keys ────────────────────────────────────────────────────────────────
  static const _kVaultPath = 'obsidian_vault_path';
  // Stores the security-scoped bookmark as a base64 string (macOS only).
  static const _kVaultBookmark = 'obsidian_vault_bookmark';

  // - [ ] task description [popcorn:: actual/expected]
  // - [x] completed task   [popcorn:: actual]
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

  // ── Boot: restore vault from bookmark / path ──────────────────────────────────

  Future<void> _restoreVault() async {
    final bookmark = _prefs.getString(_kVaultBookmark);
    final savedPath = _prefs.getString(_kVaultPath);

    if (bookmark != null) {
      // Preferred path: resolve the security-scoped bookmark.
      final result = await BookmarkService.resolveBookmark(bookmark);
      if (result != null) {
        _vaultPath = result.path;

        // Bookmark is stale (folder moved/renamed) — recreate it while we have
        // access so the next launch works too.
        if (result.stale) {
          final fresh = await BookmarkService.createBookmark(result.path);
          if (fresh != null) await _prefs.setString(_kVaultBookmark, fresh);
        }

        _startWatcher();
        await _scanVault();
        return;
      }
      // Bookmark resolve failed — fall through and clear stale data.
      await _prefs.remove(_kVaultBookmark);
    }

    // Fallback for non-macOS or first launch before bookmark was created.
    if (savedPath != null && Directory(savedPath).existsSync()) {
      _vaultPath = savedPath;
      _startWatcher();
      await _scanVault();
    }
  }

  // ── Vault management ──────────────────────────────────────────────────────────

  Future<void> connectVault(String path) async {
    if (!Directory(path).existsSync()) return;
    _vaultPath = path;
    await _prefs.setString(_kVaultPath, path);

    // Create a security-scoped bookmark so access survives future relaunches.
    final bookmark = await BookmarkService.createBookmark(path);
    if (bookmark != null) {
      await _prefs.setString(_kVaultBookmark, bookmark);
    }

    _startWatcher();
    await _scanVault();
    notifyListeners();
  }

  Future<void> disconnectVault() async {
    final path = _vaultPath;
    _watcher?.cancel();
    _watcher = null;
    _debounce?.cancel();
    _vaultPath = null;
    _tasks = [];
    await _prefs.remove(_kVaultPath);
    await _prefs.remove(_kVaultBookmark);
    if (path != null) await BookmarkService.stopAccessing(path);
    notifyListeners();
  }

  Future<void> refresh() => _scanVault();

  // ── File operations ────────────────────────────────────────────────────────────

  // Lets the user pick one or more .md files from the vault for a project.
  Future<List<String>> pickFiles() async {
    final results = await openFiles(
      initialDirectory: _vaultPath,
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
      newLine = line.replaceFirst(
        RegExp(r'\[popcorn::\s*\d+\/\d+\]'),
        '[popcorn:: $newCount/${task.expectedPomodoros}]',
      );
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
      newLine = '${line.trimRight()} [popcorn:: $newCount]';
    }

    lines[task.lineIndex] = newLine;
    await _writeAtomic(file, lines);

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
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.md')) {
          if (_isHiddenPath(entity.path, path)) continue;
          try {
            results.addAll(await scanFile(entity.path));
          } catch (_) {
            // Skip unreadable files silently
          }
        }
      }
    } on PathAccessException {
      // Sandbox revoked access — clear everything and let the user reconnect.
      await _hardReset();
      return;
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

  // SHA-1 of filePath+title — stable even if line number shifts.
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
        .listen(
          (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 600), _scanVault);
          },
          onError: (_) {
            // Watcher error (e.g. directory deleted) — ignore, next scan handles it.
          },
        );
  }

  // Full reset when sandbox access is revoked — stops the resource and clears prefs.
  Future<void> _hardReset() async {
    _watcher?.cancel();
    _watcher = null;
    _debounce?.cancel();
    final path = _vaultPath;
    _vaultPath = null;
    _tasks = [];
    await _prefs.remove(_kVaultPath);
    await _prefs.remove(_kVaultBookmark);
    if (path != null) await BookmarkService.stopAccessing(path);
    notifyListeners();
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
    // Stop accessing the security-scoped resource when the service is torn down.
    if (_vaultPath != null) {
      BookmarkService.stopAccessing(_vaultPath!);
    }
    super.dispose();
  }
}
