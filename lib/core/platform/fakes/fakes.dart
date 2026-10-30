/// Every platform fake in one import for tests and the DI overrides hook.
library;

export 'package:fin_pay/core/haptics/haptic_service.dart'
    show FakeHapticService;
export 'package:fin_pay/core/platform/fakes/fake_biometric_authenticator.dart';
export 'package:fin_pay/core/platform/fakes/fake_motion_sensor.dart';
export 'package:fin_pay/core/platform/fakes/fake_screen_protector.dart';
export 'package:fin_pay/core/platform/fakes/fake_secure_storage.dart';
export 'package:fin_pay/core/settings/settings_repository.dart'
    show InMemorySettingsRepository;
