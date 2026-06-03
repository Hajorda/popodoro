import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../controllers/timer_controller.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_typography.dart';
import '../../models/pomodoro_state.dart';
import '../../services/focus_guard_service.dart';
import '../../services/together_service.dart';
import '../../services/window_service.dart';

// ── Compact always-on-top overlay shown in mini (PiP) mode. ──────────────────
//
// v3 additions on top of v2:
//  • Pop-in entrance animation (scale + fade) when the pill first mounts.
//  • Subtle phase-coloured background tint on the pill body.
//  • Button row (skip/pause/expand) hides at rest and fades in on hover.
//  • Time digits cross-fade with a vertical slide on each tick.

void _startDragging() {
  if (WindowService.isDesktop) windowManager.startDragging();
}

class MiniTimerPill extends StatefulWidget {
  const MiniTimerPill({super.key});

  @override
  State<MiniTimerPill> createState() => _MiniTimerPillState();
}

class _MiniTimerPillState extends State<MiniTimerPill>
    with SingleTickerProviderStateMixin {
  // ── Entrance animation ──────────────────────────────────────────────────────
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceScale;
  late final Animation<double> _entranceOpacity;

  // Tracks whether the context menu overlay is open so we can dismiss it.
  OverlayEntry? _menuOverlay;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _entranceScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutBack),
    );
    _entranceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    // Fire the pop-in on the next frame so the window is fully painted first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _menuOverlay?.remove();
    _menuOverlay = null;
    super.dispose();
  }

  // ── Context menu (right-click) ──────────────────────────────────────────────

  void _showContextMenu(BuildContext context, TimerController timer,
      WindowService windowService) {
    _dismissContextMenu();

    final t = AppTokens.of(context);
    final overlay = Overlay.of(context);

    _menuOverlay = OverlayEntry(
      builder: (_) => _PillContextMenu(
        t: t,
        timer: timer,
        windowService: windowService,
        onDismiss: _dismissContextMenu,
      ),
    );
    overlay.insert(_menuOverlay!);
  }

  void _dismissContextMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final windowService = context.read<WindowService>();
    final together = context.watch<TogetherService>();

    final room = together.room;
    final inCoFocus =
        together.isInRoom && room != null && (room.isFocusing || room.isOnBreak);

    Widget content;

    // ── Room complete / exiting state ─────────────────────────────────────────
    if (together.isInRoom && room != null && !inCoFocus) {
      content = _buildShell(
        t: t,
        tintColor: t.sage,
        progress: 1.0,
        progressColor: t.sage,
        child: _RoomDonePill(t: t, room: room, windowService: windowService),
      );

    // ── Co-focus active ───────────────────────────────────────────────────────
    } else if (inCoFocus) {
      content = _buildShell(
        t: t,
        tintColor: room.isOnBreak ? t.sage : t.pop,
        progress: room.currentProgress,
        progressColor: room.isOnBreak ? t.sage : t.pop,
        child: _CoFocusPill(
          t: t,
          room: room,
          together: together,
          windowService: windowService,
        ),
      );

    // ── Solo timer ────────────────────────────────────────────────────────────
    } else {
      final timer = context.watch<TimerController>();
      final guardService = context.watch<FocusGuardService>();
      content = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () {
            if (timer.status == TimerStatus.running) {
              timer.pause();
            } else {
              timer.start();
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: _buildShell(
            t: t,
            tintColor: _phaseColor(timer.phase, t),
            progress: timer.progress,
            progressColor: _phaseColor(timer.phase, t),
            onSecondaryTap: () =>
                _showContextMenu(context, timer, windowService),
            onDoubleTap: windowService.exitMiniMode,
            child: _SoloPill(
              t: t,
              timer: timer,
              guardService: guardService,
              windowService: windowService,
              onContextMenu: () =>
                  _showContextMenu(context, timer, windowService),
            ),
          ),
        ),
      );
    }

    // ── Wrap everything in the entrance animation ──────────────────────────────
    return FadeTransition(
      opacity: _entranceOpacity,
      child: ScaleTransition(
        scale: _entranceScale,
        child: content,
      ),
    );
  }

  // ── Shared chrome ───────────────────────────────────────────────────────────
  //
  // All three pill variants share the same window chrome:
  //   • Warm background + 6% phase colour tint
  //   • Bottom border
  //   • 2 px progress bar anchored to the bottom edge
  //   • Double-tap and secondary-tap handlers on the outer shell
  Widget _buildShell({
    required AppTokens t,
    required Color tintColor,
    required double progress,
    required Color progressColor,
    required Widget child,
    VoidCallback? onDoubleTap,
    VoidCallback? onSecondaryTap,
  }) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      onSecondaryTap: onSecondaryTap,
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: t.bg,
        child: Stack(
          children: [
            // Phase tint — 6% overlay so the pill reads the current state
            // without fighting the rest of the UI.
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                color: tintColor.withValues(alpha: 0.06),
              ),
            ),

            // Main content sits above the tint.
            Container(
              decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: t.border, width: 0.5)),
              ),
              child: child,
            ),

            // 2 px progress bar pinned to the very bottom.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ProgressBar(
                progress: progress,
                color: progressColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return SizedBox(
          height: 2,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                width: (totalWidth * progress.clamp(0.0, 1.0)),
                height: 2,
                color: color,
              ),
              Expanded(child: const SizedBox()),
            ],
          ),
        );
      },
    );
  }
}

