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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserRoleProvider);
    return MaterialApp(
      title: 'Laboratory Management System',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(disablePageTransitions: role != null),
    );
  }
}
