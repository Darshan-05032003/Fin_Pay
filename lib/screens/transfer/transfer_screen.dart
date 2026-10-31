import 'dart:async';

import 'package:fin_pay/core/di/injection_container.dart' as di;
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/transfer/transfer/contact_search.dart';
import 'package:fin_pay/screens/transfer/transfer/transfer_cubit.dart';
import 'package:fin_pay/screens/transfer/transfer/transfer_rules.dart';
import 'package:fin_pay/screens/transfer/widgets/contact_avatar.dart';
import 'package:fin_pay/screens/transfer/widgets/transfer_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Send money: pick a payee (search, recently paid first, staggered
/// avatars), type the amount on the big keypad (per-digit roll), quick
/// chips, an optional note, and continue to the review with a fresh
/// idempotency key.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = TransferCubit(
          contacts: di.sl(),
          users: di.sl(),
          transactions: di.sl(),
          clock: di.sl(),
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _TransferView(),
    );
  }
}

class _TransferView extends StatefulWidget {
  const _TransferView();

  @override
  State<_TransferView> createState() => _TransferViewState();
}

class _TransferViewState extends State<_TransferView> {
  final FpShakeController _shake = FpShakeController();
  final TextEditingController _search = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _shake.dispose();
    _search.dispose();
    _note.dispose();
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

