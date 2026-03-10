import 'package:flutter/material.dart';

class StaggeredReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double dy;

  const StaggeredReveal({
    super.key,
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 240),
    this.dy = 8,
  });

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: widget.duration,
      curve: Curves.easeInOutCubic,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : Offset(0, widget.dy / 100.0),
        duration: widget.duration,
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}