// ── Solo pill ─────────────────────────────────────────────────────────────────
//
// StatefulWidget so it can own:
//  • Mouse hover state → fade button row in/out

class _SoloPill extends StatefulWidget {
  const _SoloPill({
    required this.t,
    required this.timer,
    required this.guardService,
    required this.windowService,
    required this.onContextMenu,
  });

  final AppTokens t;
  final TimerController timer;
  final FocusGuardService guardService;
  final WindowService windowService;
  final VoidCallback onContextMenu;

  @override
  State<_SoloPill> createState() => _SoloPillState();
}

class _SoloPillState extends State<_SoloPill> {
  bool _hovered = false;

  bool get _isGuardPaused =>
      widget.guardService.status == GuardStatus.noPersonDetected ||
      widget.guardService.status == GuardStatus.phoneDetected;

  bool get _isRunning => widget.timer.status == TimerStatus.running;
  bool get _isPaused => widget.timer.status == TimerStatus.paused;

  // Decide what to show in the label slot:
  //   • Focus Guard paused → "👁 AWAY" in amber
  //   • Task name set      → task name (truncated)
  //   • Otherwise          → phase label (FOCUS / SHORT BREAK / …)
  String get _labelText {
    if (_isGuardPaused) return '👁  AWAY';
    if (widget.timer.taskName.isNotEmpty) {
      return widget.timer.taskName.toUpperCase();
    }
    return _isPaused ? 'PAUSED' : widget.timer.phase.labelUpper;
  }

  Color get _labelColor {
    final t = widget.t;
    if (_isGuardPaused) return t.ember;
    if (_isPaused) return t.ink2;
    if (widget.timer.taskName.isNotEmpty) return t.ink2;
    return t.ink3;
  }

  FontWeight get _labelWeight {
    if (_isGuardPaused || _isPaused) return FontWeight.w700;
    return FontWeight.w400;
  }

