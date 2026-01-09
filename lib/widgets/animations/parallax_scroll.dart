import 'package:flutter/material.dart';

class ParallaxScroll extends StatelessWidget {
  final Widget child;
  final double parallaxFactor;

  const ParallaxScroll({
    super.key,
    required this.child,
    this.parallaxFactor = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    // Update parallax effect
                  }
                  return false;
                },
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class ParallaxWidget extends StatelessWidget {
  final Widget child;
  final ScrollController scrollController;
  final double parallaxFactor;

  const ParallaxWidget({
    super.key,
    required this.child,
    required this.scrollController,
    this.parallaxFactor = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final offset = scrollController.hasClients
            ? scrollController.offset * parallaxFactor
            : 0.0;

        return Transform.translate(
          offset: Offset(0, offset),
          child: child,
        );
      },
      child: child,
    );
  }
}

