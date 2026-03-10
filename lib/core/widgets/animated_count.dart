import 'package:flutter/material.dart';
import '../theme/motions.dart';

class AnimatedCount extends StatelessWidget {
  final int value;
  final Duration duration;
  final Curve curve;
  final String Function(int) formatter;
  final TextStyle? style;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.formatter,
    this.duration = Motions.normal,
    this.curve = Motions.ease,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => Text(formatter(v), style: style),
    );
  }
}
