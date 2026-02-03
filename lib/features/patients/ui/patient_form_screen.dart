import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../patients/data/patients_providers.dart';
import '../../patients/data/patients_repository.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  final String? patientId;
  const PatientFormScreen({super.key, this.patientId});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cnicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _referredByCtrl = TextEditingController();
  String? _gender;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cnicCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _referredByCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNew() async {
    final repo = ref.read(patientsRepositoryProvider);
    await repo.createPatient(
      fullName: _nameCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim().isEmpty ? null : _cnicCtrl.text.trim(),
      dateOfBirthSec: null,
      gender: _gender!,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      referredBy: _referredByCtrl.text.trim().isEmpty ? null : _referredByCtrl.text.trim(),
    );
  }

  Future<void> _saveEdit(String id) async {
    final repo = ref.read(patientsRepositoryProvider);
    await repo.updatePatient(
      id,
      fullName: _nameCtrl.text.trim(),
      cnic: _cnicCtrl.text.trim(),
      gender: _gender,
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      referredBy: _referredByCtrl.text.trim(),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.patientId == null) {
        await _saveNew();
      } else {
        await _saveEdit(widget.patientId!);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.patientId != null;
    final asyncPatient = isEdit ? ref.watch(patientByIdProvider(widget.patientId!)) : const AsyncValue.data(null);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Patient' : 'Add Patient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncPatient.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (row) {
            if (row != null && !_loaded) {
              _nameCtrl.text = (row['full_name'] as String?) ?? '';
              _cnicCtrl.text = (row['cnic'] as String?) ?? '';
              _phoneCtrl.text = (row['phone'] as String?) ?? '';
              _addressCtrl.text = (row['address'] as String?) ?? '';
              _referredByCtrl.text = (row['referred_by'] as String?) ?? '';
              _gender = (row['gender'] as String?) ?? _gender;
              _loaded = true;
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Full Name *'),
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _gender,
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Male')),
                                DropdownMenuItem(value: 'female', child: Text('Female')),
                                DropdownMenuItem(value: 'other', child: Text('Other')),
                              ],
                              decoration: const InputDecoration(labelText: 'Gender *'),
                              onChanged: (v) => setState(() => _gender = v),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cnicCtrl,
                              decoration: const InputDecoration(labelText: 'CNIC'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(labelText: 'Phone'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(labelText: 'Address'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _referredByCtrl,
                        decoration: const InputDecoration(labelText: 'Referred By'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _saving ? null : _handleSave,
                            child: Text(_saving ? 'Saving...' : 'Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
