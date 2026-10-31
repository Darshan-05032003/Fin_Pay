import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_event.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:fin_pay/screens/home/widgets/transaction_row.dart';
import 'package:fin_pay/screens/transactions/transactions_cubit.dart';
import 'package:fin_pay/screens/transactions/transactions_math.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// `/transactions`: the paged ledger grouped by day with sticky headers,
/// search, filter chips, swipe actions (details / delete with undo) and
/// pull-to-refresh. Amounts are on screen, so the route is under
/// `FLAG_SECURE`.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        // Home shows the newest rows from the app-wide bloc; a delete or an
        // undo here must reach it too.
        final ledger = _ledgerOf(context);
        final cubit = TransactionsCubit(
          repository: di.sl(),
          onLedgerChanged: ledger == null
              ? null
              : () => ledger.add(const LoadTransactionsEvent()),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const SecureScreen(child: _TransactionsView()),
    );
  }
}

TransactionBloc? _ledgerOf(BuildContext context) {
  try {
    return context.read<TransactionBloc>();
  } on ProviderNotFoundException {
    return null;
  }
}

class _TransactionsView extends StatefulWidget {
  const _TransactionsView();

  @override
  State<_TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<_TransactionsView> {
  final ScrollController _scroll = ScrollController();

  static DateTime _now() =>
      GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>().now() : clock.now();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification || n is ScrollEndNotification) {
      if (TransactionsMath.nearEnd(
        pixels: n.metrics.pixels,
        maxScrollExtent: n.metrics.maxScrollExtent,
      )) {
        unawaited(context.read<TransactionsCubit>().loadMore());
      }
    }
    return false;
  }

  void _delete(BuildContext context, Transaction t) {
    final cubit = context.read<TransactionsCubit>();
    unawaited(cubit.delete(t.id));
    final handle = FpToast.show(
      context,
      message: 'Transaction deleted',
      actionLabel: 'Undo',
      onAction: () {
        playHaptic(null, HapticType.selection);
        unawaited(cubit.undo(t.id));
      },
    );
    unawaited(
      handle.closed.then((_) {
        if (!handle.actionTaken) cubit.forget(t.id);
      }),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    Transaction t, {
    required bool hidden,
  }) {
    return FpBottomSheet.show<void>(
      context,
      title: 'Transaction',
      builder: (sheet) => _DetailsSheet(transaction: t, hidden: hidden),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final hidden = context.select<SettingsCubit, bool>(
      (s) => s.state.hideBalance,
    );
    final cubit = context.read<TransactionsCubit>();
    return BlocListener<TransactionsCubit, TransactionsState>(
      listenWhen: (p, n) =>
          n.errorMessage != null &&
          p.errorMessage != n.errorMessage &&
          n.status != TransactionsStatus.error,
      listener: (context, state) {
        playHaptic(null, HapticType.error);
        FpToast.show(
          context,
          message: state.errorMessage ?? 'Something went wrong',
          kind: FpToastKind.error,
        );
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          leading: FpPressable(
            semanticLabel: 'Back',
            onPressed: () => _leave(context),
            child: Icon(Icons.arrow_back, color: c.textPrimary),
          ),
          title: Text('Transactions', style: fp.text.title),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FpSpacing.lg,
                FpSpacing.sm,
                FpSpacing.lg,
                FpSpacing.sm,
              ),
              child: FpTextField(
                key: const ValueKey('transactions-search'),
                hint: 'Search by name or note',
                semanticLabel: 'Search transactions',
                prefix: Icon(Icons.search, color: c.textTertiary, size: 20),
                textInputAction: TextInputAction.search,
                maxLength: TransactionsCubit.maxQueryLength,
                onChanged: cubit.search,
              ),
            ),
            BlocBuilder<TransactionsCubit, TransactionsState>(
              buildWhen: (p, n) => p.filter != n.filter,
              builder: (context, state) => SizedBox(
                height: FpSpacing.minTapTarget,
                child: ListView(
                  key: const ValueKey('transactions-filters'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: FpSpacing.lg),
                  children: [
                    for (final filter in TransactionsFilter.values) ...[
                      FpChip(
                        key: ValueKey('filter-${filter.name}'),
                        label: filter.label,
                        selected: state.filter == filter,
                        onSelected: (_) => unawaited(cubit.setFilter(filter)),
                      ),
                      const SizedBox(width: FpSpacing.sm),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: FpSpacing.sm),
            Expanded(
              child: BlocBuilder<TransactionsCubit, TransactionsState>(
                builder: (context, state) => switch (state.status) {
                  TransactionsStatus.loading => const _ListSkeleton(),
                  TransactionsStatus.error => FpErrorState(
                    title: 'Could not load transactions',
                    message: state.errorMessage,
                    onRetry: () => unawaited(cubit.retry()),
                  ),
                  TransactionsStatus.empty => _EmptyLedger(
                    searching: state.isSearching,
                    filtered: state.filter != TransactionsFilter.all,
                  ),
                  TransactionsStatus.content => FpRefreshIndicator(
                    onRefresh: cubit.refresh,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScroll,
                      child: _GroupedList(
                        controller: _scroll,
                        state: state,
                        now: _now(),
                        hidden: hidden,
                        onDetails: (t) =>
                            unawaited(_showDetails(context, t, hidden: hidden)),
                        onDelete: (t) => _delete(context, t),
                      ),
                    ),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.controller,
    required this.state,
    required this.now,
    required this.hidden,
    required this.onDetails,
    required this.onDelete,
  });

  final ScrollController controller;
  final TransactionsState state;
  final DateTime now;
  final bool hidden;
  final ValueChanged<Transaction> onDetails;
  final ValueChanged<Transaction> onDelete;

  @override
  Widget build(BuildContext context) {
    final groups = TransactionsMath.groupByDay(state.items, now);
    return CustomScrollView(
      key: const ValueKey('transactions-scroll'),
      controller: controller,
      slivers: [
        for (final group in groups)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _DayHeaderDelegate(
                  label: group.label,
                  key: ValueKey('day-${group.label}'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: FpSpacing.lg),
                sliver: SliverList.separated(
                  itemCount: group.items.length,
                  // Elements stay keyed by id across deletes and undos.
                  findItemIndexCallback: (key) {
                    if (key is! ValueKey<String>) return null;
                    final id = key.value.replaceFirst('tx-', '');
                    final i = group.items.indexWhere((t) => t.id == id);
                    return i < 0 ? null : i;
                  },
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: FpSpacing.sm),
                  itemBuilder: (context, i) {
                    final t = group.items[i];
                    return _TransactionSwipeRow(
                      key: ValueKey('tx-${t.id}'),
                      transaction: t,
                      hidden: hidden,
                      now: now,
                      onDetails: () => onDetails(t),
                      onDelete: () => onDelete(t),
                    );
                  },
                ),
              ),
            ],
          ),
        if (state.hasMore)
          const SliverPadding(
            padding: EdgeInsets.all(FpSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: FpSkeletonRow(key: ValueKey('transactions-load-more')),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: FpSpacing.xxl)),
      ],
    );
  }
}

class _TransactionSwipeRow extends StatelessWidget {
  const _TransactionSwipeRow({
    required this.transaction,
    required this.hidden,
    required this.now,
    required this.onDetails,
    required this.onDelete,
    super.key,
  });

  final Transaction transaction;
  final bool hidden;
  final DateTime now;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final amount = hidden
        ? 'amount hidden'
        : '${t.isCredit ? 'received' : 'paid'} ${t.amount.abs().format()}';
    return FpSwipeActionRow(
      semanticLabel: '${t.title}, $amount, swipe left for actions',
      onTap: onDetails,
      actions: [
        FpSwipeAction(
          label: 'Details',
          icon: Icons.info_outline,
          onPressed: onDetails,
        ),
        FpSwipeAction(
          label: 'Delete',
          icon: Icons.delete_outline,
          tone: FpSwipeActionTone.danger,
          onPressed: onDelete,
        ),
      ],
      child: TransactionRow(transaction: t, hideAmount: hidden, now: now),
    );
  }
}

/// A pinned day label; `SliverMainAxisGroup` pushes it away when the next
/// group's header arrives, which is the sticky-header behaviour.
class _DayHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _DayHeaderDelegate({required this.label, required this.key});

  final String label;
  final Key key;

  static const double height = 36;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final fp = context.fp;
    final c = fp.colors;
    return ColoredBox(
      key: key,
      color: c.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: FpSpacing.lg),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            header: true,
            child: Text(label.toUpperCase(), style: fp.text.overline),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_DayHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return FpSkeletonGroup(
      child: ListView(
        key: const ValueKey('transactions-skeleton'),
        padding: const EdgeInsets.symmetric(horizontal: FpSpacing.lg),
        children: [
          const FpSkeleton(width: 80, height: 12),
          const SizedBox(height: FpSpacing.md),
          for (var i = 0; i < 8; i++) ...[
            const FpSkeletonRow(),
            const SizedBox(height: FpSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// "No spends yet" with a small finite pulse on the glyph.
class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.searching, required this.filtered});

  final bool searching;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return FpPulse(
      key: const ValueKey('transactions-empty'),
      maxScale: 1.03,
      child: FpEmptyState(
        icon: searching ? Icons.search_off : Icons.receipt_long_outlined,
        title: searching
            ? 'No matches'
            : filtered
            ? 'Nothing here yet'
            : 'No transactions yet',
        message: searching
            ? 'Try another name or note.'
            : filtered
            ? 'Switch the filter to see other activity.'
            : 'Send money or add a card to see activity here.',
      ),
    );
  }
}

/// Masked counterparty, amount, when, type and id.
class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({required this.transaction, required this.hidden});

  final Transaction transaction;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final t = transaction;
    final local = t.localDate;
    final when = DateFormat('d MMM yyyy, HH:mm').format(local);
    Widget row(String label, String value, {Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: FpSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label.toUpperCase(), style: fp.text.overline),
          ),
          Expanded(
            child: Text(
              value,
              key: key,
              style: fp.text.bodySmall.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
    return Column(
      key: const ValueKey('transaction-details'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.title, style: fp.text.title),
        const SizedBox(height: FpSpacing.sm),
        FpAmountText(
          key: const ValueKey('transaction-details-amount'),
          paise: t.amount.paise,
          style: fp.text.displaySmall.copyWith(
            color: t.isCredit ? c.success : c.textPrimary,
          ),
          hide: hidden ? FpAmountHide.mask : FpAmountHide.none,
        ),
        const SizedBox(height: FpSpacing.lg),
        row(
          t.isCredit ? 'From' : 'To',
          TransactionsMath.maskCounterparty(t.recipient ?? t.title),
          key: const ValueKey('transaction-details-counterparty'),
        ),
        row('When', when),
        row('Type', TransactionsMath.typeLabel(t.type)),
        row('Reference', t.id, key: const ValueKey('transaction-details-id')),
        const SizedBox(height: FpSpacing.sm),
        FpButton(
          label: 'Done',
          variant: FpButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
