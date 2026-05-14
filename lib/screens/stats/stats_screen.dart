import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/history_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../database/app_database.dart';
import '../../models/session_tag.dart';
import '../../services/focus_guard_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsPeriod _period = StatsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _StatsAppBar(t: t),
      body: Consumer2<HistoryController, FocusGuardService>(
        builder: (context, history, guard, _) => _StatsBody(
          t: t,
          history: history,
          guard: guard,
          period: _period,
          onPeriodChanged: (p) => setState(() => _period = p),
        ),
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
  const _StatsBody({
    required this.t,
    required this.history,
    required this.guard,
    required this.period,
    required this.onPeriodChanged,
  });
  final AppTokens t;
  final HistoryController history;
  final FocusGuardService guard;
  final StatsPeriod period;
  final ValueChanged<StatsPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final totalMins = history.totalMinutesForPeriod(period);
    final barData = history.barDataForPeriod(period);
    final peaks = history.peakHoursForPeriod(period);
    final heatmap = history.heatmapForPeriod(period);
    final tagStats = history.tagBreakdownForPeriod(period);
    final streak = history.streakDays;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _PeriodSwitcher(t: t, selected: period, onSelect: onPeriodChanged),
        const SizedBox(height: 20),
        _HeroStat(t: t, totalMins: totalMins, streak: streak, period: period),
        const SizedBox(height: 16),
        _BarChart(t: t, entries: barData),
        const SizedBox(height: 24),
        _SectionLabel(t: t, label: 'Heatmap · day × hour'),
        const SizedBox(height: 10),
        _Heatmap(t: t, data: heatmap),
        const SizedBox(height: 22),
        _GoldenHoursCard(t: t, peaks: peaks),
        const SizedBox(height: 22),
        _SectionLabel(t: t, label: 'Focus guard'),
        const SizedBox(height: 10),
        _FocusGuardStats(t: t, guard: guard),
        if (totalMins > 0) ...[
          const SizedBox(height: 22),
          _SectionLabel(t: t, label: 'Where it went'),
          const SizedBox(height: 10),
          _TagBreakdown(t: t, stats: tagStats, totalMins: totalMins),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Period switcher ───────────────────────────────────────────────────────────

class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({required this.t, required this.selected, required this.onSelect});
  final AppTokens t;
  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final periods = [
      (StatsPeriod.week, 'Week'),
      (StatsPeriod.month, 'Month'),
      (StatsPeriod.year, 'Year'),
      (StatsPeriod.all, 'All'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: periods.map((entry) {
          final (period, label) = entry;
          final on = period == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: on ? t.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: on
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: on ? t.ink : t.ink3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Hero stat ─────────────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.t, required this.totalMins, required this.streak, required this.period});
  final AppTokens t;
  final int totalMins;
  final int streak;
  final StatsPeriod period;

  String get _periodLabel => switch (period) {
    StatsPeriod.week => 'THIS WEEK · FOCUSED',
    StatsPeriod.month => 'THIS MONTH · FOCUSED',
    StatsPeriod.year => 'THIS YEAR · FOCUSED',
    StatsPeriod.all => 'ALL TIME · FOCUSED',
  };

  @override
  Widget build(BuildContext context) {
    final h = totalMins ~/ 60;
    final m = totalMins % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _periodLabel,
          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 0.16, color: t.ink3),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: TextStyle(fontFamily: AppFonts.display, fontSize: 56, color: t.ink, letterSpacing: -1.5, height: 1.0),
            children: totalMins == 0
                ? [const TextSpan(text: '—')]
                : [
                    TextSpan(text: '${h}h'),
                    TextSpan(text: ' · ', style: TextStyle(color: t.ink3)),
                    TextSpan(text: '${m}m'),
                  ],
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(height: 6),
          Text(
            '🔥 $streak day streak',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.sage, letterSpacing: 0.04),
          ),
        ],
      ],
    );
  }
}

