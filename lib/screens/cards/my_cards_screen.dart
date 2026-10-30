import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fin_pay/blocs/card/card_bloc.dart';
import 'package:fin_pay/blocs/card/card_event.dart';
import 'package:fin_pay/blocs/card/card_state.dart';
import 'package:fin_pay/core/platform/motion_sensor.dart';
import 'package:fin_pay/design_system/design_system.dart';
import 'package:fin_pay/domain/repositories/card_repository.dart';
import 'package:fin_pay/models/payment_card.dart';
import 'package:fin_pay/routes/app_routes.dart';
import 'package:fin_pay/screens/cards/add_card/card_validators.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_cubit.dart';
import 'package:fin_pay/screens/cards/stack/card_stack_view.dart';
import 'package:fin_pay/screens/cards/stack/cvv_reveal_cubit.dart';
import 'package:fin_pay/screens/cards/widgets/payment_card_art.dart';
import 'package:fin_pay/screens/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

/// The Cards tab: the CRED-style stack over [CardBloc], with loading,
/// empty and error states, and the way into add card and card details.
class MyCardsScreen extends StatelessWidget {
  const MyCardsScreen({super.key, this.motionSensor, this.cardRepository});

  /// Injected for tests; default to the GetIt registrations.
  final MotionSensor? motionSensor;
  final ICardRepository? cardRepository;

  /// Branch index of this tab in the shell.
  static const int tabIndex = 2;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CardStackCubit()),
        BlocProvider(
          create: (_) => CvvRevealCubit(
            repository: cardRepository ?? GetIt.I<ICardRepository>(),
            clock: GetIt.I.isRegistered<Clock>() ? GetIt.I<Clock>() : null,
          ),
        ),
      ],
      child: _MyCardsView(
        sensor:
            motionSensor ??
            (GetIt.I.isRegistered<MotionSensor>()
                ? GetIt.I<MotionSensor>()
                : null),
      ),
    );
  }
}

class _MyCardsView extends StatefulWidget {
  const _MyCardsView({required this.sensor});

  final MotionSensor? sensor;

  @override
  State<_MyCardsView> createState() => _MyCardsViewState();
}

