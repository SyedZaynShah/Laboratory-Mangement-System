import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/motions.dart';

class AnimatedMoney extends StatefulWidget {
  final int cents;
  final TextStyle? style;
  final bool emphasize; // scales slightly when value changes
  final Duration duration;
  final Curve curve;

  const AnimatedMoney({
    super.key,
    required this.cents,
    this.style,
    this.emphasize = false,
    this.duration = Motions.normal,
    this.curve = Motions.ease,
  });

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney> with SingleTickerProviderStateMixin {
  late int _oldCents;
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _oldCents = widget.cents;
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(covariant AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cents != oldWidget.cents) {
      _oldCents = oldWidget.cents;
      if (widget.emphasize) {
        _ctrl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(int cents) => NumberFormat('###,##0.00').format(cents / 100.0);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _oldCents.toDouble(), end: widget.cents.toDouble()),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, v, child) {
        final scale = widget.emphasize ? Tween<double>(begin: 1.0, end: 1.02).animate(_ctrl).value : 1.0;
        return AnimatedScale(
          duration: widget.duration,
          curve: widget.curve,
          scale: scale,
          child: Text(_fmt(v.round()), style: widget.style),
        );
      },
    );
  }
}
