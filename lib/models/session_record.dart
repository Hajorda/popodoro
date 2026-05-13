import 'dart:convert';

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.startTime,
    required this.durationMinutes,
    this.taskName,
  });

  final String id;
  final DateTime startTime;
  final int durationMinutes;
  final String? taskName;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startTime': startTime.millisecondsSinceEpoch,
    'durationMinutes': durationMinutes,
    if (taskName != null && taskName!.isNotEmpty) 'taskName': taskName,
  };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    id: json['id'] as String,
    startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime'] as int),
    durationMinutes: json['durationMinutes'] as int,
    taskName: json['taskName'] as String?,
  );

  static List<SessionRecord> decodeList(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => SessionRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String encodeList(List<SessionRecord> sessions) =>
      jsonEncode(sessions.map((s) => s.toJson()).toList());
}
