import 'dart:async';

import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:fin_pay/design_system/tokens/fp_spacing.dart';
import 'package:flutter/material.dart';

/// Toast flavour.
enum FpToastKind { success, error, info }

/// A handle for a shown toast.
class FpToastHandle {
  FpToastHandle._();

  final Completer<void> _closed = Completer<void>();
  VoidCallback? _dismiss;
  bool _actionTaken = false;

  /// True once the action button was tapped (before [closed] completes).
  bool get actionTaken => _actionTaken;

  /// Completes when the toast has left the screen.
  Future<void> get closed => _closed.future;

  /// Dismisses the toast early.
  void dismiss() => _dismiss?.call();
}

/// Top-anchored toast: slides and fades in, auto-dismisses, tap to dismiss.
/// Only one toast is visible at a time; a new one replaces the current.
class FpToast {
  const FpToast._();

  static FpToastHandle? _current;

  /// Default time on screen.
  static const Duration defaultDuration = Duration(seconds: 3);

  /// Shows [message] over the root overlay of [context].
  static FpToastHandle show(
    BuildContext context, {
    required String message,
    FpToastKind kind = FpToastKind.info,
    Duration duration = defaultDuration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _current?.dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    final handle = FpToastHandle._();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FpToastView(
        message: message,
        kind: kind,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        handle: handle,
        onClosed: () {
          if (entry.mounted) entry.remove();
          if (identical(_current, handle)) _current = null;
          if (!handle._closed.isCompleted) handle._closed.complete();
        },
      ),
    );
    _current = handle;
    overlay.insert(entry);
    return handle;
  }

  /// The toast currently on screen, if any.
  static FpToastHandle? get current => _current;
}

class _FpToastView extends StatefulWidget {
  const _FpToastView({
    required this.message,
    required this.kind,
    required this.duration,
    required this.handle,
    required this.onClosed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final FpToastKind kind;
  final Duration duration;
  final FpToastHandle handle;
  final VoidCallback onClosed;

  /// Optional action (e.g. "Undo"); tapping it runs [onAction] once and
  /// closes the toast.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_FpToastView> createState() => _FpToastViewState();
}

class _FpToastViewState extends State<_FpToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FpMotion.emphasized,
    reverseDuration: FpMotion.standard,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _controller,
    curve: FpMotion.emphasizedDecelerate,
    reverseCurve: FpMotion.emphasizedAccelerate,
  );
  Timer? _timer;
  bool _closing = false;
  bool _started = false;
  bool _actionFired = false;

  /// True when the toast's action was used before it closed.
  bool get actionFired => _actionFired;

  void _runAction() {
    if (_actionFired || _closing) return;
    _actionFired = true;
    widget.handle._actionTaken = true;
    widget.onAction?.call();
    _close();
  }

  @override
  void initState() {
    super.initState();
    widget.handle._dismiss = _close;
    _controller.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (_closing && status == AnimationStatus.dismissed) widget.onClosed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (FpMotion.of(context).reduce) {
      _controller.duration = FpMotion.fast;
      _controller.reverseDuration = FpMotion.fast;
    }
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (_controller.isDismissed) {
      widget.onClosed();
      return;
    }
    // onClosed fires from the status listener, inside the frame, so callers
    // that pump until idle see the entry removed.
    _controller.reverse();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.handle._dismiss = null;
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final reduce = FpMotion.of(context).reduce;
    final (Color accent, IconData icon, String role) = switch (widget.kind) {
      FpToastKind.success => (c.success, Icons.check_circle_outline, 'Success'),
      FpToastKind.error => (c.alert, Icons.error_outline, 'Error'),
      FpToastKind.info => (c.info, Icons.info_outline, 'Info'),
    };
    final curved = _curved;
    final actionLabel = widget.actionLabel;
    Widget card = Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        label: '$role: ${widget.message}',
        button: true,
        onTap: _close,
        explicitChildNodes: actionLabel != null,
        child: ExcludeSemantics(
          excluding: actionLabel == null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: FpSpacing.minTapTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: FpSpacing.lg,
                vertical: FpSpacing.md,
              ),
              decoration: BoxDecoration(
                color: c.surfaceHigh,
                border: Border(
                  left: BorderSide(color: accent, width: 4),
                  top: BorderSide(color: c.borderStrong),
                  right: BorderSide(color: c.borderStrong),
                  bottom: BorderSide(color: c.borderStrong),
                ),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(child: Icon(icon, color: accent, size: 20)),
                  const SizedBox(width: FpSpacing.md),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Text(
                        widget.message,
                        style: fp.text.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: FpSpacing.sm),
                    _ToastAction(label: actionLabel, onPressed: _runAction),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    card = FadeTransition(opacity: curved, child: card);
    if (!reduce) {
      card = SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.2),
          end: Offset.zero,
        ).animate(curved),
        child: card,
      );
    }
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(FpSpacing.lg),
          child: RepaintBoundary(child: card),
        ),
      ),
    );
  }
}

/// The toast's action button: pop-white label, ≥ 48 dp target.
class _ToastAction extends StatelessWidget {
  const _ToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('fp-toast-action'),
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: FpSpacing.minTapTarget,
              minHeight: FpSpacing.minTapTarget,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: FpSpacing.sm),
                child: Text(
                  label.toUpperCase(),
                  style: fp.text.label.copyWith(color: c.success),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
