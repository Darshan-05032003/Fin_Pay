import 'dart:ui' as ui;

import 'package:fin_pay/design_system/motion/fp_staggered_entrance.dart';
import 'package:fin_pay/design_system/theme/fp_tokens.dart';
import 'package:fin_pay/design_system/tokens/fp_motion.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

/// One character position of an odometer transition.
@immutable
class FpDigitRoll {
  const FpDigitRoll(this.steps);

  /// The characters shown at this position, first to last. A single element
  /// means the position does not move. An empty string is a blank cell (the
  /// position did not exist before).
  final List<String> steps;

  /// The character shown when the roll has finished.
  String get end => steps.last;

  /// The character shown before the roll starts.
  String get start => steps.first;

  bool get isStatic => steps.length == 1;

  @override
  bool operator ==(Object other) =>
      other is FpDigitRoll &&
      other.steps.length == steps.length &&
      _listEquals(other.steps, steps);

  @override
  int get hashCode => Object.hashAll(steps);

  @override
  String toString() => 'FpDigitRoll(${steps.join(' → ')})';

  static bool _listEquals(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Pure odometer planning. Unit-tested on its own.
class FpOdometer {
  const FpOdometer._();

  static bool _isDigit(String ch) =>
      ch.length == 1 && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;

  /// Compares the numeric magnitude of two strings by their digits only.
  /// Returns true when [to] is at least as large as [from].
  static bool ascending(String from, String to) {
    final a = from
        .replaceAll(RegExp('[^0-9]'), '')
        .replaceFirst(RegExp('^0+(?=.)'), '');
    final b = to
        .replaceAll(RegExp('[^0-9]'), '')
        .replaceFirst(RegExp('^0+(?=.)'), '');
    if (a.length != b.length) return b.length > a.length;
    return b.compareTo(a) >= 0;
  }

  /// Right-aligns [from] under [to] and returns one roll per position of the
  /// longer string. Digits roll in the direction of the overall change,
  /// wrapping through 9 → 0 (or 0 → 9); other characters cross-fade.
  static List<FpDigitRoll> plan(String from, String to) {
    final fromChars = from.characters.toList();
    final toChars = to.characters.toList();
    final n = fromChars.length > toChars.length
        ? fromChars.length
        : toChars.length;
    final up = ascending(from, to);
    final rolls = <FpDigitRoll>[];
    for (var i = 0; i < n; i++) {
      final fi = i - (n - fromChars.length);
      final ti = i - (n - toChars.length);
      final f = fi >= 0 ? fromChars[fi] : '';
      final t = ti >= 0 ? toChars[ti] : '';
      if (f == t) {
        rolls.add(FpDigitRoll([t]));
      } else if (_isDigit(f) && _isDigit(t)) {
        rolls.add(FpDigitRoll(_digitSteps(int.parse(f), int.parse(t), up)));
      } else {
        rolls.add(FpDigitRoll([f, t]));
      }
    }
    return rolls;
  }

  static List<String> _digitSteps(int a, int b, bool up) {
    final steps = <String>['$a'];
    var d = a;
    while (d != b) {
      d = up ? (d + 1) % 10 : (d + 9) % 10;
      steps.add('$d');
    }
    return steps;
  }
}

/// How a hidden amount is rendered.
enum FpAmountHide {
  /// Fully visible.
  none,

  /// Replaced by a fixed row of dots (default: leaks nothing, costs nothing).
  mask,

  /// The real digits behind a blur (reveals magnitude; one `saveLayer`).
  blur,
}

/// Rupee amount with a rolling odometer. Money is `int` paise.
///
/// Every character sits in its own fixed-width cell (so widths never
/// jitter) and rolls through the digits between the old and new value with a
/// small stagger from the right. Handles the full range up to
/// ₹99,99,99,999.99. With reduced motion the value changes instantly.
class FpAmountText extends StatefulWidget {
  const FpAmountText({
    required this.paise,
    super.key,
    this.style,
    this.hide = FpAmountHide.none,
    this.animateFirstBuild = false,
    this.semanticLabel,
    this.maxTextScale = 1.3,
    this.rollDuration = FpMotion.standard,
  });

  /// Amount in paise (₹1.00 = 100).
  final int paise;

  /// Defaults to the display-medium token.
  final TextStyle? style;
  final FpAmountHide hide;

  /// Count up from ₹0.00 on first build (home balance).
  final bool animateFirstBuild;
  final String? semanticLabel;

  /// Text scaling is clamped to this factor so very large amounts fit.
  final double maxTextScale;

  /// Duration of one position's roll (the stagger adds up to 200 ms).
  final Duration rollDuration;

  /// Formats [paise] as `₹1,23,456.78` (Indian grouping, `en_IN`).
  static String format(int paise) {
    final negative = paise < 0;
    final abs = paise.abs();
    final rupees = abs ~/ 100;
    final cents = abs % 100;
    final grouped = NumberFormat('#,##,##0', 'en_IN').format(rupees);
    final body = '₹$grouped.${cents.toString().padLeft(2, '0')}';
    return negative ? '-$body' : body;
  }

  /// The masked rendering.
  static const String masked = '₹••••••';

  @override
  State<FpAmountText> createState() => _FpAmountTextState();
}

class _FpAmountTextState extends State<FpAmountText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.rollDuration,
    value: 1,
  );
  late List<FpDigitRoll> _plan;
  late List<Interval> _intervals;
  late String _shown;

