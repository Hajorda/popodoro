import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../mascot/pop_mascot.dart';

// Timer variant: Pop mascot fills bottom-up with accent color as progress grows.
// Time displayed in a floating badge at the bottom of the mascot.
class TimerKernel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sessionLabel,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 10,
            color: ink3Color,
            letterSpacing: 0.14,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: _mascotSize,
          height: _mascotSize + 18, // extra for badge overflow
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Base mascot — muted (surface2) accent
              PopMascot(
                size: _mascotSize,
                mood: PopMood.focused,
                accentColor: baseColor,
                bumpColor: bumpColor,
                bumpEdgeColor: bumpEdgeColor,
                inkColor: inkColor,
              ),
              // Filled overlay — clipped from the bottom up
              ClipRect(
                clipper: _BottomFillClipper(progress: progress.clamp(0.0, 1.0)),
                child: PopMascot(
                  size: _mascotSize,
                  mood: PopMood.focused,
                  accentColor: activeColor,
                  bumpColor: bumpColor,
                  bumpEdgeColor: bumpEdgeColor,
                  inkColor: inkColor,
                ),
              ),
              // Time badge overlaid at the bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      timeDisplay,
                      style: TextStyle(
                        fontFamily: AppFonts.display,
                        fontSize: 36,
                        color: inkColor,
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
            color: ink2Color,
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
