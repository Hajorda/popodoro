import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'popodoro'));
    await dbDir.create(recursive: true);

    final db = await databaseFactory.openDatabase(
      p.join(dbDir.path, 'sessions.db'),
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await _createAllTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS detection_events (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id    TEXT NOT NULL,
                timestamp_ms  INTEGER NOT NULL,
                type          TEXT NOT NULL,
                confidence    REAL NOT NULL DEFAULT 0.0
              )
            ''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_detection_session ON detection_events(session_id)',
            );
          }
          if (oldVersion < 3) {
            await db.execute('ALTER TABLE sessions ADD COLUMN tag TEXT');
          }
          if (oldVersion < 4) {
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN project_id TEXT',
            );
            await db.execute(
              'ALTER TABLE sessions ADD COLUMN task_ref TEXT',
            );
            await db.execute('''
              CREATE TABLE projects (
                id            TEXT PRIMARY KEY,
                name          TEXT NOT NULL,
                color         TEXT NOT NULL,
                type          TEXT NOT NULL,
                obsidian_path TEXT,
                created_at    INTEGER NOT NULL,
                archived      INTEGER NOT NULL DEFAULT 0
              )
            ''');
            await db.execute('''
              CREATE TABLE project_tasks (
                id                 TEXT PRIMARY KEY,
                project_id         TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                title              TEXT NOT NULL,
                expected_pomodoros INTEGER NOT NULL DEFAULT 0,
                is_completed       INTEGER NOT NULL DEFAULT 0,
                created_at         INTEGER NOT NULL
              )
            ''');
            await db.execute('''
              CREATE TABLE task_pomodoros (
                id               TEXT PRIMARY KEY,
                task_ref         TEXT NOT NULL,
                project_id       TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                session_id       TEXT NOT NULL,
                completed_at     INTEGER NOT NULL,
                duration_minutes INTEGER NOT NULL
              )
            ''');
            await db.execute(
              'CREATE INDEX idx_task_pomodoros_project  ON task_pomodoros(project_id)',
            );
            await db.execute(
              'CREATE INDEX idx_task_pomodoros_task_ref ON task_pomodoros(task_ref)',
            );
            await db.execute(
              'CREATE INDEX idx_project_tasks_project   ON project_tasks(project_id)',
            );
            await db.execute(
              'CREATE INDEX idx_sessions_project        ON sessions(project_id)',
            );
          }
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _createAllTables(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id               TEXT PRIMARY KEY,
        start_time_ms    INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        task_name        TEXT,
        tag              TEXT,
        project_id       TEXT,
        task_ref         TEXT,
        synced_to_cloud  INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE detection_events (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id    TEXT NOT NULL,
        timestamp_ms  INTEGER NOT NULL,
        type          TEXT NOT NULL,
        confidence    REAL NOT NULL DEFAULT 0.0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_detection_session ON detection_events(session_id)',
    );
    await db.execute('''
      CREATE TABLE projects (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        color         TEXT NOT NULL,
        type          TEXT NOT NULL,
        obsidian_path TEXT,
        created_at    INTEGER NOT NULL,
        archived      INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE project_tasks (
        id                 TEXT PRIMARY KEY,
        project_id         TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        title              TEXT NOT NULL,
        expected_pomodoros INTEGER NOT NULL DEFAULT 0,
        is_completed       INTEGER NOT NULL DEFAULT 0,
        created_at         INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE task_pomodoros (
        id               TEXT PRIMARY KEY,
        task_ref         TEXT NOT NULL,
        project_id       TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        session_id       TEXT NOT NULL,
        completed_at     INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_task_pomodoros_project  ON task_pomodoros(project_id)',
    );
    await db.execute(
      'CREATE INDEX idx_task_pomodoros_task_ref ON task_pomodoros(task_ref)',
    );
    await db.execute(
      'CREATE INDEX idx_project_tasks_project   ON project_tasks(project_id)',
    );
    await db.execute(
      'CREATE INDEX idx_sessions_project        ON sessions(project_id)',
    );
  }

  static Future<AppDatabase> openInMemory() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, _) async {
          await _createAllTables(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  // ── Sessions DAO ──────────────────────────────────────────────────────────────

  Future<void> upsertSession(SessionRow row) => _db.insert(
        'sessions',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<SessionRow>> fetchAll() async {
    final maps = await _db.query('sessions', orderBy: 'start_time_ms DESC');
    return maps.map(SessionRow.fromMap).toList();
  }

  Future<List<SessionRow>> fetchUnsynced() async {
    final maps = await _db.query('sessions', where: 'synced_to_cloud = 0');
    return maps.map(SessionRow.fromMap).toList();
  }

  Future<void> markSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.rawUpdate(
      'UPDATE sessions SET synced_to_cloud = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  // ── Detection events DAO ──────────────────────────────────────────────────────

  Future<void> insertDetectionEvent(DetectionEventRow row) => _db.insert(
        'detection_events',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<DetectionEventRow>> fetchEventsForSession(String sessionId) async {
    final maps = await _db.query(
      'detection_events',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp_ms ASC',
    );
    return maps.map(DetectionEventRow.fromMap).toList();
  }

  /// Returns events grouped by session_id with counts, newest session first.
  Future<List<DetectionSummaryRow>> fetchDetectionSummaries({int limit = 60}) async {
    final maps = await _db.rawQuery('''
      SELECT
        session_id,
        MIN(timestamp_ms) AS session_ms,
        SUM(CASE WHEN type = 'no_person' THEN 1 ELSE 0 END) AS no_person_count,
        SUM(CASE WHEN type = 'phone' THEN 1 ELSE 0 END) AS phone_count,
        COUNT(*) AS total_count
      FROM detection_events
      GROUP BY session_id
      ORDER BY session_ms DESC
      LIMIT ?
    ''', [limit]);
    return maps.map(DetectionSummaryRow.fromMap).toList();
  }

  // ── Projects DAO ─────────────────────────────────────────────────────────────

  Future<void> upsertProject(ProjectRow row) => _db.insert(
        'projects',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<ProjectRow>> fetchProjects({bool includeArchived = false}) async {
    final maps = await _db.query(
      'projects',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'created_at ASC',
    );
    return maps.map(ProjectRow.fromMap).toList();
  }

  Future<void> archiveProject(String id) => _db.update(
        'projects',
        {'archived': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> deleteProject(String id) => _db.delete(
        'projects',
        where: 'id = ?',
        whereArgs: [id],
      );

  // ── Project tasks DAO ─────────────────────────────────────────────────────────

  Future<void> upsertProjectTask(ProjectTaskRow row) => _db.insert(
        'project_tasks',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<ProjectTaskRow>> fetchTasksForProject(String projectId) async {
    final maps = await _db.query(
      'project_tasks',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );
    return maps.map(ProjectTaskRow.fromMap).toList();
  }

  Future<void> completeTask(String taskId) => _db.update(
        'project_tasks',
        {'is_completed': 1},
        where: 'id = ?',
        whereArgs: [taskId],
      );

  Future<void> deleteTask(String taskId) => _db.delete(
        'project_tasks',
        where: 'id = ?',
        whereArgs: [taskId],
      );

  // ── Task pomodoros DAO ────────────────────────────────────────────────────────

  Future<void> insertTaskPomodoro(TaskPomodoroRow row) => _db.insert(
        'task_pomodoros',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<TaskPomodoroRow>> fetchPomodorosForTask(String taskRef) async {
    final maps = await _db.query(
      'task_pomodoros',
      where: 'task_ref = ?',
      whereArgs: [taskRef],
      orderBy: 'completed_at DESC',
    );
    return maps.map(TaskPomodoroRow.fromMap).toList();
  }

  Future<List<TaskPomodoroRow>> fetchPomodorosForProject(
    String projectId,
  ) async {
    final maps = await _db.query(
      'task_pomodoros',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'completed_at DESC',
    );
    return maps.map(TaskPomodoroRow.fromMap).toList();
  }

  Future<int> countPomodorosForTask(String taskRef) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as c FROM task_pomodoros WHERE task_ref = ?',
      [taskRef],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> close() => _db.close();
}

// ── Row models ────────────────────────────────────────────────────────────────

class SessionRow {
  const SessionRow({
    required this.id,
    required this.startTimeMs,
    required this.durationMinutes,
    this.taskName,
    this.tag,
    this.projectId,
    this.taskRef,
    this.syncedToCloud = false,
  });

  final String id;
  final int startTimeMs;
  final int durationMinutes;
  final String? taskName;
  final String? tag;
  final String? projectId;
  final String? taskRef;
  final bool syncedToCloud;

  Map<String, Object?> toMap() => {
        'id': id,
        'start_time_ms': startTimeMs,
        'duration_minutes': durationMinutes,
        'task_name': taskName,
        'tag': tag,
        'project_id': projectId,
        'task_ref': taskRef,
        'synced_to_cloud': syncedToCloud ? 1 : 0,
      };

  factory SessionRow.fromMap(Map<String, Object?> m) => SessionRow(
        id: m['id'] as String,
        startTimeMs: m['start_time_ms'] as int,
        durationMinutes: m['duration_minutes'] as int,
        taskName: m['task_name'] as String?,
        tag: m['tag'] as String?,
        projectId: m['project_id'] as String?,
        taskRef: m['task_ref'] as String?,
        syncedToCloud: (m['synced_to_cloud'] as int) == 1,
      );
}

// ── Project row models ────────────────────────────────────────────────────────

class ProjectRow {
  const ProjectRow({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
    required this.createdAt,
    this.obsidianPath,
    this.archived = false,
  });

  final String id;
  final String name;
  final String color;
  final String type; // 'native' | 'obsidian'
  final String? obsidianPath;
  final int createdAt;
  final bool archived;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'type': type,
        'obsidian_path': obsidianPath,
        'created_at': createdAt,
        'archived': archived ? 1 : 0,
      };

  factory ProjectRow.fromMap(Map<String, Object?> m) => ProjectRow(
        id: m['id'] as String,
        name: m['name'] as String,
        color: m['color'] as String,
        type: m['type'] as String,
        obsidianPath: m['obsidian_path'] as String?,
        createdAt: m['created_at'] as int,
        archived: (m['archived'] as int) == 1,
      );
}

class ProjectTaskRow {
  const ProjectTaskRow({
    required this.id,
    required this.projectId,
    required this.title,
    required this.createdAt,
    this.expectedPomodoros = 0,
    this.isCompleted = false,
  });

  final String id;
  final String projectId;
  final String title;
  final int expectedPomodoros;
  final bool isCompleted;
  final int createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'expected_pomodoros': expectedPomodoros,
        'is_completed': isCompleted ? 1 : 0,
        'created_at': createdAt,
      };

  factory ProjectTaskRow.fromMap(Map<String, Object?> m) => ProjectTaskRow(
        id: m['id'] as String,
        projectId: m['project_id'] as String,
        title: m['title'] as String,
        expectedPomodoros: m['expected_pomodoros'] as int,
        isCompleted: (m['is_completed'] as int) == 1,
        createdAt: m['created_at'] as int,
      );
}

class TaskPomodoroRow {
  const TaskPomodoroRow({
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
  final int completedAt;
  final int durationMinutes;

  Map<String, Object?> toMap() => {
        'id': id,
        'task_ref': taskRef,
        'project_id': projectId,
        'session_id': sessionId,
        'completed_at': completedAt,
        'duration_minutes': durationMinutes,
      };

  factory TaskPomodoroRow.fromMap(Map<String, Object?> m) => TaskPomodoroRow(
        id: m['id'] as String,
        taskRef: m['task_ref'] as String,
        projectId: m['project_id'] as String,
        sessionId: m['session_id'] as String,
        completedAt: m['completed_at'] as int,
        durationMinutes: m['duration_minutes'] as int,
      );
}

class DetectionEventRow {
  const DetectionEventRow({
    required this.sessionId,
    required this.timestampMs,
    required this.type,
    required this.confidence,
  });

  final String sessionId;
  final int timestampMs;
  final String type; // 'no_person' | 'phone'
  final double confidence;

  Map<String, Object?> toMap() => {
        'session_id': sessionId,
        'timestamp_ms': timestampMs,
        'type': type,
        'confidence': confidence,
      };

  factory DetectionEventRow.fromMap(Map<String, Object?> m) =>
      DetectionEventRow(
        sessionId: m['session_id'] as String,
        timestampMs: m['timestamp_ms'] as int,
        type: m['type'] as String,
        confidence: (m['confidence'] as num).toDouble(),
      );
}

class DetectionSummaryRow {
  const DetectionSummaryRow({
    required this.sessionId,
    required this.sessionMs,
    required this.noPersonCount,
    required this.phoneCount,
    required this.totalCount,
  });

  final String sessionId;
  final int sessionMs;
  final int noPersonCount;
  final int phoneCount;
  final int totalCount;

  factory DetectionSummaryRow.fromMap(Map<String, Object?> m) =>
      DetectionSummaryRow(
        sessionId: m['session_id'] as String,
        sessionMs: (m['session_ms'] as num).toInt(),
        noPersonCount: (m['no_person_count'] as num).toInt(),
        phoneCount: (m['phone_count'] as num).toInt(),
        totalCount: (m['total_count'] as num).toInt(),
      );
}