  double get _labelSpacing {
    if (_isPaused || _isGuardPaused) return 0.24;
    return 0.12;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final timer = widget.timer;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Drag handle (left side only) ───────────────────────────────────
          // Only this region initiates a native window drag, so the buttons on
          // the right can be tapped without accidentally dragging the window.
          GestureDetector(
            onPanStart: (_) => _startDragging(),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 32,
              height: double.infinity,
              child: Center(
                child: _PhaseDot(
                  phase: timer.phase,
                  isRunning: _isRunning,
                  isGuardPaused: _isGuardPaused,
                  t: t,
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // ── Time display with per-tick digit slide ─────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            // Slide new digit up from below; old digit exits upward.
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOut,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            // Key on the display string so only a changed value triggers the
            // transition — no flicker when other state (e.g. hover) updates.
            child: Text(
              timer.timeDisplay,
              key: ValueKey(timer.timeDisplay),
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _isPaused ? t.ink3 : t.ink,
                letterSpacing: -1,
                height: 1.0,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Label / task name ──────────────────────────────────────────────
          Expanded(
            child: Text(
              _labelText,
              style: TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 9,
                letterSpacing: _labelSpacing,
                fontWeight: _labelWeight,
                color: _labelColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Button row: fades in on hover, hidden at rest ──────────────────
          // Always in the layout (no Visibility) so the pill width never jumps.
          // AnimatedOpacity + IgnorePointer together provide the reveal without
          // layout shifts.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            opacity: _hovered || _isPaused || _isGuardPaused ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_hovered && !_isPaused && !_isGuardPaused,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip
                  _PillIconButton(
                    icon: Icons.skip_next_rounded,
                    color: t.ink3,
                    label: 'Skip phase',
                    onTap: timer.skipPhase,
                  ),
                  // Play / Pause
                  _PillIconButton(
                    icon: _isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: _isGuardPaused ? t.ember : t.ink2,
                    label: _isRunning ? 'Pause' : 'Resume',
                    onTap: () {
                      if (_isRunning) {
                        timer.pause();
                      } else {
                        timer.start();
                      }
                    },
                  ),
                  // Expand
                  _PillIconButton(
                    icon: Icons.open_in_full_rounded,
                    color: t.ink3,
                    label: 'Expand',
                    onTap: widget.windowService.exitMiniMode,
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

// ── Co-focus pill ─────────────────────────────────────────────────────────────

class _CoFocusPill extends StatelessWidget {
  const _CoFocusPill({
    required this.t,
    required this.room,
    required this.together,
    required this.windowService,
  });

  final AppTokens t;
  final TogetherRoom room;
  final TogetherService together;
  final WindowService windowService;

  @override
  Widget build(BuildContext context) {
    final dotColor = room.isOnBreak ? t.sage : t.pop;
    final label = room.isOnBreak ? 'SHORT BREAK' : 'TOGETHER';
    final participantCount = together.onlineParticipants.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle
        GestureDetector(
          onPanStart: (_) => _startDragging(),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 32,
            height: double.infinity,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: dotColor),
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        // Time
        Text(
          room.timeDisplay,
          style: TextStyle(
            fontFamily: AppFonts.mono,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: t.ink,
            letterSpacing: -1,
            height: 1.0,
          ),
        ),

        const SizedBox(width: 8),

        // Label + participant count
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 9,
                  letterSpacing: 0.12,
                  color: t.ink3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (participantCount > 0)
                Text(
                  '👥 $participantCount',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8,
                    color: t.ink3,
                  ),
                ),
            ],
          ),
        ),

        _PillIconButton(
          icon: Icons.open_in_full_rounded,
          color: t.ink3,
          label: 'Expand',
          onTap: windowService.exitMiniMode,
        ),
      ],
    );
  }
}

// ── Room done pill ────────────────────────────────────────────────────────────

class _RoomDonePill extends StatelessWidget {
  const _RoomDonePill({
    required this.t,
    required this.room,
    required this.windowService,
  });

  final AppTokens t;
  final TogetherRoom room;
  final WindowService windowService;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle
        GestureDetector(
          onPanStart: (_) => _startDragging(),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 32,
            height: double.infinity,
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: t.sage),
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            room.isComplete ? 'SESSION DONE' : 'TOGETHER',
            style: TextStyle(
              fontFamily: AppFonts.mono,
              fontSize: 11,
              letterSpacing: 0.12,
              color: t.ink2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        _PillIconButton(
          icon: Icons.open_in_full_rounded,
          color: t.ink2,
          label: 'Expand',
          onTap: windowService.exitMiniMode,
        ),
      ],
    );
  }
}

// ── Context menu overlay ──────────────────────────────────────────────────────

class _PillContextMenu extends StatelessWidget {
  const _PillContextMenu({
    required this.t,
    required this.timer,
    required this.windowService,
    required this.onDismiss,
  });

