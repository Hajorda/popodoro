import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_typography.dart';

// Circular progress ring — the default timer hero.
// Animates smoothly from the previous progress value whenever [progress] changes.
class TimerRing extends StatefulWidget {
  const TimerRing({
    super.key,
    required this.progress,
    required this.timeDisplay,
    required this.sessionLabel,
    this.taskName,
    required this.ringColor,
    required this.trackColor,
    required this.inkColor,
    required this.ink2Color,
    required this.ink3Color,
    required this.size,
    this.strokeWidth = 12,
  });

  final double progress;    // 0.0 → 1.0
  final String timeDisplay; // "14:32"
  final String sessionLabel; // "FOCUS · 02 / 04"
  final String? taskName;   // italic task name below timer
  final Color ringColor;
  final Color trackColor;
  final Color inkColor;
  final Color ink2Color;
  final Color ink3Color;
  final double size;
  final double strokeWidth;

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _anim = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(TimerRing old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _anim = Tween<double>(begin: _anim.value, end: widget.progress).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ring track + progress arc
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _RingPainter(
                progress: _anim.value,
                ringColor: widget.ringColor,
                trackColor: widget.trackColor,
                strokeWidth: widget.strokeWidth,
              ),
            ),
            // Center text
            Padding(
              padding: EdgeInsets.all(widget.strokeWidth * 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.sessionLabel,
                    style: TextStyle(fontFamily: AppFonts.mono, 
                      fontSize: 10,
                      color: widget.ink3Color,
                      letterSpacing: 0.14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(
                      widget.timeDisplay,
                      style: TextStyle(fontFamily: AppFonts.display, 
                        fontSize: widget.size * 0.30,
                        color: widget.inkColor,
                        letterSpacing: -0.02 * widget.size * 0.30,
                        height: 1.0,
                      ),
                    ),
                  ),
                  if (widget.taskName != null && widget.taskName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.taskName!,
                      style: TextStyle(fontFamily: AppFonts.display, 
                        fontSize: 14,
                        color: widget.ink2Color,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      // Progress arc
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
