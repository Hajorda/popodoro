import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/together_service.dart';
import '../../services/window_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/timer/timer_display.dart';
import '../../widgets/together/buddy_avatar.dart';
import '../../widgets/pip/mini_timer_pill.dart';
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

    // Only the host drives phase transitions — single source of truth.
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
    // ── Mini mode: hand over to the pill (which reads TogetherService) ────────
    if (WindowService.isDesktop) {
      final windowService = context.watch<WindowService>();
      if (windowService.isMiniMode) {
        return const MiniTimerPill();
      }
    }

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

        // Trigger navigate from within build via postFrameCallback.
        if (room.isComplete && !_completeTriggered) {
          _completeTriggered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _goToComplete());
        }

        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: room.isOnBreak
                ? _BreakBody(t: t, together: together)
                : _FocusBody(t: t, together: together),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Focus body — exact column layout of HomeScreen
// ═══════════════════════════════════════════════════════════════════════════════

class _FocusBody extends StatelessWidget {
  const _FocusBody({required this.t, required this.together});

  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    final room = together.room!;
    final settings = context.read<SettingsController>();
    final others =
        together.participants.where((p) => p.userId != together.myUserId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top bar (same pattern as HomeScreen._TopBar) ─────────────────────
        _TopBar(t: t, together: together),

        // ── "Greeting" row — mascot + popping copy + live pill ───────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
          child: _GreetingRow(t: t, together: together),
        ),

        // ── Task name (italic, if set) ────────────────────────────────────────
        if (room.taskName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Text(
              room.taskName!,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 18,
                color: t.ink,
                fontStyle: FontStyle.italic,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // ── Timer centre (identical to HomeScreen._TimerCenter) ───────────────
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final size = (c.maxWidth * 0.78).clamp(200.0, 310.0);
            return Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: TimerDisplay(
                  appearance: settings.timerAppearance,
                  progress: room.progress,
                  timeDisplay: room.timeDisplay,
                  sessionLabel:
                      'TOGETHER · ${together.participants.length}',
                  taskName: null,
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
              ),
            );
          }),
        ),

        // ── Session info (same slot as HomeScreen._SessionInfo) ───────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            'FOCUS · ${room.durationMinutes}m',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              color: t.ink3,
              letterSpacing: 0.14,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // ── Buddy presence (compact rows, only if others in room) ─────────────
        if (others.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
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
                const SizedBox(height: 6),
                ...others.take(3).map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: _BuddyRow(t: t, p: p, progress: room.progress),
                    )),
              ],
            ),
          ),
        ],

        // ── Reaction tray ──────────────────────────────────────────────────────
        const SizedBox(height: 10),
        Center(child: _ReactionTray(t: t, together: together)),

        // ── Action row (same slot as HomeScreen._ActionRow) ───────────────────
        const SizedBox(height: 16),
        _ActionRow(t: t, together: together),
        const SizedBox(height: 28),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Break body — same structure as BreakScreen, with buddy presence
// ═══════════════════════════════════════════════════════════════════════════════

class _BreakBody extends StatelessWidget {
  const _BreakBody({required this.t, required this.together});

  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    final room = together.room!;
    final others =
        together.participants.where((p) => p.userId != together.myUserId).toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // Phase chip — sage (same style as BreakScreen)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

