import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../mascot/pop_mascot.dart';

class TimerKernel extends StatefulWidget {
  const TimerKernel({
    super.key,
    required this.progress,
    required this.timeDisplay,
    required this.sessionLabel,
    required this.activeColor,
    required this.baseColor,
    required this.bumpColor,
    required this.bumpEdgeColor,
    required this.inkColor,
    required this.ink2Color,
    required this.ink3Color,
    required this.surfaceColor,
    required this.borderColor,
  });

  final double progress;
  final String timeDisplay;
  final String sessionLabel;
  final Color activeColor;
  final Color baseColor;
  final Color bumpColor;
  final Color bumpEdgeColor;
  final Color inkColor;
  final Color ink2Color;
  final Color ink3Color;
  final Color surfaceColor;
  final Color borderColor;

  static const double _mascotSize = 200;

  @override
  State<TimerKernel> createState() => _TimerKernelState();
}

class _TimerKernelState extends State<TimerKernel> {
  static final _rng = math.Random();

  bool _eyesClosed = false;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _scheduleBlink();
  }

  void _scheduleBlink() {
    // Random interval 3–7 s so it feels natural, not mechanical
    final delay = Duration(milliseconds: 3000 + _rng.nextInt(4000));
    _blinkTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _eyesClosed = true);
      Timer(const Duration(milliseconds: 110), () {
        if (!mounted) return;
        setState(() => _eyesClosed = false);
        _scheduleBlink();
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.progress * 100).round();
    const mascotSize = TimerKernel._mascotSize;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.sessionLabel,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            color: widget.ink3Color,
            letterSpacing: 0.14,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: mascotSize,
          height: mascotSize + 18,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Base mascot
              PopMascot(
                size: mascotSize,
                mood: PopMood.focused,
                eyesClosed: _eyesClosed,
                accentColor: widget.baseColor,
                bumpColor: widget.bumpColor,
                bumpEdgeColor: widget.bumpEdgeColor,
                inkColor: widget.inkColor,
              ),
              // Fill overlay clipped bottom-up
              ClipRect(
                clipper: _BottomFillClipper(
                    progress: widget.progress.clamp(0.0, 1.0)),
                child: PopMascot(
                  size: mascotSize,
                  mood: PopMood.focused,
                  eyesClosed: _eyesClosed,
                  accentColor: widget.activeColor,
                  bumpColor: widget.bumpColor,
                  bumpEdgeColor: widget.bumpEdgeColor,
                  inkColor: widget.inkColor,
                ),
              ),
              // Time badge
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.timeDisplay,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 36,
                        color: widget.inkColor,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '$pct% popped',
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: 18,
            color: widget.ink2Color,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _BottomFillClipper extends CustomClipper<Rect> {
  const _BottomFillClipper({required this.progress});
  final double progress;

  @override
  Rect getClip(Size size) {
    final fillHeight = size.height * progress;
    return Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight);
  }

  @override
  bool shouldReclip(_BottomFillClipper old) => old.progress != progress;
}
