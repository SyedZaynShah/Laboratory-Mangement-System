import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/roles.dart';
import '../database/app_database.dart';

class CurrentUserRole extends Notifier<UserRole?> {
  @override
  UserRole? build() => null;

  void set(UserRole? role) => state = role;
  void clear() => state = null;
}

class CurrentUserId extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
  void clear() => state = null;
}

final currentUserRoleProvider = NotifierProvider<CurrentUserRole, UserRole?>(
  () => CurrentUserRole(),
);

final currentUserIdProvider = NotifierProvider<CurrentUserId, String?>(
  () => CurrentUserId(),
);

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);

class _AuthPrefsKeys {
  static const sessionUserId = 'session_user_id';
  static const sessionUserRole = 'session_user_role';
}

class AuthController {
  final Ref ref;
  AuthController(this.ref);

  static const String _fixedAdminId = 'admin';
  static const String _fixedAdminUsername = 'admin';
  static const String _fixedAdminPassword = 'admin312';

  Future<void> ensureSingleAdmin() async {
    final db = await ref.read(appDatabaseProvider.future);
    final d = db.db;
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    d.execute('BEGIN');
    try {
      d.execute('UPDATE users SET is_active = 0 WHERE id <> ?;', [
        _fixedAdminId,
      ]);
      final stmt = d.prepare('''
        INSERT OR REPLACE INTO users (id, email, password_hash, name, role, is_active, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 1, ?, ?)
      ''');
      try {
        stmt.execute([
          _fixedAdminId,
          _fixedAdminUsername,
          _fixedAdminPassword,
          'Admin',
          'admin',
          ts,
          ts,
        ]);
      } finally {
        stmt.dispose();
      }
      d.execute('COMMIT');
    } catch (e) {
      d.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_AuthPrefsKeys.sessionUserId);
      final roleStr = prefs.getString(_AuthPrefsKeys.sessionUserRole);
      if (uid == null || roleStr == null) return;

      // Single-admin mode: only restore the fixed admin session.
      if (uid != _fixedAdminId) return;
      ref.read(currentUserRoleProvider.notifier).set(UserRole.admin);
      ref.read(currentUserIdProvider.notifier).set(_fixedAdminId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] restoreSession error: $e');
      }
    }
  }

  Future<bool> verifyCurrentUserPassword({required String password}) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return false;
    final db = await ref.read(appDatabaseProvider.future);
    final stmt = db.db.prepare(
      'SELECT 1 FROM users WHERE id = ? AND password_hash = ? AND is_active = 1 LIMIT 1',
    );
    try {
      final rs = stmt.select([uid, password]);
      return rs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] verifyCurrentUserPassword error: $e');
      }
      return false;
    } finally {
      stmt.dispose();
    }
  }

  Future<bool> signIn(String email, String password) async {
    if (email.trim() != _fixedAdminUsername ||
        password != _fixedAdminPassword) {
      return false;
    }

    // Ensure the admin user exists in DB so created_by foreign keys remain valid.
    try {
      await ensureSingleAdmin();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] ensureSingleAdmin error: $e');
      }
    }

    ref.read(currentUserRoleProvider.notifier).set(UserRole.admin);
    ref.read(currentUserIdProvider.notifier).set(_fixedAdminId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_AuthPrefsKeys.sessionUserId, _fixedAdminId);
      await prefs.setString(_AuthPrefsKeys.sessionUserRole, 'admin');
    } catch (_) {}
    return true;
  }

  Future<void> signOut() async {
    ref.read(currentUserRoleProvider.notifier).clear();
    ref.read(currentUserIdProvider.notifier).clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_AuthPrefsKeys.sessionUserId);
      await prefs.remove(_AuthPrefsKeys.sessionUserRole);
    } catch (_) {}
  }

  Future<bool> verifyPassword({
    required String email,
    required String password,
  }) async {
    return email.trim() == _fixedAdminUsername &&
        password == _fixedAdminPassword;
  }

  Future<bool> hasAnyUsers() async {
    final db = await ref.read(appDatabaseProvider.future);
    final rs = db.db.select('SELECT COUNT(1) AS c FROM users');
    final c = (rs.first['c'] as int?) ?? 0;
    return c > 0;
  }

  Future<bool> createInitialAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    return false;
  }

  Future<bool> createUser({
    required String name,
    required String email,
    required String password,
  }) async {
    return false;
  }
}