  static const Duration _staggerStep = Duration(milliseconds: 30);
  static const Duration _staggerCap = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _shown = FpAmountText.format(widget.paise);
    _setPlan(
      widget.animateFirstBuild ? FpAmountText.format(0) : _shown,
      _shown,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animateFirstBuild && _controller.value == 0) {
      _start();
    }
  }

  @override
  void didUpdateWidget(FpAmountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paise != widget.paise) {
      final next = FpAmountText.format(widget.paise);
      _setPlan(_shown, next);
      _shown = next;
      _start();
    }
  }

  void _setPlan(String from, String to) {
    _plan = FpOdometer.plan(from, to);
    final n = _plan.length;
    // Stagger from the rightmost position.
    final delays = FpStagger.delays(n, step: _staggerStep, cap: _staggerCap);
    final total =
        widget.rollDuration + (delays.isEmpty ? Duration.zero : delays.last);
    _controller.duration = total;
    final totalUs = total.inMicroseconds.toDouble();
    _intervals = List.generate(n, (i) {
      final delay = delays[n - 1 - i].inMicroseconds;
      final start = delay / totalUs;
      final end = (delay + widget.rollDuration.inMicroseconds) / totalUs;
      return Interval(
        start.clamp(0, 1),
        end.clamp(0, 1),
        curve: FpMotion.emphasizedDecelerate,
      );
    });
    _controller.value = 0;
  }

  void _start() {
    if (FpMotion.of(context).reduce) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fp = context.fp;
    final style = widget.style ?? fp.text.displayMedium;
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: widget.maxTextScale);
    final hidden = widget.hide == FpAmountHide.mask;

    Widget odometer = _Odometer(
      plan: _plan,
      intervals: _intervals,
      controller: _controller,
      style: style,
      scaler: scaler,
    );
    if (widget.hide == FpAmountHide.blur) {
      odometer = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: odometer,
      );
    }

    final reduce = FpMotion.of(context).reduce;
    return Semantics(
      container: true,
      liveRegion: true,
      label: hidden || widget.hide == FpAmountHide.blur
          ? (widget.semanticLabel ?? 'Amount hidden')
          : (widget.semanticLabel ?? _shown),
      child: ExcludeSemantics(
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : FpMotion.standard,
          child: hidden
              ? Text(
                  FpAmountText.masked,
                  key: const ValueKey('fp-amount-masked'),
                  style: style,
                  textScaler: scaler,
                  maxLines: 1,
                )
              : KeyedSubtree(
                  key: const ValueKey('fp-amount-odometer'),
                  child: odometer,
                ),
        ),
      ),
    );
  }
}

class _Odometer extends StatelessWidget {
  const _Odometer({
    required this.plan,
    required this.intervals,
    required this.controller,
    required this.style,
    required this.scaler,
  });

  final List<FpDigitRoll> plan;
  final List<Interval> intervals;
  final AnimationController controller;
  final TextStyle style;
  final TextScaler scaler;

  Size _measure(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final digitSize = _measure('0');
    var digitWidth = digitSize.width;
    for (var d = 1; d <= 9; d++) {
      final w = _measure('$d').width;
      if (w > digitWidth) digitWidth = w;
    }
    final lineHeight = digitSize.height;

    return RepaintBoundary(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          for (var i = 0; i < plan.length; i++)
            _DigitCell(
              roll: plan[i],
              controller: controller,
              curve: intervals[i],
              width:
                  plan[i].steps.every(
                    (s) => s.isEmpty || FpOdometer._isDigit(s),
                  )
                  ? digitWidth
                  : _measure(
                      plan[i].end.isEmpty ? plan[i].start : plan[i].end,
                    ).width,
              height: lineHeight,
              style: style,
              scaler: scaler,
            ),
        ],
      ),
    );
  }
}

class _DigitCell extends StatelessWidget {
  const _DigitCell({
    required this.roll,
    required this.controller,
    required this.curve,
    required this.width,
    required this.height,
    required this.style,
    required this.scaler,
  });

  final FpDigitRoll roll;
  final AnimationController controller;
  final Curve curve;
  final double width;
  final double height;
  final TextStyle style;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    if (roll.isStatic) {
      return SizedBox(
        width: width,
        height: height,
        child: Text(
          roll.end,
          style: style,
          textScaler: scaler,
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
      );
    }
    final steps = roll.steps;
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = curve.transform(controller.value.clamp(0.0, 1.0));
            final offset = -t * (steps.length - 1) * height;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var s = 0; s < steps.length; s++)
                  Positioned(
                    top: offset + s * height,
                    left: 0,
                    width: width,
                    height: height,
                    child: Text(
                      steps[s],
                      style: style,
                      textScaler: scaler,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
