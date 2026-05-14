import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/together_service.dart';
import '../../widgets/mascot/pop_mascot.dart';
import '../../widgets/together/buddy_avatar.dart';

class CompleteScreen extends StatelessWidget {
  const CompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);

    return Consumer<TogetherService>(
      builder: (context, together, _) {
        final room = together.room;
        final participants = together.participants;

        // Reactions received by me
        final myReactions = together.recentReactions
            .where((r) => r.toUserId == together.myUserId)
            .toList();

        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Sage header ──────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: t.sage.withValues(alpha: 0.14),
                  child: Text(
                    'SESSION COMPLETE · ${room?.durationMinutes ?? 25} MIN',
                    style: TextStyle(
                      fontFamily: AppFonts.mono,
                      fontSize: 11,
                      color: t.sage,
                      letterSpacing: 0.14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: Column(
                      children: [
                        // Hero copy
                        Text(
                          'you all popped.',
                          style: TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 36,
                            color: t.ink,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // Mascot trio
                        _MascotTrio(t: t, participants: participants, myUserId: together.myUserId),

                        const SizedBox(height: 32),

                        // Stats grid
                        _StatsGrid(
                          t: t,
                          durationMinutes: room?.durationMinutes ?? 25,
                          count: participants.length,
                        ),

                        // Reactions received
                        if (myReactions.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _ReactionsCard(t: t, reactions: myReactions),
                        ],

                        const SizedBox(height: 32),

                        // Buttons
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: () async {
                              await together.leaveRoom();
                              if (context.mounted) {
                                Navigator.of(context)
                                    .popUntil((r) => r.isFirst);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 18),
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

  @override
  Widget build(BuildContext context) {
    // Pick up to 3 participants; put "me" in the center
    final me = participants.where((p) => p.userId == myUserId).firstOrNull;
    final others = participants.where((p) => p.userId != myUserId).toList();

    final left = others.isNotEmpty ? others.first : null;
    final right = others.length > 1 ? others[1] : null;

    final colors = [t.lavender, t.pop, t.ember];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (left != null) ...[
          _MascotTile(
            t: t,
            displayName: left.displayName,
            size: 68,
            ringColor: colors[0],
            mood: PopMood.celebrating,
          ),
          const SizedBox(width: 8),
        ],
        // Center (me) — slightly bigger
        _MascotTile(
          t: t,
          displayName: me != null ? 'you' : (participants.isNotEmpty ? participants.first.displayName : 'you'),
          size: 92,
          ringColor: t.sage,
          mood: PopMood.celebrating,
        ),
        if (right != null) ...[
          const SizedBox(width: 8),
          _MascotTile(
            t: t,
            displayName: right.displayName,
            size: 68,
            ringColor: colors[2],
            mood: PopMood.celebrating,
          ),
        ],
      ],
    );
  }
}

class _MascotTile extends StatelessWidget {
  const _MascotTile({
    required this.t,
    required this.displayName,
    required this.size,
    required this.ringColor,
    required this.mood,
  });

  final AppTokens t;
  final String displayName;
  final double size;
  final Color ringColor;
  final PopMood mood;

  @override
  Widget build(BuildContext context) {
    return BuddyAvatar(
      t: t,
      size: size,
      ringColor: ringColor,
      mood: mood,
      label: displayName,
    );
  }
}

// ── Stats grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.t,
    required this.durationMinutes,
    required this.count,
  });

  final AppTokens t;
  final int durationMinutes;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: t.dim,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            t: t,
            value: '${durationMinutes ~/ 60 > 0 ? "${durationMinutes ~/ 60}h" : ""}${durationMinutes % 60 > 0 ? "${durationMinutes % 60}m" : ""}',
            label: 'focused',
          ),
          Container(width: 1, height: 28, color: t.border),
          _Stat(t: t, value: count.toString(), label: 'together'),
          Container(width: 1, height: 28, color: t.border),
          _Stat(t: t, value: '🎉', label: 'popped!'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.t, required this.value, required this.label});
  final AppTokens t;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
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

// ── Reactions card ────────────────────────────────────────────────────────────

class _ReactionsCard extends StatelessWidget {
  const _ReactionsCard({required this.t, required this.reactions});
  final AppTokens t;
  final List<dynamic> reactions;

  @override
  Widget build(BuildContext context) {
    final emojiCounts = <String, int>{};
    for (final r in reactions) {
      emojiCounts[r.emoji as String] = (emojiCounts[r.emoji as String] ?? 0) + 1;
    }

    return Container(
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
            children: emojiCounts.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: t.dim,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${e.key} ${e.value}',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 14,
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
