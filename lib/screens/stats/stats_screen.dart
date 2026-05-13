import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/history_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _StatsAppBar(t: t),
      body: Consumer<HistoryController>(
        builder: (context, history, _) => _StatsBody(t: t, history: history),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _StatsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _StatsAppBar({required this.t});
  final AppTokens t;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: t.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.surface,
              border: Border.all(color: t.border),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text(
        'Stats',
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 17, fontWeight: FontWeight.w600, color: t.ink),
      ),
      centerTitle: true,
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.t, required this.history});
  final AppTokens t;
  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    final last7 = history.last7Days;
    final peaks = history.peakHours;
    final allTimeMins = history.totalFocusedMinutesAllTime;
    final streak = history.streakDays;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      children: [
        const SizedBox(height: 12),
        _SummaryRow(t: t, totalMins: allTimeMins, streak: streak),
        const SizedBox(height: 8),
        _Section(
          title: 'Last 7 Days',
          t: t,
          child: _WeekHeatmap(t: t, days: last7),
        ),
        const SizedBox(height: 8),
        _Section(
          title: 'Golden Hours',
          t: t,
          child: peaks.isEmpty
              ? _EmptyPeaks(t: t)
              : _PeakHoursRail(t: t, peaks: peaks),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.t, required this.totalMins, required this.streak});
  final AppTokens t;
  final int totalMins;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniCard(t: t, label: 'All-time', value: _fmtMins(totalMins), flex: 2),
        const SizedBox(width: 10),
        _MiniCard(t: t, label: 'Streak', value: '$streak d', flex: 1),
      ],
    );
  }

  String _fmtMins(int mins) {
    if (mins == 0) return '0m';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.t, required this.label, required this.value, required this.flex});
  final AppTokens t;
  final String label;
  final String value;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontFamily: AppFonts.display, fontSize: 26, color: t.ink, height: 1.0)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }
}

// ── Section wrapper ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.t, required this.child});
  final String title;
  final AppTokens t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: t.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ── 7-day heatmap ─────────────────────────────────────────────────────────────

class _WeekHeatmap extends StatelessWidget {
  const _WeekHeatmap({required this.t, required this.days});
  final AppTokens t;
  final List<DayStats> days;

  @override
  Widget build(BuildContext context) {
    final maxMins = days.fold(0, (m, d) => d.minutes > m ? d.minutes : m);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: days.map((d) => _DayBar(t: t, day: d, maxMins: maxMins)).toList(),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: days.map((d) {
            const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
            return SizedBox(
              width: 30,
              child: Text(
                labels[d.date.weekday - 1],
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.1),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.t, required this.day, required this.maxMins});
  final AppTokens t;
  final DayStats day;
  final int maxMins;

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(day.date, DateTime.now());
    final fraction = maxMins > 0 ? (day.minutes / maxMins).clamp(0.0, 1.0) : 0.0;
    const maxBarHeight = 80.0;
    const minBarHeight = 4.0;
    final barHeight = day.minutes > 0
        ? (minBarHeight + (maxBarHeight - minBarHeight) * fraction)
        : minBarHeight;

    return SizedBox(
      width: 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (day.minutes > 0)
            Text(
              _fmtMins(day.minutes),
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 8, color: t.ink3),
            ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            width: 20,
            height: barHeight,
            decoration: BoxDecoration(
              color: day.minutes > 0
                  ? (isToday ? t.pop : t.pop.withValues(alpha: 0.5))
                  : t.surface2,
              borderRadius: BorderRadius.circular(6),
              border: isToday ? Border.all(color: t.popDeep, width: 1.5) : null,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtMins(int mins) {
    if (mins < 60) return '${mins}m';
    return '${mins ~/ 60}h';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── Peak hours rail ───────────────────────────────────────────────────────────

class _PeakHoursRail extends StatelessWidget {
  const _PeakHoursRail({required this.t, required this.peaks});
  final AppTokens t;
  final List<PeakHour> peaks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "You're usually a beast at ${_hourLabel(peaks.first.hour)}. Your golden hours:",
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, height: 1.4),
        ),
        const SizedBox(height: 14),
        ...peaks.asMap().entries.map((e) => _PeakRow(
          t: t,
          peak: e.value,
          rank: e.key + 1,
          maxMins: peaks.first.minutes,
          isLast: e.key == peaks.length - 1,
        )),
      ],
    );
  }

  String _hourLabel(int hour) {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final suffix = hour >= 12 ? 'pm' : 'am';
    return '$h $suffix';
  }
}

class _PeakRow extends StatelessWidget {
  const _PeakRow({required this.t, required this.peak, required this.rank, required this.maxMins, required this.isLast});
  final AppTokens t;
  final PeakHour peak;
  final int rank;
  final int maxMins;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final fraction = maxMins > 0 ? (peak.minutes / maxMins).clamp(0.0, 1.0) : 0.0;
    final h = peak.hour > 12 ? peak.hour - 12 : (peak.hour == 0 ? 12 : peak.hour);
    final suffix = peak.hour >= 12 ? 'pm' : 'am';
    final hourStr = '$h $suffix';

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              '#$rank',
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              hourStr,
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: t.ink, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: t.surface2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    height: 8,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: rank == 1 ? t.pop : t.pop.withValues(alpha: 0.5 + 0.2 * (3 - rank)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              '${peak.sessions} sess',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty peaks ───────────────────────────────────────────────────────────────

class _EmptyPeaks extends StatelessWidget {
  const _EmptyPeaks({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'Complete a few sessions to discover your peak focus hours.',
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, height: 1.5),
      ),
    );
  }
}
