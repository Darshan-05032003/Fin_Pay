import 'dart:async';

import 'package:fin_pay/core/platform/motion_sensor.dart';

/// [MotionSensor] driven by tests through [emit].
class FakeMotionSensor implements MotionSensor {
  FakeMotionSensor({this.available = true});

  bool available;
  final StreamController<Tilt> _controller = StreamController.broadcast();

  /// Number of active subscribers, to assert streams are cancelled.
  int get listeners => _listeners;
  int _listeners = 0;

  /// Pushes a tilt sample to every listener.
  void emit(Tilt tilt) => _controller.add(tilt);

  @override
  Future<bool> get isAvailable async => available;

  @override
  Stream<Tilt> get tilt {
    late StreamController<Tilt> proxy;
    StreamSubscription<Tilt>? sub;
    proxy = StreamController<Tilt>(
      onListen: () {
        _listeners++;
        sub = _controller.stream.listen(proxy.add);
      },
      onCancel: () async {
        _listeners--;
        await sub?.cancel();
      },
    );
    return proxy.stream;
  }

  Future<void> dispose() => _controller.close();
}
