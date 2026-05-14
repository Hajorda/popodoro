import '../database/app_database.dart';
import '../models/project.dart';

class ProjectService {
  ProjectService(this._db);

  final AppDatabase _db;

  // ── Projects ──────────────────────────────────────────────────────────────────

  Future<List<Project>> fetchProjects({bool includeArchived = false}) async {
    final rows = await _db.fetchProjects(includeArchived: includeArchived);
    final projects = <Project>[];

    for (final row in rows) {
      final pomodoros = await _db.fetchPomodorosForProject(row.id);
      final tasks = await _db.fetchTasksForProject(row.id);
      final completed = tasks.where((t) => t.isCompleted).length;

      projects.add(
        Project.fromRow(row).copyWith(
          totalPomodoros: pomodoros.length,
          completedTasks: completed,
          totalTasks: tasks.length,
        ),
      );
    }

    return projects;
  }

  Future<Project> createProject({
    required String id,
    required String name,
    required String color,
    required ProjectType type,
    List<String> obsidianPaths = const [],
  }) async {
    final project = Project(
      id: id,
      name: name,
      color: color,
      type: type,
      obsidianPaths: obsidianPaths,
      createdAt: DateTime.now(),
    );
    await _db.upsertProject(project.toRow());
    return project;
  }

  Future<void> updateProjectName(String id, String name) async {
    final rows = await _db.fetchProjects(includeArchived: true);
    final row = rows.firstWhere((r) => r.id == id);
    await _db.upsertProject(ProjectRow(
      id: row.id,
      name: name,
      color: row.color,
      type: row.type,
      obsidianPath: row.obsidianPath,
      createdAt: row.createdAt,
      archived: row.archived,
    ));
  }

  Future<void> archiveProject(String id) => _db.archiveProject(id);

  Future<void> deleteProject(String id) => _db.deleteProject(id);

  // ── Tasks ─────────────────────────────────────────────────────────────────────

  Future<List<ProjectTask>> fetchTasks(String projectId) async {
    final rows = await _db.fetchTasksForProject(projectId);
    final tasks = <ProjectTask>[];

    for (final row in rows) {
      final count = await _db.countPomodorosForTask(row.id);
      tasks.add(ProjectTask.fromRow(row, actualPomodoros: count));
    }

    return tasks;
  }

  Future<ProjectTask> addTask({
    required String id,
    required String projectId,
    required String title,
    int expectedPomodoros = 0,
  }) async {
    final task = ProjectTask(
      id: id,
      projectId: projectId,
      title: title,
      expectedPomodoros: expectedPomodoros,
      createdAt: DateTime.now(),
    );
    await _db.upsertProjectTask(task.toRow());
    return task;
  }

  Future<void> completeTask(String taskId) => _db.completeTask(taskId);

  Future<void> deleteTask(String taskId) => _db.deleteTask(taskId);

  // ── Pomodoros ─────────────────────────────────────────────────────────────────

  Future<void> recordPomodoro({
    required String id,
    required String taskRef,
    required String projectId,
    required String sessionId,
    required int durationMinutes,
  }) =>
      _db.insertTaskPomodoro(TaskPomodoroRow(
        id: id,
        taskRef: taskRef,
        projectId: projectId,
        sessionId: sessionId,
        completedAt: DateTime.now().millisecondsSinceEpoch,
        durationMinutes: durationMinutes,
      ));

  Future<int> pomodoroCount(String taskRef) =>
      _db.countPomodorosForTask(taskRef);

  Future<List<TaskPomodoro>> historyForTask(String taskRef) async {
    final rows = await _db.fetchPomodorosForTask(taskRef);
    return rows.map(TaskPomodoro.fromRow).toList();
  }

  Future<List<TaskPomodoro>> historyForProject(String projectId) async {
    final rows = await _db.fetchPomodorosForProject(projectId);
    return rows.map(TaskPomodoro.fromRow).toList();
  }
}