            // Resting mascot (same as BreakScreen)
            Center(
              child: PopMascot(
                size: 130,
                mood: PopMood.resting,
                accentColor: t.pop,
                bumpColor: t.bump,
                bumpEdgeColor: t.bumpEdge,
                inkColor: t.ink,
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'take five.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 36,
                color: t.ink,
                height: 1.05,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 6),
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

            // Buddy avatar strip
            if (others.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: others.take(4).map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
            ],

            const Spacer(flex: 2),

            // Large time display (same as BreakScreen)
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

            // Thin sage progress bar (same as BreakScreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: _ProgressBar(
                progress: room.breakProgress,
                color: t.sage,
                trackColor: t.surface2,
              ),
            ),

            const Spacer(flex: 3),

            // Break action row
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
                    const SizedBox(width: 16),
                  ],
                  _OutlineBtn(
                    t: t,
                    label: 'Leave',
                    onTap: () => _confirmLeave(context, together),
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
                child: Icon(Icons.picture_in_picture_alt_rounded,
                    size: 16, color: t.ink2),
              ),
            ),
          ),
      ],
    );
  }

  void _confirmLeave(BuildContext context, TogetherService together) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _LeaveDialog(t: t),
    );
    if (ok == true && context.mounted) {
      await together.leaveRoom();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

// ── Top bar (same shape as HomeScreen._TopBar) ────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.t, required this.together});
  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LIVE pill (replaces wordmark in co-focus context)
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

          // Right icons — same 36×36 circle style as HomeScreen
          Row(
            children: [
              if (WindowService.isDesktop) ...[
                _IconBtn(
                  t: t,
                  child: Icon(Icons.picture_in_picture_alt_rounded,
                      size: 16, color: t.ink2),
                  onTap: () => context.read<WindowService>().enterMiniMode(),
                ),
                const SizedBox(width: 8),
              ],
              _IconBtn(
                t: t,
                child: Icon(Icons.close_rounded, size: 16, color: t.ink2),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => _LeaveDialog(t: t),
                  );
                  if (ok == true && context.mounted) {
                    await context.read<TogetherService>().leaveRoom();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.t, required this.child, required this.onTap});
  final AppTokens t;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: t.surface,
          border: Border.all(color: t.border),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── Greeting row (same slot as HomeScreen._GreetingRow) ───────────────────────

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.t, required this.together});
  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    final others = together.participants
        .where((p) => p.userId != together.myUserId)
        .take(2)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          // Mini buddy avatars stacked (or solo mascot if alone)
          if (others.isEmpty)
            PopMascot(
              size: 44,
              mood: PopMood.working,
              accentColor: t.pop,
              bumpColor: t.bump,
              bumpEdgeColor: t.bumpEdge,
              inkColor: t.ink,
            )
          else
            SizedBox(
              width: 44 + (others.length - 1).clamp(0, 1) * 26.0,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Self
                  BuddyAvatar(
                    t: t,
                    size: 44,
                    ringColor: t.pop,
                    statusColor: t.ember,
                    mood: PopMood.working,
                  ),
                  // First buddy, slightly offset right
                  if (others.isNotEmpty)
                    Positioned(
                      left: 22,
                      child: BuddyAvatar(
                        t: t,
                        size: 36,
                        ringColor: t.sage,
                        statusColor: t.sage,
                        mood: PopMood.working,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'popping together.',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontSize: 22,
                  color: t.ink,
                  height: 1.1,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Buddy progress row ────────────────────────────────────────────────────────

class _BuddyRow extends StatelessWidget {
  const _BuddyRow({required this.t, required this.p, required this.progress});
  final AppTokens t;
  final TogetherParticipant p;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(height: 44, color: t.ember.withValues(alpha: 0.10)),
          ),
          SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  BuddyAvatar(
                    t: t,
                    size: 28,
                    ringColor: t.ember,
                    statusColor: t.ember,
                    mood: PopMood.working,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.displayName,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: t.ink,
                      ),
                    ),
                  ),
                  Text(
                    p.isDone ? 'done ✓' : 'focusing',
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

// ── Action row (same slot as HomeScreen._ActionRow) ───────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.t, required this.together});
  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    final isHost = together.isHost;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // +5 button — same secondary small style as HomeScreen
          _SmallBtn(
            t: t,
            label: '+ 5',
            onTap: isHost ? () => together.addMinutes(5) : null,
          ),
          const SizedBox(width: 10),

          // Primary CTA
          Expanded(
            child: _PrimaryBtn(
              t: t,
              label: isHost ? 'End focus →' : 'Leave',
              onTap: isHost
                  ? () => together.startBreak()
                  : () async {
                      await together.leaveRoom();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reaction tray ─────────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${incoming.fromDisplayName} sent ${incoming.emoji}',
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 10,
                  color: t.ink3,
                ),
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: active
                      ? BoxDecoration(
                          color: t.pop.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(e, style: const TextStyle(fontSize: 18)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Thin progress bar (same as BreakScreen._ProgressBar) ─────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar(
      {required this.progress, required this.color, required this.trackColor});
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

// ── Utility buttons ───────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.t, required this.label, required this.onTap});
  final AppTokens t;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: t.pop,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.t, required this.label, this.onTap});
  final AppTokens t;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: enabled ? t.surface : t.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: enabled ? t.ink : t.ink3,
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({required this.t, required this.label, required this.onTap});
  final AppTokens t;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.ui,
            fontSize: 15,
            color: t.ink2,
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

// ── Leave confirmation dialog ─────────────────────────────────────────────────

class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Leave session?',
          style: TextStyle(
              fontFamily: AppFonts.ui, fontSize: 16, color: t.ink)),
      content: Text(
        'You\'ll exit the room. Your friends will keep going.',
        style:
            TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2),
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
