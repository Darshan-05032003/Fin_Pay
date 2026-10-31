import 'dart:math' as math;

import 'package:fin_pay/core/money/money.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/screens/statistics/stats_math.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Chart height shared by the bar and line cards.
const double kStatsChartHeight = 180;

String _amount(Money money, {required bool hidden}) =>
    hidden ? FpAmountText.masked : money.format();

/// Spend (accent) and received (success) per bucket. The bars grow with
/// [reveal]; tapping a bar shows a tooltip above the chart (tap again or
/// elsewhere to hide it).
class StatsBarChart extends StatefulWidget {
  const StatsBarChart({
    required this.buckets,
    required this.reveal,
    required this.hidden,
    super.key,
  });

  final List<StatsBucket> buckets;
  final Animation<double> reveal;
  final bool hidden;

  @override
  State<StatsBarChart> createState() => _StatsBarChartState();
}

class _StatsBarChartState extends State<StatsBarChart> {
  int? _selected;

  void _onTouch(FlTouchEvent event, BarTouchResponse? response) {
    if (event is! FlTapUpEvent) return;
    final index = response?.spot?.touchedBarGroupIndex;
    setState(() => _selected = index == _selected ? null : index);
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final buckets = widget.buckets;
    final peak = math.max(1, StatsMath.rupees(StatsMath.peak(buckets)));
    final selected = _selected;
    final bucket = selected == null || selected >= buckets.length
        ? null
        : buckets[selected];
    final labelEvery = buckets.length > 7 ? 2 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: bucket == null
              ? Center(
                  child: Text('Tap a bar to inspect', style: fp.text.caption),
                )
              : FpSurface(
                  key: const ValueKey('stats-tooltip'),
                  variant: FpSurfaceVariant.raised,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FpSpacing.md,
                    vertical: FpSpacing.sm,
                  ),
                  child: Text(
                    '${bucket.label}: spent '
                    '${_amount(bucket.spend, hidden: widget.hidden)}, '
                    'received '
                    '${_amount(bucket.income, hidden: widget.hidden)}',
                    style: fp.text.bodySmall.copyWith(color: c.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
        ),
        const SizedBox(height: FpSpacing.sm),
        Semantics(
          label: _barsLabel(buckets),
          child: ExcludeSemantics(
            child: SizedBox(
              height: kStatsChartHeight,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: widget.reveal,
                  builder: (context, _) {
                    final t = widget.reveal.value;
                    return BarChart(
                      BarChartData(
                        maxY: peak * 1.1,
                        minY: 0,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          handleBuiltInTouches: false,
                          touchCallback: _onTouch,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                          topTitles: const AxisTitles(),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 ||
                                    i >= buckets.length ||
                                    i % labelEvery != 0) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: FpSpacing.xs,
                                  ),
                                  child: Text(
                                    buckets[i].label,
                                    style: fp.text.caption,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (final (i, b) in buckets.indexed)
                            BarChartGroupData(
                              x: i,
                              barsSpace: 2,
                              barRods: [
                                BarChartRodData(
                                  toY: StatsMath.rupees(b.spend) * t,
                                  width: buckets.length > 7 ? 6 : 10,
                                  color: i == selected ? c.popWhite : c.accent,
                                  borderRadius: BorderRadius.zero,
                                ),
                                BarChartRodData(
                                  toY: StatsMath.rupees(b.income) * t,
                                  width: buckets.length > 7 ? 6 : 10,
                                  color: i == selected ? c.popWhite : c.success,
                                  borderRadius: BorderRadius.zero,
                                ),
                              ],
                            ),
                        ],
                      ),
                      duration: Duration.zero,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: FpSpacing.sm),
        Row(
          children: [
            _LegendDot(color: c.accent, label: 'Spent'),
            const SizedBox(width: FpSpacing.lg),
            _LegendDot(color: c.success, label: 'Received'),
          ],
        ),
      ],
    );
  }

  String _barsLabel(List<StatsBucket> buckets) {
    final parts = [
      for (final b in buckets)
        '${b.label} spent ${_amount(b.spend, hidden: widget.hidden)}',
    ];
    return 'Bar chart: ${parts.join(', ')}';
  }
}

/// Daily spend as a line that draws on from the left with [reveal]; the
/// built-in tooltip shows the day and the amount.
class StatsLineChart extends StatelessWidget {
  const StatsLineChart({
    required this.series,
    required this.reveal,
    required this.hidden,
    super.key,
  });

