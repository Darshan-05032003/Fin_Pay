import 'package:flutter/material.dart';

class ParallaxScroll extends StatelessWidget {

  const ParallaxScroll({
    required this.child, super.key,
    this.parallaxFactor = 0.5,
  });
  final Widget child;
  final double parallaxFactor;

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

  const ParallaxWidget({
    required this.child, required this.scrollController, super.key,
    this.parallaxFactor = 0.5,
  });
  final Widget child;
  final ScrollController scrollController;
  final double parallaxFactor;

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

