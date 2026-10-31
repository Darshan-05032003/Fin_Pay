import 'dart:async';

import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:fin_pay/screens/transfer/payment/payment_receipt.dart';
import 'package:fin_pay/screens/transfer/widgets/receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Payment sent: drawn check, confetti burst and success haptic once the
/// check completes, the amount counting up on the odometer, the receipt
/// and "Share receipt" (copies a masked plain-text receipt). Back and
/// Done both go home; the payment can never be resubmitted from here.
class TransferSuccessScreen extends StatefulWidget {
  const TransferSuccessScreen({required this.receipt, super.key});

  final PaymentReceipt receipt;

  @override
  State<TransferSuccessScreen> createState() => _TransferSuccessScreenState();
}

class _TransferSuccessScreenState extends State<TransferSuccessScreen> {
  final FpConfettiController _confetti = FpConfettiController();
  bool _celebrated = false;

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _onCheckDrawn() {
    if (_celebrated) return;
    _celebrated = true;
    _confetti.burst();
    playHaptic(null, HapticType.success);
  }

  void _home(BuildContext context) => context.go(AppRoutes.home);

  Future<void> _share(BuildContext context) async {
    final text = widget.receipt.shareText();
    await FpBottomSheet.show<void>(
      context,
      title: 'Receipt',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FpSurface(
            variant: FpSurfaceVariant.flat,
            child: SelectableText(
              text,
              key: const ValueKey('receipt-share-text'),
              style: sheetContext.fp.text.bodySmall,
            ),
          ),
          const SizedBox(height: FpSpacing.lg),
          FpButton(
            key: const ValueKey('receipt-copy'),
            label: 'Copy receipt',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (!context.mounted) return;
              FpToast.show(
                context,
                message: 'Receipt copied',
                kind: FpToastKind.success,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final receipt = widget.receipt;
    return SecureScreen(
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _home(context);
        },
        child: Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FpSpacing.lg,
                      vertical: FpSpacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: FpConfetti(
                            controller: _confetti,
                            child: FpDrawnCheck(
                              key: const ValueKey('success-check'),
                              size: 112,
                              onCompleted: _onCheckDrawn,
                              semanticLabel: receipt.alreadyPaid
                                  ? 'Already paid'
                                  : 'Payment sent',
                            ),
                          ),
                        ),
                        const SizedBox(height: FpSpacing.xl),
                        FpEntrance(
                          delay: FpMotion.fast,
                          child: Column(
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  receipt.alreadyPaid
                                      ? 'Already paid'
                                      : 'Payment sent',
                                  style: fp.text.headline,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: FpSpacing.sm),
                              FpAmountText(
                                key: const ValueKey('success-amount'),
                                paise: receipt.draft.amount.paise,
                                animateFirstBuild: true,
                                style: fp.text.displayLarge,
                                semanticLabel:
                                    'Amount ${receipt.draft.amount.format()}',
                              ),
                              const SizedBox(height: FpSpacing.xs),
                              Text(
                                'to ${receipt.draft.recipientName}',
                                style: fp.text.body.copyWith(
                                  color: c.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: FpSpacing.xl),
                        FpEntrance(
                          delay: FpMotion.standard,
                          child: ReceiptCard(receipt: receipt),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FpSpacing.lg,
                    FpSpacing.sm,
                    FpSpacing.lg,
                    FpSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FpButton(
                        key: const ValueKey('success-share'),
                        label: 'Share receipt',
                        variant: FpButtonVariant.secondary,
                        leadingIcon: Icons.ios_share,
                        onPressed: () => _share(context),
                      ),
                      const SizedBox(height: FpSpacing.md),
                      FpButton(
                        key: const ValueKey('success-done'),
                        label: 'Done',
                        onPressed: () => _home(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
