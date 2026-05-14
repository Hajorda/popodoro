import 'dart:convert';

import '../database/app_database.dart';

enum ProjectType { native, obsidian }

extension ProjectTypeX on ProjectType {
  String get value => name; // 'native' | 'obsidian'
  static ProjectType fromString(String s) =>
      s == 'obsidian' ? ProjectType.obsidian : ProjectType.native;
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    required this.createdAt,
    this.obsidianPaths = const [],
    this.archived = false,
    this.totalPomodoros = 0,
    this.completedTasks = 0,
    this.totalTasks = 0,
  });

  final String id;
  final String name;
  final String color; // hex e.g. '#7BB893'
  final ProjectType type;

  // One or more absolute paths to .md files (Obsidian projects).
  // Stored as a JSON array in the obsidian_path column.
  final List<String> obsidianPaths;

  final DateTime createdAt;
  final bool archived;

  // Computed stats (populated by ProjectService)
  final int totalPomodoros;
  final int completedTasks;
  final int totalTasks;

  bool get isObsidian => type == ProjectType.obsidian;

  // Convenience — first file path (legacy callers)
  String? get obsidianPath =>
      obsidianPaths.isNotEmpty ? obsidianPaths.first : null;

  Project copyWith({
    String? name,
    String? color,
    List<String>? obsidianPaths,
    bool? archived,
    int? totalPomodoros,
    int? completedTasks,
    int? totalTasks,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        type: type,
        obsidianPaths: obsidianPaths ?? this.obsidianPaths,
        createdAt: createdAt,
        archived: archived ?? this.archived,
        totalPomodoros: totalPomodoros ?? this.totalPomodoros,
        completedTasks: completedTasks ?? this.completedTasks,
        totalTasks: totalTasks ?? this.totalTasks,
      );

  factory Project.fromRow(ProjectRow row) {
    final paths = _decodePaths(row.obsidianPath);
    return Project(
      id: row.id,
      name: row.name,
      color: row.color,
      type: ProjectTypeX.fromString(row.type),
      obsidianPaths: paths,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      archived: row.archived,
    );
  }

  ProjectRow toRow() => ProjectRow(
        id: id,
        name: name,
        color: color,
        type: type.value,
        obsidianPath: obsidianPaths.isEmpty
            ? null
            : jsonEncode(obsidianPaths),
        createdAt: createdAt.millisecondsSinceEpoch,
        archived: archived,
      );

  static List<String> _decodePaths(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
      // Legacy: plain single path
      return [raw];
    } catch (_) {
      return [raw]; // Legacy plain path
    }
  }
}

class ProjectTask {
  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    required this.createdAt,
    this.expectedPomodoros = 0,
    this.actualPomodoros = 0,
    this.isCompleted = false,
  });

  final String id;
  final String projectId;
  final String title;
  final int expectedPomodoros;
  final int actualPomodoros; // populated from task_pomodoros count
  final bool isCompleted;
  final DateTime createdAt;

  double get progress {
    if (expectedPomodoros == 0) return 0;
    return (actualPomodoros / expectedPomodoros).clamp(0.0, 1.0);
  }

  ProjectTask copyWith({int? actualPomodoros, bool? isCompleted}) =>
      ProjectTask(
        id: id,
        projectId: projectId,
        title: title,
        expectedPomodoros: expectedPomodoros,
        actualPomodoros: actualPomodoros ?? this.actualPomodoros,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt,
      );

  factory ProjectTask.fromRow(ProjectTaskRow row, {int actualPomodoros = 0}) =>
      ProjectTask(
        id: row.id,
        projectId: row.projectId,
        title: row.title,
        expectedPomodoros: row.expectedPomodoros,
        actualPomodoros: actualPomodoros,
        isCompleted: row.isCompleted,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      );

  ProjectTaskRow toRow() => ProjectTaskRow(
        id: id,
        projectId: projectId,
        title: title,
        expectedPomodoros: expectedPomodoros,
        isCompleted: isCompleted,
        createdAt: createdAt.millisecondsSinceEpoch,
      );
}

class TaskPomodoro {
  const TaskPomodoro({
    required this.id,
    required this.taskRef,
    required this.projectId,
    required this.sessionId,
    required this.completedAt,
    required this.durationMinutes,
  });

  final String id;
  final String taskRef;
  final String projectId;
  final String sessionId;
  final DateTime completedAt;
  final int durationMinutes;

  factory TaskPomodoro.fromRow(TaskPomodoroRow row) => TaskPomodoro(
        id: row.id,
        taskRef: row.taskRef,
        projectId: row.projectId,
        sessionId: row.sessionId,
        completedAt: DateTime.fromMillisecondsSinceEpoch(row.completedAt),
        durationMinutes: row.durationMinutes,
      );

  TaskPomodoroRow toRow() => TaskPomodoroRow(
        id: id,
        taskRef: taskRef,
        projectId: projectId,
        sessionId: sessionId,
        completedAt: completedAt.millisecondsSinceEpoch,
        durationMinutes: durationMinutes,
      );
}
