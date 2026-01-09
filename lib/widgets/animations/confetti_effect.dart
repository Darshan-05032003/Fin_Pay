import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;

class ConfettiEffect extends StatefulWidget {
  final Widget child;
  final bool autoPlay;
  final Duration duration;

  const ConfettiEffect({
    super.key,
    required this.child,
    this.autoPlay = false,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<ConfettiEffect> createState() => _ConfettiEffectState();
}

class _ConfettiEffectState extends State<ConfettiEffect> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: widget.duration);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.play();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void play() {
    _controller.play();
  }

  void stop() {
    _controller.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: math.pi / 2,
            maxBlastForce: 20,
            minBlastForce: 5,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.3,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.red,
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: -math.pi / 2,
            maxBlastForce: 20,
            minBlastForce: 5,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.3,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
              Colors.red,
            ],
          ),
        ),
      ],
    );
  }
}

