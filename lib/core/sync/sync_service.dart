import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncService {
  Timer? _timer;
  final Ref ref;
  SyncService(this.ref);

  void ensureStarted() {
    _timer ??= Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  Future<void> _tick() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return;
    // TODO: Push pending records to Firebase when configured
    if (kDebugMode) {
      debugPrint('[Sync] Tick (connectivity: $results)');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(service.dispose);
  return service;
});
