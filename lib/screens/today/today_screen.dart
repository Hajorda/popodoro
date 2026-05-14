import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/history_controller.dart';
import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pomodoro_state.dart';
import '../../models/session_record.dart';
import '../../models/session_tag.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../stats/stats_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _TodayAppBar(t: t),
      body: Consumer<HistoryController>(
        builder: (context, history, _) => _TodayBody(t: t, history: history),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _TodayAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _TodayAppBar({required this.t});
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
        'Today',
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 17, fontWeight: FontWeight.w600, color: t.ink),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsScreen()),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.surface,
                border: Border.all(color: t.border),
              ),
              child: Icon(Icons.bar_chart_rounded, size: 16, color: t.ink2),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _TodayBody extends StatelessWidget {
  const _TodayBody({required this.t, required this.history});
  final AppTokens t;
  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    final sessions = history.todaySessions;
    final totalMins = history.totalFocusedMinutesToday;
    final streak = history.streakDays;
    final timer = context.watch<TimerController>();
    final isRunning = timer.status == TimerStatus.running &&
        timer.phase == TimerPhase.focus;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const SizedBox(height: 16),
        _HeroHeader(t: t),
        const SizedBox(height: 16),
        _StatsBanner(t: t, totalMins: totalMins, streak: streak, count: sessions.length),
        const SizedBox(height: 20),
        _DayArc(t: t, sessions: sessions, isRunning: isRunning, timer: timer),
        const SizedBox(height: 22),
        if (sessions.isEmpty && !isRunning)
          _EmptyState(t: t)
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'SESSIONS',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14),
                ),
                const SizedBox(width: 8),
                Text(
                  '${sessions.length}',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3),
                ),
              ],
            ),
          ),
          _Timeline(t: t, sessions: sessions, timer: timer, isRunning: isRunning),
        ],
        if (sessions.isNotEmpty || isRunning) ...[
          const SizedBox(height: 16),
          _PopNote(t: t, history: history),
        ],
      ],
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dateLabel = '${days[now.weekday - 1]} · ${months[now.month - 1]} ${now.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dateLabel,
          style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, letterSpacing: 0.16, color: t.ink3),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: TextStyle(fontFamily: AppFonts.display, fontSize: 36, color: t.ink, letterSpacing: -0.5, height: 1.05),
            children: const [
              TextSpan(text: 'your day, '),
              TextSpan(text: 'popped.', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Stats banner ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  const _StatsBanner({required this.t, required this.totalMins, required this.streak, required this.count});
  final AppTokens t;
  final int totalMins;
  final int streak;
  final int count;

  String _fmtMins(int mins) {
    if (mins == 0) return '—';
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          _BigStat(t: t, value: _fmtMins(totalMins), label: 'focused', accent: t.pop),
          _Divider(t: t),
          _BigStat(t: t, value: count.toString(), label: 'sessions'),
          _Divider(t: t),
          _BigStat(t: t, value: streak > 0 ? '🔥 $streak' : '—', label: 'streak'),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.t, required this.value, required this.label, this.accent});
  final AppTokens t;
  final String value;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontFamily: AppFonts.display, fontSize: 24, color: accent ?? t.ink, letterSpacing: -0.3, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.14),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.t});
  final AppTokens t;
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, color: t.border);
}

// ── Day arc ───────────────────────────────────────────────────────────────────

class _DayArc extends StatelessWidget {
  const _DayArc({required this.t, required this.sessions, required this.isRunning, required this.timer});
  final AppTokens t;
  final List<SessionRecord> sessions;
  final bool isRunning;
  final TimerController timer;

  static const _hStart = 7;
  static const _hEnd = 19;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowFrac = ((now.hour + now.minute / 60.0) - _hStart) / (_hEnd - _hStart);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('YOUR DAY · 7AM → 7PM',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14)),
            Text('NOW',
                style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink3, letterSpacing: 0.1)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(
            size: const Size(double.infinity, 36),
            painter: _DayArcPainter(
              sessions: sessions,
              nowFrac: nowFrac.clamp(0, 1),
              hStart: _hStart,
              hEnd: _hEnd,
              bgColor: t.dim,
              tickColor: t.border,
              focusColor: t.pop,
              nowColor: t.ink,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const ['7', '9', '11', '1', '3', '5', '7']
              .map((h) => Text(h, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: Color(0xFF8E867C), letterSpacing: 0.1)))
              .toList(),
        ),
      ],
    );
  }
}

class _DayArcPainter extends CustomPainter {
  const _DayArcPainter({
    required this.sessions,
    required this.nowFrac,
    required this.hStart,
    required this.hEnd,
    required this.bgColor,
    required this.tickColor,
    required this.focusColor,
    required this.nowColor,
  });

