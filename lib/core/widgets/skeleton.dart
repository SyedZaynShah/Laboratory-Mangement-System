import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              begin: Alignment(-1.0, -0.3),
              end: Alignment(1.0, 0.3),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(rect);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;
  const SkeletonBox({
    super.key,
    required this.height,
    required this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class SkeletonTable extends StatelessWidget {
  final int rows;
  final List<double> columnFlex;
  const SkeletonTable({
    super.key,
    this.rows = 6,
    this.columnFlex = const [2, 2, 1, 1, 1],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(rows, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              for (final f in columnFlex)
                Expanded(
                  flex: (f * 100).toInt(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: SkeletonBox(
                      height: 20,
                      width: double.infinity,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
