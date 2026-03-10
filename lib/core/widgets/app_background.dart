import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: _GradientLayer()),
        const Positioned.fill(child: _RadialGlowLayer()),
        const Positioned.fill(child: _NoiseLayer(opacity: 0.06)),
        child,
      ],
    );
  }
}

class _GradientLayer extends StatelessWidget {
  const _GradientLayer();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B132B),
            Color(0xFF0E1C3A),
            Color(0xFF060B1A),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _RadialGlowLayer extends StatelessWidget {
  const _RadialGlowLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(
            left: -220,
            top: -260,
            child: _GlowBlob(
              size: 620,
              color: Color(0x334EA4FF),
            ),
          ),
          Positioned(
            right: -260,
            bottom: -320,
            child: _GlowBlob(
              size: 760,
              color: Color(0x262E6BFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _NoiseLayer extends StatelessWidget {
  final double opacity;
  const _NoiseLayer({required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: _NoisePainter(),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF);

    final w = size.width;
    final h = size.height;

    const step = 7.0;
    for (double y = 0; y < h; y += step) {
      for (double x = 0; x < w; x += step) {
        final v = _hash01(x, y);
        if (v < 0.82) continue;
        final a = (v - 0.82) / 0.18;
        paint.color = const Color(0xFFFFFFFF).withOpacity(0.22 * a);
        canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), paint);
      }
    }
  }

  double _hash01(double x, double y) {
    final s = math.sin(x * 12.9898 + y * 78.233) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
