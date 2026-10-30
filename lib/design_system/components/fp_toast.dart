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
  });

  final String message;
  final FpToastKind kind;
  final Duration duration;
  final FpToastHandle handle;
  final VoidCallback onClosed;

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
    Widget card = Material(
      type: MaterialType.transparency,
      child: Semantics(
        liveRegion: true,
        label: '$role: ${widget.message}',
        button: true,
        onTap: _close,
        child: ExcludeSemantics(
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
                  Icon(icon, color: accent, size: 20),
                  const SizedBox(width: FpSpacing.md),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: fp.text.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