// ── Bar chart (period-aware) ───────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  const _BarChart({required this.t, required this.entries});
  final AppTokens t;
  final List<BarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final values = entries.map((e) => e.minutes.toDouble()).toList();
    final maxVal = values.fold(0.0, math.max);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 72,
            child: CustomPaint(
              size: const Size(double.infinity, 72),
              painter: _BarChartPainter(
                values: values,
                maxVal: maxVal > 0 ? maxVal : 1,
                barColor: t.pop,
                highlightColor: t.popDeep,
                bgColor: t.surface2,
                highlightIndices: entries
                    .asMap()
                    .entries
                    .where((e) => e.value.isHighlighted)
                    .map((e) => e.key)
                    .toSet(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: entries.map((e) {
              return SizedBox(
                width: entries.length <= 7 ? 32 : null,
                child: Flexible(
                  child: Text(
                    e.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      color: e.isHighlighted ? t.ink : t.ink3,
                      fontWeight: e.isHighlighted ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.values,
    required this.maxVal,
    required this.barColor,
    required this.highlightColor,
    required this.bgColor,
    required this.highlightIndices,
  });

  final List<double> values;
  final double maxVal;
  final Color barColor;
  final Color highlightColor;
  final Color bgColor;
  final Set<int> highlightIndices;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final n = values.length;
    const padH = 2.0;
    const padV = 4.0;
    final totalWidth = size.width - padH * 2;
    final barWidth = (totalWidth / n - 3).clamp(4.0, 32.0);
    final slotWidth = totalWidth / n;

    for (var i = 0; i < n; i++) {
      final x = padH + i * slotWidth + (slotWidth - barWidth) / 2;
      final frac = values[i] / maxVal;
      final barH = (frac * (size.height - padV * 2)).clamp(2.0, size.height - padV * 2);
      final top = size.height - padV - barH;

      // Track
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, padV, barWidth, size.height - padV * 2),
          const Radius.circular(4),
        ),
        Paint()..color = bgColor,
      );

      if (values[i] > 0) {
        final isHl = highlightIndices.contains(i);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, top, barWidth, barH),
            const Radius.circular(4),
          ),
          Paint()..color = isHl ? highlightColor : barColor.withValues(alpha: 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.values != values;
}

// ── Heatmap ───────────────────────────────────────────────────────────────────

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.t, required this.data});
  final AppTokens t;
  final List<List<int>> data;

  Color _cell(int v) {
    switch (v) {
      case 1: return t.pop.withValues(alpha: 0.3);
      case 2: return t.pop.withValues(alpha: 0.65);
      case 3: return t.pop;
      default: return t.surface2;
    }
  }

  @override
  Widget build(BuildContext context) {
    const hStart = 6;
    const hEnd = 21;
    final hours = List.generate(hEnd - hStart, (i) => i + hStart);
    const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 30),
            ...hours.map((h) => Expanded(
              child: Text(
                h % 3 == 0 ? '$h' : '',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 8, color: t.ink3, letterSpacing: 0.04),
              ),
            )),
          ],
        ),
        const SizedBox(height: 4),
        ...List.generate(7, (dayIdx) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    dayLabels[dayIdx],
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.06),
                  ),
                ),
                ...hours.map((h) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: _cell(data[dayIdx][h]),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                )),
              ],
            ),
          );
        }),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('LESS', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.08)),
            const SizedBox(width: 6),
            ...[0, 1, 2, 3].map((v) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(color: _cell(v), borderRadius: BorderRadius.circular(3)),
              ),
            )),
            Text('MORE', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.08)),
          ],
        ),
      ],
    );
  }
}

// ── Golden hours card ─────────────────────────────────────────────────────────

class _GoldenHoursCard extends StatelessWidget {
  const _GoldenHoursCard({required this.t, required this.peaks});
  final AppTokens t;
  final List<PeakHour> peaks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.pop,
                  boxShadow: [BoxShadow(color: t.pop.withValues(alpha: 0.3), blurRadius: 6, spreadRadius: 2)],
                ),
              ),
              const SizedBox(width: 8),
              Text('GOLDEN HOURS',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.pop, fontWeight: FontWeight.w700, letterSpacing: 0.16)),
            ],
          ),
          const SizedBox(height: 4),
          Text('You at your best.',
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, color: t.ink, letterSpacing: -0.3)),
          const SizedBox(height: 14),
          if (peaks.isEmpty)
            Text(
              'Complete a few sessions to discover your golden hours.',
              style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, height: 1.5),
            )
          else
            ...peaks.asMap().entries.map((e) => Padding(
              padding: EdgeInsets.only(bottom: e.key < peaks.length - 1 ? 8 : 0),
              child: _GoldenRow(t: t, peak: e.value, isTop: e.key == 0, maxMins: peaks.first.minutes),
            )),
        ],
      ),
    );
  }
}

class _GoldenRow extends StatelessWidget {
  const _GoldenRow({required this.t, required this.peak, required this.isTop, required this.maxMins});
  final AppTokens t;
  final PeakHour peak;
  final bool isTop;
  final int maxMins;

