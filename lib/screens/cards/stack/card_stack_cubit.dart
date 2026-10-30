import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// UI state of the card stack: pile or fanned carousel, which card is in
/// front, and which cards show their back.
class CardStackState extends Equatable {
  const CardStackState({
    this.fanned = false,
    this.focused = 0,
    this.flipped = const {},
    this.count = 0,
  });

  final bool fanned;

  /// Index of the card on top of the pile / centred in the carousel.
  final int focused;

  /// Ids of the cards currently showing their back.
  final Set<String> flipped;

  /// Number of cards the stack was last told about.
  final int count;

  bool isFlipped(String id) => flipped.contains(id);

  CardStackState copyWith({
    bool? fanned,
    int? focused,
    Set<String>? flipped,
    int? count,
  }) => CardStackState(
    fanned: fanned ?? this.fanned,
    focused: focused ?? this.focused,
    flipped: flipped ?? this.flipped,
    count: count ?? this.count,
  );

  @override
  List<Object?> get props => [fanned, focused, flipped, count];
}

/// Drives the card stack. Pure UI state: nothing here touches storage.
class CardStackCubit extends Cubit<CardStackState> {
  CardStackCubit() : super(const CardStackState());

  /// Tells the stack how many cards there are (clamps the focus; a new
  /// card at index 0 becomes the focused, fanned card).
  void cardsChanged(int count, {bool focusNewest = false}) {
    if (count <= 0) {
      emit(const CardStackState());
      return;
    }
    final focused = focusNewest && count > state.count
        ? 0
        : state.focused.clamp(0, count - 1);
    emit(
      state.copyWith(
        count: count,
        focused: focused,
        fanned: state.fanned || (focusNewest && count > state.count),
      ),
    );
  }

  /// Tap on the pile: fans the cards out.
  void fanOut() {
    if (!state.fanned) emit(state.copyWith(fanned: true));
  }

  /// Back to the pile; every card shows its front again.
  void collapse() {
    if (state.fanned || state.flipped.isNotEmpty) {
      emit(state.copyWith(fanned: false, flipped: const {}));
    }
  }

  void toggle() => state.fanned ? collapse() : fanOut();

  /// The carousel settled on [index]; cards that are no longer in front
  /// turn back over.
  void focus(int index) {
    if (state.count == 0) return;
    final i = index.clamp(0, state.count - 1);
    if (i == state.focused) return;
    emit(state.copyWith(focused: i, flipped: const {}));
  }

  void flip(String id) {
    final next = {...state.flipped};
    if (!next.remove(id)) next.add(id);
    emit(state.copyWith(flipped: next));
  }

  /// Turns every card to its front (the app went to the background).
  void unflipAll() {
    if (state.flipped.isNotEmpty) emit(state.copyWith(flipped: const {}));
  }
}
