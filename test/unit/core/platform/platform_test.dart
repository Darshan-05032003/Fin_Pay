import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/platform/biometric_authenticator.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/platform/flutter_haptic_service.dart';
import 'package:fin_pay/core/platform/motion_sensor.dart';
import 'package:fin_pay/core/platform/screen_protector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FlutterHapticService', () {
    late List<MethodCall> platformCalls;
    late List<List<int>> patterns;
    var enabled = true;
    var hasVibrator = true;

    setUp(() {
      platformCalls = [];
      patterns = [];
      enabled = true;
      hasVibrator = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            platformCalls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    FlutterHapticService build() => FlutterHapticService(
      isEnabled: () => enabled,
      hasVibrator: () async => hasVibrator,
      vibrate: (pattern) async => patterns.add(pattern),
    );

    test('impacts and selection go through HapticFeedback', () async {
      final haptics = build();
      await haptics.light();
      await haptics.medium();
      await haptics.heavy();
      await haptics.selection();
      expect(platformCalls.map((c) => c.arguments), [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
        'HapticFeedbackType.selectionClick',
      ]);
    });

    test('success and error use vibration patterns when available', () async {
      final haptics = build();
      await haptics.success();
      await haptics.error();
      expect(patterns, [
        FlutterHapticService.successPattern,
        FlutterHapticService.errorPattern,
      ]);
      expect(platformCalls, isEmpty);
    });

    test('success and error fall back to impacts without a vibrator', () async {
      hasVibrator = false;
      final haptics = build();
      await haptics.success();
      await haptics.error();
      expect(patterns, isEmpty);
      expect(platformCalls.map((c) => c.arguments), [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test(
      'everything is a no-op when haptics are disabled in settings',
      () async {
        enabled = false;
        final haptics = build();
        for (final type in HapticType.values) {
          await haptics.play(type);
        }
        expect(platformCalls, isEmpty);
        expect(patterns, isEmpty);
      },
    );

    test('play dispatches every type', () async {
      final haptics = build();
      for (final type in HapticType.values) {
        await haptics.play(type);
      }
      expect(platformCalls, hasLength(4));
      expect(patterns, hasLength(2));
    });

    test('a platform error is swallowed', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            throw PlatformException(code: 'nope');
          });
      await expectLater(build().light(), completes);
    });
  });

  group('BiometricAuthenticator', () {
    test('maps local_auth error codes', () {
      expect(
        LocalAuthBiometricAuthenticator.mapErrorCode('NotAvailable'),
        BiometricResult.notAvailable,
      );
      expect(
        LocalAuthBiometricAuthenticator.mapErrorCode('PasscodeNotSet'),
        BiometricResult.notAvailable,
      );
      expect(
        LocalAuthBiometricAuthenticator.mapErrorCode('NotEnrolled'),
        BiometricResult.notEnrolled,
      );
      expect(
        LocalAuthBiometricAuthenticator.mapErrorCode('LockedOut'),
        BiometricResult.lockedOut,
      );
      expect(
        LocalAuthBiometricAuthenticator.mapErrorCode('PermanentlyLockedOut'),
        BiometricResult.lockedOut,
      );
      expect(
        LocalAuthBiometricAuthenticator.mapErrorCode('whatever'),
        BiometricResult.error,
      );
    });

    test(
      'the real authenticator reports not available without a plugin',
      () async {
        final auth = LocalAuthBiometricAuthenticator();
        expect(await auth.isAvailable(), isFalse);
        expect(
          await auth.authenticate(reason: 'test'),
          BiometricResult.notAvailable,
        );
      },
    );

    test('the fake is scriptable and records prompts', () async {
      final fake = FakeBiometricAuthenticator();
      expect(await fake.authenticate(reason: 'pay'), BiometricResult.success);
      fake.result = BiometricResult.failed;
      expect(await fake.authenticate(reason: 'again'), BiometricResult.failed);
      fake.available = false;
      expect(await fake.isAvailable(), isFalse);
      expect(
        await fake.authenticate(reason: 'x'),
        BiometricResult.notAvailable,
      );
      expect(fake.prompts, ['pay', 'again', 'x']);
    });
  });

  group('MotionSensor', () {
    test('normalises accelerometer events to -1…1 tilt', () async {
      final now = DateTime(2026);
      final events = Stream.fromIterable([
        AccelerometerEvent(0, 0, 9.8, now),
        AccelerometerEvent(-9.80665, 4.9, 0, now),
        AccelerometerEvent(50, -50, 0, now),
      ]);
      final sensor = SensorsPlusMotionSensor(events: events);
      final tilts = await sensor.tilt.toList();
      expect(tilts[0], Tilt.flat);
      expect(tilts[1].x, closeTo(1, 1e-9));
      expect(tilts[1].y, closeTo(0.4996, 1e-3));
      expect(tilts[2], const Tilt(-1, -1));
    });

    test(
      'isAvailable is true when a sample arrives and false otherwise',
      () async {
        final now = DateTime(2026);
        final live = SensorsPlusMotionSensor(
          events: Stream.value(AccelerometerEvent(0, 0, 0, now)),
        );
        expect(await live.isAvailable, isTrue);
        final dead = SensorsPlusMotionSensor(
          events: const Stream.empty(),
          probeTimeout: const Duration(milliseconds: 10),
        );
        expect(await dead.isAvailable, isFalse);
        final silent = SensorsPlusMotionSensor(
          events: Stream.fromFuture(
            Future.delayed(
              const Duration(seconds: 5),
              () => AccelerometerEvent(0, 0, 0, now),
            ),
          ),
          probeTimeout: const Duration(milliseconds: 10),
        );
        expect(await silent.isAvailable, isFalse);
      },
    );

    test('the fake tracks listeners and forwards emitted tilts', () async {
      final fake = FakeMotionSensor();
      final received = <Tilt>[];
      final sub = fake.tilt.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      expect(fake.listeners, 1);
      fake.emit(const Tilt(0.5, -0.5));
      await Future<void>.delayed(Duration.zero);
      expect(received, [const Tilt(0.5, -0.5)]);
      await sub.cancel();
      expect(fake.listeners, 0);
      fake.available = false;
      expect(await fake.isAvailable, isFalse);
      await fake.dispose();
    });
  });

  group('ScreenProtector', () {
    const channel = MethodChannel(MethodChannelScreenProtector.channelName);
    late List<String> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('invokes enable/disable on Android', () async {
      final protector = MethodChannelScreenProtector(
        platform: TargetPlatform.android,
      );
      await protector.enable();
      await protector.disable();
      expect(calls, ['enable', 'disable']);
    });

    test('is a no-op on other platforms', () async {
      final protector = MethodChannelScreenProtector(
        platform: TargetPlatform.iOS,
      );
      await protector.enable();
      expect(calls, isEmpty);
    });

    test('tolerates a missing native side and platform errors', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      final protector = MethodChannelScreenProtector(
        platform: TargetPlatform.android,
      );
      await expectLater(protector.enable(), completes);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'x');
          });
      await expectLater(protector.disable(), completes);
    });

    test('the fake records state', () async {
      final fake = FakeScreenProtector();
      await fake.enable();
      await fake.enable();
      await fake.disable();
      expect(fake.enabled, isFalse);
      expect(fake.enableCalls, 2);
      expect(fake.disableCalls, 1);
    });
  });

  group('FakeSecureStorage', () {
    test('supports every operation and a failing mode', () async {
      final storage = FakeSecureStorage({'a': '1'});
      expect(await storage.read('a'), '1');
      expect(await storage.containsKey('a'), isTrue);
      await storage.write('b', '2');
      await storage.delete('a');
      expect(await storage.read('a'), isNull);
      await storage.deleteAll();
      expect(storage.values, isEmpty);
      storage.failing = true;
      await expectLater(storage.read('a'), throwsA(isA<Exception>()));
    });
  });
}
