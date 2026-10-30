import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_state.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:fin_pay/screens/cards/details/card_details_cubit.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_view.dart';
import 'package:fin_pay/screens/cards/stack/cvv_reveal_cubit.dart';
import 'package:fin_pay/screens/cards/widgets/payment_card_art.dart';
import 'package:fin_pay/screens/home/widgets/transaction_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// One card: the full-size art (hero from the stack / home preview), the
/// masked number with copy-last-4, recent card payments, a freeze toggle
/// and removal behind a confirmation sheet. Screenshot-protected.
class CardDetailsScreen extends StatelessWidget {
  const CardDetailsScreen({required this.cardId, super.key, this.repository});

  final String cardId;

  /// Injected for tests; defaults to the GetIt registration.
  final ICardRepository? repository;

  /// How many recent card payments are listed.
  static const int recentLimit = 5;

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => CardDetailsCubit(
              cards: context.read<CardBloc>(),
              cardId: cardId,
            ),
          ),
          BlocProvider(
            create: (_) => CvvRevealCubit(
              repository: repository ?? GetIt.I<ICardRepository>(),
              clock: GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>() : null,
            ),
          ),
        ],
        child: _CardDetailsView(cardId: cardId),
      ),
    );
  }
}

class _CardDetailsView extends StatefulWidget {
  const _CardDetailsView({required this.cardId});

  final String cardId;

  @override
  State<_CardDetailsView> createState() => _CardDetailsViewState();
}