  final AppTokens t;
  final TimerController timer;
  final WindowService windowService;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap outside the menu dismisses it.
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          // Offset from the top-right to sit comfortably below the pill buttons.
          padding: const EdgeInsets.only(top: 12, right: 8),
          child: _MenuCard(
            t: t,
            items: [
              _MenuItem(
                label: 'Skip phase',
                icon: Icons.skip_next_rounded,
                onTap: () {
                  onDismiss();
                  timer.skipPhase();
                },
              ),
              _MenuItem(
                label: '+5 min',
                icon: Icons.more_time_rounded,
                onTap: () {
                  onDismiss();
                  timer.addMinutes(5);
                },
              ),
              _MenuItem(
                label: 'Reset',
                icon: Icons.refresh_rounded,
                onTap: () {
                  onDismiss();
                  timer.reset();
                },
              ),
              _MenuItem(
                label: 'Expand',
                icon: Icons.open_in_full_rounded,
                onTap: () {
                  onDismiss();
                  windowService.exitMiniMode();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.t, required this.items});

  final AppTokens t;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: t.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map((item) => _MenuItemRow(t: t, item: item))
              .toList(),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _MenuItemRow extends StatefulWidget {
  const _MenuItemRow({required this.t, required this.item});

  final AppTokens t;
  final _MenuItem item;

  @override
  State<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends State<_MenuItemRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.item.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _hovered ? t.surface2 : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 13, color: t.ink2),
              const SizedBox(width: 8),
              Text(
                widget.item.label,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 11,
                  color: t.ink2,
                  letterSpacing: 0.08,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

Color _phaseColor(TimerPhase phase, AppTokens t) {
  switch (phase) {
    case TimerPhase.focus:
      return t.pop;
    case TimerPhase.shortBreak:
      return t.sage;
    case TimerPhase.longBreak:
      return t.lavender;
  }
}

// ── Phase dot with pulse animation while running ──────────────────────────────

class _PhaseDot extends StatefulWidget {
  const _PhaseDot({
    required this.phase,
    required this.isRunning,
    required this.isGuardPaused,
    required this.t,
  });

  final TimerPhase phase;
  final bool isRunning;
  final bool isGuardPaused;
  final AppTokens t;

  @override
  State<_PhaseDot> createState() => _PhaseDotState();
}

class _PhaseDotState extends State<_PhaseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_PhaseDot old) {
    super.didUpdateWidget(old);
    if (old.isRunning != widget.isRunning) _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.isRunning && !widget.isGuardPaused) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.animateTo(0.0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _color {
    if (widget.isGuardPaused) return widget.t.ember;
    switch (widget.phase) {
      case TimerPhase.focus:
        return widget.t.pop;
      case TimerPhase.shortBreak:
        return widget.t.sage;
      case TimerPhase.longBreak:
        return widget.t.lavender;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 8,
        height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _color),
      ),
    );
  }
}

// ── Icon button ───────────────────────────────────────────────────────────────

class _PillIconButton extends StatefulWidget {
  const _PillIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;

  @override
  State<_PillIconButton> createState() => _PillIconButtonState();
}

class _PillIconButtonState extends State<_PillIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hovered
                      ? t.surface2
                      : Colors.transparent,
                ),
                child: Center(
                  child: Icon(widget.icon, size: 15, color: widget.color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
