import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:fin_pay/services/haptic_service.dart';
import 'package:flutter/material.dart';

class CelebratoryAnimation extends StatefulWidget {

  const CelebratoryAnimation({
    required this.child, required this.title, required this.icon, super.key,
    this.subtitle,
    this.color = Colors.green,
    this.onComplete,
  });
  final Widget child;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onComplete;

  @override
  State<CelebratoryAnimation> createState() => _CelebratoryAnimationState();
}

class _CelebratoryAnimationState extends State<CelebratoryAnimation>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.easeInOut),
    );

    _startCelebration();
  }

  Future<void> _startCelebration() async {
    await HapticService.success();
    _confettiController.play();
    _scaleController.forward();
    _rotationController.repeat();
    
    await Future.delayed(const Duration(milliseconds: 800));
    _rotationController.stop();
    _rotationController.reset();
    
    await Future.delayed(const Duration(seconds: 3));
    widget.onComplete?.call();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: math.pi / 2,
            maxBlastForce: 25,
            minBlastForce: 10,
            emissionFrequency: 0.05,
            numberOfParticles: 60,
            gravity: 0.3,
            colors: [
              widget.color,
              widget.color.withOpacity(0.7),
              Colors.white,
              Colors.yellow,
              Colors.orange,
            ],
          ),
        ),
        Align(
          child: AnimatedBuilder(
            animation: Listenable.merge([_scaleAnimation, _rotationAnimation]),
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      size: 80,
                      color: widget.color,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

