import 'package:flutter/material.dart';

/// CRED-style page transition with scale and fade
class CredPageTransition<T> extends PageRouteBuilder<T> {
  CredPageTransition({
    required this.page,
    super.transitionDuration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         reverseTransitionDuration: const Duration(milliseconds: 250),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
             CurvedAnimation(
               parent: animation,
               curve: const Interval(0, 0.6, curve: Curves.easeOut),
             ),
           );

           final scaleAnimation = Tween<double>(begin: 0.96, end: 1).animate(
             CurvedAnimation(
               parent: animation,
               curve: const Interval(0, 0.8, curve: Curves.easeOutCubic),
             ),
           );

           final slideAnimation =
               Tween<Offset>(
                 begin: const Offset(0, 0.01),
                 end: Offset.zero,
               ).animate(
                 CurvedAnimation(
                   parent: animation,
                   curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
                 ),
               );

           return RepaintBoundary(
             child: FadeTransition(
               opacity: fadeAnimation,
               child: ScaleTransition(
                 scale: scaleAnimation,
                 child: SlideTransition(position: slideAnimation, child: child),
               ),
             ),
           );
         },
       );
  final Widget page;
  final Curve curve;
}