  String _hourLabel(int hour) {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final suffix = hour >= 12 ? 'pm' : 'am';
    return '$h $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final pct = maxMins > 0 ? (peak.minutes / maxMins) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTop ? t.pop.withValues(alpha: 0.10) : t.dim,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTop ? t.pop.withValues(alpha: 0.4) : t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _hourLabel(peak.hour),
                      style: TextStyle(fontFamily: AppFonts.display, fontSize: 18, color: t.ink, letterSpacing: -0.2),
                    ),
                    if (isTop) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: t.pop, borderRadius: BorderRadius.circular(999)),
                        child: Text('GOLDEN', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink, fontWeight: FontWeight.w700, letterSpacing: 0.08)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${peak.sessions} sessions · ${peak.minutes}m focused',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.06),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, color: t.ink, letterSpacing: -0.3),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: t.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(t.pop),
                    minHeight: 4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tag breakdown (real data) ─────────────────────────────────────────────────

class _TagBreakdown extends StatelessWidget {
  const _TagBreakdown({required this.t, required this.stats, required this.totalMins});
  final AppTokens t;
  final List<TagStat> stats;
  final int totalMins;

  Color _tagColor(String tagLabel) {
    final tag = SessionTag.fromString(tagLabel);
    return tag?.colorFor(t) ?? t.ink3;
  }

  String _fmtMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.dim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Text(
          'Tag your sessions to see a breakdown here.',
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, height: 1.5),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          // Progress bar stack
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                children: stats.map((s) => Flexible(
                  flex: s.minutes,
                  child: Container(color: _tagColor(s.tag)),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Tag rows
          ...stats.map((s) {
            final tag = SessionTag.fromString(s.tag);
            final color = _tagColor(s.tag);
            final pct = totalMins > 0 ? (s.minutes / totalMins * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 8),
                  if (tag != null) ...[
                    Text(tag.emoji, style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      s.tag,
                      style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink),
                    ),
                  ),
                  Text(
                    _fmtMins(s.minutes),
                    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink2),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$pct%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: t.ink3),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Focus guard stats ─────────────────────────────────────────────────────────

class _FocusGuardStats extends StatefulWidget {
  const _FocusGuardStats({required this.t, required this.guard});
  final AppTokens t;
  final FocusGuardService guard;

  @override
  State<_FocusGuardStats> createState() => _FocusGuardStatsState();
}

class _FocusGuardStatsState extends State<_FocusGuardStats> {
  List<DetectionSummaryRow>? _summaries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await widget.guard.fetchSummaries(limit: 14);
    if (mounted) setState(() => _summaries = rows);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final summaries = _summaries;

    if (summaries == null) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: t.pop),
          ),
        ),
      );
    }

    if (summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.dim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Text(
          'No guard data yet. Enable Focus Guard in Settings → Focus → Focus guard.',
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2, height: 1.5),
        ),
      );
    }

    final totalNoPerson = summaries.fold(0, (s, r) => s + r.noPersonCount);
    final totalPhone = summaries.fold(0, (s, r) => s + r.phoneCount);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _GuardStatChip(t: t, emoji: '🚶', count: totalNoPerson, label: 'walk-aways', color: t.ember),
              const SizedBox(width: 10),
              _GuardStatChip(t: t, emoji: '📱', count: totalPhone, label: 'phone checks', color: t.lavender),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'DETECTIONS PER SESSION',
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.14),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: _DetectionBarChart(t: t, summaries: summaries),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _LegendDot(color: t.ember),
              const SizedBox(width: 4),
              Text('Walk-away', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3)),
              const SizedBox(width: 12),
              _LegendDot(color: t.lavender),
              const SizedBox(width: 4),
              Text('Phone', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuardStatChip extends StatelessWidget {
  const _GuardStatChip({required this.t, required this.emoji, required this.count, required this.label, required this.color});
  final AppTokens t;
  final String emoji;
  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, color: t.ink, height: 1.0)),
            Text(label, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.08)),
          ],
        ),
      ),
    );
  }
}

class _DetectionBarChart extends StatelessWidget {
  const _DetectionBarChart({required this.t, required this.summaries});
  final AppTokens t;
  final List<DetectionSummaryRow> summaries;

  @override
  Widget build(BuildContext context) {
    final data = summaries.reversed.take(10).toList();
    final maxY = data.fold(0, (m, r) => math.max(m, r.totalCount)).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY > 0 ? maxY + 1 : 5,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: math.max(1, maxY / 3).ceilToDouble(),
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: row.noPersonCount.toDouble(),
                width: 8,
                color: t.ember.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              BarChartRodData(
                toY: row.phoneCount.toDouble(),
                width: 8,
                color: t.lavender.withValues(alpha: 0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ],
            barsSpace: 3,
          );
        }).toList(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => t.surface,
            tooltipBorder: BorderSide(color: t.border),
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final row = data[groupIndex];
              final label = rodIndex == 0 ? '🚶 ${row.noPersonCount}' : '📱 ${row.phoneCount}';
              return BarTooltipItem(label, TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: t.ink));
            },
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.t, required this.label});
  final AppTokens t;
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14),
  );
}
