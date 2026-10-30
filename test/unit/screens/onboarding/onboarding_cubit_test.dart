import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/core/settings/settings_repository.dart';
import 'package:fin_pay/screens/onboarding/onboarding_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySettingsRepository repo;
  late SettingsCubit settings;

  setUp(() {
    repo = InMemorySettingsRepository();
    settings = SettingsCubit(repo);
  });

  tearDown(() => settings.close());

  OnboardingCubit build() => OnboardingCubit(settings: settings);

  test('three pages, starts on the first', () {
    final cubit = build();
    expect(cubit.state, const OnboardingState());
    expect(cubit.pageCount, OnboardingCubit.pages.length);
    expect(cubit.pageCount, 3);
    expect(cubit.state.isLast(cubit.pageCount), isFalse);
    unawaited(cubit.close());
  });

  blocTest<OnboardingCubit, OnboardingState>(
    'next advances and finishes on the last page',
    build: build,
    act: (c) async {
      await c.next();
      await c.next();
      await c.next();
    },
    expect: () => const [
      OnboardingState(page: 1),
      OnboardingState(page: 2),
      OnboardingState(page: 2, completed: true),
    ],
    verify: (_) => expect(repo.settings.onboardingSeen, isTrue),
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'swiping reports the page; out-of-range and repeats are ignored',
    build: build,
    act: (c) {
      c
        ..pageChanged(2)
        ..pageChanged(2)
        ..pageChanged(7)
        ..pageChanged(-1)
        ..pageChanged(0);
    },
    expect: () => const [OnboardingState(page: 2), OnboardingState()],
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'skip finishes from any page and persists once',
    build: build,
    act: (c) async {
      await c.skip();
      await c.skip();
    },
    expect: () => const [OnboardingState(completed: true)],
    verify: (_) {
      expect(repo.settings.onboardingSeen, isTrue);
      expect(repo.saves, 1);
    },
  );

  blocTest<OnboardingCubit, OnboardingState>(
    'a failed save still completes the flow (never traps the user)',
    build: () {
      repo.failing = true;
      return build();
    },
    act: (c) => c.skip(),
    expect: () => const [OnboardingState(completed: true)],
  );
}