class _CardDetailsViewState extends State<_CardDetailsView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cards = context.read<CardBloc>();
    if (cards.state is CardInitial) cards.add(const LoadCardsEvent());
    final transactions = context.read<TransactionBloc>();
    if (transactions.state is TransactionInitial) {
      transactions.add(const LoadTransactionsEvent());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      context.read<CvvRevealCubit>().hide();
      context.read<CardDetailsCubit>().unflip();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.cards);
    }
  }

  Future<void> _copyLast4(BuildContext context, PaymentCard card) async {
    // Only the last four digits ever reach the clipboard (D-044).
    await Clipboard.setData(ClipboardData(text: card.last4));
    if (!context.mounted) return;
    context.read<CardDetailsCubit>().copiedLast4();
    playHaptic(null, HapticType.light);
    FpToast.show(context, message: 'Last 4 digits copied');
  }

  Future<void> _confirmRemove(BuildContext context, PaymentCard card) async {
    final cubit = context.read<CardDetailsCubit>();
    final confirmed = await FpBottomSheet.show<bool>(
      context,
      title: 'Remove this card?',
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${CardNetworkLabel.of(card)} ending ${card.last4} will be '
            'removed from this device, along with its stored number and CVV.',
            style: sheet.fp.text.bodySmall,
          ),
          const SizedBox(height: FpSpacing.xl),
          FpButton(
            key: const ValueKey('card-remove-confirm'),
            label: 'Remove card',
            variant: FpButtonVariant.danger,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          const SizedBox(height: FpSpacing.md),
          FpButton(
            label: 'Keep it',
            variant: FpButtonVariant.ghost,
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.remove();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return BlocListener<CardDetailsCubit, CardDetailsState>(
      listenWhen: (p, n) => p.removal != n.removal,
      listener: (context, state) {
        switch (state.removal) {
          case CardRemoveStatus.removed:
            playHaptic(null, HapticType.success);
            FpToast.show(
              context,
              message: 'Card removed',
              kind: FpToastKind.success,
            );
            _leave(context);
          case CardRemoveStatus.failed:
            playHaptic(null, HapticType.error);
            FpToast.show(
              context,
              message: state.message ?? 'Could not remove the card',
              kind: FpToastKind.error,
            );
          case CardRemoveStatus.idle || CardRemoveStatus.removing:
            break;
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: BlocBuilder<CardBloc, CardState>(
            builder: (context, cardsState) {
              final card = cardsState is CardContent
                  ? cardsState.cards
                        .where((card) => card.id == widget.cardId)
                        .firstOrNull
                  : null;
              return ListView(
                key: const ValueKey('card-details-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.sm,
                  FpSpacing.lg,
                  FpSpacing.xl,
                ),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _leave(context),
                        tooltip: 'Back',
                        constraints: const BoxConstraints(
                          minWidth: FpSpacing.minTapTarget,
                          minHeight: FpSpacing.minTapTarget,
                        ),
                        icon: Icon(Icons.arrow_back, color: c.textPrimary),
                      ),
                      const SizedBox(width: FpSpacing.xs),
                      Semantics(
                        header: true,
                        child: Text('Card details', style: fp.text.headline),
                      ),
                    ],
                  ),
                  const SizedBox(height: FpSpacing.lg),
                  switch (cardsState) {
                    CardInitial() || CardLoading() => const FpSkeletonGroup(
                      key: ValueKey('card-details-loading'),
                      child: AspectRatio(
                        aspectRatio: PaymentCardArt.aspectRatio,
                        child: FpSkeleton(height: double.infinity),
                      ),
                    ),
                    CardError(:final message) => FpErrorState(
                      key: const ValueKey('card-details-error'),
                      title: 'Could not load this card',
                      message: message,
                      onRetry: () =>
                          context.read<CardBloc>().add(const LoadCardsEvent()),
                    ),
                    CardEmpty() ||
                    CardContent() when card == null => FpErrorState(
                      key: const ValueKey('card-details-missing'),
                      icon: Icons.credit_card_off_outlined,
                      title: 'Card not found',
                      message: 'This card is not on this device any more.',
                      retryLabel: 'Back to cards',
                      onRetry: () => _leave(context),
                    ),
                    _ => _Details(
                      card: card!,
                      onCopyLast4: () => _copyLast4(context, card),
                      onRemove: () => _confirmRemove(context, card),
                    ),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Neutral network label for a stored card.
abstract final class CardNetworkLabel {
  static String of(PaymentCard card) => switch (card.cardType) {
    CardType.visa => 'Visa',
    CardType.mastercard => 'Mastercard',
    CardType.rupay => 'RuPay',
    CardType.amex => 'Card',
  };
}

class _Details extends StatelessWidget {
  const _Details({
    required this.card,
    required this.onCopyLast4,
    required this.onRemove,
  });

  final PaymentCard card;
  final VoidCallback onCopyLast4;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return BlocBuilder<CardDetailsCubit, CardDetailsState>(
      builder: (context, state) {
        final cubit = context.read<CardDetailsCubit>();
        final label = PaymentCardArt.describe(card);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FpTiltCard(
              child: FpFlipCard(
                key: const ValueKey('card-details-card'),
                flipped: state.flipped,
                onTap: cubit.toggleFlip,
                semanticLabel: state.flipped
                    ? '$label, back. Tap to turn over'
                    : '$label. Tap to see the back',
                front: FpHero(
                  tag: cardHeroTag(card.id),
                  child: PaymentCardArt.of(card, frozen: state.frozen),
                ),
                back: CardBackWithCvv(card: card),
              ),
            ),
            const SizedBox(height: FpSpacing.xl),
            FpStaggeredEntrance(
              children: [
                FpSurface(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CARD NUMBER', style: fp.text.overline),
                            const SizedBox(height: FpSpacing.xs),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                PaymentCardArt.maskedNumber(card.last4),
                                key: const ValueKey('card-details-number'),
                                style: fp.text.numeric.copyWith(
                                  letterSpacing: 1.5,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FpButton(
                        key: const ValueKey('card-copy-last4'),
                        label: 'Copy last 4',
                        variant: FpButtonVariant.secondary,
                        size: FpButtonSize.small,
                        expand: false,
                        onPressed: onCopyLast4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FpSpacing.md),
                FpSurface(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Freeze card', style: fp.text.title),
                            const SizedBox(height: FpSpacing.xs),
                            Text(
                              state.frozen
                                  ? 'Payments are blocked on this device.'
                                  : 'Block payments without removing it.',
                              style: fp.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FpToggle(
                        key: const ValueKey('card-freeze'),
                        value: state.frozen,
                        semanticLabel: 'Freeze card',
                        onChanged: (v) => cubit.setFrozen(frozen: v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FpSpacing.xl),
                Semantics(
                  header: true,
                  child: Text('RECENT CARD PAYMENTS', style: fp.text.overline),
                ),
                const SizedBox(height: FpSpacing.md),
                const _CardTransactions(),
                const SizedBox(height: FpSpacing.xl),
                FpButton(
                  key: const ValueKey('card-remove'),
                  label: 'Remove card',
                  variant: FpButtonVariant.danger,
                  leadingIcon: Icons.delete_outline,
                  isLoading: state.busy,
                  onPressed: onRemove,
                ),
                const SizedBox(height: FpSpacing.sm),
                Text(
                  'Removing deletes the stored number and CVV from the '
                  'device keystore.',
                  style: fp.text.caption.copyWith(color: c.textTertiary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The newest card payments (the ledger has no card column yet, so every
/// `payment` counts; see DECISIONS).
class _CardTransactions extends StatelessWidget {
  const _CardTransactions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        switch (state) {
          case TransactionInitial() || TransactionLoading():
            return const FpSkeletonGroup(
              child: Column(children: [FpSkeletonRow(), FpSkeletonRow()]),
            );
          case TransactionError(:final message):
            return FpErrorState(
              title: 'Could not load payments',
              message: message,
              onRetry: () => context.read<TransactionBloc>().add(
                const LoadTransactionsEvent(),
              ),
            );
          case TransactionEmpty():
            return const FpEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              message: 'Payments made with this card show up here.',
            );
          case TransactionContent(:final transactions):
            final payments = transactions
                .where((t) => t.type == TransactionType.payment)
                .take(CardDetailsScreen.recentLimit)
                .toList();
            if (payments.isEmpty) {
              return const FpEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No payments yet',
                message: 'Payments made with this card show up here.',
              );
            }
            return Column(
              children: [
                for (final t in payments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FpSpacing.sm),
                    child: TransactionRow(transaction: t),
                  ),
              ],
            );
        }
      },
    );
  }
}
