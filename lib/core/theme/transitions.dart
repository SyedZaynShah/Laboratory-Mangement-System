import 'package:flutter/material.dart';

class FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, c) {
        final dy = (1.0 - curved.value) * 8.0;
        return FadeTransition(
          opacity: fade,
          child: Transform.translate(offset: Offset(0, dy), child: c),
        );
      },
    );
  }
}

class NoPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
