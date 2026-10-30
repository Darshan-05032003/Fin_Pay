import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/screens/cards/stack/cvv_reveal_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements ICardRepository {}

void main() {
  late MockCardRepository repo;

  setUp(() {
    Logger.sink = (_) {};
    repo = MockCardRepository();
    when(
      () => repo.readCvv('c1'),
    ).thenAnswer((_) async => const Success('987'));
    when(
      () => repo.readCvv('c2'),
    ).thenAnswer((_) async => const Success('111'));
    when(
      () => repo.readCvv('none'),
    ).thenAnswer((_) async => const Success(null));
    when(
      () => repo.readCvv('broken'),
    ).thenAnswer((_) async => const Failure('keystore'));
  });

  test('reveal shows the CVV for 5 s, counts down, then masks and forgets', () {
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2026));
      final cubit = CvvRevealCubit(repository: repo, clock: clock);
      final states = <CvvRevealState>[];
      cubit.stream.listen(states.add);
      expect(cubit.cvv, isNull);
      unawaited(cubit.reveal('c1'));
      async.flushMicrotasks();
      expect(cubit.state.status, CvvRevealStatus.revealed);
      expect(cubit.state.remaining, const Duration(seconds: 5));
      expect(cubit.cvv, '987');
      async.elapse(const Duration(seconds: 2));
      expect(cubit.state.remaining, const Duration(seconds: 3));
      expect(cubit.cvv, '987');
      async.elapse(const Duration(seconds: 3));
      expect(cubit.state, const CvvRevealState());
      expect(cubit.cvv, isNull);
      expect(states.first.status, CvvRevealStatus.loading);
      // The digits never travel through the state stream.
      for (final s in states) {
        expect(s.toString(), isNot(contains('987')));
        expect(s.props.join(), isNot(contains('987')));
      }
      unawaited(cubit.close());
      async.flushTimers();
    });
  });

  test('hide masks at once (backgrounding); close wipes', () {
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2026));
      final cubit = CvvRevealCubit(repository: repo, clock: clock);
      unawaited(cubit.reveal('c1'));
      async.flushMicrotasks();
      expect(cubit.cvv, '987');
      cubit.hide();
      expect(cubit.state, const CvvRevealState());
      expect(cubit.cvv, isNull);
      cubit.hide();
      unawaited(cubit.reveal('c1'));
      async.flushMicrotasks();
      expect(cubit.cvv, '987');
      unawaited(cubit.close());
      expect(cubit.cvv, isNull);
      async.flushTimers();
    });
  });

  test('revealing again restarts the window; another card swaps', () {
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2026));
      final cubit = CvvRevealCubit(repository: repo, clock: clock);
      unawaited(cubit.reveal('c1'));
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 4));
      expect(cubit.state.remaining, const Duration(seconds: 1));
      unawaited(cubit.reveal('c1'));
      async.flushMicrotasks();
      expect(cubit.state.remaining, const Duration(seconds: 5));
      verify(() => repo.readCvv('c1')).called(1);
      unawaited(cubit.reveal('c2'));
      async.flushMicrotasks();
      expect(cubit.state.cardId, 'c2');
      expect(cubit.cvv, '111');
      async.elapse(const Duration(seconds: 5));
      expect(cubit.state.status, CvvRevealStatus.hidden);
      unawaited(cubit.close());
      async.flushTimers();
    });
  });

  test('a clock jump backwards cannot extend the window', () {
    fakeAsync((async) {
      var offset = Duration.zero;
      final base = async.getClock(DateTime.utc(2026));
      final clock = Clock(() => base.now().add(offset));
      final cubit = CvvRevealCubit(repository: repo, clock: clock);
      unawaited(cubit.reveal('c1'));
      async.flushMicrotasks();
      offset = const Duration(hours: -1);
      async.elapse(const Duration(seconds: 1));
      expect(
        cubit.state.remaining,
        lessThanOrEqualTo(const Duration(seconds: 5)),
      );
      // A jump forward ends it.
      offset = const Duration(hours: 1);
      async.elapse(const Duration(seconds: 1));
      expect(cubit.state.status, CvvRevealStatus.hidden);
      unawaited(cubit.close());
      async.flushTimers();
    });
  });

  test('missing vault entry and storage failure are reported', () async {
    final cubit = CvvRevealCubit(repository: repo);
    await cubit.reveal('none');
    expect(cubit.state.status, CvvRevealStatus.failed);
    expect(cubit.state.message, 'No CVV stored for this card');
    await cubit.reveal('broken');
    expect(cubit.state.status, CvvRevealStatus.failed);
    expect(cubit.state.message, 'keystore');
    expect(cubit.cvv, isNull);
    await cubit.close();
  });

  test('a reveal that completes after hide() is discarded', () async {
    final gate = Completer<Result<String?>>();
    when(() => repo.readCvv('slow')).thenAnswer((_) => gate.future);
    final cubit = CvvRevealCubit(repository: repo);
    final pending = cubit.reveal('slow');
    expect(cubit.state.isLoading('slow'), isTrue);
    cubit.hide();
    gate.complete(const Success('555'));
    await pending;
    expect(cubit.state, const CvvRevealState());
    expect(cubit.cvv, isNull);
    await cubit.close();
  });

  test('concurrent reveals of one card read storage once', () async {
    final cubit = CvvRevealCubit(repository: repo);
    await Future.wait([for (var i = 0; i < 100; i++) cubit.reveal('c1')]);
    verify(() => repo.readCvv('c1')).called(1);
    expect(cubit.cvv, '987');
    await cubit.close();
  });

  test('Logger redacts a CVV should anyone log one', () {
    expect(Logger.redact('cvv: 987'), 'cvv: ***');
    expect(Logger.redact('{"cvv":"987"}'), '{"cvv":"***"}');
  });
}
