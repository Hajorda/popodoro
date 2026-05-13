import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/history_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _periodIndex = 0; // 0=Week, 1=Month, 2=Year, 3=All

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _StatsAppBar(t: t),
      body: Consumer<HistoryController>(
        builder: (context, history, _) => _StatsBody(
          t: t,
          history: history,
          periodIndex: _periodIndex,
          onPeriodChanged: (i) => setState(() => _periodIndex = i),
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
  const _StatsBody({required this.t, required this.history, required this.periodIndex, required this.onPeriodChanged});
  final AppTokens t;
  final HistoryController history;
  final int periodIndex;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final last7 = history.last7Days;
    final peaks = history.peakHours;
    final allTimeMins = history.totalFocusedMinutesAllTime;
    final streak = history.streakDays;
    final heatmap = history.heatmap;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _PeriodSwitcher(t: t, selected: periodIndex, onSelect: onPeriodChanged),
        const SizedBox(height: 20),
        _HeroStat(t: t, totalMins: allTimeMins, streak: streak),
        const SizedBox(height: 16),
        _Sparkline(t: t, days: last7),
        const SizedBox(height: 24),
        _SectionLabel(t: t, label: 'Heatmap · day × hour'),
        const SizedBox(height: 10),
        _Heatmap(t: t, data: heatmap),
        const SizedBox(height: 22),
        _GoldenHoursCard(t: t, peaks: peaks),
        if (allTimeMins > 0) ...[
          const SizedBox(height: 22),
          _SectionLabel(t: t, label: 'Where it went'),
          const SizedBox(height: 10),
          _TagBreakdown(t: t),
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
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = ['Week', 'Month', 'Year', 'All'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final on = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: on ? t.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: on ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                ),
                child: Text(
                  labels[i],
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
        }),
      ),
    );
  }
}

// ── Hero stat ─────────────────────────────────────────────────────────────────

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.t, required this.totalMins, required this.streak});
  final AppTokens t;
  final int totalMins;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final h = totalMins ~/ 60;
    final m = totalMins % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALL TIME · FOCUSED',
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

// ── Sparkline ─────────────────────────────────────────────────────────────────

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.t, required this.days});
  final AppTokens t;
  final List<DayStats> days;

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final todayIdx = DateTime.now().weekday - 1;
    final values = days.map((d) => d.minutes.toDouble()).toList();
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
              painter: _SparklinePainter(
                values: values,
                maxVal: maxVal > 0 ? maxVal : 1,
                lineColor: t.pop,
                areaColor: t.pop.withValues(alpha: 0.18),
                bgColor: t.bg,
                todayIdx: todayIdx,
                dotColor: t.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isToday = i == todayIdx;
              return SizedBox(
                width: 32,
                child: Text(
                  dayLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    color: isToday ? t.ink : t.ink3,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 0.1,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.maxVal,
    required this.lineColor,
    required this.areaColor,
    required this.bgColor,
    required this.todayIdx,
    required this.dotColor,
  });

  final List<double> values;
  final double maxVal;
  final Color lineColor;
  final Color areaColor;
  final Color bgColor;
  final int todayIdx;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const pad = 6.0;
    final n = values.length;

    Offset pt(int i) {
      final x = pad + i * (size.width - pad * 2) / (n - 1);
      final y = size.height - pad - (values[i] / maxVal) * (size.height - pad * 2);
      return Offset(x, y);
    }

    final points = List.generate(n, pt);

    // Area fill
    final area = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) { area.lineTo(p.dx, p.dy); }
    area.lineTo(points.last.dx, size.height - pad);
    area.lineTo(points.first.dx, size.height - pad);
    area.close();
    canvas.drawPath(area, Paint()..color = areaColor);

    // Line
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) { line.lineTo(p.dx, p.dy); }
    canvas.drawPath(line, Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);

    // Dots
    for (var i = 0; i < n; i++) {
      final isToday = i == todayIdx;
      canvas.drawCircle(points[i], isToday ? 5 : 3,
          Paint()..color = bgColor);
      canvas.drawCircle(points[i], isToday ? 3.5 : 2,
          Paint()..color = isToday ? dotColor : lineColor);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
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
    // Show hours 6–20 (15 columns)
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

// ── Tag breakdown (mocked — tags not yet in SessionRecord) ────────────────────

class _TagBreakdown extends StatelessWidget {
  const _TagBreakdown({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    final tags = [
      _TagEntry('deep work', t.pop, 58, '—'),
      _TagEntry('meetings', t.lavender, 22, '—'),
      _TagEntry('shallow', t.sage, 14, '—'),
      _TagEntry('learning', t.ember, 6, '—'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                children: tags.map((tag) => Flexible(
                  flex: tag.pct,
                  child: Container(color: tag.color),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...tags.map((tag) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: tag.color)),
                const SizedBox(width: 10),
                Expanded(child: Text(tag.name, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink))),
                Text(tag.hrs, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink2)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 30,
                  child: Text('${tag.pct}%', textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: t.ink3)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _TagEntry {
  const _TagEntry(this.name, this.color, this.pct, this.hrs);
  final String name;
  final Color color;
  final int pct;
  final String hrs;
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
