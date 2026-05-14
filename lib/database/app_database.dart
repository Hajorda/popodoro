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
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE sessions (
              id               TEXT PRIMARY KEY,
              start_time_ms    INTEGER NOT NULL,
              duration_minutes INTEGER NOT NULL,
              task_name        TEXT,
              tag              TEXT,
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
        },
      ),
    );
    return AppDatabase._(db);
  }

  static Future<AppDatabase> openInMemory() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE sessions (
              id               TEXT PRIMARY KEY,
              start_time_ms    INTEGER NOT NULL,
              duration_minutes INTEGER NOT NULL,
              task_name        TEXT,
              tag              TEXT,
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
    this.syncedToCloud = false,
  });

  final String id;
  final int startTimeMs;
  final int durationMinutes;
  final String? taskName;
  final String? tag;
  final bool syncedToCloud;

  Map<String, Object?> toMap() => {
        'id': id,
        'start_time_ms': startTimeMs,
        'duration_minutes': durationMinutes,
        'task_name': taskName,
        'tag': tag,
        'synced_to_cloud': syncedToCloud ? 1 : 0,
      };

  factory SessionRow.fromMap(Map<String, Object?> m) => SessionRow(
        id: m['id'] as String,
        startTimeMs: m['start_time_ms'] as int,
        durationMinutes: m['duration_minutes'] as int,
        taskName: m['task_name'] as String?,
        tag: m['tag'] as String?,
        syncedToCloud: (m['synced_to_cloud'] as int) == 1,
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
