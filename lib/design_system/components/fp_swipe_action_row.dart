import 'dart:async';
import 'dart:math' as math;

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/fp_haptics.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Pure geometry of a swipe-to-reveal row (tested without widgets).
///
/// Offsets are horizontal translations of the row's foreground: `0` is
/// closed, `-reveal` is fully open (the action tray is visible), and a
/// dismissible row keeps following the finger past the tray.
abstract final class FpSwipeActionMath {
  /// Width of one action in the tray.
  static const double actionWidth = 72;

  /// The row snaps open once this fraction of the tray is revealed.
  static const double openThreshold = 0.5;

  /// A horizontal fling faster than this (px/s) toggles open/closed
  /// regardless of where the finger stopped.
  static const double flingVelocity = 800;

  /// A dismissible row released past this fraction of its own width (or
  /// flung further than the tray) is dismissed.
  static const double dismissFraction = 0.55;

  /// How much of the finger's movement a non-dismissible row follows once
  /// the tray is fully revealed.
  static const double overdragResistance = 0.3;

  /// The tray width for [actions] actions.
  static double revealWidth(int actions) => math.max(0, actions) * actionWidth;

  /// Maps the cumulative drag [raw] onto the foreground offset.
  ///
  /// Right swipes are ignored; past the tray a dismissible row follows the
  /// finger (bounded by `-rowWidth`), a non-dismissible one resists.
  static double clampOffset(
    double raw, {
    required double reveal,
    required double rowWidth,
    required bool dismissible,
  }) {
    if (raw.isNaN || raw >= 0) return 0;
    if (raw >= -reveal) return raw;
    if (dismissible) return math.max(raw, -rowWidth);
    return -reveal + (raw + reveal) * overdragResistance;
  }

  /// 0 closed … 1 fully revealed.
  static double progress(double offset, {required double reveal}) =>
      reveal <= 0 ? 0 : (-offset / reveal).clamp(0.0, 1.0);

  /// True once the tray is revealed at least [openThreshold] of the way.
  static bool isPastThreshold(double offset, {required double reveal}) =>
      reveal > 0 && progress(offset, reveal: reveal) >= openThreshold;

  /// Where the row settles on release: `0` (closed) or `-reveal` (open).
  static double snapTarget({
    required double offset,
    required double velocity,
    required double reveal,
  }) {
    if (reveal <= 0) return 0;
    if (velocity <= -flingVelocity) return -reveal;
    if (velocity >= flingVelocity) return 0;
    return isPastThreshold(offset, reveal: reveal) ? -reveal : 0;
  }

  /// Whether a release at [offset] dismisses the row.
  static bool shouldDismiss({
    required double offset,
    required double velocity,
    required double reveal,
    required double rowWidth,
    required bool dismissible,
  }) {
    if (!dismissible || rowWidth <= 0) return false;
    if (-offset >= rowWidth * dismissFraction) return true;
    return -offset > reveal && velocity <= -flingVelocity;
  }
}

/// The visual weight of a swipe action.
enum FpSwipeActionTone {
  /// Pop-white face, dark glyph (e.g. "Details").
  neutral,

  /// Alert face (e.g. "Delete").
  danger,
}

/// One action in the tray behind an [FpSwipeActionRow].
@immutable
class FpSwipeAction {
  const FpSwipeAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = FpSwipeActionTone.neutral,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final FpSwipeActionTone tone;
}

/// Closes an [FpSwipeActionRow] from outside (e.g. when another row opens).
class FpSwipeActionController extends ChangeNotifier {
  bool _closeRequested = false;

  /// Asks the row to snap closed.
  void close() {
    _closeRequested = true;
    notifyListeners();
  }
}

/// A list row that slides left to reveal up to three NeoPOP actions and,
/// when [onDismissed] is given, slides away entirely when dragged far
/// enough. Pure maths in [FpSwipeActionMath].
///
/// Screen readers get the actions as custom semantics actions (plus
/// "Dismiss" when dismissible), so nothing depends on the gesture.
class FpSwipeActionRow extends StatefulWidget {
  const FpSwipeActionRow({
    required this.child,
    required this.actions,
    super.key,
    this.onDismissed,
    this.onTap,
    this.semanticLabel,
    this.controller,
    this.haptics,
    this.enabled = true,
  }) : assert(
         actions.length >= 1 && actions.length <= 3,
         'one to three actions',
       );

  final Widget child;
  final List<FpSwipeAction> actions;

  /// Called once the row has slid away; null makes the row non-dismissible.
  final VoidCallback? onDismissed;

  /// Tap on the foreground while closed.
  final VoidCallback? onTap;
  final String? semanticLabel;
  final FpSwipeActionController? controller;
  final HapticService? haptics;
  final bool enabled;

  @override
  State<FpSwipeActionRow> createState() => _FpSwipeActionRowState();
}

