import 'package:flutter/material.dart';

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  final TextAlign? textAlign;
  const GradientText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.gradient = const LinearGradient(
      colors: [Color(0xFFB7E3FF), Color(0xFF2E6BFF)],
    ),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? Theme.of(context).textTheme.headlineSmall;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(text, style: effectiveStyle, textAlign: textAlign),
    );
  }
}
