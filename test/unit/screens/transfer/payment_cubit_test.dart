import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/notification/notification_state.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_state.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/logger.dart';
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/platform/fakes/fakes.dart';
import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/payments/payment_gateway.dart';
import 'package:fin_pay/domain/repositories/notification_repository.dart';
import 'package:fin_pay/domain/repositories/transaction_repository.dart';
import 'package:fin_pay/domain/repositories/user_repository.dart';
import 'package:fin_pay/domain/usecases/add_transaction_usecase.dart';
import 'package:fin_pay/domain/usecases/get_transactions_usecase.dart';
import 'package:fin_pay/domain/usecases/get_user_usecase.dart';
import 'package:fin_pay/domain/usecases/update_user_usecase.dart';
import 'package:fin_pay/models/notification_item.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/models/user.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/transfer/payment/payment_cubit.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserRepository extends Mock implements IUserRepository {}

class MockNotificationRepository extends Mock
    implements INotificationRepository {}

/// An in-memory ledger with the real idempotency and balance rules.
class FakeLedger implements ITransactionRepository {
  FakeLedger({this.balance = const Money.paise(5624690)});

  Money balance;
  final List<Transaction> rows = [];
  final Set<String> keys = {};
  String? failWith;
  Completer<void>? gate;
  int addCalls = 0;

  @override
  Future<Result<TransactionOutcome>> addTransaction(Transaction t) async {
    addCalls++;
    if (gate != null) await gate!.future;
    if (failWith case final message?) return Failure(message);
    if (!keys.add(t.idempotencyKey)) {
      return const Success(TransactionOutcome.duplicate);
    }
    final next = balance + t.amount;
    if (next.isNegative) {
      keys.remove(t.idempotencyKey);
      return const Success(TransactionOutcome.insufficientBalance);
    }
    balance = next;
    rows.add(t);
    return const Success(TransactionOutcome.recorded);
  }

  @override
  Future<Result<void>> addTransactions(List<Transaction> transactions) async =>
      const Success(null);

  @override
  Future<Result<void>> deleteTransaction(String id) async =>
      const Success(null);

  @override
  Future<Result<List<Transaction>>> getRecentTransactions({int limit = 5}) =>
      getTransactions(limit: limit);

  @override
  Future<Result<List<Transaction>>> getTransactions({
    int? limit,
    int? offset,
    TransactionType? type,
  }) async => Success(rows.reversed.toList());

  @override
  Future<Result<List<Transaction>>> searchTransactions(
    String query, {
    TransactionType? type,
  }) async => Success(rows);

  @override
  Future<Result<List<Transaction>>> getTransactionsBetween(
    DateTime from,
    DateTime to,
  ) async => Success(rows.reversed.toList());
}

const TransferDraft draft = TransferDraft(
  recipientName: 'Priya Raghavan',
  recipientAccount: 'priya.r@okaxis',
  amount: Money.paise(125000),
  idempotencyKey: 'transfer-1-abcdef01',
  note: 'chai',
);

