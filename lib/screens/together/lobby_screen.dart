import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../services/together_service.dart';
import '../../widgets/together/buddy_avatar.dart';
import '../../widgets/mascot/pop_mascot.dart';
import 'co_focus_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _codeCopied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Navigate when host starts the room.
    final together = context.read<TogetherService>();
    if (together.room?.status == 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToFocus());
    }
  }

  void _goToFocus() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const CoFocusScreen()),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _codeCopied = false);
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
            body: Center(
              child: CircularProgressIndicator(color: t.pop),
            ),
          );
        }

        // Auto-navigate when room becomes active.
        if (room.status == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) => _goToFocus());
        }

        final others = together.participants
            .where((p) => p.userId != together.myUserId)
            .toList();
        final me = together.myParticipant;
        final allReady = together.allReady;

        return Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Row(
                    children: [
                      PulsingDot(color: t.ember, size: 8),
                      const SizedBox(width: 8),
                      Text(
                        'LOBBY · ${room.durationMinutes} MIN FOCUS',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: 10,
                          color: t.ink3,
                          letterSpacing: 0.14,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          await together.leaveRoom();
                          if (context.mounted) Navigator.of(context).pop();
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

                  const SizedBox(height: 32),

                  // Waiting copy
                  Text(
                    others.isEmpty
                        ? 'waiting for friends…'
                        : others.length == 1
                            ? 'waiting for ${others.first.displayName}.'
                            : 'waiting for everyone.',
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 28,
                      color: t.ink,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Participants row
                  _ParticipantsRow(
                    t: t,
                    me: me,
                    others: others,
                  ),

                  const SizedBox(height: 20),

                  // Task pill
                  if (room.taskName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: t.surface2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        room.taskName!,
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontSize: 14,
                          color: t.ink2,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Room code
                  _RoomCode(
                    t: t,
                    code: room.code,
                    copied: _codeCopied,
                    onCopy: () => _copyCode(room.code),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryBtn(
                          t: t,
                          label: 'Start solo',
                          onTap: () async {
                            await together.leaveRoom();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: together.isHost
                            ? _PrimaryBtn(
                                t: t,
                                label: allReady
                                    ? 'Start!'
                                    : 'Waiting…',
                                enabled: allReady ||
                                    together.participants.isNotEmpty,
                                loading: together.loading,
                                onTap: together.startRoom,
                              )
                            : _PrimaryBtn(
                                t: t,
                                label: me?.isReady == true
                                    ? 'Ready ✓'
                                    : 'I\'m ready',
                                enabled: me?.isReady != true,
                                loading: false,
                                onTap: together.setReady,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Participants row ──────────────────────────────────────────────────────────

class _ParticipantsRow extends StatelessWidget {
  const _ParticipantsRow({
    required this.t,
    required this.me,
    required this.others,
  });

  final AppTokens t;
  final TogetherParticipant? me;
  final List<TogetherParticipant> others;

  Color _ringFor(TogetherParticipant p) {
    if (p.isReady || p.isFocusing) return t.sage;
    return t.border;
  }

  Color? _statusFor(TogetherParticipant p) {
    if (p.isReady || p.isFocusing) return t.sage;
    return t.ink3;
  }

  PopMood _moodFor(TogetherParticipant p) {
    if (p.isReady) return PopMood.hi;
    if (p.isFocusing) return PopMood.working;
    return PopMood.resting;
  }

  @override
  Widget build(BuildContext context) {
    final participants = [
      ?me,
      ...others,
    ];

    if (participants.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: BuddyAvatar(
            t: t,
            size: 80,
            ringColor: t.sage,
            statusColor: t.sage,
            mood: PopMood.hi,
            label: 'you',
          ),
        ),
      );
    }

    if (participants.length == 1) {
      final p = participants.first;
      return BuddyAvatar(
        t: t,
        size: 88,
        ringColor: _ringFor(p),
        statusColor: _statusFor(p),
        mood: _moodFor(p),
        label: me?.userId == p.userId ? 'you' : p.displayName,
      );
    }

    // 2 participants: connected pair with dashed line
    if (participants.length == 2) {
      final left = participants[0];
      final right = participants[1];
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BuddyAvatar(
            t: t,
            size: 88,
            ringColor: _ringFor(left),
            statusColor: _statusFor(left),
            mood: _moodFor(left),
            label: me?.userId == left.userId ? 'you' : left.displayName,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _DashedLine(color: t.border),
          ),
          BuddyAvatar(
            t: t,
            size: 88,
            ringColor: _ringFor(right),
            statusColor: _statusFor(right),
            mood: right.isReady || right.isFocusing
                ? _moodFor(right)
                : PopMood.resting,
            label: me?.userId == right.userId ? 'you' : right.displayName,
          ),
        ],
      );
    }

    // 3+ participants: wrap row
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: participants.map((p) {
        return BuddyAvatar(
          t: t,
          size: 68,
          ringColor: _ringFor(p),
          statusColor: _statusFor(p),
          mood: _moodFor(p),
          label: me?.userId == p.userId ? 'you' : p.displayName,
        );
      }).toList(),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 2),
      painter: _DashedPainter(color: color),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2),
          Offset(x + dashWidth, size.height / 2), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

// ── Room code ─────────────────────────────────────────────────────────────────

class _RoomCode extends StatelessWidget {
  const _RoomCode({
    required this.t,
    required this.code,
    required this.copied,
    required this.onCopy,
  });

  final AppTokens t;
  final String code;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Text(
            'ROOM CODE',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 10,
              color: t.ink3,
              letterSpacing: 0.14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              code,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 18,
                color: t.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCopy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: copied ? t.sage.withValues(alpha: 0.15) : t.ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                copied ? 'Copied!' : 'Copy',
                style: TextStyle(
                  fontFamily: AppFonts.ui,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: copied ? t.sage : t.bg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.t,
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final AppTokens t;
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !loading ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled ? t.pop : t.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: t.ink3),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? t.ink : t.ink3,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.t,
    required this.label,
    required this.onTap,
  });

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
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.border),
        ),
        child: Center(
          child: Text(
            label,
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
