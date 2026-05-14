import 'dart:convert';

import '../database/app_database.dart';

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.startTime,
    required this.durationMinutes,
    this.taskName,
    this.tag,
    this.projectId,
    this.taskRef,
  });

  final String id;
  final DateTime startTime;
  final int durationMinutes;
  final String? taskName;
  final String? tag;
  final String? projectId;
  final String? taskRef;

  // ── Database bridge ───────────────────────────────────────────────────────────

  factory SessionRecord.fromRow(SessionRow row) => SessionRecord(
        id: row.id,
        startTime: DateTime.fromMillisecondsSinceEpoch(row.startTimeMs),
        durationMinutes: row.durationMinutes,
        taskName: row.taskName,
        tag: row.tag,
        projectId: row.projectId,
        taskRef: row.taskRef,
      );

  SessionRow toRow({bool synced = false}) => SessionRow(
        id: id,
        startTimeMs: startTime.millisecondsSinceEpoch,
        durationMinutes: durationMinutes,
        taskName: taskName,
        tag: tag,
        projectId: projectId,
        taskRef: taskRef,
        syncedToCloud: synced,
      );

  // ── Legacy JSON (SharedPreferences migration only) ────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.millisecondsSinceEpoch,
        'durationMinutes': durationMinutes,
        if (taskName != null && taskName!.isNotEmpty) 'taskName': taskName,
        if (tag != null && tag!.isNotEmpty) 'tag': tag,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String,
        startTime:
            DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
        durationMinutes: json['durationMinutes'] as int,
        taskName: json['taskName'] as String?,
        tag: json['tag'] as String?,
      );

  static List<SessionRecord> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