class _FpSwipeActionRowState extends State<FpSwipeActionRow>
    with TickerProviderStateMixin {
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _height = AnimationController(
    vsync: this,
    duration: FpMotion.standard,
    value: 1,
  );
  double _raw = 0;
  double _rowWidth = 1;
  bool _dismissed = false;

  bool get _dismissible => widget.onDismissed != null;
  double get _reveal => FpSwipeActionMath.revealWidth(widget.actions.length);
  // A settled spring can rest a hair below zero; that is still "closed".
  bool get _isOpen => _offset.value < -0.5;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onController);
  }

  @override
  void didUpdateWidget(FpSwipeActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onController);
      widget.controller?.addListener(_onController);
    }
  }

  void _onController() {
    final c = widget.controller;
    if (c == null || !c._closeRequested) return;
    c._closeRequested = false;
    if (_isOpen) _animateTo(0, 0);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _offset.dispose();
    _height.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _offset.stop();
    _raw = _offset.value;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final before = _offset.value;
    _raw += details.delta.dx;
    final next = FpSwipeActionMath.clampOffset(
      _raw,
      reveal: _reveal,
      rowWidth: _rowWidth,
      dismissible: _dismissible,
    );
    _offset.value = next;
    final wasPast = FpSwipeActionMath.isPastThreshold(before, reveal: _reveal);
    final isPast = FpSwipeActionMath.isPastThreshold(next, reveal: _reveal);
    if (wasPast != isPast) playHaptic(widget.haptics, HapticType.selection);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (FpSwipeActionMath.shouldDismiss(
      offset: _offset.value,
      velocity: velocity,
      reveal: _reveal,
      rowWidth: _rowWidth,
      dismissible: _dismissible,
    )) {
      unawaited(_dismiss());
      return;
    }
    _animateTo(
      FpSwipeActionMath.snapTarget(
        offset: _offset.value,
        velocity: velocity,
        reveal: _reveal,
      ),
      velocity,
    );
  }

  void _animateTo(double target, double velocity) {
    if (FpMotion.of(context).reduce) {
      _offset.value = target;
      return;
    }
    _offset.animateWith(
      FpSprings.simulation(
        FpSprings.slider,
        start: _offset.value,
        end: target,
        velocity: velocity,
      ),
    );
  }

  Future<void> _dismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    playHaptic(widget.haptics, HapticType.medium);
    final reduce = FpMotion.of(context).reduce;
    if (!reduce) {
      await _offset.animateTo(
        -_rowWidth,
        duration: FpMotion.standard,
        curve: FpMotion.emphasizedAccelerate,
      );
      if (!mounted) return;
      await _height.reverse();
      if (!mounted) return;
    } else {
      _offset.value = -_rowWidth;
      _height.value = 0;
    }
    widget.onDismissed?.call();
  }

  void _runAction(FpSwipeAction action) {
    _animateTo(0, 0);
    action.onPressed();
  }

  void _onTap() {
    if (_isOpen) {
      _animateTo(0, 0);
      return;
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final interactive = widget.enabled && !_dismissed;

    final tray = Positioned.fill(
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerRight,
          child: AnimatedBuilder(
            animation: _offset,
            builder: (context, child) {
              final visible = (-_offset.value).clamp(0.0, _reveal);
              return SizedBox(
                width: visible,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: 0,
                  maxWidth: _reveal,
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in widget.actions)
                  _ActionTile(
                    action: action,
                    onPressed: interactive ? () => _runAction(action) : null,
                    haptics: widget.haptics,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final foreground = AnimatedBuilder(
      animation: _offset,
      builder: (context, child) =>
          Transform.translate(offset: Offset(_offset.value, 0), child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // `down`: the movement that resolved the gesture counts, so the row
        // follows the finger from the first pixel instead of jumping.
        dragStartBehavior: DragStartBehavior.down,
        onTap: interactive ? _onTap : null,
        onHorizontalDragStart: interactive ? _onDragStart : null,
        onHorizontalDragUpdate: interactive ? _onDragUpdate : null,
        onHorizontalDragEnd: interactive ? _onDragEnd : null,
        child: ColoredBox(
          color: c.background,
          child: ExcludeSemantics(
            excluding: widget.semanticLabel != null,
            child: widget.child,
          ),
        ),
      ),
    );

    final body = LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isFinite) _rowWidth = constraints.maxWidth;
        // Passthrough: the foreground takes the row's full width (the
        // stack would otherwise shrink-wrap it to the child's width).
        return Stack(fit: StackFit.passthrough, children: [tray, foreground]);
      },
    );

    return Semantics(
      label: widget.semanticLabel,
      customSemanticsActions: interactive
          ? {
              for (final action in widget.actions)
                CustomSemanticsAction(label: action.label): action.onPressed,
              if (_dismissible)
                const CustomSemanticsAction(label: 'Dismiss'): _dismiss,
            }
          : const {},
      child: SizeTransition(
        sizeFactor: _height,
        alignment: Alignment.topCenter,
        child: ClipRect(
          child: RepaintBoundary(
            child: SizedBox(
              width: double.infinity,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: FpSpacing.minTapTarget,
                ),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.onPressed,
    required this.haptics,
  });

  final FpSwipeAction action;
  final VoidCallback? onPressed;
  final HapticService? haptics;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final (Color face, Color ink) = switch (action.tone) {
      FpSwipeActionTone.neutral => (c.popWhite, c.onPop),
      FpSwipeActionTone.danger => (c.alertFill, c.onAlert),
    };
    return SizedBox(
      width: FpSwipeActionMath.actionWidth,
      child: Semantics(
        button: true,
        label: action.label,
        child: GestureDetector(
          key: ValueKey('fp-swipe-action-${action.label}'),
          behavior: HitTestBehavior.opaque,
          onTap: onPressed == null
              ? null
              : () {
                  playHaptic(haptics, HapticType.light);
                  onPressed!();
                },
          child: ColoredBox(
            color: face,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(action.icon, color: ink, size: 20),
                const SizedBox(height: FpSpacing.xs),
                Text(
                  action.label,
                  style: fp.text.caption.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
