import 'dart:async';

import 'package:fin_pay/blocs/notification/notification_bloc.dart';
import 'package:fin_pay/blocs/transaction/transaction_bloc.dart';
import 'package:fin_pay/blocs/user/user_bloc.dart';
import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/routes/transfer_draft.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:fin_pay/screens/auth/widgets/spring_rise.dart';
import 'package:fin_pay/screens/transfer/payment/payment_cubit.dart';
import 'package:fin_pay/screens/transfer/widgets/drawn_cross.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Review and pay: the summary rises on a spring, the swipe-to-pay slider
/// confirms, a processing panel with a ring covers the three phases, and
/// a failure view (cross draw + shake) offers Retry on the same idempotency
/// key or a way back. Screenshot-protected; back is blocked mid-payment.
class TransferReviewScreen extends StatelessWidget {
  const TransferReviewScreen({required this.draft, super.key});

  final TransferDraft draft;

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: BlocProvider(
        create: (context) => PaymentCubit(
          draft: draft,
          gateway: di.sl(),
          transactions: context.read<TransactionBloc>(),
          notifications: _maybe<NotificationBloc>(context),
          user: _maybe<UserBloc>(context),
          clock: di.sl(),
        ),
        child: const _ReviewView(),
      ),
    );
  }

  static T? _maybe<T extends StateStreamable<Object?>>(BuildContext context) {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _ReviewView extends StatefulWidget {
  const _ReviewView();

  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  final FpShakeController _shake = FpShakeController();

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _home(BuildContext context) => context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final cubit = context.read<PaymentCubit>();
    final draft = cubit.draft;
    return BlocListener<PaymentCubit, PaymentState>(
      listenWhen: (p, n) => p.phase != n.phase || p.attempts != n.attempts,
      listener: (context, state) {
        switch (state.phase) {
          case PaymentPhase.success:
            final receipt = cubit.receipt;
            if (receipt == null) return;
            context.pushReplacement(AppRoutes.transferSuccess, extra: receipt);
          case PaymentPhase.failure:
            _shake.shake();
            playHaptic(null, HapticType.error);
          case PaymentPhase.idle:
          case PaymentPhase.authorizing:
          case PaymentPhase.recording:
          case PaymentPhase.settling:
            break;
        }
      },
      child: BlocBuilder<PaymentCubit, PaymentState>(
        builder: (context, state) {
          final processing = state.isProcessing;
          return PopScope(
            canPop: !processing,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              FpToast.show(
                context,
                message: 'Payment in progress. Please wait.',
              );
            },
            child: Scaffold(
              backgroundColor: c.background,
              appBar: AppBar(
                backgroundColor: c.background,
                leading: FpPressable(
                  semanticLabel: 'Back',
                  enabled: !processing,
                  onPressed: () => _leave(context),
                  child: Icon(
                    Icons.arrow_back,
                    color: processing ? c.textDisabled : c.textPrimary,
                  ),
                ),
                title: Text(
                  state.phase == PaymentPhase.failure
                      ? 'Payment failed'
                      : 'Review',
                  style: fp.text.title,
                ),
              ),
              body: state.phase == PaymentPhase.failure
                  ? _FailureView(
                      key: const ValueKey('review-failure'),
                      shake: _shake,
                      failure: state.failure!,
                      attempts: state.attempts,
                      onRetry: () => unawaited(cubit.retry()),
                      onEdit: () => _leave(context),
                      onHome: () => _home(context),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: FpSpacing.lg,
                              vertical: FpSpacing.md,
                            ),
                            child: AnimatedSwitcher(
                              duration: fp.motion.standard,
                              switchInCurve: fp.motion.enter,
                              switchOutCurve: fp.motion.exit,
                              child: processing
                                  ? _ProcessingPanel(
                                      key: const ValueKey('review-processing'),
                                      label: state.phaseLabel,
                                      attempts: state.attempts,
                                    )
                                  : _Summary(
                                      key: const ValueKey('review-summary'),
                                      draft: draft,
                                    ),
                            ),
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              FpSpacing.lg,
                              FpSpacing.sm,
                              FpSpacing.lg,
                              FpSpacing.lg,
                            ),
                            child: FpSwipeToPay(
                              key: const ValueKey('review-swipe'),
                              label: 'Swipe to pay ${draft.amount.format()}',
                              processing: processing,
                              onConfirmed: cubit.pay,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.draft, super.key});

  final TransferDraft draft;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final contact = Contact(
      id: 'draft',
      name: draft.recipientName,
      vpa: draft.recipientAccount,
    );
    final note = draft.note;
    return SpringRise(
      child: FpSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  color: c.accent,
                  alignment: Alignment.center,
                  child: Text(
                    contact.initials,
                    style: fp.text.label.copyWith(color: c.onPop),
                  ),
                ),
                const SizedBox(width: FpSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYING',
                        style: fp.text.overline.copyWith(color: c.textTertiary),
                      ),
                      Text(
                        draft.recipientName,
                        style: fp.text.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        draft.recipientAccount,
                        style: fp.text.bodySmall.copyWith(
                          color: c.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: FpSpacing.xl),
            Center(
              child: FpAmountText(
                paise: draft.amount.paise,
                semanticLabel: 'Amount ${draft.amount.format()}',
              ),
            ),
            const SizedBox(height: FpSpacing.xl),
            if (note != null && note.isNotEmpty) ...[
              _Line(label: 'Note', value: note),
              Divider(color: c.border, height: FpSpacing.xl),
            ],
            _Line(label: 'Amount', value: draft.amount.format()),
            const SizedBox(height: FpSpacing.sm),
            const _Line(label: 'Fee', value: '₹0.00'),
            Divider(color: c.border, height: FpSpacing.xl),
            _Line(label: 'Total', value: draft.amount.format(), strong: true),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: fp.text.bodySmall.copyWith(
              color: strong ? c.textPrimary : c.textSecondary,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: strong ? fp.text.title : fp.text.numeric,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _ProcessingPanel extends StatelessWidget {
  const _ProcessingPanel({
    required this.label,
    required this.attempts,
    super.key,
  });

  final String label;
  final int attempts;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return FpSurface(
      child: Column(
        children: [
          const SizedBox(height: FpSpacing.lg),
          const FpProcessingRing(size: 96, strokeWidth: 6),
          const SizedBox(height: FpSpacing.xl),
          Semantics(
            liveRegion: true,
            child: Text(
              label,
              style: fp.text.title,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: FpSpacing.sm),
          Text(
            attempts > 1
                ? 'Checking with your bank before paying again.'
                : 'Keep the app open. This takes a moment.',
            style: fp.text.bodySmall.copyWith(color: c.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: FpSpacing.lg),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({
    required this.shake,
    required this.failure,
    required this.attempts,
    required this.onRetry,
    required this.onEdit,
    required this.onHome,
    super.key,
  });

  final FpShakeController shake;
  final PaymentFailure failure;
  final int attempts;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: FpSpacing.lg,
              vertical: FpSpacing.xl,
            ),
            child: FpShake(
              controller: shake,
              child: Column(
                children: [
                  DrawnCross(key: ValueKey('failure-cross-$attempts')),
                  const SizedBox(height: FpSpacing.xl),
                  Semantics(
                    liveRegion: true,
                    header: true,
                    child: Text(
                      failure.title,
                      style: fp.text.headline,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: FpSpacing.md),
                  Text(
                    failure.message,
                    style: fp.text.body.copyWith(color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (attempts > 1) ...[
                    const SizedBox(height: FpSpacing.sm),
                    Text(
                      'Attempt $attempts',
                      style: fp.text.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FpSpacing.lg,
              FpSpacing.sm,
              FpSpacing.lg,
              FpSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (failure.retryable)
                  FpButton(
                    key: const ValueKey('failure-retry'),
                    label: 'Retry',
                    onPressed: onRetry,
                  )
                else
                  FpButton(
                    key: const ValueKey('failure-edit'),
                    label: failure.canEditAmount
                        ? 'Edit amount'
                        : 'Edit payment',
                    onPressed: onEdit,
                  ),
                const SizedBox(height: FpSpacing.md),
                FpButton(
                  key: const ValueKey('failure-home'),
                  label: 'Back to home',
                  variant: FpButtonVariant.ghost,
                  onPressed: onHome,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
