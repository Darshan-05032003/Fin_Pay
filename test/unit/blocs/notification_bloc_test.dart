import 'package:bloc_test/bloc_test.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_event.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationRepository extends Mock
    implements INotificationRepository {}

void main() {
  late MockNotificationRepository repo;
  late List<NotificationEffect> effects;

  final n1 = NotificationItem(
    id: 'n1',
    title: 'A',
    message: 'a',
    time: DateTime.utc(2026),
    type: NotificationType.cashback,
  );
  final n2 = n1.copyWith(id: 'n2', isRead: true);

  setUpAll(() => registerFallbackValue(n1));

  setUp(() {
    Logger.sink = (_) {};
    repo = MockNotificationRepository();
    effects = [];
    when(
      () => repo.getNotifications(limit: any(named: 'limit')),
    ).thenAnswer((_) async => Success([n1, n2]));
  });

  NotificationBloc build() {
    final bloc = NotificationBloc(repository: repo);
    bloc.effects.listen(effects.add);
    return bloc;
  }

  test('initial state', () async {
    final bloc = build();
    expect(bloc.state, const NotificationInitial());
    await bloc.close();
  });

  blocTest<NotificationBloc, NotificationState>(
    'load content with unread count',
    build: build,
    act: (b) => b.add(const LoadNotificationsEvent()),
    expect: () => [
      const NotificationLoading(),
      NotificationContent([n1, n2]),
    ],
    verify: (b) => expect((b.state as NotificationContent).unreadCount, 1),
  );

  blocTest<NotificationBloc, NotificationState>(
    'load empty and error',
    build: () {
      var first = true;
      when(() => repo.getNotifications(limit: any(named: 'limit'))).thenAnswer((
        _,
      ) async {
        if (first) {
          first = false;
          return const Success([]);
        }
        return const Failure('db');
      });
      return build();
    },
    act: (b) => b
      ..add(const LoadNotificationsEvent())
      ..add(const LoadNotificationsEvent()),
    expect: () => [
      const NotificationLoading(),
      const NotificationEmpty(),
      const NotificationLoading(),
      const NotificationError('db'),
    ],
  );

  blocTest<NotificationBloc, NotificationState>(
    'add prepends to content, or starts content from any other state',
    build: () {
      when(
        () => repo.addNotification(any()),
      ).thenAnswer((_) async => const Success(null));
      return build();
    },
    act: (b) => b
      ..add(AddNotificationEvent(n2))
      ..add(AddNotificationEvent(n1)),
    expect: () => [
      NotificationContent([n2]),
      NotificationContent([n1, n2]),
    ],
    verify: (_) =>
        expect(effects, [NotificationAdded(n2), NotificationAdded(n1)]),
  );

  blocTest<NotificationBloc, NotificationState>(
    'add failure is an effect',
    build: () {
      when(
        () => repo.addNotification(any()),
      ).thenAnswer((_) async => const Failure('x'));
      return build();
    },
    act: (b) => b.add(AddNotificationEvent(n1)),
    expect: () => const <NotificationState>[],
    verify: (_) => expect(effects, [const NotificationFailed('x')]),
  );

  blocTest<NotificationBloc, NotificationState>(
    'delete emits the removed item for undo; last one yields empty',
    build: () {
      when(
        () => repo.deleteNotification(any()),
      ).thenAnswer((_) async => const Success(null));
      return build();
    },
    act: (b) => b
      ..add(const LoadNotificationsEvent())
      ..add(const DeleteNotificationEvent('n1'))
      ..add(const DeleteNotificationEvent('n2')),
    expect: () => [
      const NotificationLoading(),
      NotificationContent([n1, n2]),
      NotificationContent([n2]),
      const NotificationEmpty(),
    ],
    verify: (_) =>
        expect(effects, [NotificationDeleted(n1), NotificationDeleted(n2)]),
  );

  blocTest<NotificationBloc, NotificationState>(
    'delete failure is an effect',
    build: () {
      when(
        () => repo.deleteNotification('n1'),
      ).thenAnswer((_) async => const Failure('x'));
      return build();
    },
    act: (b) => b.add(const DeleteNotificationEvent('n1')),
    expect: () => const <NotificationState>[],
    verify: (_) => expect(effects, [const NotificationFailed('x')]),
  );
}
