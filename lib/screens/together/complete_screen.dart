import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/together_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/together/buddy_avatar.dart';
import 'lobby_screen.dart';

class CompleteScreen extends StatelessWidget {
  const CompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Consumer<TogetherService>(
      builder: (context, together, _) {
        final room = together.room;
        final participants = together.participants;

        final myReactions = together.recentReactions
            .where((r) => r.toUserId == together.myUserId)
            .toList();

        final focusMins = room?.durationMinutes ?? 25;
        final focusLabel = focusMins >= 60
            ? '${focusMins ~/ 60}h ${focusMins % 60 > 0 ? "${focusMins % 60}m" : ""}'
            : '${focusMins}m';

        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Sage header ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  color: t.sage.withValues(alpha: 0.14),
                  child: Text(
                    'SESSION COMPLETE · $focusLabel',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: t.sage,
                      letterSpacing: 0.14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        const Spacer2(height: 32),

                        // Hero copy
                        Text(
                          'you all popped.',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 38,
                            color: t.ink,
                            fontStyle: FontStyle.italic,
                            height: 1.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (room?.taskName != null) ...[
                          const Spacer2(height: 8),
                          Text(
                            room!.taskName!,
                            style: TextStyle(
                              fontFamily: AppFonts.display,
                              fontSize: 16,
                              color: t.ink3,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const Spacer2(height: 32),

                        // Mascot trio (left buddy · center you · right buddy)
                        _MascotTrio(
                          t: t,
                          participants: participants,
                          myUserId: together.myUserId,
                        ),

                        const Spacer2(height: 28),

                        // Stats grid
                        _StatsGrid(
                          t: t,
                          focusLabel: focusLabel,
                          count: participants.length,
                        ),

                        // Reactions received
                        if (myReactions.isNotEmpty) ...[
                          const Spacer2(height: 16),
                          _ReactionsCard(t: t, reactions: myReactions),
                        ],

                        const Spacer2(height: 32),

                        // CTA buttons
                        _CTAButtons(t: t, together: together),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Spacer helper (avoids Spacer inside SingleChildScrollView) ────────────────

class Spacer2 extends StatelessWidget {
  const Spacer2({super.key, required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

// ── Mascot trio ───────────────────────────────────────────────────────────────

class _MascotTrio extends StatelessWidget {
  const _MascotTrio({
    required this.t,
    required this.participants,
    required this.myUserId,
  });

  final AppTokens t;
  final List<TogetherParticipant> participants;
  final String? myUserId;

  static const _sideColors = [Color(0xFF9A8FE8), Color(0xFFF26B4F)]; // lavender, ember

  @override
  Widget build(BuildContext context) {
    final me = participants.where((p) => p.userId == myUserId).firstOrNull;
    final others = participants.where((p) => p.userId != myUserId).toList();
    final left = others.isNotEmpty ? others.first : null;
    final right = others.length > 1 ? others[1] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (left != null) ...[
          _MascotTile(
            t: t,
            label: left.displayName,
            size: 68,
            ringColor: _sideColors[0],
          ),
          const SizedBox(width: 8),
        ],
        // Center — slightly bigger, always "you"
        _MascotTile(
          t: t,
          label: me != null
              ? 'you'
              : (participants.isNotEmpty ? participants.first.displayName : 'you'),
          size: 92,
          ringColor: t.sage,
        ),
        if (right != null) ...[
          const SizedBox(width: 8),
          _MascotTile(
            t: t,
            label: right.displayName,
            size: 68,
            ringColor: _sideColors[1],
          ),
        ],
      ],
    );
  }
}

class _MascotTile extends StatelessWidget {
  const _MascotTile({
    required this.t,
    required this.label,
    required this.size,
    required this.ringColor,
  });

  final AppTokens t;
  final String label;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return BuddyAvatar(
      t: t,
      size: size,
      ringColor: ringColor,
      mood: PopMood.celebrating,
      label: label,
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.t,
    required this.focusLabel,
    required this.count,
  });

  final AppTokens t;
  final String focusLabel;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCell(t: t, value: focusLabel, label: 'focused'),
          Container(width: 1, height: 32, color: t.border),
          _StatCell(t: t, value: '$count', label: 'together'),
          Container(width: 1, height: 32, color: t.border),
          _StatCell(t: t, value: '🎉', label: 'popped!'),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.t, required this.value, required this.label});
  final AppTokens t;
  final String value;
  final String label;

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
            fontFamily: AppFonts.mono,
            fontSize: 9,
            color: t.ink3,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ── Reactions received card ───────────────────────────────────────────────────

class _ReactionsCard extends StatelessWidget {
  const _ReactionsCard({required this.t, required this.reactions});
  final AppTokens t;
  final List<TogetherReaction> reactions;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REACTIONS RECEIVED',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              color: t.ink3,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: counts.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: t.dim,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${e.key}  ${e.value}',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    color: t.ink,
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

// ── CTA buttons ───────────────────────────────────────────────────────────────

class _CTAButtons extends StatelessWidget {
  const _CTAButtons({required this.t, required this.together});
  final AppTokens t;
  final TogetherService together;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "Pop another?" — resets the same room back to lobby
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () async {
              // Host resets the room; non-host just navigates and waits for Realtime.
              if (together.isHost) await together.resetRoom();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => const LobbyScreen()),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: t.pop,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Pop another? →',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: t.ink,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // "End session"
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () async {
              await together.leaveRoom();
              if (context.mounted) {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 17),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
              ),
              child: Text(
                'End session',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: t.ink2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
