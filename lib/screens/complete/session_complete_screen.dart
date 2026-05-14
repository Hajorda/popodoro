import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/window_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/common/pop_button.dart';

class SessionCompleteScreen extends StatelessWidget {
  const SessionCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Consumer<TimerController>(
          builder: (context, timer, _) =>
              _CompleteContent(timer: timer, t: t),
        ),
      ),
    );
  }
}

class _CompleteContent extends StatelessWidget {
  const _CompleteContent({required this.timer, required this.t});

  final TimerController timer;
  final AppTokens t;

  int get _count => timer.settings.sessionsBeforeLongBreak;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        // Session count badge
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.pop.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.pop.withValues(alpha: 0.4)),
            ),
            child: Text(
              '$_count OF $_count SESSIONS',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                letterSpacing: 0.12,
                color: t.popDeep,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const Spacer(flex: 2),
        // Pop celebrating
        Center(
          child: PopMascot(
            size: 140,
            mood: PopMood.celebrating,
            accentColor: t.pop,
            bumpColor: t.bump,
            bumpEdgeColor: t.bumpEdge,
            inkColor: t.ink,
          ),
        ),
        const SizedBox(height: 28),
        // Headline
        Text(
          'nice work!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 40,
            color: t.ink,
            height: 1.0,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$_count sessions popped. Long break deserved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            color: t.ink2,
            height: 1.4,
          ),
        ),
        const Spacer(flex: 2),
        // Mock stats card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: _StatsCard(t: t, sessionCount: _count),
        ),
        const Spacer(flex: 3),
        // CTAs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PopButton(
                label: '↑ Share',
                variant: PopButtonVariant.secondary,
                small: true,
                onPressed: () => _onShare(context),
                inkColor: t.ink,
                bgColor: t.bg,
                surfaceColor: t.surface,
                borderColor: t.border,
                ink2Color: t.ink2,
              ),
              const SizedBox(width: 12),
              PopButton(
                label: 'Take your break →',
                variant: PopButtonVariant.primary,
                onPressed: () {
                  context.read<TimerController>().acknowledgeCycleComplete();
                },
                inkColor: t.ink,
                bgColor: t.bg,
                surfaceColor: t.surface,
                borderColor: t.border,
                ink2Color: t.ink2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
        ),
        if (WindowService.isDesktop)
          Positioned(
            top: 12,
            right: 16,
            child: GestureDetector(
              onTap: () => context.read<WindowService>().enterMiniMode(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.surface,
                  border: Border.all(color: t.border),
                ),
                child: Icon(Icons.picture_in_picture_alt_rounded, size: 16, color: t.ink2),
              ),
            ),
          ),
      ],
    );
  }

  void _onShare(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shareable recap coming soon!',
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.t, required this.sessionCount});

  final AppTokens t;
  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    // Mock values — will be replaced with real tracking in a future phase.
    final focusMinutes = sessionCount * 25;
    final hours = focusMinutes ~/ 60;
    final mins = focusMinutes % 60;
    final focusLabel = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'Focus time', value: focusLabel, t: t),
          _Divider(t: t),
          _Stat(label: 'Sessions', value: '$sessionCount', t: t),
          _Divider(t: t),
          _Stat(label: 'Streak', value: '3 days', t: t),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.t});

  final String label;
  final String value;
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 22,
            color: t.ink,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 11,
            color: t.ink3,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: t.border);
  }
}
