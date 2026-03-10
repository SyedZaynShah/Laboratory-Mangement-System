import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockState extends Notifier<bool> {
  static const _kLockedKey = 'app_locked';

  @override
  bool build() {
    // Default: unlocked. Then restore persisted state.
    Future(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final locked = prefs.getBool(_kLockedKey) ?? false;
        if (state != locked) state = locked;
      } catch (_) {}
    });
    return false;
  }

  Future<void> lock() async {
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLockedKey, true);
    } catch (_) {}
  }

  Future<void> unlock() async {
    state = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLockedKey, false);
    } catch (_) {}
  }
}

final appLockProvider = NotifierProvider<AppLockState, bool>(
  () => AppLockState(),
);