  final List<StatsPoint> series;
  final Animation<double> reveal;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    var peak = 0.0;
    for (final p in series) {
      peak = math.max(peak, StatsMath.rupees(p.spend));
    }
    final maxY = math.max(1, peak) * 1.15;
    final spots = [
      for (final (i, p) in series.indexed)
        FlSpot(i.toDouble(), StatsMath.rupees(p.spend)),
    ];
    final total = series.fold(Money.zero, (sum, p) => sum + p.spend);
    return Semantics(
      label:
          'Line chart: ${series.length} days, total spend '
          '${_amount(total, hidden: hidden)}',
      child: ExcludeSemantics(
        child: SizedBox(
          height: kStatsChartHeight,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: reveal,
              builder: (context, child) =>
                  ClipRect(clipper: _RevealClipper(reveal.value), child: child),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: math.max(1, series.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => c.surfaceHigh,
                      tooltipBorder: BorderSide(color: c.borderStrong),
                      getTooltipItems: (touched) => [
                        for (final s in touched)
                          LineTooltipItem(
                            _pointLabel(s.x.toInt()),
                            fp.text.caption.copyWith(color: c.textPrimary),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: series.length <= 31,
                      preventCurveOverShooting: true,
                      color: c.accent,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: c.accent.withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                ),
                duration: Duration.zero,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _pointLabel(int index) {
    if (index < 0 || index >= series.length) return '';
    final p = series[index];
    return '${DateFormat('d MMM').format(p.day)}\n'
        '${_amount(p.spend, hidden: hidden)}';
  }
}

/// Clips to the left [fraction] of the child (the line "draws on").
class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction.clamp(0.0, 1.0), size.height);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

/// Category shares as a donut that sweeps clockwise with [reveal], with a
/// legend listing label and share.
class StatsDonutChart extends StatelessWidget {
  const StatsDonutChart({
    required this.categories,
    required this.reveal,
    required this.hidden,
    super.key,
  });

  final List<StatsCategory> categories;
  final Animation<double> reveal;
  final bool hidden;

  /// Slice colours, in legend order.
  static List<Color> palette(FpColorScheme c) => [
    c.accent,
    c.success,
    c.info,
    c.popWhite,
    c.textSecondary,
    c.alert,
  ];

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final colors = palette(c);
    if (categories.isEmpty) {
      return Text('No spends in this period.', style: fp.text.bodySmall);
    }
    final shares = categories.map((cat) => cat.share).toList();
    return Semantics(
      label:
          'Donut chart: ${categories.map((cat) => '${cat.label} '
              '${(cat.share * 100).round()} percent').join(', ')}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: reveal,
                  builder: (context, _) {
                    final t = reveal.value.clamp(0.0, 1.0);
                    return PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        pieTouchData: PieTouchData(enabled: false),
                        sections: [
                          for (final (i, share) in shares.indexed)
                            PieChartSectionData(
                              value: math.max(share * t, 0.0001),
                              color: colors[i % colors.length],
                              radius: 22,
                              showTitle: false,
                            ),
                          if (t < 1)
                            PieChartSectionData(
                              value: 1 - t,
                              color: c.surface,
                              radius: 22,
                              showTitle: false,
                            ),
                        ],
                      ),
                      duration: Duration.zero,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: FpSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, cat) in categories.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: FpSpacing.xs),
                      child: Row(
                        children: [
                          _LegendDot(
                            color: colors[i % colors.length],
                            label: cat.label,
                          ),
                          const Spacer(),
                          Text(
                            '${(cat.share * 100).round()}%',
                            style: fp.text.caption.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: FpSpacing.sm),
        Text(label, style: fp.text.caption, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}
