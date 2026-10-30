import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// NeoPOP modal bottom sheet with spring physics and drag-to-dismiss.
///
/// The sheet enters on [FpSprings.sheet]; dragging follows the finger and,
/// on release, either snaps back or dismisses depending on position and
/// fling velocity. Only one sheet is open at a time: a second [show] while
/// one is open returns `null` immediately (a double-tap on "open" never
/// stacks two sheets). With reduced motion the sheet fades in and out.
class FpBottomSheet {
  const FpBottomSheet._();

  static _FpSheetRoute<dynamic>? _current;

  /// True while a sheet is on screen.
  static bool get isOpen => _current?.isActive ?? false;

  /// Forgets the current sheet. For tests only.
  @visibleForTesting
  static void reset() => _current = null;

  /// Downward fling velocity (px/s) that dismisses regardless of position.
  static const double dismissVelocity = 700;

  /// Fraction of the sheet that must remain visible on release to snap back.
  static const double dismissThreshold = 0.5;

  /// Pure decision used on drag release. [visible] is the fraction still on
  /// screen; [velocity] is the vertical velocity in px/s (down is positive).
  static bool shouldDismiss({
    required double visible,
    required double velocity,
  }) {
    if (velocity >= dismissVelocity) return true;
    if (velocity <= -dismissVelocity) return false;
    return visible < dismissThreshold;
  }

  /// Shows the sheet and completes with the value passed to `Navigator.pop`.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    String? title,
    String barrierLabel = 'Dismiss',
    bool isDismissible = true,
    bool useRootNavigator = true,
  }) async {
    if (isOpen) return null;
    final c = context.fp.colors;
    final route = _FpSheetRoute<T>(
      builder: builder,
      title: title,
      barrierLabelText: barrierLabel,
      dismissible: isDismissible,
      scrim: c.scrim,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    _current = route;
    try {
      return await Navigator.of(
        context,
        rootNavigator: useRootNavigator,
      ).push<T>(route);
    } finally {
      if (identical(_current, route)) _current = null;
    }
  }
}

class _FpSheetRoute<T> extends PopupRoute<T> {
  _FpSheetRoute({
    required this.builder,
    required this.title,
    required this.barrierLabelText,
    required this.dismissible,
    required this.scrim,
    required this.reduceMotion,
  });

  final WidgetBuilder builder;
  final String? title;
  final String barrierLabelText;
  final bool dismissible;
  final Color scrim;
  final bool reduceMotion;

  AnimationController? _sheetController;

  @override
  Color? get barrierColor => scrim;

  @override
  bool get barrierDismissible => dismissible;

  @override
  String? get barrierLabel => barrierLabelText;

  @override
  Duration get transitionDuration =>
      reduceMotion ? FpMotion.fast : FpMotion.emphasized;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? FpMotion.fast : FpMotion.standard;

  @override
  AnimationController createAnimationController() {
    final controller = super.createAnimationController();
    _sheetController = controller;
    return controller;
  }

  @override
  TickerFuture didPush() {
    final future = super.didPush();
    final controller = _sheetController;
    if (controller != null && !reduceMotion) {
      // Replace the curve-driven forward with a spring.
      return controller.animateWith(
        FpSprings.simulation(FpSprings.sheet, start: controller.value, end: 1),
      );
    }
    return future;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _FpSheetBody<T>(
      route: this,
      animation: animation,
      title: title,
      child: builder(context),
    );
  }
}

class _FpSheetBody<T> extends StatefulWidget {
  const _FpSheetBody({
    required this.route,
    required this.animation,
    required this.title,
    required this.child,
  });

  final _FpSheetRoute<T> route;
  final Animation<double> animation;
  final String? title;
  final Widget child;

  @override
  State<_FpSheetBody<T>> createState() => _FpSheetBodyState<T>();
}

class _FpSheetBodyState<T> extends State<_FpSheetBody<T>> {
  final GlobalKey _sheetKey = GlobalKey();
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    // `animateWith` always reports `completed`, even when the simulation
    // ends at zero, so accept either terminal status while dismissing.
    if (!_dismissing || status.isAnimating) return;
    if (mounted && widget.route.isCurrent) Navigator.of(context).pop();
  }

  AnimationController? get _controller => widget.route._sheetController;

  double get _sheetHeight =>
      _sheetKey.currentContext?.size?.height ??
      MediaQuery.sizeOf(context).height;

  void _onDragUpdate(DragUpdateDetails details) {
    final controller = _controller;
    if (controller == null || _dismissing) return;
    controller.value -= details.primaryDelta! / _sheetHeight;
  }

  void _onDragEnd(DragEndDetails details) {
    final controller = _controller;
    if (controller == null || _dismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    final visible = controller.value;
    if (FpBottomSheet.shouldDismiss(visible: visible, velocity: velocity)) {
      _dismiss(velocity: -velocity / _sheetHeight);
    } else {
      controller.animateWith(
        FpSprings.simulation(
          FpSprings.sheet,
          start: visible,
          end: 1,
          velocity: -velocity / _sheetHeight,
        ),
      );
    }
  }

  void _dismiss({double velocity = 0}) {
    if (_dismissing) return;
    _dismissing = true;
    final controller = _controller;
    if (controller == null || widget.route.reduceMotion) {
      if (widget.route.isCurrent) Navigator.of(context).pop();
      return;
    }
    // Spring the sheet out; the status listener pops the route when the
    // animation reaches zero.
    controller.animateWith(
      FpSprings.simulation(
        FpSprings.sheet,
        start: controller.value,
        end: 0,
        velocity: velocity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = widget.route.reduceMotion;
    final title = widget.title;

    Widget sheet = Container(
      key: _sheetKey,
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderStrong, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Drag handle. Swipe down to dismiss',
              button: true,
              onTap: widget.route.dismissible ? _dismiss : null,
              child: GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTap: widget.route.dismissible ? _dismiss : null,
                onVerticalDragUpdate: widget.route.dismissible
                    ? _onDragUpdate
                    : null,
                onVerticalDragEnd: widget.route.dismissible ? _onDragEnd : null,
                child: SizedBox(
                  height: FpSpacing.minTapTarget,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      color: c.borderStrong,
                    ),
                  ),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.xl,
                  0,
                  FpSpacing.xl,
                  FpSpacing.md,
                ),
                child: Text(title, style: fp.text.title, semanticsLabel: title),
              ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.xl,
                  0,
                  FpSpacing.xl,
                  FpSpacing.xl,
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );

    sheet = Semantics(
      container: true,
      scopesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Material(type: MaterialType.transparency, child: sheet),
    );

    if (reduce) {
      sheet = FadeTransition(opacity: widget.animation, child: sheet);
    } else {
      sheet = AnimatedBuilder(
        animation: widget.animation,
        child: sheet,
        builder: (context, child) => FractionalTranslation(
          key: const ValueKey('fp-sheet-translation'),
          translation: Offset(0, 1 - widget.animation.value.clamp(0.0, 1.5)),
          child: child,
        ),
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: sheet,
      ),
    );
  }
}
