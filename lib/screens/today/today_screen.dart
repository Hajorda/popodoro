import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/history_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/session_record.dart';
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

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      children: [
        const SizedBox(height: 12),
        _StatsBanner(t: t, totalMins: totalMins, streak: streak, count: sessions.length),
        const SizedBox(height: 24),
        if (sessions.isEmpty)
          _EmptyState(t: t)
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'TIMELINE',
              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14),
            ),
          ),
          ...sessions.asMap().entries.map((e) => _SessionTile(
            t: t,
            session: e.value,
            isLast: e.key == sessions.length - 1,
          )),
        ],
        const SizedBox(height: 32),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BannerCard(t: t, label: 'Focused', value: _formatMins(totalMins), flex: 2),
        const SizedBox(width: 10),
        _BannerCard(t: t, label: 'Sessions', value: count.toString(), flex: 1),
        const SizedBox(width: 10),
        _BannerCard(t: t, label: 'Streak', value: '$streak d', flex: 1),
      ],
    );
  }

  String _formatMins(int mins) {
    if (mins < 60) return '${mins}m';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.t, required this.label, required this.value, required this.flex});
  final AppTokens t;
  final String label;
  final String value;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontFamily: AppFonts.display, fontSize: 28, color: t.ink, height: 1.0)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.1)),
          ],
        ),
      ),
    );
  }
}

// ── Timeline tile ─────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.t, required this.session, required this.isLast});
  final AppTokens t;
  final SessionRecord session;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final start = session.startTime;
    final endTime = start.add(Duration(minutes: session.durationMinutes));
    final timeLabel = '${_fmt(start)} – ${_fmt(endTime)}';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: t.pop,
                    shape: BoxShape.circle,
                    border: Border.all(color: t.popDeep, width: 1.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: t.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.taskName != null && session.taskName!.isNotEmpty
                                ? session.taskName!
                                : 'Focus session',
                            style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, fontWeight: FontWeight.w500, color: t.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeLabel,
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.08),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.pop.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${session.durationMinutes}m',
                        style: TextStyle(fontFamily: AppFonts.mono, fontSize: 11, color: t.popDeep, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'pm' : 'am';
    return '$h:$m $suffix';
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Text('🕐', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
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
