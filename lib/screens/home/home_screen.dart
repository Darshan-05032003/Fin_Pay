import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/blocs/transaction/transaction_state.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/blocs/user/user_event.dart';
import 'package:fin_pay/blocs/user/user_state.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_view.dart';
import 'package:fin_pay/screens/cards/widgets/payment_card_art.dart';
import 'package:fin_pay/screens/home/widgets/balance_header.dart';
import 'package:fin_pay/screens/home/widgets/offers_carousel.dart';
import 'package:fin_pay/screens/home/widgets/quick_actions.dart';
import 'package:fin_pay/screens/home/widgets/transaction_row.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Reloads the three home blocs and waits for each to leave its loading
/// state (bounded by [timeout]), so a pull-to-refresh holds until the data
/// is actually back.
Future<void> refreshHome({
  required UserBloc user,
  required TransactionBloc transactions,
  required CardBloc cards,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final settled = Future.wait<void>([
    user.stream.firstWhere((s) => s is! UserLoading && s is! UserInitial),
    transactions.stream.firstWhere(
      (s) => s is! TransactionLoading && s is! TransactionInitial,
    ),
    cards.stream.firstWhere((s) => s is! CardLoading && s is! CardInitial),
  ]).timeout(timeout, onTimeout: () => const []);
  user.add(const LoadUserEvent());
  transactions.add(const LoadTransactionsEvent());
  cards.add(const LoadCardsEvent());
  await settled;
}

/// The Home tab: collapsing balance header, quick actions, the first card
/// (hero into its details), offers, the five newest transactions, and
/// pull-to-refresh. Screenshot protection is handled by the shell.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Branch index of this tab in the shell.
  static const int tabIndex = 0;

  /// How many transactions are listed.
  static const int recentLimit = 5;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scroll = ScrollController();
  TabReselect? _reselect;
  int _seenReselects = 0;

  static Clock _clock() =>
      GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>() : const Clock();

  @override
  void initState() {
    super.initState();
    final user = context.read<UserBloc>();
    if (user.state is UserInitial) user.add(const LoadUserEvent());
    final transactions = context.read<TransactionBloc>();
    if (transactions.state is TransactionInitial) {
      transactions.add(const LoadTransactionsEvent());
    }
    final cards = context.read<CardBloc>();
    if (cards.state is CardInitial) cards.add(const LoadCardsEvent());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reselect = AppShell.reselectOf(context);
    if (reselect != _reselect) {
      _reselect?.removeListener(_onReselect);
      _reselect = reselect;
      _seenReselects = reselect?.count ?? 0;
      reselect?.addListener(_onReselect);
    }
  }

  void _onReselect() {
    final r = _reselect;
    if (r == null || r.count == _seenReselects) return;
    _seenReselects = r.count;
    if (r.index != HomeScreen.tabIndex || !_scroll.hasClients) return;
    if (FpMotion.of(context).reduce) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: FpMotion.emphasized,
        curve: FpMotion.standardCurve,
      );
    }
  }

  @override
  void dispose() {
    _reselect?.removeListener(_onReselect);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() => refreshHome(
    user: context.read<UserBloc>(),
    transactions: context.read<TransactionBloc>(),
    cards: context.read<CardBloc>(),
  );

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final hidden = context.select<SettingsCubit, bool>(
      (s) => s.state.hideBalance,
    );
    return HeroMode(
      enabled: AppShell.isVisibleTab(context, HomeScreen.tabIndex),
      child: Scaffold(
        backgroundColor: c.background,
        body: FpRefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            key: const ValueKey('home-scroll'),
            controller: _scroll,
            slivers: [
              BalanceHeader(
                now: _clock().now(),
                onNotifications: () =>
                    unawaited(context.push(AppRoutes.notifications)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.xl,
                  FpSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: QuickActions(
                    actions: [
                      QuickAction(
                        key: const ValueKey('home-action-send'),
                        icon: Icons.north_east,
                        label: 'Send',
                        onPressed: () =>
                            unawaited(context.push(AppRoutes.transfer)),
                      ),
                      QuickAction(
                        key: const ValueKey('home-action-add-card'),
                        icon: Icons.add_card_outlined,
                        label: 'Add card',
                        onPressed: () =>
                            unawaited(context.push(AppRoutes.addCard)),
                      ),
                      QuickAction(
                        key: const ValueKey('home-action-stats'),
                        icon: Icons.bar_chart_outlined,
                        label: 'Stats',
                        onPressed: () => context.go(AppRoutes.statistics),
                      ),
                      QuickAction(
                        key: const ValueKey('home-action-history'),
                        icon: Icons.receipt_long_outlined,
                        label: 'History',
                        onPressed: () =>
                            unawaited(context.push(AppRoutes.transactions)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.xl,
                  FpSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'YOUR CARD',
                    actionLabel: 'All cards',
                    actionKey: const ValueKey('home-all-cards'),
                    onAction: () => context.go(AppRoutes.cards),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.md,
                  FpSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(child: _CardPreview()),
              ),
              const SliverPadding(
                padding: EdgeInsets.only(top: FpSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: FpSpacing.lg),
                    child: _SectionHeader(title: 'FOR YOU'),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.only(top: FpSpacing.md),
                sliver: SliverToBoxAdapter(child: OffersCarousel()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  FpSpacing.xl,
                  FpSpacing.lg,
                  FpSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'RECENT',
                    actionLabel: 'See all',
                    actionKey: const ValueKey('home-see-all'),
                    onAction: () =>
                        unawaited(context.push(AppRoutes.transactions)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  FpSpacing.lg,
                  0,
                  FpSpacing.lg,
                  FpSpacing.xxxl,
                ),
                sliver: SliverToBoxAdapter(
                  child: _RecentTransactions(hidden: hidden),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: fp.text.overline),
          ),
        ),
        if (actionLabel != null)
          FpButton(
            key: actionKey,
            label: actionLabel!,
            variant: FpButtonVariant.ghost,
            size: FpButtonSize.small,
            expand: false,
            onPressed: onAction,
          ),
      ],
    );
  }
}

/// The newest card, compact, as the hero source for its details.
class _CardPreview extends StatelessWidget {
  const _CardPreview();

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return BlocBuilder<CardBloc, CardState>(
      builder: (context, state) {
        switch (state) {
          case CardInitial() || CardLoading():
            return const FpSkeletonGroup(
              key: ValueKey('home-card-loading'),
              child: FpSkeleton(height: 96),
            );
          case CardError():
            return FpSurface(
              key: const ValueKey('home-card-error'),
              variant: FpSurfaceVariant.flat,
              semanticLabel: 'Cards unavailable. Tap to retry',
              onTap: () => context.read<CardBloc>().add(const LoadCardsEvent()),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: c.alert),
                  const SizedBox(width: FpSpacing.md),
                  Expanded(
                    child: Text(
                      'Cards unavailable · tap to retry',
                      style: fp.text.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          case CardEmpty():
            return FpSurface(
              key: const ValueKey('home-card-empty'),
              variant: FpSurfaceVariant.raised,
              semanticLabel: 'Add your first card',
              onTap: () => unawaited(context.push(AppRoutes.addCard)),
              child: Row(
                children: [
                  Icon(Icons.add_card_outlined, color: c.accent),
                  const SizedBox(width: FpSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add your first card', style: fp.text.title),
                        const SizedBox(height: FpSpacing.xs),
                        Text(
                          'Pay from a saved debit or credit card.',
                          style: fp.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.textSecondary),
                ],
              ),
            );
          case CardContent(:final cards):
            final card = cards.first;
            return FpPressable(
              key: const ValueKey('home-card-preview'),
              semanticLabel: '${PaymentCardArt.describe(card)}. Open details',
              onPressed: () =>
                  unawaited(context.push(AppRoutes.cardDetailsFor(card.id))),
              child: ExcludeSemantics(
                child: FpHero(
                  tag: cardHeroTag(card.id),
                  child: PaymentCardArt.of(card),
                ),
              ),
            );
        }
      },
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({required this.hidden});

  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      builder: (context, state) {
        switch (state) {
          case TransactionInitial() || TransactionLoading():
            return const FpSkeletonGroup(
              key: ValueKey('home-recent-loading'),
              child: Column(
                children: [FpSkeletonRow(), FpSkeletonRow(), FpSkeletonRow()],
              ),
            );
          case TransactionError(:final message):
            return FpErrorState(
              key: const ValueKey('home-recent-error'),
              title: 'Could not load transactions',
              message: message,
              onRetry: () => context.read<TransactionBloc>().add(
                const LoadTransactionsEvent(),
              ),
            );
          case TransactionEmpty():
            return FpEmptyState(
              key: const ValueKey('home-recent-empty'),
              icon: Icons.receipt_long_outlined,
              title: 'No transactions yet',
              message: 'Send money to see it here.',
              actionLabel: 'Send money',
              onAction: () => unawaited(context.push(AppRoutes.transfer)),
            );
          case TransactionContent(:final transactions):
            final recent = transactions.take(HomeScreen.recentLimit).toList();
            return FpStaggeredEntrance(
              key: ValueKey('home-recent-${recent.length}-${recent.first.id}'),
              children: [
                for (final t in recent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: FpSpacing.sm),
                    child: TransactionRow(
                      transaction: t,
                      hideAmount: hidden,
                      onTap: () =>
                          unawaited(context.push(AppRoutes.transactions)),
                    ),
                  ),
              ],
            );
        }
      },
    );
  }
}
