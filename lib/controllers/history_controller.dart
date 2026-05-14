import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/session_record.dart';

enum StatsPeriod { week, month, year, all }

class DayStats {
  const DayStats({required this.date, required this.count, required this.minutes});
  final DateTime date;
  final int count;
  final int minutes;
}

class BarEntry {
  const BarEntry({required this.label, required this.minutes, this.isHighlighted = false});
  final String label;
  final int minutes;
  final bool isHighlighted; // true for the current day/week/month
}

class PeakHour {
  const PeakHour({required this.hour, required this.minutes, required this.sessions});
  final int hour;
  final int minutes;
  final int sessions;
}

class TagStat {
  const TagStat({required this.tag, required this.minutes});
  final String tag;
  final int minutes;
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
    } catch (_) {}
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

  // ── Period-aware stats ────────────────────────────────────────────────────────

  List<SessionRecord> sessionsForPeriod(StatsPeriod period) {
    if (period == StatsPeriod.all) return allSessions;
    final cutoff = switch (period) {
      StatsPeriod.week => DateTime.now().subtract(const Duration(days: 7)),
      StatsPeriod.month => DateTime.now().subtract(const Duration(days: 30)),
      StatsPeriod.year => DateTime.now().subtract(const Duration(days: 365)),
      StatsPeriod.all => throw StateError('unreachable'),
    };
    return _sessions.where((s) => s.startTime.isAfter(cutoff)).toList();
  }

  int totalMinutesForPeriod(StatsPeriod period) =>
      sessionsForPeriod(period).fold(0, (sum, s) => sum + s.durationMinutes);

  int get totalFocusedMinutesAllTime =>
      _sessions.fold(0, (sum, s) => sum + s.durationMinutes);

  /// Bar chart data for the given period.
  /// Week → 7 daily bars. Month → 4 weekly bars. Year/All → 12 monthly bars.
  List<BarEntry> barDataForPeriod(StatsPeriod period) {
    final sessions = sessionsForPeriod(period);
    final now = DateTime.now();

    switch (period) {
      case StatsPeriod.week:
        const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
        return List.generate(7, (i) {
          final day = now.subtract(Duration(days: 6 - i));
          final mins = sessions
              .where((s) => _isSameDay(s.startTime, day))
              .fold(0, (sum, s) => sum + s.durationMinutes);
          return BarEntry(
            label: dayLabels[day.weekday - 1],
            minutes: mins,
            isHighlighted: _isSameDay(day, now),
          );
        });

      case StatsPeriod.month:
        return List.generate(4, (i) {
          // w0 = oldest (3 weeks ago), w3 = most recent (this week)
          final weekEndDay = now.subtract(Duration(days: (3 - i) * 7));
          final weekStartDay = weekEndDay.subtract(const Duration(days: 6));
          final wStart = DateTime(weekStartDay.year, weekStartDay.month, weekStartDay.day);
          final wEnd = DateTime(weekEndDay.year, weekEndDay.month, weekEndDay.day, 23, 59, 59);
          final mins = sessions
              .where((s) => !s.startTime.isBefore(wStart) && !s.startTime.isAfter(wEnd))
              .fold(0, (sum, s) => sum + s.durationMinutes);
          return BarEntry(label: 'W${i + 1}', minutes: mins, isHighlighted: i == 3);
        });

      case StatsPeriod.year:
      case StatsPeriod.all:
        const monthLabels = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
        return List.generate(12, (i) {
          final month = DateTime(now.year, now.month - 11 + i, 1);
          final mins = sessions
              .where((s) => s.startTime.year == month.year && s.startTime.month == month.month)
              .fold(0, (sum, s) => sum + s.durationMinutes);
          return BarEntry(
            label: monthLabels[month.month - 1],
            minutes: mins,
            isHighlighted: month.year == now.year && month.month == now.month,
          );
        });
    }
  }

  /// Top 3 peak hours by focused minutes for the given period.
  List<PeakHour> peakHoursForPeriod(StatsPeriod period) {
    final sessions = sessionsForPeriod(period);
    final byHour = <int, List<SessionRecord>>{};
    for (final s in sessions) {
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

  /// 7×24 heatmap for the given period.
  List<List<int>> heatmapForPeriod(StatsPeriod period) {
    final sessions = sessionsForPeriod(period);
    final counts = List.generate(7, (_) => List.filled(24, 0));
    for (final s in sessions) {
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

  /// Tag breakdown sorted by minutes descending.
  List<TagStat> tagBreakdownForPeriod(StatsPeriod period) {
    final sessions = sessionsForPeriod(period);
    final map = <String, int>{};
    for (final s in sessions) {
      final key = (s.tag != null && s.tag!.isNotEmpty) ? s.tag! : 'untagged';
      map[key] = (map[key] ?? 0) + s.durationMinutes;
    }
    return (map.entries.map((e) => TagStat(tag: e.key, minutes: e.value)).toList())
      ..sort((a, b) => b.minutes.compareTo(a.minutes));
  }

  // ── Legacy (kept for Today screen) ───────────────────────────────────────────

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

  List<PeakHour> get peakHours {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = _sessions.where((s) => s.startTime.isAfter(cutoff)).toList();
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
