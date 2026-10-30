import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and hides the app in the recents switcher on screens
/// that show balances, card details or payments (Android `FLAG_SECURE`).
///
/// No-op on platforms without the native side.
abstract interface class ScreenProtector {
  /// Turns protection on; safe to call repeatedly.
  Future<void> enable();

  /// Turns protection off.
  Future<void> disable();
}

/// [ScreenProtector] over the `fin_pay/screen_protector` method channel
/// implemented in `MainActivity.kt`.
class MethodChannelScreenProtector implements ScreenProtector {
  MethodChannelScreenProtector({
    MethodChannel? channel,
    TargetPlatform? platform,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _platform = platform;

  /// Name of the platform channel.
  static const String channelName = 'fin_pay/screen_protector';

  final MethodChannel _channel;
  final TargetPlatform? _platform;

  bool get _supported =>
      (_platform ?? defaultTargetPlatform) == TargetPlatform.android;

  Future<void> _invoke(String method) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Native side not registered (tests, other embeddings).
    } on PlatformException {
      // Best effort: never block the UI on this.
    }
  }

  @override
  Future<void> enable() => _invoke('enable');

  @override
  Future<void> disable() => _invoke('disable');
}
