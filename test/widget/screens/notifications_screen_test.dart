import 'dart:async';

import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'insights_activity_fixtures.dart';
import 'screen_harness.dart';

void main() {
  late ScreenHarness h;
  late InsightsRepos repos;

  setUp(() => h = ScreenHarness());

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    bool rm = false,
    bool settle = true,
  }) async {
    repos = InsightsRepos();
    await repos.init(h, tester: tester);
    await h.pump(
      tester,
      AppRoutes.notifications,
      textScale: scale,
      reduceMotion: rm,
    );
    if (settle) await h.settle(tester);
  }

  Finder row(String id) => find.byKey(ValueKey('notification-$id'));

  Finder openAction(String label) => find
      .byWidgetPredicate(
        (w) => w.key == ValueKey('fp-swipe-action-$label'),
        skipOffstage: false,
      )
      .hitTestable();

  Future<void> swipe(WidgetTester tester, String id, double dx) async {
    await tester.dragFrom(tester.getCenter(row(id)), Offset(dx, 0));
    await tester.pump();
    await h.settle(tester);
  }

  NotificationContent content(WidgetTester tester) =>
      BlocProvider.of<NotificationBloc>(
            tester.element(find.byKey(const ValueKey('notifications-scroll'))),
          ).state
          as NotificationContent;

  group('states', () {
    testWidgets('loading: skeleton rows', (tester) async {
      repos = InsightsRepos();
      final gate = Completer<Result<List<NotificationItem>>>();
      when(
        () => repos.notes.getNotifications(limit: any(named: 'limit')),
      ).thenAnswer((_) => gate.future);
      when(repos.notes.getNotifications).thenAnswer((_) => gate.future);
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.notifications);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('notifications-skeleton')),
        findsOneWidget,
      );
      gate.complete(Success(repos.notifications));
      await tester.pump();
      await h.settle(tester);
      expect(
        find.byKey(const ValueKey('notifications-skeleton')),
        findsNothing,
      );
      expect(row('n0'), findsOneWidget);
    });

    testWidgets('empty: "All caught up"', (tester) async {
      repos = InsightsRepos();
      when(
        () => repos.notes.getNotifications(limit: any(named: 'limit')),
      ).thenAnswer((_) async => const Success([]));
      when(
        repos.notes.getNotifications,
      ).thenAnswer((_) async => const Success([]));
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.notifications);
      await h.settle(tester);
      expect(find.text('All caught up'), findsOneWidget);
      expect(find.byKey(const ValueKey('notifications-empty')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notifications-mark-all')),
        findsNothing,
      );
    });

    testWidgets('error: message and retry', (tester) async {
      repos = InsightsRepos();
      var calls = 0;
      Future<Result<List<NotificationItem>>> answer(Invocation _) async {
        calls++;
        return calls == 1
            ? const Failure('Storage unavailable')
            : Success(repos.notifications);
      }

      when(
        () => repos.notes.getNotifications(limit: any(named: 'limit')),
      ).thenAnswer(answer);
      when(repos.notes.getNotifications).thenAnswer(answer);
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.notifications);
      await h.settle(tester);
      expect(find.text('Could not load notifications'), findsOneWidget);
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(row('n0'), findsOneWidget);
    });

    testWidgets('content: staggered rows, unread dots pulse finitely, mark '
        'all offered', (tester) async {
      await open(tester, settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      // Early in the entrance the first row is further along than the last.
      double opacityOf(String id) => tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: find.byKey(ValueKey('notification-entrance-$id')),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      expect(opacityOf('n0'), greaterThanOrEqualTo(opacityOf('n5')));
      await h.settle(tester);
      expect(find.text('Cashback credited'), findsWidgets);
      expect(find.byKey(const ValueKey('unread-dot-n0')), findsOneWidget);
      expect(find.byKey(const ValueKey('unread-dot-n3')), findsNothing);
      final pulse = tester.widget<FpPulse>(
        find.byKey(const ValueKey('unread-dot-n0')),
      );
      expect(pulse.pulses, 3, reason: 'finite');
      expect(
        find.byKey(const ValueKey('notifications-mark-all')),
        findsOneWidget,
      );
      expect(find.text('1 h ago'), findsOneWidget);
      expect(find.text('22 h ago'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('tap marks one read; the dot and the bold title go', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(row('n1'));
      await tester.pump();
      await h.settle(tester);
      verify(() => repos.notes.markRead(['n1'])).called(1);
      expect(find.byKey(const ValueKey('unread-dot-n1')), findsNothing);
      expect(content(tester).unreadCount, 2);
      expect(h.haptics.calls, contains(HapticType.selection));
      h.haptics.reset();
      await tester.tap(row('n1'));
      await tester.pump();
      expect(h.haptics.calls, isEmpty, reason: 'already read: no-op');
    });

    testWidgets('mark all read clears every dot and hides the button', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('notifications-mark-all')));
      await tester.pump();
      await h.settle(tester);
      verify(() => repos.notes.markRead(['n0', 'n1', 'n2'])).called(1);
      expect(
        find.byKey(const ValueKey('notifications-mark-all')),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('unread-dot-'),
        ),
        findsNothing,
      );
      expect(h.haptics.calls, contains(HapticType.success));
    });

    testWidgets('swipe to dismiss removes the row; Undo brings it back in '
        'place and twice is harmless', (tester) async {
      await open(tester);
      final before = tester.getTopLeft(row('n2')).dy;
      await tester.dragFrom(tester.getCenter(row('n2')), const Offset(-320, 0));
      await tester.pump();
      await h.settle(tester);
      expect(row('n2'), findsNothing);
      verify(() => repos.notes.deleteNotification('n2')).called(1);
      expect(find.text('Notification dismissed'), findsOneWidget);
      expect(h.haptics.calls, contains(HapticType.medium));
      // The toast slides in after the row has collapsed; let it land.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('fp-toast-action')));
      await tester.pump();
      await h.settle(tester);
      expect(row('n2'), findsOneWidget);
      expect(tester.getTopLeft(row('n2')).dy, before);
      expect(content(tester).notifications.length, 8);
      expect(content(tester).notifications.map((n) => n.id).toSet().length, 8);
      verify(() => repos.notes.addNotification(any())).called(1);
    });

    testWidgets('the Dismiss swipe action and the Read action work from the '
        'tray', (tester) async {
      await open(tester);
      await swipe(tester, 'n0', -120);
      expect(openAction('Read'), findsOneWidget);
      await tester.tap(openAction('Read'));
      await tester.pump();
      await h.settle(tester);
      verify(() => repos.notes.markRead(['n0'])).called(1);
      await swipe(tester, 'n4', -100);
      expect(openAction('Read'), findsNothing, reason: 'already read');
      await tester.tap(openAction('Dismiss'));
      await tester.pump();
      await h.settle(tester);
      expect(row('n4'), findsNothing);
      verify(() => repos.notes.deleteNotification('n4')).called(1);
    });

    testWidgets('letting the undo toast expire keeps the row gone', (
      tester,
    ) async {
      await open(tester);
      await tester.dragFrom(tester.getCenter(row('n7')), const Offset(-320, 0));
      await tester.pump();
      await h.settle(tester);
      expect(find.text('Notification dismissed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await h.settle(tester);
      expect(find.text('Notification dismissed'), findsNothing);
      expect(row('n7'), findsNothing);
      verifyNever(() => repos.notes.addNotification(any()));
    });

    testWidgets('dismissing everything shows the empty state', (tester) async {
      repos = InsightsRepos();
      final one = [repos.notifications.first];
      when(
        () => repos.notes.getNotifications(limit: any(named: 'limit')),
      ).thenAnswer((_) async => Success(one));
      when(repos.notes.getNotifications).thenAnswer((_) async => Success(one));
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.notifications);
      await h.settle(tester);
      await tester.dragFrom(tester.getCenter(row('n0')), const Offset(-320, 0));
      await tester.pump();
      await h.settle(tester);
      expect(find.text('All caught up'), findsOneWidget);
    });

    testWidgets('a failed delete reports an error toast', (tester) async {
      await open(tester);
      when(
        () => repos.notes.deleteNotification(any()),
      ).thenAnswer((_) async => const Failure('Storage is locked'));
      await tester.dragFrom(tester.getCenter(row('n0')), const Offset(-320, 0));
      await tester.pump();
      await h.settle(tester);
      expect(find.text('Storage is locked'), findsOneWidget);
      expect(h.haptics.calls, contains(HapticType.error));
    });

    testWidgets('pull to refresh reloads', (tester) async {
      await open(tester);
      await tester.drag(
        find.byKey(const ValueKey('notifications-scroll')),
        const Offset(0, 300),
      );
      await tester.pump();
      await h.settle(tester);
      verify(repos.notes.getNotifications).called(2);
    });
  });

  group('motion, navigation and accessibility', () {
    testWidgets('reduce motion: rows appear at once and the dot never '
        'pulses', (tester) async {
      await open(tester, rm: true, settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Cashback credited'), findsWidgets);
      final dot = find.descendant(
        of: find.byKey(const ValueKey('unread-dot-n0')),
        matching: find.byType(ScaleTransition),
      );
      await tester.pump(const Duration(milliseconds: 350));
      if (dot.evaluate().isNotEmpty) {
        expect(tester.widget<ScaleTransition>(dot.first).scale.value, 1);
      }
    });

    testWidgets('back leaves to home when nothing can pop', (tester) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pump();
      await h.settle(tester);
      expect(h.location, AppRoutes.home);
    });

    testWidgets('1.3×: no overflow and guidelines met', (tester) async {
      await open(tester, scale: 1.3);
      expect(tester.takeException(), isNull);
      await expectGuidelines(tester);
    });

    testWidgets('rows describe title, message, time and unread state', (
      tester,
    ) async {
      await open(tester);
      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(row('n0')).label,
        allOf(contains('Cashback credited'), contains('unread')),
      );
      expect(tester.getSemantics(row('n3')).label, isNot(contains('unread')));
      handle.dispose();
    });
  });
}
