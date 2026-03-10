import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double blurSigma;
  final Color fillColor;
  final Color borderColor;
  final List<BoxShadow> boxShadow;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.blurSigma = 26,
    this.fillColor = const Color(0x17FFFFFF),
    this.borderColor = const Color(0x26FFFFFF),
    this.boxShadow = const [
      BoxShadow(
        color: Color(0x66030A1A),
        blurRadius: 28,
        offset: Offset(0, 14),
      ),
      BoxShadow(
        color: Color(0x224EA4FF),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: boxShadow,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
