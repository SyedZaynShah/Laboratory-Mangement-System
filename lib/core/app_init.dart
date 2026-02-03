import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'sync/sync_service.dart';

final appInitProvider = FutureProvider<void>((ref) async {
  await ref.read(appDatabaseProvider.future);
  ref.read(syncServiceProvider).ensureStarted();
});

class AppBootstrapper extends ConsumerWidget {
  final Widget child;
  const AppBootstrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(appInitProvider);
    return init.when(
      data: (_) => child,
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) =>
          Scaffold(body: Center(child: Text('Initialization failed: $e'))),
    );
  }
}
