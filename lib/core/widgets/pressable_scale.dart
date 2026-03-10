import 'package:flutter/material.dart';
import '../theme/motions.dart';

class PressableScale extends StatefulWidget {
  final Widget child;
  final double scale;
  final Duration duration;
  const PressableScale({super.key, required this.child, this.scale = 0.98, this.duration = Motions.quick});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Motions.ease,
        child: widget.child,
      ),
    );
  }
}
