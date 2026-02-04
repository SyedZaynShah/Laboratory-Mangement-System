import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../screen/backup_restore_screen.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../models/roles.dart';
import '../data/lab_profile_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();
  final _addr = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _logoPath;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(labProfileRepositoryProvider);
    final row = await repo.getProfile();
    _name.text = (row?['lab_name'] as String?) ?? '';
    _addr.text = (row?['address'] as String?) ?? '';
    _phone.text = (row?['phone'] as String?) ?? '';
    _email.text = (row?['email'] as String?) ?? '';
    _logoPath = (row?['logo_path'] as String?) ?? '';
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.first.path;
    if (path == null) return;
    setState(() => _logoPath = path);
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(labProfileRepositoryProvider);
      await repo.upsertProfile(
        labName: _name.text.trim().isEmpty ? 'Laboratory' : _name.text.trim(),
        address: _addr.text.trim().isEmpty ? null : _addr.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        logoPath: (_logoPath == null || _logoPath!.isEmpty) ? null : _logoPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lab profile saved')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserRoleProvider);
    return FutureBuilder(
      future: _load(),
      builder: (context, snap) {
        return SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Lab Profile',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (role != UserRole.admin)
                              const Text('Only Admin can edit lab profile.')
                            else ...[
                              TextField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Lab Name',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _addr,
                                decoration: const InputDecoration(
                                  labelText: 'Address',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _phone,
                                      decoration: const InputDecoration(
                                        labelText: 'Phone',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _email,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _logoPath == null || _logoPath!.isEmpty
                                          ? 'No logo selected'
                                          : _logoPath!,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _pickLogo,
                                    icon: const Icon(Icons.image),
                                    label: const Text('Pick Logo'),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _logoPath = ''),
                                    child: const Text('Clear'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: _saving ? null : _saveProfile,
                                    child: Text(_saving ? 'Saving...' : 'Save'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Text('Backup & Restore'),
                            SizedBox(height: 8),
                            BackupRestoreScreen(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
