import 'dart:math';
import 'package:riverpod/riverpod.dart';
import 'package:sqlite3/sqlite3.dart' as sq3;
import 'database_service.dart';

class BaseRepository {
  final Ref ref;
  BaseRepository(this.ref);

  Future<sq3.Database> get db async {
    return ref.read(sqliteDbProvider.future);
  }

  int nowSec() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  Future<int> softDelete(String table, String id) async {
    final d = await db;
    final ts = nowSec();
    final stmt = d.prepare(
      'UPDATE $table SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL',
    );
    try {
      stmt.execute([ts, ts, id]);
      return _changes(d);
    } finally {
      stmt.dispose();
    }
  }

  String notDeleted([String? alias]) {
    if (alias == null || alias.isEmpty) return 'deleted_at IS NULL';
    return '$alias.deleted_at IS NULL';
  }

  String newId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    final b = StringBuffer();
    for (final x in bytes) {
      b.write(x.toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  int _changes(sq3.Database d) {
    final rs = d.select('SELECT changes() AS c');
    if (rs.isEmpty) return 0;
    final v = rs.first['c'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}
