import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/project.dart';
import '../services/obsidian_service.dart';
import '../services/project_service.dart';

const _uuid = Uuid();

// Holds either a native ProjectTask or an Obsidian task — never both.
class ActiveTask {
  ActiveTask.native(ProjectTask task)
      : nativeTask = task,
        obsidianTask = null,
        taskRef = task.id,
        title = task.title;

  ActiveTask.obsidian(ObsidianTask task)
      : nativeTask = null,
        obsidianTask = task,
        taskRef = task.blockRef,
        title = task.title;

  final ProjectTask? nativeTask;
  final ObsidianTask? obsidianTask;
  final String taskRef;
  final String title;

  bool get isNative => nativeTask != null;
}

class ProjectController extends ChangeNotifier {
  ProjectController({
    required ProjectService projectService,
    required ObsidianService obsidianService,
  })  : _projectService = projectService,
        _obsidianService = obsidianService {
    _obsidianService.addListener(_onObsidianChanged);
    _load();
  }

  final ProjectService _projectService;
  final ObsidianService _obsidianService;

  List<Project> _projects = [];
  Project? _activeProject;
  ActiveTask? _activeTask;
  List<ProjectTask> _nativeTasks = [];
  bool _loading = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────────

  List<Project> get projects => _projects;
  Project? get activeProject => _activeProject;
  ActiveTask? get activeTask => _activeTask;
  bool get loading => _loading;
  String? get error => _error;

  // Tasks for the currently selected project
  List<ProjectTask> get nativeTasks => _nativeTasks;
  List<ObsidianTask> get obsidianTasks {
    final project = _activeProject;
    if (project == null || !project.isObsidian || project.obsidianPaths.isEmpty) {
      return _obsidianService.pendingTasks;
    }
    return _obsidianService.pendingTasks
        .where((t) => project.obsidianPaths.any((p) => t.filePath == p))
        .toList();
  }

  // ── Project selection ─────────────────────────────────────────────────────────

  Future<void> selectProject(Project project) async {
    _activeProject = project;
    _activeTask = null;
    _nativeTasks = [];
    notifyListeners();

    if (!project.isObsidian) {
      _nativeTasks = await _projectService.fetchTasks(project.id);
      notifyListeners();
    }
  }

  void selectNativeTask(ProjectTask task) {
    _activeTask = ActiveTask.native(task);
    notifyListeners();
  }

  void selectObsidianTask(ObsidianTask task) {
    _activeTask = ActiveTask.obsidian(task);
    notifyListeners();
  }

  void clearSelection() {
    _activeProject = null;
    _activeTask = null;
    _nativeTasks = [];
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────────

  Future<Project?> createProject({
    required String name,
    required String color,
    required ProjectType type,
    List<String> obsidianPaths = const [],
  }) async {
    _error = null;
    try {
      final project = await _projectService.createProject(
        id: _uuid.v4(),
        name: name,
        color: color,
        type: type,
        obsidianPaths: obsidianPaths,
      );
      await _load();
      return project;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<ProjectTask?> addTask({
    required String title,
    int expectedPomodoros = 0,
  }) async {
    final project = _activeProject;
    if (project == null || project.isObsidian) return null;
    _error = null;
    try {
      final task = await _projectService.addTask(
        id: _uuid.v4(),
        projectId: project.id,
        title: title,
        expectedPomodoros: expectedPomodoros,
      );
      _nativeTasks = await _projectService.fetchTasks(project.id);
      await _load();
      return task;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> completeTask(String taskId) async {
    await _projectService.completeTask(taskId);
    if (_activeProject != null) {
      _nativeTasks = await _projectService.fetchTasks(_activeProject!.id);
    }
    if (_activeTask?.taskRef == taskId) {
      _activeTask = null;
    }
    await _load();
  }

  Future<void> deleteTask(String taskId) async {
    await _projectService.deleteTask(taskId);
    if (_activeProject != null) {
      _nativeTasks = await _projectService.fetchTasks(_activeProject!.id);
    }
    if (_activeTask?.taskRef == taskId) _activeTask = null;
    await _load();
  }

  Future<void> archiveProject(String id) async {
    await _projectService.archiveProject(id);
    if (_activeProject?.id == id) clearSelection();
    await _load();
  }

  // ── Session completion hook ───────────────────────────────────────────────────

  // Called by TimerController's onSessionComplete. Records the pomodoro in DB
  // and, for Obsidian tasks, writes back to the markdown file.
  Future<void> onSessionComplete({
    required String sessionId,
    required int durationMinutes,
  }) async {
    final project = _activeProject;
    final task = _activeTask;
    if (project == null || task == null) return;

    // Record in SQLite
    await _projectService.recordPomodoro(
      id: _uuid.v4(),
      taskRef: task.taskRef,
      projectId: project.id,
      sessionId: sessionId,
      durationMinutes: durationMinutes,
    );

    // Write back to Obsidian file
    if (task.obsidianTask != null) {
      await _obsidianService.incrementPomodoro(task.obsidianTask!);
    }

    // Refresh native task counts
    if (!project.isObsidian) {
      _nativeTasks = await _projectService.fetchTasks(project.id);
    }

    await _load();
  }

  // ── Internal ──────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    _loading = true;
    notifyListeners();
    try {
      _projects = await _projectService.fetchProjects();
      // Refresh active project stats if one is selected
      if (_activeProject != null) {
        final refreshed = _projects.where((p) => p.id == _activeProject!.id);
        if (refreshed.isNotEmpty) _activeProject = refreshed.first;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onObsidianChanged() => notifyListeners();

  @override
  void dispose() {
    _obsidianService.removeListener(_onObsidianChanged);
    super.dispose();
  }
}
