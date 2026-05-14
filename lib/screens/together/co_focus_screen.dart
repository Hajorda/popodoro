import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/together_service.dart';
import '../../widgets/together/buddy_avatar.dart';
import '../../widgets/mascot/pop_mascot.dart';
import 'complete_screen.dart';

class CoFocusScreen extends StatefulWidget {
  const CoFocusScreen({super.key});

  @override
  State<CoFocusScreen> createState() => _CoFocusScreenState();
}

class _CoFocusScreenState extends State<CoFocusScreen> {
  Timer? _ticker;
  bool _sessionCompleted = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _checkComplete();
    });
  }

  void _checkComplete() {
    final together = context.read<TogetherService>();
    final room = together.room;
    if (room == null || _sessionCompleted) return;

    if (room.remaining == Duration.zero) {
      _sessionCompleted = true;
      _onSessionEnd();
    }
  }

  Future<void> _onSessionEnd() async {
    final together = context.read<TogetherService>();
    await together.completeSession();
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

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
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

        final others = together.participants
            .where((p) => p.userId != together.myUserId)
            .toList();
        final progress = room.progress;
        final remaining = room.remaining;

        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: t.ember.withValues(alpha: 0.14),
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
                              Navigator.of(context).popUntil(
                                  (r) => r.isFirst);
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
                ),

                const Spacer(),

                // ── Timer hero ───────────────────────────────────────────────
                Text(
                  _fmt(remaining),
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 64,
                    fontWeight: FontWeight.w700,
                    color: t.ink,
                    letterSpacing: -2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                if (room.taskName != null)
                  Text(
                    room.taskName!,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 16,
                      color: t.ink2,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                const Spacer(),

                // ── Buddy rows ───────────────────────────────────────────────
                if (others.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'POPPING WITH YOU',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 10,
                            color: t.ink3,
                            letterSpacing: 0.14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...others
                            .take(3)
                            .map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _BuddyProgressRow(
                                    t: t,
                                    participant: p,
                                    progress: progress,
                                  ),
                                )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Reaction tray ────────────────────────────────────────────
                _ReactionTray(t: t, together: together),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Buddy progress row ────────────────────────────────────────────────────────

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
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Background
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Progress fill
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 52,
              color: t.ember.withValues(alpha: 0.12),
            ),
          ),
          // Content
          SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  BuddyAvatar(
                    t: t,
                    size: 32,
                    ringColor: t.ember,
                    statusColor: t.ember,
                    mood: PopMood.working,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      participant.displayName,
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.ink,
                      ),
                    ),
                  ),
                  Text(
                    participant.isFocusing ? 'focusing' : participant.isDone ? 'done ✓' : 'joining',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 10,
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
  String? _sentEmoji;

  Future<void> _send(String emoji) async {
    setState(() => _sentEmoji = emoji);
    // Send to all other participants
    for (final p in widget.together.participants) {
      if (p.userId != widget.together.myUserId) {
        await widget.together.sendReaction(emoji, p.userId);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _sentEmoji = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;

    // Show last received reaction (not from me)
    final incoming = widget.together.recentReactions
        .where((r) => r.toUserId == widget.together.myUserId)
        .firstOrNull;

    return Column(
      children: [
        // Incoming reaction
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: incoming != null
              ? Padding(
                  key: ValueKey(incoming.createdAt),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${incoming.fromDisplayName} sent ${incoming.emoji}',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: t.ink3,
                    ),
                  ),
                )
              : const SizedBox(height: 0),
        ),

        // Emoji buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: t.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _emojis.map((emoji) {
              final isActive = _sentEmoji == emoji;
              return GestureDetector(
                onTap: _sentEmoji == null ? () => _send(emoji) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: isActive
                      ? BoxDecoration(
                          color: t.pop.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Leave dialog ──────────────────────────────────────────────────────────────

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
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 16, color: t.ink),
      ),
      content: Text(
        'You\'ll exit the co-focus room. Your friends will keep going.',
        style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink2),
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
