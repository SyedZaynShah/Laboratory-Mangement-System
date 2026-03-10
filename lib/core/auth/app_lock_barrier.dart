import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_lock_controller.dart';
import 'lock_screen.dart';

class AppLockBarrier extends ConsumerWidget {
  final Widget child;
  const AppLockBarrier({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(appLockProvider);
    return Stack(
      children: [
        IgnorePointer(
          ignoring: locked,
          child: child,
        ),
        if (locked) const Positioned.fill(child: LockScreen()),
      ],
    );
  }
}
