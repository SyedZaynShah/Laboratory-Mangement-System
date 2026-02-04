import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../core/backup/database_backup_service.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../models/roles.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _busy = false;

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(databaseBackupServiceProvider);
      final path = await svc.createBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup created: $path')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromPath(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text('This will overwrite current data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(databaseBackupServiceProvider);
      await svc.restoreBackup(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore complete. Restarting app...')),
      );
      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromPicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await _restoreFromPath(path);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    if (role != UserRole.admin) {
      return const Center(
        child: Text('Backup & Restore is available to Admin only.'),
      );
    }
    final svc = ref.watch(databaseBackupServiceProvider);
    return FutureBuilder(
      future: svc.listBackups(),
      builder: (context, snap) {
        final backups = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _createBackup,
                  icon: const Icon(Icons.save_alt),
                  label: Text(_busy ? 'Working...' : 'Create Backup'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restoreFromPicker,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore from file...'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: backups.isEmpty
                      ? const Center(child: Text('No backups yet'))
                      : ListView.separated(
                          itemCount: backups.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final f = backups[i] as File;
                            final name = p.basename(f.path);
                            return ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(name),
                              subtitle: Text(f.path),
                              trailing: FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _restoreFromPath(f.path),
                                child: const Text('Restore'),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
