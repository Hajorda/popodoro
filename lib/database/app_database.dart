import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Thin wrapper around an SQLite database via sqflite_common_ffi.
///
/// Schema (v1):
///   sessions(id TEXT PK, start_time_ms INTEGER, duration_minutes INTEGER,
///            task_name TEXT, synced_to_cloud INTEGER DEFAULT 0)
///
/// All methods are safe to call from any isolate — sqflite serialises access.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  // ── Factory ───────────────────────────────────────────────────────────────────

  static Future<AppDatabase> open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(dir.path, 'popodoro'));
    await dbDir.create(recursive: true);

    final db = await databaseFactory.openDatabase(
      p.join(dbDir.path, 'sessions.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE sessions (
            id               TEXT PRIMARY KEY,
            start_time_ms    INTEGER NOT NULL,
            duration_minutes INTEGER NOT NULL,
            task_name        TEXT,
            synced_to_cloud  INTEGER NOT NULL DEFAULT 0
          )
        '''),
      ),
    );
    return AppDatabase._(db);
  }

  /// In-memory database for tests — no file I/O.
  static Future<AppDatabase> openInMemory() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE sessions (
            id               TEXT PRIMARY KEY,
            start_time_ms    INTEGER NOT NULL,
            duration_minutes INTEGER NOT NULL,
            task_name        TEXT,
            synced_to_cloud  INTEGER NOT NULL DEFAULT 0
          )
        '''),
      ),
    );
    return AppDatabase._(db);
  }

  // ── DAO ───────────────────────────────────────────────────────────────────────

  Future<void> upsertSession(SessionRow row) => _db.insert(
        'sessions',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<SessionRow>> fetchAll() async {
    final maps = await _db.query(
      'sessions',
      orderBy: 'start_time_ms DESC',
    );
    return maps.map(SessionRow.fromMap).toList();
  }

  Future<List<SessionRow>> fetchUnsynced() async {
    final maps = await _db.query(
      'sessions',
      where: 'synced_to_cloud = 0',
    );
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

  Future<void> close() => _db.close();
}

// ── Row model ─────────────────────────────────────────────────────────────────

class SessionRow {
  const SessionRow({
    required this.id,
    required this.startTimeMs,
    required this.durationMinutes,
    this.taskName,
    this.syncedToCloud = false,
  });

  final String id;
  final int startTimeMs;
  final int durationMinutes;
  final String? taskName;
  final bool syncedToCloud;

  Map<String, Object?> toMap() => {
        'id': id,
        'start_time_ms': startTimeMs,
        'duration_minutes': durationMinutes,
        'task_name': taskName,
        'synced_to_cloud': syncedToCloud ? 1 : 0,
      };

  factory SessionRow.fromMap(Map<String, Object?> m) => SessionRow(
        id: m['id'] as String,
        startTimeMs: m['start_time_ms'] as int,
        durationMinutes: m['duration_minutes'] as int,
        taskName: m['task_name'] as String?,
        syncedToCloud: (m['synced_to_cloud'] as int) == 1,
      );
}
