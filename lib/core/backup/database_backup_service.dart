import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

class DatabaseBackupService {
  final Ref ref;
  DatabaseBackupService(this.ref);

  Future<Directory> _backupsDir() async {
    // Prefer Windows Documents folder
    try {
      final user = Platform.environment['USERPROFILE'];
      if (user != null && user.isNotEmpty) {
        final docsPath =
            '$user${Platform.pathSeparator}Documents${Platform.pathSeparator}lms_backups';
        final dir = Directory(docsPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (_) {}
    // Fallback to application documents
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}lms_backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> createBackup() async {
    final appDb = await ref.read(appDatabaseProvider.future);
    final srcPath = appDb.dbPath;
    final backups = await _backupsDir();
    final now = DateTime.now();
    final ts =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}';
    final dstPath =
        '${backups.path}${Platform.pathSeparator}lms_backup_${ts}.db';
    final src = File(srcPath);
    await src.copy(dstPath);
    if (kDebugMode) {
      debugPrint('[Backup] Created: $dstPath');
    }
    return dstPath;
  }

  Future<List<FileSystemEntity>> listBackups() async {
    final dir = await _backupsDir();
    final entries = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return entries;
  }

  Future<void> restoreBackup(String backupPath) async {
    final appDb = await ref.read(appDatabaseProvider.future);
    // Close DB to release file locks
    appDb.close();
    final dst = File(appDb.dbPath);
    final src = File(backupPath);
    if (!await src.exists()) {
      throw StateError('Backup file not found');
    }
    await src.copy(dst.path);
  }
}

final databaseBackupServiceProvider = Provider<DatabaseBackupService>((ref) {
  return DatabaseBackupService(ref);
});
