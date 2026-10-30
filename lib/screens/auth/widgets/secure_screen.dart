import 'package:fin_pay/core/platform/screen_protector.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

/// Turns screenshot / recents protection (`FLAG_SECURE`) on while any
/// [SecureScreen] is mounted and off when the last one goes away.
///
/// The count matters: login → create account pushes a second protected
/// screen over the first, and popping it must not switch protection off
/// while the login form is still visible.
class SecureScreen extends StatefulWidget {
  const SecureScreen({
    required this.child,
    super.key,
    this.protector,
    this.active = true,
  });

  final Widget child;

  /// When false the screen does not count as protected (a tab that is
  /// mounted in an `IndexedStack` but not the visible one). Toggling it
  /// enables or disables protection like mounting / unmounting would.
  final bool active;

  /// Injected for tests; defaults to the GetIt registration (no-op when
  /// none is registered).
  final ScreenProtector? protector;

  /// Number of mounted protected screens.
  static int get activeCount => _active;
  static int _active = 0;

  /// Resets the counter between tests.
  @visibleForTesting
  static void debugReset() => _active = 0;

  static ScreenProtector? _resolve(ScreenProtector? given) {
    if (given != null) return given;
    if (GetIt.I.isRegistered<ScreenProtector>()) return GetIt.I();
    return null;
  }

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  ScreenProtector? _protector;
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    _protector = SecureScreen._resolve(widget.protector);
    if (widget.active) _acquire();
  }

  @override
  void didUpdateWidget(SecureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _acquire();
    } else {
      _release();
    }
  }

  void _acquire() {
    if (_counted) return;
    _counted = true;
    if (++SecureScreen._active == 1) _protector?.enable().ignore();
  }

  void _release() {
    if (!_counted) return;
    _counted = false;
    if (--SecureScreen._active <= 0) {
      SecureScreen._active = 0;
      _protector?.disable().ignore();
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
