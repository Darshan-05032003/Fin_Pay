import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/core/haptics/haptic_service.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/auth/widgets/inline_message.dart';
import 'package:fin_pay/screens/auth/widgets/secure_screen.dart';
import 'package:fin_pay/screens/cards/add_card/add_card_cubit.dart';
import 'package:fin_pay/screens/cards/add_card/card_validators.dart';
import 'package:fin_pay/screens/cards/widgets/payment_card_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// Add a card: a live preview that updates per keystroke (grouping,
/// network detection, flip to the back while the CVV is typed), inline
/// validation with shake and haptic, duplicate detection, and a single
/// submission through [CardBloc]. Screenshot-protected.
class AddCardScreen extends StatelessWidget {
  const AddCardScreen({super.key});

  static Clock _clock() =>
      GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>() : const Clock();

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: BlocProvider(
        create: (context) =>
            AddCardCubit(cards: context.read<CardBloc>(), clock: _clock()),
        child: const _AddCardView(),
      ),
    );
  }
}

class _AddCardView extends StatefulWidget {
  const _AddCardView();

  @override
  State<_AddCardView> createState() => _AddCardViewState();
}

class _AddCardViewState extends State<_AddCardView>
    with WidgetsBindingObserver {
  final FpShakeController _shake = FpShakeController();
  final FocusNode _name = FocusNode();
  final FocusNode _expiry = FocusNode();
  final FocusNode _cvv = FocusNode();
  final TextEditingController _cvvText = TextEditingController();
  final TextEditingController _numberText = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cvv.addListener(_onCvvFocus);
  }

  void _onCvvFocus() =>
      context.read<AddCardCubit>().cvvFocusChanged(focused: _cvv.hasFocus);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      context.read<AddCardCubit>().hideBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cvv.removeListener(_onCvvFocus);
    // Do not leave the typed secrets in controllers that outlive the screen.
    _cvvText
      ..clear()
      ..dispose();
    _numberText
      ..clear()
      ..dispose();
    _name.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.cards);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final cubit = context.read<AddCardCubit>();
    return BlocListener<AddCardCubit, AddCardState>(
      listenWhen: (p, n) => p.status != n.status || p.failures != n.failures,
      listener: (context, state) {
        switch (state.status) {
          case AddCardStatus.failure:
            _shake.shake();
            playHaptic(null, HapticType.error);
          case AddCardStatus.success:
            playHaptic(null, HapticType.success);
            FpToast.show(
              context,
              message: 'Card added',
              kind: FpToastKind.success,
            );
            _leave(context);
          case AddCardStatus.idle || AddCardStatus.submitting:
            break;
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: BlocBuilder<AddCardCubit, AddCardState>(
            builder: (context, state) {
              return ListView(
                key: const ValueKey('add-card-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
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
                        child: Text('Add a card', style: fp.text.headline),
                      ),
                    ],
                  ),
                  const SizedBox(height: FpSpacing.lg),
                  LiveCardPreview(
                    key: const ValueKey('add-card-preview'),
                    network: state.network,
                    number: state.previewNumber,
                    holder: state.name,
                    expiry: state.expiry,
                    cvvLength: state.cvvLength,
                    showBack: state.cvvFocused,
                  ),
                  const SizedBox(height: FpSpacing.xl),
                  FpShake(
                    controller: _shake,
                    child: FpStaggeredEntrance(
                      children: [
                        FpTextField(
                          key: const ValueKey('add-card-number'),
                          controller: _numberText,
                          label: 'Card number',
                          hint: '•••• •••• •••• ••••',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          inputFormatters: const [CardNumberInputFormatter()],
                          autofillHints: const [AutofillHints.creditCardNumber],
                          enableSuggestions: false,
                          autocorrect: false,
                          errorText: state.numberError,
                          helperText: state.network == CardNetwork.unknown
                              ? 'Visa, Mastercard or RuPay'
                              : '${state.network.label} detected',
                          prefix: const Icon(Icons.credit_card_outlined),
                          onChanged: cubit.numberChanged,
                          onSubmitted: (_) => _name.requestFocus(),
                        ),
                        const SizedBox(height: FpSpacing.lg),
                        FpTextField(
                          key: const ValueKey('add-card-name'),
                          label: 'Name on card',
                          hint: 'AS PRINTED ON THE CARD',
                          focusNode: _name,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: const [CardNameInputFormatter()],
                          autofillHints: const [AutofillHints.creditCardName],
                          errorText: state.nameError,
                          prefix: const Icon(Icons.person_outline),
                          onChanged: cubit.nameChanged,
                          onSubmitted: (_) => _expiry.requestFocus(),
                        ),
                        const SizedBox(height: FpSpacing.lg),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FpTextField(
                                key: const ValueKey('add-card-expiry'),
                                label: 'Expiry',
                                hint: 'MM/YY',
                                focusNode: _expiry,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                inputFormatters: const [ExpiryInputFormatter()],
                                autofillHints: const [
                                  AutofillHints.creditCardExpirationDate,
                                ],
                                enableSuggestions: false,
                                autocorrect: false,
                                errorText: state.expiryError,
                                onChanged: cubit.expiryChanged,
                                onSubmitted: (_) => _cvv.requestFocus(),
                              ),
                            ),
                            const SizedBox(width: FpSpacing.md),
                            Expanded(
                              child: FpTextField(
                                key: const ValueKey('add-card-cvv'),
                                controller: _cvvText,
                                label: 'CVV',
                                hint: '•••',
                                focusNode: _cvv,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                obscureText: true,
                                obscureToggle: false,
                                inputFormatters: const [
                                  DigitsInputFormatter(
                                    max: CardValidators.cvvLength + 1,
                                  ),
                                ],
                                // No autofill: the CVV must never be stored
                                // by a keyboard or password manager.
                                enableSuggestions: false,
                                autocorrect: false,
                                errorText: state.cvvError,
                                helperText: 'Never saved on your phone',
                                onChanged: cubit.cvvChanged,
                                onSubmitted: (_) => cubit.submit(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: FpSpacing.lg),
                  InlineMessage(
                    key: const ValueKey('add-card-message'),
                    message: state.message,
                  ),
                  FpButton(
                    key: const ValueKey('add-card-submit'),
                    label: 'Add card',
                    size: FpButtonSize.large,
                    isLoading: state.status == AddCardStatus.submitting,
                    enabled: state.canSubmit,
                    onPressed: cubit.submit,
                  ),
                  const SizedBox(height: FpSpacing.md),
                  Text(
                    'Your card number and CVV are kept in the device keystore, '
                    'never in the app database.',
                    style: fp.text.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
