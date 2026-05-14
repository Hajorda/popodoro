import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/together_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/timer/timer_display.dart';
import '../../widgets/together/buddy_avatar.dart';
import 'complete_screen.dart';

class CoFocusScreen extends StatefulWidget {
  const CoFocusScreen({super.key});

  @override
  State<CoFocusScreen> createState() => _CoFocusScreenState();
}

class _CoFocusScreenState extends State<CoFocusScreen> {
  Timer? _ticker;
  bool _breakTriggered = false;
  bool _completeTriggered = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkTransitions();
    });
  }

  void _checkTransitions() {
    final together = context.read<TogetherService>();
    final room = together.room;
    if (room == null) return;

    if (room.isComplete && !_completeTriggered) {
      _completeTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToComplete());
      return;
    }

    // Only the host drives phase transitions so there's a single source of truth.
    if (!together.isHost) return;

    if (room.isFocusing && room.remaining == Duration.zero && !_breakTriggered) {
      _breakTriggered = true;
      together.startBreak();
    }

    if (room.isOnBreak && room.breakRemaining == Duration.zero && !_completeTriggered) {
      _completeTriggered = true;
      together.endSession();
    }
  }

  void _goToComplete() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const CompleteScreen()),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Consumer<TogetherService>(
      builder: (context, together, _) {
        final room = together.room;
        if (room == null) {
          return Scaffold(
            backgroundColor: t.bg,
            body: Center(child: CircularProgressIndicator(color: t.pop)),
          );
        }

        // Trigger navigate from within build only via postFrameCallback.
        if (room.isComplete && !_completeTriggered) {
          _completeTriggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _goToComplete());
        }

        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: room.isOnBreak
                ? _BreakView(t: t, together: together)
                : _FocusView(t: t, together: together),
          ),
        );
      },
    );
  }
}

// ── Focus view — mirrors HomeScreen layout ────────────────────────────────────

class _FocusView extends StatelessWidget {
  const _FocusView({required this.t, required this.together});

  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    final room = together.room!;
    final settings = context.read<SettingsController>();
    final others = together.participants
        .where((p) => p.userId != together.myUserId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top bar — LIVE pill + leave
        _CoFocusTopBar(t: t, together: together),

        // Phase label row (mimics _GreetingRow spacing)
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
          child: Row(
            children: [
              PulsingDot(color: t.ember, size: 7),
              const SizedBox(width: 8),
              Text(
                'FOCUS · ${together.participants.length} POPPING TOGETHER',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  color: t.ink3,
                  letterSpacing: 0.14,
                ),
              ),
            ],
          ),
        ),
        if (room.taskName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Text(
              room.taskName!,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 20,
                color: t.ink,
                fontStyle: FontStyle.italic,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Timer — identical to HomeScreen's _TimerCenter
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final size = (c.maxWidth * 0.78).clamp(200.0, 310.0);
            return Center(
              child: TimerDisplay(
                appearance: settings.timerAppearance,
                progress: room.progress,
                timeDisplay: room.timeDisplay,
                sessionLabel: 'TOGETHER · ${room.durationMinutes}m',
                taskName: null, // shown above instead
                ringColor: t.pop,
                trackColor: t.surface2,
                inkColor: t.ink,
                ink2Color: t.ink2,
                ink3Color: t.ink3,
                surfaceColor: t.surface,
                borderColor: t.border,
                bumpColor: t.bump,
                bumpEdgeColor: t.bumpEdge,
                size: size,
                strokeWidth: size * 0.045,
              ),
            );
          }),
        ),

        // Buddy presence strip
        if (others.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POPPING WITH YOU',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    color: t.ink3,
                    letterSpacing: 0.14,
                  ),
                ),
                const SizedBox(height: 8),
                ...others.take(3).map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _BuddyProgressRow(
                          t: t,
                          participant: p,
                          progress: room.progress,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ] else
          const SizedBox(height: 8),

        // Reaction tray
        _ReactionTray(t: t, together: together),
        const SizedBox(height: 20),

        // Action row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: _LeaveButton(t: t, together: together),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ── Break view — mirrors BreakScreen layout ───────────────────────────────────

