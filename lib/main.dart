import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/app_init.dart';
import 'core/widgets/app_shell.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/app_lock_barrier.dart';
import 'core/widgets/app_background.dart';
import 'features/auth/screen/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(
      controller: details.controller,
      thumbVisibility: true,
      thickness: 8,
      radius: const Radius.circular(10),
      interactive: true,
      child: child,
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    return MaterialApp(
      title: 'Laboratory Management System',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(disablePageTransitions: role != null),
      builder: (context, child) {
        final wrapped = ScrollConfiguration(
          behavior: const _AppScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
        return AppBackground(child: wrapped);
      },
      home: AppBootstrapper(child: AppLockBarrier(child: const _Root())),
    );
  }
}

class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    if (role == null) {
      return const LoginScreen();
    }
    return AppShell(role: role);
  }
}