  final List<SessionRecord> sessions;
  final double nowFrac;
  final int hStart;
  final int hEnd;
  final Color bgColor;
  final Color tickColor;
  final Color focusColor;
  final Color nowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final span = hEnd - hStart;
    final bg = Paint()..color = bgColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    // Hour ticks
    final tick = Paint()..color = tickColor;
    for (var i = 0; i <= span; i++) {
      final x = (i / span) * size.width;
      tick.color = tickColor.withValues(alpha: i % 3 == 0 ? 1.0 : 0.5);
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), tick);
    }

    // Session blocks
    final block = Paint()..color = focusColor;
    for (final s in sessions) {
      final startH = s.startTime.hour + s.startTime.minute / 60.0;
      final endH = startH + s.durationMinutes / 60.0;
      final left = ((startH - hStart) / span * size.width).clamp(0.0, size.width);
      final right = ((endH - hStart) / span * size.width).clamp(0.0, size.width);
      if (right <= left) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, 6, right, size.height - 6),
          const Radius.circular(4),
        ),
        block,
      );
    }

    // Now marker
    final nowX = nowFrac * size.width;
    final nowPaint = Paint()..color = nowColor;
    canvas.drawRect(Rect.fromLTWH(nowX - 1, 0, 2, size.height), nowPaint);
    canvas.drawCircle(Offset(nowX, -2), 4, nowPaint);
  }

  @override
  bool shouldRepaint(_DayArcPainter old) =>
      old.sessions != sessions || old.nowFrac != nowFrac;
}

// ── Timeline ──────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  const _Timeline({required this.t, required this.sessions, required this.timer, required this.isRunning});
  final AppTokens t;
  final List<SessionRecord> sessions;
  final TimerController timer;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    for (var i = 0; i < sessions.length; i++) {
      final isLast = i == sessions.length - 1 && !isRunning;
      tiles.add(_SessionTile(t: t, session: sessions[i], isLast: isLast, isNow: false));
    }
    if (isRunning) {
      tiles.add(_NowTile(t: t, timer: timer, isLast: true));
    }

    return _TimelineRail(t: t, children: tiles);
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail({required this.t, required this.children});
  final AppTokens t;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Stack(
        children: [
          // vertical rail
          Positioned(
            left: -20,
            top: 8,
            bottom: 8,
            child: Container(width: 2, color: t.border),
          ),
          Column(children: children),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.t, required this.session, required this.isLast, required this.isNow});
  final AppTokens t;
  final SessionRecord session;
  final bool isLast;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final start = session.startTime;
    final timeLabel = _fmt(start);
    final hasTask = session.taskName != null && session.taskName!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // dot
          Positioned(
            left: -24,
            top: 16,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.pop,
                border: Border.all(color: t.bg, width: 2),
              ),
            ),
          ),
          // time gutter
          Positioned(
            left: -52,
            top: 15,
            child: Text(
              timeLabel,
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.04),
            ),
          ),
          // card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasTask ? session.taskName! : 'Focus session',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          color: t.ink,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _TagPill(t: t, tagString: session.tag),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${session.durationMinutes} min',
                  style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _NowTile extends StatelessWidget {
  const _NowTile({required this.t, required this.timer, required this.isLast});
  final AppTokens t;
  final TimerController timer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeLabel = _fmt(now);
    final hasTask = timer.taskName.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // pulsing ember dot
          Positioned(
            left: -28,
            top: 14,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.ember.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: t.ember),
                ),
              ),
            ),
          ),
          // time gutter
          Positioned(
            left: -52,
            top: 15,
            child: Text(
              timeLabel,
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.04),
            ),
          ),
          // card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.ember, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasTask ? timer.taskName : 'Focus session',
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          color: t.ink,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      timer.timeDisplay,
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 12, color: t.ink, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.ember.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: t.ember)),
                          const SizedBox(width: 5),
                          Text('NOW', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ember, letterSpacing: 0.1)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: timer.progress,
                    backgroundColor: t.surface2,
                    valueColor: AlwaysStoppedAnimation<Color>(t.ember),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Pop's note ────────────────────────────────────────────────────────────────

class _PopNote extends StatelessWidget {
  const _PopNote({required this.t, required this.history});
  final AppTokens t;
  final HistoryController history;

  String _buildMessage() {
    final peaks = history.peakHours;
    if (peaks.isEmpty) return 'You\'re building momentum. Keep popping!';
    final h = peaks.first.hour;
    final hLabel = h > 12 ? '${h - 12} pm' : (h == 12 ? '12 pm' : '$h am');
    return 'Your morning is usually a beast around $hLabel. Want to pop one before the day gets away?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PopMascot(
            size: 36,
            mood: PopMood.hi,
            accentColor: t.pop,
            bumpColor: t.bump,
            bumpEdgeColor: t.bumpEdge,
            inkColor: t.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _buildMessage(),
                style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12, color: t.ink2, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag pill ──────────────────────────────────────────────────────────────────

class _TagPill extends StatelessWidget {
  const _TagPill({required this.t, required this.tagString});
  final AppTokens t;
  final String? tagString;

  @override
  Widget build(BuildContext context) {
    final tag = SessionTag.fromString(tagString);
    final tagColor = tag?.colorFor(t) ?? t.ink3;
    final label = tag?.label ?? 'focus';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.10),
        border: Border.all(color: tagColor.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag != null) ...[
            Text(tag.emoji, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: tagColor),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Text('🕐', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text(
            'No sessions yet today.',
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 16, fontWeight: FontWeight.w500, color: t.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Start a focus session and it will appear here.',
            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
