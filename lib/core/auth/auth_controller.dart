import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
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

class AuthController {
  final Ref ref;
  AuthController(this.ref);

  Future<bool> signIn(String email, String password) async {
    final db = await ref.read(appDatabaseProvider.future);
    final stmt = db.db.prepare(
      'SELECT id, role FROM users WHERE email = ? AND password_hash = ? AND is_active = 1 LIMIT 1',
    );
    try {
      final result = stmt.select([email.trim(), password]);
      if (result.isNotEmpty) {
        final roleStr = result.first['role'] as String;
        final uid = result.first['id'] as String;
        final role = _roleFromString(roleStr);
        ref.read(currentUserRoleProvider.notifier).set(role);
        ref.read(currentUserIdProvider.notifier).set(uid);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] signIn error: $e');
      }
      return false;
    } finally {
      stmt.dispose();
    }
  }

  Future<void> signOut() async {
    ref.read(currentUserRoleProvider.notifier).clear();
    ref.read(currentUserIdProvider.notifier).clear();
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
    final exists = await hasAnyUsers();
    if (exists) return false;
    final db = await ref.read(appDatabaseProvider.future);
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final stmt = db.db.prepare('''
      INSERT INTO users (id, email, password_hash, name, role, is_active, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, 1, ?, ?)
    ''');
    try {
      stmt.execute([
        email.trim().toLowerCase(),
        email.trim().toLowerCase(),
        password,
        name.trim(),
        'admin',
        ts,
        ts,
      ]);
      ref.read(currentUserRoleProvider.notifier).set(UserRole.admin);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Auth] createInitialAdmin error: $e');
      }
      return false;
    } finally {
      stmt.dispose();
    }
  }

  UserRole _roleFromString(String s) {
    switch (s) {
      case 'admin':
        return UserRole.admin;
      case 'receptionist':
        return UserRole.receptionist;
      case 'technician':
        return UserRole.technician;
      case 'pathologist':
        return UserRole.pathologist;
      case 'accountant':
        return UserRole.accountant;
      default:
        return UserRole.receptionist;
    }
  }
}