class _BreakView extends StatelessWidget {
  const _BreakView({required this.t, required this.together});

  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    final room = together.room!;
    final others = together.participants
        .where((p) => p.userId != together.myUserId)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        // Phase chip
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.sage.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: t.sage.withValues(alpha: 0.35)),
            ),
            child: Text(
              'SHORT BREAK · ${room.breakMinutes}m',
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 10,
                letterSpacing: 0.12,
                color: t.sage,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const Spacer(flex: 2),

        // Pop mascot (resting)
        Center(
          child: PopMascot(
            size: 120,
            mood: PopMood.resting,
            accentColor: t.pop,
            bumpColor: t.bump,
            bumpEdgeColor: t.bumpEdge,
            inkColor: t.ink,
          ),
        ),
        const SizedBox(height: 22),

        Text(
          'take five.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 34,
            color: t.ink,
            height: 1.05,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'recharging together.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 14,
            color: t.ink2,
            height: 1.4,
          ),
        ),

        const Spacer(flex: 1),

        // Buddy strip (compact, resting)
        if (others.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: others.take(4).map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: BuddyAvatar(
                    t: t,
                    size: 44,
                    ringColor: t.sage,
                    statusColor: t.sage,
                    mood: PopMood.resting,
                    label: p.displayName,
                  ),
                );
              }).toList(),
            ),
          ),

        const Spacer(flex: 2),

        // Time display
        Text(
          room.timeDisplay,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: t.ink,
            height: 1.0,
            letterSpacing: -2,
          ),
        ),
        const SizedBox(height: 8),

        // Thin sage progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: _ProgressBar(
            progress: room.breakProgress,
            color: t.sage,
            trackColor: t.surface2,
          ),
        ),

        const Spacer(flex: 3),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (together.isHost) ...[
                _GhostBtn(
                  t: t,
                  label: 'Skip break →',
                  onTap: () => together.endSession(),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _LeaveButton(t: t, together: together),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shared subwidgets ─────────────────────────────────────────────────────────

class _CoFocusTopBar extends StatelessWidget {
  const _CoFocusTopBar({required this.t, required this.together});
  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: t.ember.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PulsingDot(color: t.ember, size: 6),
                const SizedBox(width: 6),
                Text(
                  'LIVE · ${together.participants.length} FOCUSING',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    color: t.ember,
                    letterSpacing: 0.14,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => _LeaveDialog(t: t),
              );
              if (confirmed == true && context.mounted) {
                await context.read<TogetherService>().leaveRoom();
                if (context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              }
            },
            child: Text(
              'Leave',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                color: t.ink3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuddyProgressRow extends StatelessWidget {
  const _BuddyProgressRow({
    required this.t,
    required this.participant,
    required this.progress,
  });

  final AppTokens t;
  final TogetherParticipant participant;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Stack(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          // Progress fill (left → right)
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 48,
              color: t.ember.withValues(alpha: 0.10),
            ),
          ),
          SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  BuddyAvatar(
                    t: t,
                    size: 30,
                    ringColor: t.ember,
                    statusColor: t.ember,
                    mood: PopMood.working,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      participant.displayName,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: t.ink,
                      ),
                    ),
                  ),
                  Text(
                    participant.isDone ? 'done ✓' : 'focusing',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 9,
                      color: t.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionTray extends StatefulWidget {
  const _ReactionTray({required this.t, required this.together});
  final AppTokens t;
  final TogetherService together;

  @override
  State<_ReactionTray> createState() => _ReactionTrayState();
}

class _ReactionTrayState extends State<_ReactionTray> {
  static const _emojis = ['🔥', '💪', '⚡', '🎉', '❤️'];
  String? _sent;

  Future<void> _send(String emoji) async {
    setState(() => _sent = emoji);
    for (final p in widget.together.participants) {
      if (p.userId != widget.together.myUserId) {
        await widget.together.sendReaction(emoji, p.userId);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _sent = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final incoming = widget.together.recentReactions
        .where((r) => r.toUserId == widget.together.myUserId)
        .firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (incoming != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Padding(
              key: ValueKey(incoming.createdAt),
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${incoming.fromDisplayName} sent ${incoming.emoji}',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 11,
                  color: t.ink3,
                ),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _emojis.map((e) {
              final active = _sent == e;
              return GestureDetector(
                onTap: _sent == null ? () => _send(e) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  padding: const EdgeInsets.all(7),
                  decoration: active
                      ? BoxDecoration(
                          color: t.pop.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(e, style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.color,
    required this.trackColor,
  });
  final double progress;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 4,
        color: trackColor,
        child: FractionallySizedBox(
          widthFactor: progress.clamp(0.0, 1.0),
          alignment: Alignment.centerLeft,
          child: Container(color: color),
        ),
      ),
    );
  }
}

class _LeaveButton extends StatelessWidget {
  const _LeaveButton({required this.t, required this.together});
  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => _LeaveDialog(t: t),
        );
        if (confirmed == true && context.mounted) {
          await context.read<TogetherService>().leaveRoom();
          if (context.mounted) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Center(
          child: Text(
            'Leave',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 15,
              color: t.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({required this.t, required this.label, required this.onTap});
  final AppTokens t;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.ui,
          fontSize: 14,
          color: t.ink3,
        ),
      ),
    );
  }
}

class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Leave session?',
        style: TextStyle(
            fontFamily: AppFonts.ui, fontSize: 16, color: t.ink),
      ),
      content: Text(
        'You\'ll exit the room. Your friends will keep going.',
        style: TextStyle(
            fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Stay',
              style: TextStyle(
                  fontFamily: AppFonts.ui, fontSize: 14, color: t.ink2)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Leave',
              style: TextStyle(
                  fontFamily: AppFonts.ui, fontSize: 14, color: t.ember)),
        ),
      ],
    );
  }
}
