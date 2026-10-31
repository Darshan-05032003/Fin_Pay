import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/widgets/contact_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'screen_harness.dart';
import 'transfer_fixtures.dart';

const ValueKey<String> _search = ValueKey('transfer-search');
const ValueKey<String> _note = ValueKey('transfer-note');
const ValueKey<String> _amount = ValueKey('transfer-amount');
const ValueKey<String> _continue = ValueKey('transfer-continue');

Finder _key(String name) => find.byKey(ValueKey('key-$name'));
Finder _contact(String id) => find.byKey(ValueKey('contact-$id'));
Finder _amountLabel(String formatted) =>
    find.bySemanticsLabel(RegExp('Amount ${RegExp.escape(formatted)},'));

void main() {
  late ScreenHarness h;
  late TransferRepos repos;

  setUp(() {
    h = ScreenHarness();
    repos = TransferRepos();
  });

  Future<void> open(
    WidgetTester tester, {
    double scale = 1,
    bool rm = false,
  }) async {
    await repos.init(h, tester: tester);
    await h.pump(
      tester,
      AppRoutes.transfer,
      textScale: scale,
      reduceMotion: rm,
    );
    await h.settle(tester);
  }

  Future<void> type(WidgetTester tester, String keys) async {
    for (final k in keys.split('')) {
      await tester.tap(_key(k == '.' ? 'dot' : k));
      await tester.pump();
    }
    await h.settle(tester);
  }

  group('states', () {
    testWidgets('loading shows a skeleton until contacts arrive', (
      tester,
    ) async {
      final gate = Completer<Result<List<Contact>>>();
      when(repos.contacts.getContacts).thenAnswer((_) => gate.future);
      await repos.init(h, tester: tester);
      await h.pump(tester, AppRoutes.transfer);
      await tester.pump();
      expect(find.byType(FpSkeletonGroup), findsOneWidget);
      expect(find.byKey(_search), findsNothing);
      expect(tester.widget<FpButton>(find.byKey(_continue)).enabled, isFalse);
      gate.complete(const Success([]));
      await h.settle(tester);
      expect(find.byType(FpSkeletonGroup), findsNothing);
      expect(find.byKey(_search), findsOneWidget);
      expect(
        find.byKey(const ValueKey('transfer-no-contacts')),
        findsOneWidget,
      );
    });

    testWidgets('error shows a retry that reloads', (tester) async {
      when(
        repos.contacts.getContacts,
      ).thenAnswer((_) async => const Failure('No address book'));
      await open(tester);
      expect(find.byType(FpErrorState), findsOneWidget);
      expect(find.text('No address book'), findsOneWidget);
      when(
        repos.contacts.getContacts,
      ).thenAnswer((_) async => const Success([]));
      await tapButton(tester, 'Retry');
      await h.settle(tester);
      expect(find.byType(FpErrorState), findsNothing);
      expect(find.byKey(_search), findsOneWidget);
    });

    testWidgets('content: search, recent-first contacts, amount, chips, '
        'note, keypad, disabled continue', (tester) async {
      await open(tester);
      expect(find.text('Send money'), findsOneWidget);
      expect(find.byKey(_search), findsOneWidget);
      expect(find.byType(ContactAvatar), findsWidgets);
      // Meera was paid most recently, so she comes first and is marked.
      final first = tester.widget<ContactAvatar>(
        find.byType(ContactAvatar).first,
      );
      expect(first.contact.name, 'Meera Kulkarni');
      expect(first.recent, isTrue);
      expect(
        find.bySemanticsLabel(
          RegExp('Meera Kulkarni, meera.k@oksbi, recently paid'),
        ),
        findsOneWidget,
      );
      expect(_amountLabel('₹0.00'), findsOneWidget);
      expect(find.text('Available ₹56,246.90'), findsOneWidget);
      for (final chip in ['₹500', '₹1,000', '₹2,000', '₹5,000']) {
        expect(find.text(chip.toUpperCase()), findsOneWidget);
      }
      expect(find.byKey(_note), findsOneWidget);
      for (var d = 0; d <= 9; d++) {
        expect(_key('$d'), findsOneWidget);
      }
      expect(_key('dot'), findsOneWidget);
      expect(_key('backspace'), findsOneWidget);
      expect(tester.widget<FpButton>(find.byKey(_continue)).enabled, isFalse);
      // The amount screen is not a payment screen: no FLAG_SECURE yet.
      expect(h.protector.enabled, isFalse);
    });
  });

  group('contacts', () {
    testWidgets('search filters by name or VPA and reports no matches', (
      tester,
    ) async {
      await open(tester);
      await typeInto(tester, _search, 'ok');
      await h.settle(tester);
      expect(find.byType(ContactAvatar), findsNWidgets(4));
      await typeInto(tester, _search, 'ZZZ');
      await h.settle(tester);
      expect(find.byType(ContactAvatar), findsNothing);
      expect(find.text('No contacts match "ZZZ"'), findsOneWidget);
      await typeInto(tester, _search, '');
      await h.settle(tester);
      expect(find.byType(ContactAvatar).evaluate().length, greaterThan(4));
    });

    testWidgets('tapping selects with a selection haptic', (tester) async {
      await open(tester);
      h.haptics.reset();
      await tester.tap(_contact('c-priya'));
      await h.settle(tester);
      expect(
        tester.widget<ContactAvatar>(_contact('c-priya')).selected,
        isTrue,
      );
      expect(
        tester.widget<ContactAvatar>(_contact('c-meera')).selected,
        isFalse,
      );
      expect(h.haptics.calls, contains(HapticType.selection));
    });
  });

  group('amount', () {
    testWidgets('keypad digits roll the amount; backspace rolls back; long '
        'press clears', (tester) async {
      await open(tester);
      await type(tester, '12.5');
      expect(_amountLabel('₹12.50'), findsOneWidget);
      // Every key press is a selection haptic.
      expect(
        h.haptics.calls.where((c) => c == HapticType.selection).length,
        greaterThanOrEqualTo(4),
      );
      await tester.tap(_key('backspace'));
      await h.settle(tester);
      expect(_amountLabel('₹12.00'), findsOneWidget);
      await tester.longPress(_key('backspace'));
      await h.settle(tester);
      expect(_amountLabel('₹0.00'), findsOneWidget);
    });

    testWidgets('quick chips set the amount and show as selected', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('chip-100000')));
      await h.settle(tester);
      expect(_amountLabel('₹1,000.00'), findsOneWidget);
      expect(
        tester
            .widget<FpChip>(find.byKey(const ValueKey('chip-100000')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('chip-500000')));
      await h.settle(tester);
      expect(_amountLabel('₹5,000.00'), findsOneWidget);
    });

    testWidgets('over the balance: inline error, shake, error haptic, '
        'continue disabled', (tester) async {
      await open(tester);
      await tester.tap(_contact('c-priya'));
      await tester.pump();
      h.haptics.reset();
      await type(tester, '99999');
      expect(
        find.text("That's more than your balance (₹56,246.90)"),
        findsOneWidget,
      );
      expect(h.haptics.calls.where((c) => c == HapticType.error).length, 1);
      expect(tester.widget<FpButton>(find.byKey(_continue)).enabled, isFalse);
      await type(tester, '9');
      expect(find.text('Maximum ₹1,00,000 per transfer'), findsOneWidget);
      // Still one shake: the amount never left the error state.
      expect(h.haptics.calls.where((c) => c == HapticType.error).length, 1);
      await tester.longPress(_key('backspace'));
      await h.settle(tester);
      expect(find.text('Available ₹56,246.90'), findsOneWidget);
    });

    testWidgets('a long press on the amount pastes a normalised amount', (
      tester,
    ) async {
      final clipboard = FakeClipboard(tester, text: '１,２３４.５');
      await open(tester);
      await tester.longPress(find.byKey(_amount));
      await h.settle(tester);
      expect(_amountLabel('₹1,234.50'), findsOneWidget);
      clipboard.text = 'abc';
      h.haptics.reset();
      await tester.longPress(find.byKey(_amount));
      await h.settle(tester);
      expect(_amountLabel('₹1,234.50'), findsOneWidget);
      expect(h.haptics.calls, contains(HapticType.error));
      clipboard.text = '9' * 100000;
      await tester.longPress(find.byKey(_amount));
      await h.settle(tester);
      expect(_amountLabel('₹1,234.50'), findsOneWidget);
      clipboard.text = '-50';
      await tester.longPress(find.byKey(_amount));
      await h.settle(tester);
      expect(_amountLabel('₹1,234.50'), findsOneWidget);
    });
  });

  group('continue', () {
    testWidgets('needs a contact and a valid amount, then pushes a draft '
        'with a fresh key and the sanitised note', (tester) async {
      await open(tester);
      await type(tester, '1250');
      expect(tester.widget<FpButton>(find.byKey(_continue)).enabled, isFalse);
      await tester.tap(_contact('c-priya'));
      await tester.pump();
      await typeInto(tester, _note, '  chai \u202E for\u0000 two  ');
      expect(tester.widget<FpButton>(find.byKey(_continue)).enabled, isTrue);
      await tapButton(tester, 'Continue');
      await h.settle(tester);
      expect(h.location, AppRoutes.transferReview);
      final draft = h.extra! as TransferDraft;
      expect(draft.recipientName, 'Priya Raghavan');
      expect(draft.recipientAccount, 'priya.r@okaxis');
      expect(draft.amount, const Money.paise(125000));
      expect(draft.note, 'chai for two');
      expect(
        draft.idempotencyKey,
        matches(RegExp(r'^transfer-\d+-[0-9a-f]{8}$')),
      );
      // Review shows what was typed.
      expect(find.text('Priya Raghavan'), findsOneWidget);
      // Back returns to the form with everything kept; continuing again
      // mints a new key (a new confirmation is a new payment).
      await tester.tap(find.bySemanticsLabel('Back'));
      await h.settle(tester);
      expect(h.location, AppRoutes.transfer);
      expect(_amountLabel('₹1,250.00'), findsOneWidget);
      await tapButton(tester, 'Continue');
      await h.settle(tester);
      final again = h.extra! as TransferDraft;
      expect(again.idempotencyKey, isNot(draft.idempotencyKey));
      expect(again.copyWith(idempotencyKey: draft.idempotencyKey), draft);
    });

    testWidgets('the note is capped at 40 characters', (tester) async {
      await open(tester);
      await typeInto(tester, _note, 'x' * 100);
      final field = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(_note),
          matching: find.byType(EditableText),
        ),
      );
      expect(field.controller.text.length, lessThanOrEqualTo(40));
    });

    testWidgets('back leaves to home when nothing can be popped', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('Back'));
      await h.settle(tester);
      expect(h.location, AppRoutes.home);
      await h.flush(tester);
    });
  });

  group('accessibility', () {
    testWidgets('meets the guidelines at 1.3x with an error shown', (
      tester,
    ) async {
      await open(tester, scale: 1.3);
      await tester.tap(_contact('c-priya'));
      await tester.pump();
      await type(tester, '99999');
      expect(tester.takeException(), isNull);
      await expectGuidelines(tester);
    });

    testWidgets('reduce motion renders the form without entrances', (
      tester,
    ) async {
      await open(tester, rm: true);
      expect(find.byType(ContactAvatar), findsWidgets);
      await type(tester, '42');
      expect(_amountLabel('₹42.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a hostile search query is only ever text', (tester) async {
      await open(tester);
      await typeInto(tester, _search, "' OR 1=1 --\u202E😀");
      await h.settle(tester);
      expect(find.byType(ContactAvatar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