  Future<void> _paste(TransferCubit cubit) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text ?? '';
    // Never hand the parser an unbounded paste; the parser rejects it
    // anyway, but there is no reason to copy a megabyte around first.
    cubit.pasteAmount(text.length > 64 ? text.substring(0, 64) : text);
  }

  void _continue(BuildContext context, TransferCubit cubit) {
    final draft = cubit.createDraft();
    if (draft == null) return;
    unawaited(context.push(AppRoutes.transferReview, extra: draft));
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final cubit = context.read<TransferCubit>();
    return BlocListener<TransferCubit, TransferState>(
      listenWhen: (p, n) => p.shakes != n.shakes,
      listener: (context, state) {
        _shake.shake();
        playHaptic(null, HapticType.error);
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
          title: Text('Send money', style: fp.text.title),
        ),
        body: BlocBuilder<TransferCubit, TransferState>(
          builder: (context, state) => switch (state.status) {
            TransferStatus.loading => const _TransferSkeleton(),
            TransferStatus.error => FpErrorState(
              title: 'Could not load',
              message: state.message,
              onRetry: () => unawaited(cubit.load()),
            ),
            TransferStatus.content => _content(context, state, cubit),
          },
        ),
        bottomNavigationBar: BlocBuilder<TransferCubit, TransferState>(
          buildWhen: (p, n) => p.canContinue != n.canContinue,
          builder: (context, state) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                FpSpacing.lg,
                FpSpacing.sm,
                FpSpacing.lg,
                FpSpacing.lg,
              ),
              child: FpButton(
                key: const ValueKey('transfer-continue'),
                label: 'Continue',
                enabled: state.canContinue,
                onPressed: () => _continue(context, cubit),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    TransferState state,
    TransferCubit cubit,
  ) {
    final fp = context.fp;
    final c = fp.colors;
    final visible = state.visibleContacts;
    final amountLabel = FpAmountText.format(state.amount.paise);
    return ListView(
      key: const ValueKey('transfer-scroll'),
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: FpSpacing.lg),
      children: [
        Padding(
          padding: FpSpacing.page,
          child: FpTextField(
            key: const ValueKey('transfer-search'),
            controller: _search,
            hint: 'Search name or UPI ID',
            prefix: Icon(Icons.search, color: c.textTertiary),
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 64,
            onChanged: cubit.queryChanged,
            semanticLabel: 'Search contacts',
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        if (visible.isEmpty)
          Padding(
            padding: FpSpacing.page,
            child: Semantics(
              liveRegion: true,
              child: Text(
                'No contacts match "${state.query.trim()}"',
                key: const ValueKey('transfer-no-contacts'),
                style: fp.text.bodySmall,
              ),
            ),
          )
        else
          FpStaggeredEntrance(
            key: ValueKey('transfer-contacts-${state.query}'),
            offset: const Offset(24, 0),
            builder: (context, children) => SizedBox(
              height: 104,
              child: ListView(
                key: const ValueKey('transfer-contacts'),
                scrollDirection: Axis.horizontal,
                padding: FpSpacing.page,
                children: children,
              ),
            ),
            children: [
              for (final contact in visible)
                Padding(
                  padding: const EdgeInsets.only(right: FpSpacing.sm),
                  child: ContactAvatar(
                    key: ValueKey('contact-${contact.id}'),
                    contact: contact,
                    selected: contact.id == state.selectedId,
                    recent: ContactSearch.isRecent(
                      contact,
                      state.recentRecipients,
                    ),
                    onSelected: () => cubit.selectContact(contact.id),
                  ),
                ),
            ],
          ),
        const SizedBox(height: FpSpacing.lg),
        FpShake(
          controller: _shake,
          child: Padding(
            padding: FpSpacing.page,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AMOUNT',
                  style: fp.text.overline.copyWith(color: c.textTertiary),
                ),
                const SizedBox(height: FpSpacing.xs),
                Semantics(
                  label: 'Amount $amountLabel, long press to paste',
                  button: true,
                  onLongPress: () => unawaited(_paste(cubit)),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      key: const ValueKey('transfer-amount'),
                      behavior: HitTestBehavior.opaque,
                      onLongPress: () => unawaited(_paste(cubit)),
                      child: FpAmountText(
                        paise: state.amount.paise,
                        style: fp.text.displayLarge.copyWith(
                          color: state.amountError == null
                              ? c.textPrimary
                              : c.alert,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: FpSpacing.xs),
                Semantics(
                  liveRegion: true,
                  // One text whose style animates: a keyed switcher would
                  // collide with itself when the error flips faster than
                  // its transition (found by the 10k-key stress test).
                  child: AnimatedDefaultTextStyle(
                    duration: fp.motion.fast,
                    style: fp.text.caption.copyWith(
                      color: state.amountMessage == null
                          ? c.textTertiary
                          : c.alert,
                    ),
                    child: Text(
                      state.amountMessage ??
                          'Available ${state.balance.format()}',
                      key: const ValueKey('transfer-amount-message'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: FpSpacing.page,
            children: [
              for (final quick in AmountRules.quickAmounts)
                Padding(
                  padding: const EdgeInsets.only(right: FpSpacing.sm),
                  child: FpChip(
                    key: ValueKey('chip-${quick.paise}'),
                    label: _wholeRupees(quick.format()),
                    selected: state.amount.paise == quick.paise,
                    onSelected: (_) => cubit.quickAmount(quick),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        Padding(
          padding: FpSpacing.page,
          child: FpTextField(
            key: const ValueKey('transfer-note'),
            controller: _note,
            hint: 'Add a note (optional)',
            maxLength: TransferNote.maxLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: cubit.noteChanged,
            semanticLabel: 'Note',
          ),
        ),
        const SizedBox(height: FpSpacing.md),
        Padding(
          padding: FpSpacing.page,
          child: TransferKeypad(
            onDigit: cubit.digit,
            onDecimal: cubit.decimal,
            onBackspace: cubit.backspace,
            onClear: cubit.clearAmount,
          ),
        ),
      ],
    );
  }

  static String _wholeRupees(String formatted) => formatted.endsWith('.00')
      ? formatted.substring(0, formatted.length - 3)
      : formatted;
}

class _TransferSkeleton extends StatelessWidget {
  const _TransferSkeleton();

  @override
  Widget build(BuildContext context) {
    return FpSkeletonGroup(
      child: Padding(
        padding: FpSpacing.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: FpSpacing.sm),
            const FpSkeleton(height: 48),
            const SizedBox(height: FpSpacing.lg),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  const FpSkeleton.circle(size: ContactAvatar.size),
                  const SizedBox(width: FpSpacing.lg),
                ],
              ],
            ),
            const SizedBox(height: FpSpacing.xl),
            const FpSkeleton(width: 220, height: 56),
            const SizedBox(height: FpSpacing.lg),
            const FpSkeleton(height: 36),
          ],
        ),
      ),
    );
  }
}
