import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

// Pop is Popodoro's work-buddy mascot: a butter-yellow squircle with three
// cream popcorn tufts on top. Five mood variants drive the facial expression.
enum PopMood { hi, focused, working, resting, celebrating }

class PopMascot extends StatelessWidget {
  const PopMascot({
    super.key,
    this.size = 120,
    this.mood = PopMood.hi,
    this.eyesClosed = false,
    required this.accentColor,
    required this.bumpColor,
    required this.bumpEdgeColor,
    required this.inkColor,
  });

  final double size;
  final PopMood mood;
  final bool eyesClosed;
  final Color accentColor;
  final Color bumpColor;
  final Color bumpEdgeColor;
  final Color inkColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _PopPainter(
              accentColor: accentColor,
              bumpColor: bumpColor,
              bumpEdgeColor: bumpEdgeColor,
              inkColor: inkColor,
              mood: mood,
              eyesClosed: eyesClosed,
            ),
          ),
          // Sleepy 'z' — rendered as a widget so it uses the real font
          if (mood == PopMood.resting)
            Positioned(
              right: -size * 0.04,
              top: size * 0.02,
              child: Text(
                'z',
                style: TextStyle(fontFamily: AppFonts.display, 
                  fontSize: size * 0.18,
                  color: const Color(0xFF9A8FE8),
                  fontStyle: FontStyle.italic,
                  height: 1.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Painter ──────────────────────────────────────────────────────────────────

class _PopPainter extends CustomPainter {
  const _PopPainter({
    required this.accentColor,
    required this.bumpColor,
    required this.bumpEdgeColor,
    required this.inkColor,
    required this.mood,
    this.eyesClosed = false,
  });

  final Color accentColor;
  final Color bumpColor;
  final Color bumpEdgeColor;
  final Color inkColor;
  final PopMood mood;
  final bool eyesClosed;

  @override
  void paint(Canvas canvas, Size s) {
    _drawShadow(canvas, s);
    _drawBumps(canvas, s);
    _drawBody(canvas, s);
    _drawCheeks(canvas, s);
    if (mood == PopMood.focused) _drawBrows(canvas, s);
    _drawEyes(canvas, s);
    _drawMouth(canvas, s);
    if (mood == PopMood.working || mood == PopMood.hi || mood == PopMood.celebrating) {
      _drawArms(canvas, s);
    }
  }

  // ── Shadow ──────────────────────────────────────────────────────────────────

  void _drawShadow(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = const Color(0xFF1C1A17).withValues(alpha: 0.10)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromLTWH(s.width * 0.14, s.height * 0.94, s.width * 0.72, s.height * 0.08),
      paint,
    );
  }

  // ── Popcorn bumps ────────────────────────────────────────────────────────────

  void _drawBumps(Canvas canvas, Size s) {
    // left, center, right — as in CSS: 14/36/58% left, -2/-10/-2% top
    _drawBump(canvas, s, left: 0.14, top: -0.02, w: 0.34, h: 0.34);
    _drawBump(canvas, s, left: 0.36, top: -0.10, w: 0.36, h: 0.36);
    _drawBump(canvas, s, left: 0.58, top: -0.02, w: 0.30, h: 0.30);
  }

  void _drawBump(Canvas canvas, Size s,
      {required double left, required double top, required double w, required double h}) {
    final rect = Rect.fromLTWH(s.width * left, s.height * top, s.width * w, s.height * h);
    // CSS border-radius: '50% 50% 46% 46% / 60% 60% 40% 40%'
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.elliptical(rect.width * 0.50, rect.height * 0.60),
      topRight: Radius.elliptical(rect.width * 0.50, rect.height * 0.60),
      bottomRight: Radius.elliptical(rect.width * 0.46, rect.height * 0.40),
      bottomLeft: Radius.elliptical(rect.width * 0.46, rect.height * 0.40),
    );
    // Gradient: white top → bump fill → bump edge bottom
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, bumpColor, bumpEdgeColor],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  // ── Squircle body ────────────────────────────────────────────────────────────

  void _drawBody(Canvas canvas, Size s) {
    final bL = s.width * 0.06;
    final bT = s.height * 0.18;
    final bW = s.width * 0.88;
    final bH = s.height * 0.78;
    final bodyRect = Rect.fromLTWH(bL, bT, bW, bH);

    // CSS border-radius: '38% 38% 42% 42% / 44% 44% 46% 46%'
    final rrect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.elliptical(bW * 0.38, bH * 0.44),
      topRight: Radius.elliptical(bW * 0.38, bH * 0.44),
      bottomRight: Radius.elliptical(bW * 0.42, bH * 0.46),
      bottomLeft: Radius.elliptical(bW * 0.42, bH * 0.46),
    );

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(accentColor, 0.06), accentColor, _darken(accentColor, 0.06)],
        stops: const [0.0, 0.60, 1.0],
      ).createShader(bodyRect);
    canvas.drawRRect(rrect, fillPaint);

    // Inset bottom shadow
    final shadowPaint = Paint()
      ..color = _darken(accentColor, 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.height * 0.055
      ..strokeCap = StrokeCap.round;
    final y = bT + bH - s.height * 0.045;
    canvas.drawLine(Offset(bL + bW * 0.18, y), Offset(bL + bW * 0.82, y), shadowPaint);
  }

  // ── Cheek blush ──────────────────────────────────────────────────────────────

  void _drawCheeks(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = const Color(0xFFF26B4F).withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    // left: 12%, top: 55%, w: 14%, h: 9%
    canvas.drawOval(Rect.fromLTWH(s.width * 0.12, s.height * 0.55, s.width * 0.14, s.height * 0.09), paint);
    // right: 1 - 0.12 - 0.14 = 0.74
    canvas.drawOval(Rect.fromLTWH(s.width * 0.74, s.height * 0.55, s.width * 0.14, s.height * 0.09), paint);
  }

  // ── Eyebrows (focused only) ──────────────────────────────────────────────────

  void _drawBrows(Canvas canvas, Size s) {
    final paint = Paint()..color = inkColor;
    final browsY = s.height * 0.435;
    final browsH = s.height * 0.03;
    final browsW = s.width * 0.12;

    // Left brow: left 30%, rotated +8°
    canvas.save();
    canvas.translate(s.width * 0.36, browsY);
    canvas.rotate(8 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: browsW, height: browsH), const Radius.circular(2)),
      paint,
    );
    canvas.restore();

    // Right brow: left 58%, rotated -8°
    canvas.save();
    canvas.translate(s.width * 0.64, browsY);
    canvas.rotate(-8 * math.pi / 180);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: browsW, height: browsH), const Radius.circular(2)),
      paint,
    );
    canvas.restore();
  }

  // ── Eyes ─────────────────────────────────────────────────────────────────────

  void _drawEyes(Canvas canvas, Size s) {
    final ink = Paint()..color = inkColor;

    if (eyesClosed) {
      // Blink: thin closed arc (same as resting but shorter/thinner)
      final arc = Paint()
        ..color = inkColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * 0.028
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromLTWH(s.width * 0.30, s.height * 0.52, s.width * 0.10, s.height * 0.035), math.pi, -math.pi, false, arc);
      canvas.drawArc(Rect.fromLTWH(s.width * 0.60, s.height * 0.52, s.width * 0.10, s.height * 0.035), math.pi, -math.pi, false, arc);
      return;
    }

    switch (mood) {
      case PopMood.resting:
        // Closed arcs — top arc = sleeping
        final arc = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.03
          ..strokeCap = StrokeCap.round;
        // top arc: startAngle=pi, sweepAngle=-pi (counter-clockwise over the top)
        canvas.drawArc(Rect.fromLTWH(s.width * 0.30, s.height * 0.52, s.width * 0.12, s.height * 0.04), math.pi, -math.pi, false, arc);
        canvas.drawArc(Rect.fromLTWH(s.width * 0.58, s.height * 0.52, s.width * 0.12, s.height * 0.04), math.pi, -math.pi, false, arc);

      case PopMood.focused:
        // Narrow, squinting eyes
        canvas.drawOval(Rect.fromLTWH(s.width * 0.32, s.height * 0.48, s.width * 0.08, s.height * 0.08), ink);
        canvas.drawOval(Rect.fromLTWH(s.width * 0.60, s.height * 0.48, s.width * 0.08, s.height * 0.08), ink);

      case PopMood.celebrating:
        // Happy crescent (bottom arc)
        final arc = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.03
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromLTWH(s.width * 0.28, s.height * 0.48, s.width * 0.14, s.height * 0.10), 0, math.pi, false, arc);
        canvas.drawArc(Rect.fromLTWH(s.width * 0.58, s.height * 0.48, s.width * 0.14, s.height * 0.10), 0, math.pi, false, arc);

      default: // hi / working — wide-open eyes with sparkle
        _drawEyeWithSparkle(canvas, s, left: 0.32);
        _drawEyeWithSparkle(canvas, s, left: 0.60);
    }
  }

  void _drawEyeWithSparkle(Canvas canvas, Size s, {required double left}) {
    final eW = s.width * 0.10;
    final eH = s.height * 0.12;
    final eL = s.width * left;
    final eT = s.height * 0.48;

    canvas.drawOval(Rect.fromLTWH(eL, eT, eW, eH), Paint()..color = inkColor);
    // White sparkle: 18% inset
    canvas.drawOval(
      Rect.fromLTWH(eL + eW * 0.18, eT + eH * 0.18, eW * 0.34, eH * 0.34),
      Paint()..color = Colors.white,
    );
  }

  // ── Mouth ────────────────────────────────────────────────────────────────────

  void _drawMouth(Canvas canvas, Size s) {
    switch (mood) {
      case PopMood.celebrating:
        // Open oval mouth (filled)
        final mL = s.width * 0.42;
        final mT = s.height * 0.68;
        final mW = s.width * 0.16;
        final mH = s.height * 0.13;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(mL, mT, mW, mH),
            bottomLeft: Radius.circular(mW),
            bottomRight: Radius.circular(mW),
          ),
          Paint()..color = inkColor,
        );
        // Tongue dot
        canvas.drawOval(
          Rect.fromLTWH(mL + mW * 0.18, mT + mH * 0.60, mW * 0.64, mH * 0.34),
          Paint()..color = const Color(0xFFF26B4F),
        );

      case PopMood.resting:
        // Tiny neutral arc
        final arc = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.025
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromLTWH(s.width * 0.46, s.height * 0.70, s.width * 0.08, s.height * 0.06), 0, math.pi, false, arc);

      case PopMood.focused:
        // Flat neutral line
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.46, s.height * 0.72, s.width * 0.08, s.height * 0.02), const Radius.circular(2)),
          Paint()..color = inkColor,
        );

      default: // hi / working — gentle smile
        final arc = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * 0.025
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(Rect.fromLTWH(s.width * 0.42, s.height * 0.68, s.width * 0.16, s.height * 0.08), 0, math.pi, false, arc);
    }
  }

  // ── Arms ──────────────────────────────────────────────────────────────────────

  void _drawArms(Canvas canvas, Size s) {
    final armColor = _darken(accentColor, 0.08);
    final armPaint = Paint()..color = armColor;
    final aW = s.width * 0.14;
    final aH = s.height * 0.10;
    final aY = s.height * 0.63;
    final isCelebrating = mood == PopMood.celebrating;

    // Left arm: origin at left edge of body
    canvas.save();
    canvas.translate(s.width * 0.06, aY);
    canvas.rotate(isCelebrating ? -50 * math.pi / 180 : 15 * math.pi / 180);
    if (isCelebrating) canvas.translate(0, -aH * 0.30);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset.zero, width: aW, height: aH),
        topLeft: Radius.circular(aW * 0.4),
        bottomLeft: Radius.circular(aW * 0.4),
        topRight: Radius.circular(aW * 0.6),
        bottomRight: Radius.circular(aW * 0.6),
      ),
      armPaint,
    );
    canvas.restore();

    // Right arm
    canvas.save();
    canvas.translate(s.width * 0.94, aY);
    canvas.rotate(isCelebrating ? 50 * math.pi / 180 : -15 * math.pi / 180);
    if (isCelebrating) canvas.translate(0, -aH * 0.30);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset.zero, width: aW, height: aH),
        topLeft: Radius.circular(aW * 0.6),
        bottomLeft: Radius.circular(aW * 0.6),
        topRight: Radius.circular(aW * 0.4),
        bottomRight: Radius.circular(aW * 0.4),
      ),
      armPaint,
    );
    canvas.restore();
  }

  // ── Color helpers ─────────────────────────────────────────────────────────────

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(_PopPainter old) =>
      old.mood != mood ||
      old.eyesClosed != eyesClosed ||
      old.accentColor != accentColor ||
      old.inkColor != inkColor;
}