class _MyCardsViewState extends State<_MyCardsView>
    with WidgetsBindingObserver {
  final FpTiltController _tilt = FpTiltController();
  StreamSubscription<Tilt>? _sensor;
  bool _sensorAvailable = false;
  bool _probed = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cards = context.read<CardBloc>();
    if (cards.state is CardInitial) cards.add(const LoadCardsEvent());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = AppShell.isVisibleTab(context, MyCardsScreen.tabIndex);
    final reduce = FpMotion.of(context).reduce;
    if (visible && !reduce) {
      unawaited(_listenToSensor());
    } else {
      _stopSensor();
    }
  }

  Future<void> _listenToSensor() async {
    final sensor = widget.sensor;
    if (sensor == null || _sensor != null) return;
    if (!_probed) {
      _probed = true;
      final available = await sensor.isAvailable;
      if (!mounted) return;
      setState(() => _sensorAvailable = available);
    }
    if (!_sensorAvailable || _sensor != null) return;
    _sensor = sensor.tilt.listen(
      (t) => _tilt.push(Offset(t.x, t.y)),
      onError: (Object _) => _stopSensor(),
    );
  }

  void _stopSensor() {
    unawaited(_sensor?.cancel());
    _sensor = null;
    _tilt.set(Offset.zero);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      // Never leave a CVV or a card back in the app switcher.
      context.read<CvvRevealCubit>().hide();
      context.read<CardStackCubit>().unflipAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSensor();
    _tilt.dispose();
    super.dispose();
  }

  void _openDetails(BuildContext context, PaymentCard card) {
    context.read<CvvRevealCubit>().hide();
    unawaited(context.push(AppRoutes.cardDetailsFor(card.id)));
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    final visible = AppShell.isVisibleTab(context, MyCardsScreen.tabIndex);
    return HeroMode(
      enabled: visible,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: BlocConsumer<CardBloc, CardState>(
            listener: (context, state) {
              final count = state is CardContent ? state.cards.length : 0;
              context.read<CardStackCubit>().cardsChanged(
                count,
                focusNewest: count > _lastCount && _lastCount > 0,
              );
              _lastCount = count;
            },
            builder: (context, state) {
              return CustomScrollView(
                key: const ValueKey('cards-scroll'),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      FpSpacing.lg,
                      FpSpacing.lg,
                      FpSpacing.lg,
                      FpSpacing.sm,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                'Your cards',
                                style: fp.text.headline,
                              ),
                            ),
                          ),
                          FpButton(
                            key: const ValueKey('cards-add'),
                            label: 'Add',
                            leadingIcon: Icons.add,
                            size: FpButtonSize.small,
                            variant: FpButtonVariant.secondary,
                            expand: false,
                            onPressed: () => context.push(AppRoutes.addCard),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      FpSpacing.lg,
                      FpSpacing.md,
                      FpSpacing.lg,
                      FpSpacing.xxxl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: switch (state) {
                        CardInitial() ||
                        CardLoading() => const _CardsSkeleton(),
                        CardError(:final message) => FpErrorState(
                          key: const ValueKey('cards-error'),
                          title: 'Could not load your cards',
                          message: message,
                          onRetry: () => context.read<CardBloc>().add(
                            const LoadCardsEvent(),
                          ),
                        ),
                        CardEmpty() => FpEmptyState(
                          key: const ValueKey('cards-empty'),
                          icon: Icons.credit_card_outlined,
                          title: 'No cards yet',
                          message: 'Add a debit or credit card to pay from it.',
                          actionLabel: 'Add a card',
                          onAction: () => context.push(AppRoutes.addCard),
                        ),
                        CardContent(:final cards) => _CardsContent(
                          cards: cards,
                          tilt: _tilt,
                          sensorAvailable: _sensorAvailable,
                          onOpenDetails: (card) => _openDetails(context, card),
                        ),
                      },
                    ),
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

class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const FpSkeletonGroup(
      key: ValueKey('cards-loading'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: PaymentCardArt.aspectRatio,
            child: FpSkeleton(height: double.infinity),
          ),
          SizedBox(height: FpSpacing.lg),
          FpSkeletonRow(),
        ],
      ),
    );
  }
}

String _pileHint(int count) =>
    '$count ${count == 1 ? 'card' : 'cards'} · tap the pile to fan out';

class _CardsContent extends StatelessWidget {
  const _CardsContent({
    required this.cards,
    required this.tilt,
    required this.sensorAvailable,
    required this.onOpenDetails,
  });

  final List<PaymentCard> cards;
  final FpTiltController tilt;
  final bool sensorAvailable;
  final ValueChanged<PaymentCard> onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final c = fp.colors;
    return BlocBuilder<CardStackCubit, CardStackState>(
      builder: (context, stack) {
        final cubit = context.read<CardStackCubit>();
        final focused = cards[stack.focused.clamp(0, cards.length - 1)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    stack.fanned
                        ? 'Swipe to browse, tap to flip'
                        : _pileHint(cards.length),
                    style: fp.text.bodySmall,
                  ),
                ),
                if (stack.fanned)
                  FpButton(
                    key: const ValueKey('cards-collapse'),
                    label: 'Stack',
                    variant: FpButtonVariant.ghost,
                    size: FpButtonSize.small,
                    expand: false,
                    onPressed: cubit.collapse,
                  ),
              ],
            ),
            const SizedBox(height: FpSpacing.md),
            CardStackView(
              cards: cards,
              tilt: tilt,
              sensorAvailable: sensorAvailable,
              onOpenDetails: onOpenDetails,
            ),
            const SizedBox(height: FpSpacing.xl),
            FpEntrance(
              key: ValueKey('focused-summary-${focused.id}'),
              child: FpSurface(
                key: const ValueKey('cards-focused-summary'),
                variant: FpSurfaceVariant.raised,
                semanticLabel:
                    '${PaymentCardArt.describe(focused)}. Open details',
                onTap: () => onOpenDetails(focused),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${CardNetwork.forType(focused.cardType).label}'
                            ' · ${focused.last4}',
                            style: fp.text.title,
                          ),
                          const SizedBox(height: FpSpacing.xs),
                          Text(
                            'Expires ${focused.expireDate} · '
                            '${focused.cardHolderName}',
                            style: fp.text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
