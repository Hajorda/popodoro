import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/history_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../widgets/mascot/pop_mascot.dart';

class NudgesScreen extends StatelessWidget {
  const NudgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: _AppBar(t: t),
      body: Consumer<HistoryController>(
        builder: (context, history, _) => _Body(t: t, history: history),
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar({required this.t});
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
            decoration: BoxDecoration(shape: BoxShape.circle, color: t.surface, border: Border.all(color: t.border)),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: t.ink),
          ),
        ),
      ),
      title: Text("Pop's nudges",
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 17, fontWeight: FontWeight.w600, color: t.ink)),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Done', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 15, color: t.pop, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.t, required this.history});
  final AppTokens t;
  final HistoryController history;

  @override
  Widget build(BuildContext context) {
    final peaks = history.peakHours;
    final sessionCount = history.allSessions.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const SizedBox(height: 12),

        // Hero card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              PopMascot(
                size: 56,
                mood: PopMood.hi,
                accentColor: t.pop,
                bumpColor: t.bump,
                bumpEdgeColor: t.bumpEdge,
                inkColor: t.ink,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Noticing your\ngolden hours.',
                      style: TextStyle(fontFamily: AppFonts.display, fontSize: 19, color: t.ink, letterSpacing: -0.2, height: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'BUILT FROM $sessionCount SESSIONS',
                      style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Detected golden windows
        if (peaks.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionLabel(t: t, label: "Pop's notes on you"),
          const SizedBox(height: 10),
          ...peaks.map((p) {
            final h = p.hour;
            final hLabel = h > 12 ? '${h - 12} ${h >= 12 ? 'pm' : 'am'}' : '$h ${h >= 12 ? 'pm' : 'am'}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hLabel, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 13, color: t.ink, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${p.sessions} sessions · ${p.minutes}m focused',
                              style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.05)),
                        ],
                      ),
                    ),
                    if (p == peaks.first)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: t.pop, borderRadius: BorderRadius.circular(999)),
                        child: Text('GOLDEN',
                            style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: t.ink, fontWeight: FontWeight.w700, letterSpacing: 0.06)),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],

        const SizedBox(height: 22),
        _SectionLabel(t: t, label: 'When Pop speaks up'),
        const SizedBox(height: 10),
        _TogglesCard(t: t),

        const SizedBox(height: 22),
        _SectionLabel(t: t, label: 'Quiet hours'),
        const SizedBox(height: 10),
        _QuietHours(t: t),
      ],
    );
  }
}

// ── Toggles (stateful, no controller backing yet) ─────────────────────────────

class _TogglesCard extends StatefulWidget {
  const _TogglesCard({required this.t});
  final AppTokens t;
  @override
  State<_TogglesCard> createState() => _TogglesCardState();
}

class _TogglesCardState extends State<_TogglesCard> {
  bool _goldenHour = true;
  bool _streakCheckin = true;
  bool _sessionPat = true;
  bool _buddyFocus = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.border)),
      child: Column(
        children: [
          _ToggleRow(t: t, label: 'Golden-hour nudges', sub: 'Gentle hello at the start of your best windows',
              value: _goldenHour, onChanged: (v) => setState(() => _goldenHour = v)),
          Divider(color: t.border, height: 1, indent: 16),
          _ToggleRow(t: t, label: 'Streak check-in', sub: "Only if you haven't focused by 4pm",
              value: _streakCheckin, onChanged: (v) => setState(() => _streakCheckin = v)),
          Divider(color: t.border, height: 1, indent: 16),
          _ToggleRow(t: t, label: 'End-of-session pat', sub: 'Quiet celebration after each session',
              value: _sessionPat, onChanged: (v) => setState(() => _sessionPat = v)),
          Divider(color: t.border, height: 1, indent: 16),
          _ToggleRow(t: t, label: 'Buddy is focusing', sub: 'When a buddy starts a session',
              value: _buddyFocus, onChanged: (v) => setState(() => _buddyFocus = v), isLast: true),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.t, required this.label, required this.sub, required this.value, required this.onChanged, this.isLast = false});
  final AppTokens t;
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, fontWeight: FontWeight.w500, color: t.ink)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontFamily: AppFonts.ui, fontSize: 11, color: t.ink3, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: t.pop,
            activeTrackColor: t.pop.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Quiet hours visual ────────────────────────────────────────────────────────

class _QuietHours extends StatelessWidget {
  const _QuietHours({required this.t});
  final AppTokens t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('No nudges between', style: TextStyle(fontFamily: AppFonts.ui, fontSize: 14, fontWeight: FontWeight.w600, color: t.ink)),
              Text('21:00 → 08:30', style: TextStyle(fontFamily: AppFonts.mono, fontSize: 13, color: t.ink)),
            ],
          ),
          const SizedBox(height: 12),
          // 24h visual track
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 28,
              child: CustomPaint(
                size: const Size(double.infinity, 28),
                painter: _QuietHoursPainter(
                  quietStart: 21,
                  quietEnd: 8.5,
                  bgColor: t.dim,
                  bandColor: t.lavender,
                  tickColor: t.border,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const ['00', '06', '12', '18', '24'].map((h) =>
              Text(h, style: TextStyle(fontFamily: AppFonts.mono, fontSize: 9, color: Color(0xFF8E867C), letterSpacing: 0.1)),
            ).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuietHoursPainter extends CustomPainter {
  const _QuietHoursPainter({
    required this.quietStart,
    required this.quietEnd,
    required this.bgColor,
    required this.bandColor,
    required this.tickColor,
  });

  final double quietStart;
  final double quietEnd;
  final Color bgColor;
  final Color bandColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = bgColor);

    // Hour ticks
    final tick = Paint()..color = tickColor;
    for (var i = 0; i < 24; i++) {
      final x = (i / 24) * size.width;
      tick.color = tickColor.withValues(alpha: i % 6 == 0 ? 1.0 : 0.4);
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), tick);
    }

    // Quiet band (wraps midnight: 21→24 and 0→8.5)
    final band = Paint()..color = bandColor.withValues(alpha: 0.35);
    final x1 = (quietStart / 24) * size.width;
    canvas.drawRect(Rect.fromLTRB(x1, 0, size.width, size.height), band);
    final x2 = (quietEnd / 24) * size.width;
    canvas.drawRect(Rect.fromLTRB(0, 0, x2, size.height), band);
  }

  @override
  bool shouldRepaint(_QuietHoursPainter old) => false;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.t, required this.label});
  final AppTokens t;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(label.toUpperCase(),
        style: TextStyle(fontFamily: AppFonts.mono, fontSize: 10, color: t.ink3, letterSpacing: 0.14)),
  );
}
