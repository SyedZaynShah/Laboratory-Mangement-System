import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/motions.dart';

class AccentCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accentColor;
  final bool accentTop;
  final double radius;
  const AccentCard({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
    this.accentTop = false,
    this.radius = 12,
  });

  @override
  State<AccentCard> createState() => _AccentCardState();
}

class _AccentCardState extends State<AccentCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? AppColors.accent;
    final pad = widget.padding ?? const EdgeInsets.all(12);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: Motions.normal,
          curve: Motions.ease,
          scale: _pressed ? 0.98 : (_hovered ? 1.035 : 1.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: AnimatedContainer(
                duration: Motions.normal,
                curve: Motions.ease,
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(widget.radius),
                  border: widget.accentTop
                      ? Border(
                          top: BorderSide(
                            color: _hovered ? color : color.withOpacity(0.85),
                            width: 3,
                          ),
                        )
                      : Border(
                          left: BorderSide(
                            color: _hovered ? color : color.withOpacity(0.85),
                            width: 3,
                          ),
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: _hovered
                          ? color.withOpacity(0.18)
                          : const Color(0xFF061024).withOpacity(0.55),
                      blurRadius: _hovered ? 18 : 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(padding: pad, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
