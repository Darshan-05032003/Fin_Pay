import 'package:clock/clock.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';

/// One transaction in a list: a glyph for the type, the title, when it
/// happened, and the signed amount (credits in the success colour).
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    required this.transaction,
    super.key,
    this.onTap,
    this.hideAmount = false,
    this.now,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  /// Masks the amount (hide-balance setting).
  final bool hideAmount;

  /// "Now" for the relative date; defaults to the injected `Clock`.
  final DateTime? now;

  static DateTime _now() =>
      GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>().now() : clock.now();

  /// Relative day label: Today, Yesterday, or `d MMM`.
  static String dayLabel(DateTime local, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM').format(local);
  }

  static IconData iconFor(TransactionType type) => switch (type) {
    TransactionType.payment => Icons.shopping_bag_outlined,
    TransactionType.sendMoney => Icons.north_east,
    TransactionType.receiveMoney => Icons.south_west,
    TransactionType.topUp => Icons.add_card_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final t = transaction;
    final local = t.localDate;
    final when =
        '${dayLabel(local, now ?? _now())}, '
        '${DateFormat('HH:mm').format(local)}';
    final credit = t.isCredit;
    final amountText = hideAmount
        ? FpAmountText.masked
        : '${credit ? '+' : '−'}${t.amount.abs().format()}';
    final label =
        '${t.title}, $when, ${hideAmount ? 'amount hidden' : amountText}';
    return FpSurface(
      variant: FpSurfaceVariant.flat,
      padding: const EdgeInsets.symmetric(
        horizontal: FpSpacing.md,
        vertical: FpSpacing.md,
      ),
      semanticLabel: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                border: Border.all(color: c.border),
              ),
              child: Icon(
                iconFor(t.type),
                size: 20,
                color: credit ? c.success : c.textSecondary,
              ),
            ),
            const SizedBox(width: FpSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: fp.text.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: FpSpacing.xs),
                  Text(when, style: fp.text.caption, maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: FpSpacing.md),
            Text(
              amountText,
              style: fp.text.numeric.copyWith(
                color: credit ? c.success : c.textPrimary,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
