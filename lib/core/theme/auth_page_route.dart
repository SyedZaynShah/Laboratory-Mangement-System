import 'package:flutter/material.dart';

class AuthPageRoute<T> extends PageRouteBuilder<T> {
  AuthPageRoute({
    required WidgetBuilder builder,
    required bool forward,
    RouteSettings? settings,
  }) : super(
         settings: settings,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: const Duration(milliseconds: 240),
         reverseTransitionDuration: const Duration(milliseconds: 240),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeInOutCubic,
             reverseCurve: Curves.easeInOutCubic,
           );

           final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
             CurvedAnimation(
               parent: animation,
               curve: const Interval(0.40, 1.0, curve: Curves.easeInOutCubic),
             ),
           );

           final dx = forward ? 10.0 : -10.0;

           return AnimatedBuilder(
             animation: curved,
             child: child,
             builder: (context, c) {
               final x = (1.0 - curved.value) * dx;
               return FadeTransition(
                 opacity: fadeIn,
                 child: Transform.translate(offset: Offset(x, 0), child: c),
               );
             },
           );
         },
       );
}
