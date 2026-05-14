import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/session_record.dart';

class DayStats {
  const DayStats({required this.date, required this.count, required this.minutes});
  final DateTime date;
  final int count;
  final int minutes;
}

class PeakHour {
  const PeakHour({required this.hour, required this.minutes, required this.sessions});
  final int hour;
  final int minutes;
  final int sessions;
}

class HistoryController extends ChangeNotifier {
  HistoryController({
    required AppDatabase db,
    SharedPreferences? legacyPrefs,
    void Function()? onNewSession,
  })  : _db = db,
        _onNewSession = onNewSession {
    _init(legacyPrefs);
  }

  final AppDatabase _db;
  final void Function()? _onNewSession;
  List<SessionRecord> _sessions = [];

  // ── Init ──────────────────────────────────────────────────────────────────────

  Future<void> _init(SharedPreferences? prefs) async {
    await _migrateFromPrefs(prefs);
    await _load();
  }

  /// One-time migration: reads the old SharedPreferences JSON blob, inserts
  /// each record into SQLite, then removes the key so this never runs again.
  Future<void> _migrateFromPrefs(SharedPreferences? prefs) async {
    if (prefs == null) return;
    const key = 'sessionHistory';
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final old = SessionRecord.decodeList(raw);
      for (final s in old) {
        await _db.upsertSession(s.toRow());
      }
      await prefs.remove(key);
    } catch (_) {
      // Corrupt legacy data — discard silently.
    }
  }

  Future<void> _load() async {
    final rows = await _db.fetchAll();
    _sessions = rows.map(SessionRecord.fromRow).toList();
    notifyListeners();
  }

  // ── Public data ───────────────────────────────────────────────────────────────

  List<SessionRecord> get allSessions => List.unmodifiable(_sessions);

  List<SessionRecord> get todaySessions {
    final now = DateTime.now();
    return _sessions
        .where((s) => _isSameDay(s.startTime, now))
        .toList()
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
        cursor = cursor.subtract(const Duration(days: 1));
        if (!days.contains(_dayKey(cursor))) break;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Last 7 days including today, oldest first.
  List<DayStats> get last7Days {
    final today = DateTime.now();
    return List.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final daySessions =
          _sessions.where((s) => _isSameDay(s.startTime, day)).toList();
      return DayStats(
        date: day,
        count: daySessions.length,
        minutes: daySessions.fold(0, (sum, s) => sum + s.durationMinutes),
      );
    });
  }

  /// 7×24 intensity grid (0–3). Row = weekday-1 (0=Mon), col = hour 0–23.
  List<List<int>> get heatmap {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = _sessions.where((s) => s.startTime.isAfter(cutoff));
    final counts = List.generate(7, (_) => List.filled(24, 0));
    for (final s in recent) {
      counts[s.startTime.weekday - 1][s.startTime.hour]++;
    }
    final maxCount = counts.fold<int>(
        0, (m, row) => row.fold(m, (m2, v) => v > m2 ? v : m2));
    if (maxCount == 0) return counts;
    return counts
        .map((row) => row.map((v) {
              if (v == 0) return 0;
              if (v * 3 <= maxCount) return 1;
              if (v * 3 <= maxCount * 2) return 2;
              return 3;
            }).toList())
        .toList();
  }

  /// Top 3 peak hours by total focused minutes (last 30 days).
  List<PeakHour> get peakHours {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent =
        _sessions.where((s) => s.startTime.isAfter(cutoff)).toList();
    final byHour = <int, List<SessionRecord>>{};
    for (final s in recent) {
      byHour.putIfAbsent(s.startTime.hour, () => []).add(s);
    }
    final peaks = byHour.entries
        .map((e) => PeakHour(
              hour: e.key,
              minutes: e.value.fold(0, (sum, s) => sum + s.durationMinutes),
              sessions: e.value.length,
            ))
        .toList()
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
    return peaks.take(3).toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  Future<void> record(SessionRecord session) async {
    await _db.upsertSession(session.toRow());
    _sessions.insert(0, session);
    notifyListeners();
    _onNewSession?.call();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
