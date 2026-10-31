import 'dart:async';

import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/core/settings/settings_cubit.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:fin_pay/screens/statistics/stats_cubit.dart';
import 'package:fin_pay/screens/statistics/stats_math.dart';
import 'package:fin_pay/screens/statistics/widgets/stats_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The Stats tab: spend / income summary for the selected period, bars
/// that grow in, a trend line that draws on, a category donut that sweeps,
/// tap-to-inspect tooltips and the top merchants. Screenshot protection is
/// handled by the shell (the tab shows totals).
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  /// Branch index of this tab in the shell.
  static const int tabIndex = 1;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = StatsCubit(repository: di.sl(), clock: di.sl());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _StatsView(),
    );
  }
}

class _StatsView extends StatefulWidget {
  const _StatsView();

  @override
  State<_StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<_StatsView>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: FpMotion.emphasized,
  );
  late final CurvedAnimation _curved = CurvedAnimation(
    parent: _reveal,
    curve: FpMotion.emphasizedDecelerate,
  );
  TabReselect? _reselect;
  int _seenReselects = 0;
  int _shownRevision = 0;

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
    if (r.index != StatisticsScreen.tabIndex || !_scroll.hasClients) return;
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
    _curved.dispose();
    _reveal.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Runs the chart entrance for a new revision (bars grow, line draws,
  /// donut sweeps); with reduce motion the charts appear complete.
  void _revealFor(int revision) {
    if (revision == _shownRevision) return;
    _shownRevision = revision;
    if (FpMotion.of(context).reduce) {
      _reveal.value = 1;
    } else {
      _reveal.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final hidden = context.select<SettingsCubit, bool>(
      (s) => s.state.hideBalance,
    );
    final cubit = context.read<StatsCubit>();
    return BlocListener<StatsCubit, StatsState>(
      listenWhen: (p, n) => p.revision != n.revision,
      listener: (context, state) => _revealFor(state.revision),
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: BlocBuilder<StatsCubit, StatsState>(
            builder: (context, state) {
              // A content state that arrived before the listener was attached
              // (first build) still needs its entrance.
              if (state.status == StatsStatus.content &&
                  state.revision != _shownRevision) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => mounted ? _revealFor(state.revision) : null,
                );
              }
              return FpRefreshIndicator(
                onRefresh: cubit.refresh,
                child: ListView(
                  key: const ValueKey('stats-scroll'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    FpSpacing.lg,
                    FpSpacing.sm,
                    FpSpacing.lg,
                    FpSpacing.xxl,
                  ),
                  children: [
                    Text('Insights', style: fp.text.headline),
                    const SizedBox(height: FpSpacing.md),
                    FpSegmentedControl(
                      key: const ValueKey('stats-period'),
                      segments: [for (final p in StatsPeriod.values) p.label],
                      selectedIndex: state.period.index,
                      onChanged: (i) =>
                          unawaited(cubit.setPeriod(StatsPeriod.values[i])),
                    ),
                    const SizedBox(height: FpSpacing.lg),
                    switch (state.status) {
                      StatsStatus.loading => const _StatsSkeleton(),
                      StatsStatus.error => FpErrorState(
                        key: const ValueKey('stats-error'),
                        title: 'Could not load insights',
                        message: state.message,
                        onRetry: () => unawaited(cubit.retry()),
                      ),
                      StatsStatus.empty => const _NoSpends(),
                      StatsStatus.content => _StatsContent(
                        key: ValueKey('stats-content-${state.revision}'),
                        summary: state.summary!,
                        reveal: _curved,
                        hidden: hidden,
                      ),
                    },
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({
    required this.summary,
    required this.reveal,
    required this.hidden,
    super.key,
  });

  final StatsSummary summary;
  final Animation<double> reveal;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return FpStaggeredEntrance(
      children: [
        Row(
          children: [
            Expanded(
              child: _TotalCard(
                key: const ValueKey('stats-spent'),
                label: 'Spent',
                money: summary.spend,
                color: c.textPrimary,
                hidden: hidden,
              ),
            ),
            const SizedBox(width: FpSpacing.md),
            Expanded(
              child: _TotalCard(
                key: const ValueKey('stats-received'),
                label: 'Received',
                money: summary.income,
                color: c.success,
                hidden: hidden,
              ),
            ),
          ],
        ),
        const SizedBox(height: FpSpacing.md),
        _ChartCard(
          title: 'Spend vs received',
          child: StatsBarChart(
            key: const ValueKey('stats-bars'),
            buckets: summary.buckets,
            reveal: reveal,
            hidden: hidden,
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        _ChartCard(
          title: 'Daily spend',
          child: StatsLineChart(
            key: const ValueKey('stats-line'),
            series: summary.series,
            reveal: reveal,
            hidden: hidden,
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        _ChartCard(
          title: 'Where it went',
          child: StatsDonutChart(
            key: const ValueKey('stats-donut'),
            categories: summary.categories,
            reveal: reveal,
            hidden: hidden,
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        _ChartCard(
          title: 'Top merchants',
          child: _Merchants(merchants: summary.merchants, hidden: hidden),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.money,
    required this.color,
    required this.hidden,
    super.key,
  });

  final String label;
  final Money money;
  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    return FpSurface(
      variant: FpSurfaceVariant.raised,
      padding: const EdgeInsets.all(FpSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: fp.text.overline),
          const SizedBox(height: FpSpacing.xs),
          FpAmountText(
            paise: money.paise,
            style: fp.text.displaySmall.copyWith(color: color, fontSize: 26),
            hide: hidden ? FpAmountHide.mask : FpAmountHide.none,
            animateFirstBuild: true,
            semanticLabel: hidden
                ? '$label hidden'
                : '$label ${money.format()}',
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    return FpSurface(
      variant: FpSurfaceVariant.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: fp.text.overline),
          const SizedBox(height: FpSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Merchants extends StatelessWidget {
  const _Merchants({required this.merchants, required this.hidden});

  final List<StatsMerchant> merchants;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    if (merchants.isEmpty) {
      return Text('No spends in this period.', style: fp.text.bodySmall);
    }
    return Column(
      key: const ValueKey('stats-merchants'),
      children: [
        for (final (i, m) in merchants.indexed)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == merchants.length - 1 ? 0 : FpSpacing.md,
            ),
            child: Semantics(
              label: hidden
                  ? '${m.title}, ${m.count} payments, amount hidden'
                  : '${m.title}, ${m.count} payments, ${m.total.format()}',
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        border: Border.all(color: c.border),
                      ),
                      child: Text('${i + 1}', style: fp.text.caption),
                    ),
                    const SizedBox(width: FpSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: fp.text.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            m.count == 1 ? '1 payment' : '${m.count} payments',
                            style: fp.text.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: FpSpacing.md),
                    Text(
                      hidden ? FpAmountText.masked : m.total.format(),
                      style: fp.text.numeric,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return FpSkeletonGroup(
      child: Column(
        key: const ValueKey('stats-skeleton'),
        children: [
          const Row(
            children: [
              Expanded(child: FpSkeleton(height: 72)),
              SizedBox(width: FpSpacing.md),
              Expanded(child: FpSkeleton(height: 72)),
            ],
          ),
          const SizedBox(height: FpSpacing.md),
          const FpSkeleton(height: 200),
          const SizedBox(height: FpSpacing.md),
          const FpSkeleton(height: 160),
          const SizedBox(height: FpSpacing.md),
          for (var i = 0; i < 3; i++) ...[
            const FpSkeletonRow(),
            const SizedBox(height: FpSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _NoSpends extends StatelessWidget {
  const _NoSpends();

  @override
  Widget build(BuildContext context) {
    return const FpPulse(
      key: ValueKey('stats-empty'),
      maxScale: 1.03,
      child: FpEmptyState(
        icon: Icons.insights_outlined,
        title: 'No spends yet',
        message: 'Your charts fill in as you pay and receive money.',
      ),
    );
  }
}