void main() {
  late FakeLedger ledger;
  late TransactionBloc transactions;
  late FakePaymentGateway gateway;
  late MockUserRepository userRepo;
  late MockNotificationRepository notificationRepo;
  late UserBloc user;
  late NotificationBloc notifications;
  final clock = Clock.fixed(DateTime.utc(2026, 10, 31, 6, 30));

  setUpAll(() {
    registerFallbackValue(
      NotificationItem(
        id: 'x',
        title: 'x',
        message: 'x',
        time: DateTime.utc(2026),
        type: NotificationType.paymentRequest,
      ),
    );
  });

  setUp(() {
    Logger.sink = (_) {};
    ledger = FakeLedger();
    transactions = TransactionBloc(
      getTransactionsUseCase: GetTransactionsUseCase(ledger),
      addTransactionUseCase: AddTransactionUseCase(ledger),
      transactionRepository: ledger,
    );
    gateway = FakePaymentGateway();
    userRepo = MockUserRepository();
    when(userRepo.getCurrentUser).thenAnswer(
      (_) async => Success(
        User(
          id: 'u1',
          fullName: 'Aarav',
          email: 'a@b.c',
          balance: ledger.balance,
          createdAt: DateTime.utc(2026),
        ),
      ),
    );
    user = UserBloc(
      getUserUseCase: GetUserUseCase(userRepo),
      updateUserUseCase: UpdateUserUseCase(userRepo),
    );
    notificationRepo = MockNotificationRepository();
    when(
      () => notificationRepo.addNotification(any()),
    ).thenAnswer((_) async => const Success(null));
    notifications = NotificationBloc(repository: notificationRepo);
  });

  tearDown(() async {
    await transactions.close();
    await user.close();
    await notifications.close();
  });

  PaymentCubit build({
    TransferDraft payload = draft,
    PaymentGateway? useGateway,
    bool withBlocs = true,
  }) => PaymentCubit(
    draft: payload,
    gateway: useGateway ?? gateway,
    transactions: transactions,
    notifications: withBlocs ? notifications : null,
    user: withBlocs ? user : null,
    clock: clock,
  );

  group('happy path', () {
    blocTest<PaymentCubit, PaymentState>(
      'authorizing → recording → settling → success',
      build: build,
      act: (c) => c.pay(),
      expect: () => const [
        PaymentState(phase: PaymentPhase.authorizing, attempts: 1),
        PaymentState(phase: PaymentPhase.recording, attempts: 1),
        PaymentState(phase: PaymentPhase.settling, attempts: 1),
        PaymentState(
          phase: PaymentPhase.success,
          attempts: 1,
          reference: 'FPTEST000001',
        ),
      ],
      verify: (c) {
        expect(ledger.rows, hasLength(1));
        expect(ledger.rows.single.amount, const Money.paise(-125000));
        expect(ledger.rows.single.idempotencyKey, draft.idempotencyKey);
        expect(ledger.rows.single.type, TransactionType.sendMoney);
        expect(ledger.rows.single.recipient, 'Priya Raghavan');
        expect(ledger.balance, const Money.paise(5499690));
        expect(gateway.authorizeCalls, hasLength(1));
        expect(gateway.settleCalls, hasLength(1));
        final receipt = c.receipt!;
        expect(receipt.reference, 'FPTEST000001');
        expect(receipt.alreadyPaid, isFalse);
        expect(receipt.paidAt, clock.now());
        expect(receipt.draft, draft);
      },
    );

    test('refreshes the balance and posts one notification', () async {
      final c = build();
      await c.pay();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(user.state, isA<UserContent>());
      final item =
          verify(
                () => notificationRepo.addNotification(captureAny()),
              ).captured.single
              as NotificationItem;
      expect(item.id, 'notify-${draft.idempotencyKey}');
      expect(item.message, contains('₹1,250.00'));
      expect(item.message, isNot(contains('okaxis')));
      await c.close();
    });

    test('works without the optional blocs', () async {
      final c = build(withBlocs: false);
      await c.pay();
      expect(c.state.phase, PaymentPhase.success);
      await c.close();
    });
  });

  group('idempotency', () {
    test('the same key paid twice records one row and reports already '
        'paid', () async {
      final first = build();
      await first.pay();
      await first.close();
      final second = build();
      await second.pay();
      expect(second.state.phase, PaymentPhase.success);
      expect(second.receipt!.alreadyPaid, isTrue);
      expect(ledger.rows, hasLength(1));
      expect(ledger.balance, const Money.paise(5499690));
      // One notification for the first payment, none for the replay.
      verify(() => notificationRepo.addNotification(any())).called(1);
      await second.close();
    });

    test('pay() while in flight or after success is ignored', () async {
      ledger.gate = Completer<void>();
      final c = build();
      final first = c.pay();
      unawaited(c.pay());
      unawaited(c.pay());
      expect(c.state.phase, PaymentPhase.authorizing);
      await Future<void>.delayed(Duration.zero);
      ledger.gate!.complete();
      await first;
      expect(c.state.phase, PaymentPhase.success);
      await c.pay();
      expect(c.state.attempts, 1);
      expect(ledger.addCalls, 1);
      expect(gateway.authorizeCalls, hasLength(1));
      await c.close();
    });

    test('1,000 concurrent pay() calls → one ledger write', () async {
      ledger.gate = Completer<void>();
      final c = build();
      final futures = [for (var i = 0; i < 1000; i++) c.pay()];
      await Future<void>.delayed(Duration.zero);
      ledger.gate!.complete();
      await Future.wait(futures);
      expect(ledger.addCalls, 1);
      expect(ledger.rows, hasLength(1));
      expect(c.state.attempts, 1);
      await c.close();
    });

    test(
      'a timeout at settlement, then retry → already paid, one row',
      () async {
        final flaky = FakePaymentGateway(
          settleResults: const [GatewayTimedOut()],
        );
        final c = build(useGateway: flaky);
        await c.pay();
        expect(c.state.phase, PaymentPhase.failure);
        expect(c.state.failure!.retryable, isTrue);
        expect(c.state.failure!.title, 'Bank did not confirm');
        expect(ledger.rows, hasLength(1));
        await c.retry();
        expect(c.state.phase, PaymentPhase.success);
        expect(c.state.attempts, 2);
        expect(c.receipt!.alreadyPaid, isTrue);
        expect(ledger.rows, hasLength(1));
        expect(flaky.settleCalls, hasLength(2));
        expect(flaky.settleCalls.map((r) => r.idempotencyKey).toSet(), {
          draft.idempotencyKey,
        });
        await c.close();
      },
    );
  });

  group('failures', () {
    test('a decline costs nothing and is not retryable', () async {
      final c = build(
        useGateway: FakePaymentGateway(
          authorizeResults: const [GatewayDeclined('Your bank said no.')],
        ),
      );
      await c.pay();
      expect(c.state.phase, PaymentPhase.failure);
      expect(c.state.failure!.title, 'Payment declined');
      expect(c.state.failure!.message, contains('Your bank said no.'));
      expect(c.state.failure!.retryable, isFalse);
      expect(ledger.addCalls, 0);
      await c.close();
    });

    test('an unreachable bank is retryable and costs nothing', () async {
      final c = build(useGateway: FakePaymentGateway(throwOnAuthorize: true));
      await c.pay();
      expect(c.state.failure!.title, 'Could not reach your bank');
      expect(c.state.failure!.retryable, isTrue);
      expect(ledger.addCalls, 0);
      await c.close();
    });

    test('a timeout at authorization is retryable and costs nothing', () async {
      final c = build(
        useGateway: FakePaymentGateway(
          authorizeResults: const [GatewayTimedOut()],
        ),
      );
      await c.pay();
      expect(c.state.failure!.retryable, isTrue);
      expect(ledger.addCalls, 0);
      await c.close();
    });

    test('insufficient balance → failure the amount screen can fix', () async {
      ledger.balance = const Money.paise(100);
      final c = build();
      await c.pay();
      expect(c.state.phase, PaymentPhase.failure);
      expect(c.state.failure!.title, 'Insufficient balance');
      expect(c.state.failure!.retryable, isFalse);
      expect(c.state.failure!.canEditAmount, isTrue);
      expect(ledger.rows, isEmpty);
      expect(gateway.settleCalls, isEmpty);
      await c.close();
    });

    test('a storage failure is retryable; the retry records once', () async {
      ledger.failWith = 'disk full';
      final c = build();
      await c.pay();
      expect(c.state.failure!.title, 'Could not save the payment');
      expect(c.state.failure!.retryable, isTrue);
      ledger.failWith = null;
      await c.retry();
      expect(c.state.phase, PaymentPhase.success);
      expect(c.receipt!.alreadyPaid, isFalse);
      expect(ledger.rows, hasLength(1));
      await c.close();
    });

    test('a ledger that never answers times out on the fake clock', () {
      fakeAsync((async) {
        ledger.gate = Completer<void>();
        final c = build();
        unawaited(c.pay());
        async.elapse(const Duration(seconds: 9));
        expect(c.state.phase, PaymentPhase.recording);
        async.elapse(const Duration(seconds: 2));
        expect(c.state.phase, PaymentPhase.failure);
        expect(c.state.failure!.title, 'No answer from the ledger');
        expect(c.state.failure!.retryable, isTrue);
        ledger.gate!.complete();
        async.flushMicrotasks();
        unawaited(c.close());
        async.flushMicrotasks();
      });
    });

    test('a closed transaction bloc is a retryable failure', () async {
      await transactions.close();
      final c = build();
      await c.pay();
      expect(c.state.phase, PaymentPhase.failure);
      expect(c.state.failure!.retryable, isTrue);
      await c.close();
    });

    test('a settle decline is retryable (status check)', () async {
      final c = build(
        useGateway: FakePaymentGateway(
          settleResults: const [GatewayDeclined('Unknown status.')],
        ),
      );
      await c.pay();
      expect(c.state.failure!.title, 'Bank could not confirm');
      expect(c.state.failure!.retryable, isTrue);
      await c.close();
    });
  });

  group('tampered drafts never reach the bank or the ledger', () {
    for (final (name, payload) in [
      ('zero amount', draft.copyWith(amount: Money.zero)),
      ('negative amount', draft.copyWith(amount: const Money.paise(-125000))),
      ('int64 min', draft.copyWith(amount: Money.min)),
      ('int64 max', draft.copyWith(amount: Money.max)),
      ('over the maximum', draft.copyWith(amount: const Money.paise(10000001))),
      ('empty key', draft.copyWith(idempotencyKey: '   ')),
      ('empty recipient', draft.copyWith(recipientName: '')),
      ('empty VPA', draft.copyWith(recipientAccount: ' ')),
    ]) {
      test(name, () async {
        final c = build(payload: payload);
        await c.pay();
        expect(c.state.phase, PaymentPhase.failure);
        expect(c.state.failure!.title, 'Invalid payment');
        expect(c.state.failure!.retryable, isFalse);
        expect(c.state.failure!.canEditAmount, isTrue);
        expect(c.state.attempts, 0);
        expect(gateway.authorizeCalls, isEmpty);
        expect(ledger.addCalls, 0);
        expect(ledger.balance, const Money.paise(5624690));
        await c.close();
      });
    }

    test('the maximum itself is allowed', () async {
      ledger.balance = const Money.paise(20000000);
      final c = build(
        payload: draft.copyWith(amount: const Money.paise(10000000)),
      );
      await c.pay();
      expect(c.state.phase, PaymentPhase.success);
      await c.close();
    });
  });

  group('lifecycle', () {
    test('closing mid-flight emits nothing afterwards and leaves no '
        'listener', () async {
      ledger.gate = Completer<void>();
      final c = build();
      final paying = c.pay();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.phase, PaymentPhase.recording);
      expect(transactions.hasEffectListeners, isTrue);
      await c.close();
      ledger.gate!.complete();
      await paying;
      expect(c.state.phase, PaymentPhase.recording);
      expect(transactions.hasEffectListeners, isFalse);
      expect(ledger.rows, hasLength(1));
    });

    test('state and receipt toString carry no amount or VPA', () async {
      final c = build();
      await c.pay();
      expect(c.state.toString(), 'PaymentState(success)');
      expect(c.receipt.toString(), 'PaymentReceipt(FPTEST000001)');
      expect(c.transaction.toString(), isNot(contains('okaxis')));
      await c.close();
    });
  });

  group('PaymentReceipt', () {
    final receipt = PaymentReceipt(
      draft: draft,
      reference: 'FPABC1234567',
      paidAt: DateTime.utc(2026, 10, 31, 6, 30),
    );

    test('masks the VPA and lists amount, reference, time, note, status', () {
      final text = receipt.shareText();
      expect(text, contains('₹1,250.00 to Priya Raghavan (pr•••••@okaxis)'));
      expect(text, contains('Reference FPABC1234567'));
      expect(text, contains('Note: chai'));
      expect(text, contains('Status: Paid'));
      expect(text, isNot(contains('priya.r@okaxis')));
      expect(text, isNot(contains(draft.idempotencyKey)));
      expect(receipt.paidAtLabel, matches(RegExp(r'^31 Oct 2026, \d\d:\d\d$')));
    });

    test('already paid changes the status and an empty note is omitted', () {
      final r = PaymentReceipt(
        draft: draft.copyWith(note: ''),
        reference: 'FPABC1234567',
        paidAt: DateTime.utc(2026),
        alreadyPaid: true,
      );
      expect(r.statusLabel, 'Already paid');
      expect(r.shareText(), isNot(contains('Note:')));
      expect(r.shareText(), contains('Status: Already paid'));
    });

    test('is a value type', () {
      expect(
        receipt,
        PaymentReceipt(
          draft: draft,
          reference: 'FPABC1234567',
          paidAt: DateTime.utc(2026, 10, 31, 6, 30),
        ),
      );
    });
  });

  test('TransferDraft round-trips through copyWith and equality', () {
    expect(draft.copyWith(), draft);
    expect(draft.copyWith(note: 'x'), isNot(draft));
    expect(draft.copyWith(note: 'x').copyWith(note: 'chai'), draft);
    expect(draft.props, hasLength(5));
  });

  test(
    'TransactionState effects are consumed only by the matching key',
    () async {
      final c = build();
      final other = draft.copyWith(idempotencyKey: 'transfer-other');
      final o = build(payload: other);
      await Future.wait([c.pay(), o.pay()]);
      expect(c.state.phase, PaymentPhase.success);
      expect(o.state.phase, PaymentPhase.success);
      expect(ledger.rows, hasLength(2));
      expect(c.receipt!.alreadyPaid, isFalse);
      expect(o.receipt!.alreadyPaid, isFalse);
      expect(transactions.state, isA<TransactionContent>());
      expect(notifications.state, isA<NotificationState>());
      await c.close();
      await o.close();
    },
  );
}
