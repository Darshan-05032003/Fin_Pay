import 'package:equatable/equatable.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/screens/onboarding/onboarding_illustrations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingState extends Equatable {
  const OnboardingState({this.page = 0, this.completed = false});

  final int page;

  /// True once "onboarding seen" has been recorded; the screen navigates on.
  final bool completed;

  bool isLast(int pageCount) => page >= pageCount - 1;

  OnboardingState copyWith({int? page, bool? completed}) => OnboardingState(
    page: page ?? this.page,
    completed: completed ?? this.completed,
  );

  @override
  List<Object?> get props => [page, completed];
}

/// Onboarding progress and the "seen" flag.
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required SettingsCubit settings})
    : _settings = settings,
      super(const OnboardingState());

  /// The page specs (titles, copy, illustration layers).
  static List<OnboardingPageSpec> get pages => OnboardingPageSpec.all;

  final SettingsCubit _settings;

  int get pageCount => pages.length;

  /// Reports a swipe. Out-of-range indexes are ignored.
  void pageChanged(int index) {
    if (index < 0 || index >= pageCount || index == state.page) return;
    emit(state.copyWith(page: index));
  }

  /// Advances one page, or finishes on the last one.
  Future<void> next() async {
    if (state.completed) return;
    if (state.isLast(pageCount)) return await finish();
    emit(state.copyWith(page: state.page + 1));
  }

  Future<void> skip() => finish();

  /// Persists "seen" (a failed save never traps the user here) and marks
  /// the flow complete exactly once.
  Future<void> finish() async {
    if (state.completed) return;
    await _settings.setOnboardingSeen(seen: true);
    if (isClosed) return;
    emit(state.copyWith(completed: true));
  }
}
