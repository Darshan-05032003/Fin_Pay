import 'dart:async';

import 'package:flutter/foundation.dart';

/// Turns a stream (a bloc's state stream) into the [Listenable] that
/// `GoRouter.refreshListenable` expects, so redirects re-run on every change.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<Object?> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
