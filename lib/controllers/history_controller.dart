import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_record.dart';

class DayStats {
  const DayStats({required this.date, required this.count, required this.minutes});
  final DateTime date;
  final int count;
  final int minutes;
}

class PeakHour {
  const PeakHour({required this.hour, required this.minutes, required this.sessions});
  final int hour;      // 0–23
  final int minutes;
  final int sessions;
}

class HistoryController extends ChangeNotifier {
  HistoryController({required SharedPreferences prefs}) : _prefs = prefs {
    _load();
  }

  final SharedPreferences _prefs;
  List<SessionRecord> _sessions = [];

  static const _kSessions = 'sessionHistory';

  // ── Public data ──────────────────────────────────────────────────────────────

  List<SessionRecord> get allSessions => List.unmodifiable(_sessions);

  List<SessionRecord> get todaySessions {
    final now = DateTime.now();
    return _sessions.where((s) => _isSameDay(s.startTime, now)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  int get totalFocusedMinutesToday =>
      todaySessions.fold(0, (sum, s) => sum + s.durationMinutes);

  int get totalFocusedMinutesAllTime =>
      _sessions.fold(0, (sum, s) => sum + s.durationMinutes);

  int get streakDays {
    if (_sessions.isEmpty) return 0;
    final days = _sessions.map((s) => _dayKey(s.startTime)).toSet();
    var streak = 0;
    var cursor = DateTime.now();
    while (true) {
      if (days.contains(_dayKey(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (streak == 0) {
        // Allow today to not have sessions yet
        cursor = cursor.subtract(const Duration(days: 1));
        if (!days.contains(_dayKey(cursor))) break;
      } else {
        break;
      }
    }
    return streak;
  }

  // Last 7 days including today, oldest first.
  List<DayStats> get last7Days {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final daySessions = _sessions.where((s) => _isSameDay(s.startTime, day)).toList();
      return DayStats(
        date: day,
        count: daySessions.length,
        minutes: daySessions.fold(0, (sum, s) => sum + s.durationMinutes),
      );
    });
  }

  // Top peak hours sorted by total focused minutes (last 30 days).
  List<PeakHour> get peakHours {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = _sessions.where((s) => s.startTime.isAfter(cutoff)).toList();
    final byHour = <int, List<SessionRecord>>{};
    for (final s in recent) {
      byHour.putIfAbsent(s.startTime.hour, () => []).add(s);
    }
    final peaks = byHour.entries.map((e) => PeakHour(
      hour: e.key,
      minutes: e.value.fold(0, (sum, s) => sum + s.durationMinutes),
      sessions: e.value.length,
    )).toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    return peaks.take(3).toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  Future<void> record(SessionRecord session) async {
    _sessions.add(session);
    await _save();
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────────

  void _load() {
    final raw = _prefs.getString(_kSessions);
    if (raw != null) {
      try {
        _sessions = SessionRecord.decodeList(raw);
      } catch (_) {
        _sessions = [];
      }
    }
  }

  Future<void> _save() async {
    await _prefs.setString(_kSessions, SessionRecord.encodeList(_sessions));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
