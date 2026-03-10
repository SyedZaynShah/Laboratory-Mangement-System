import 'package:flutter/material.dart';

class AuthCardFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double height;

  const AuthCardFrame({
    super.key,
    required this.child,
    this.maxWidth = 420,
    this.height = 520,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(
          height: height,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return ClipRect(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(child: child),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
