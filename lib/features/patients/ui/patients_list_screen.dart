import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../patients/data/patients_providers.dart';
import '../../patients/data/patients_repository.dart';
import 'patient_form_screen.dart';

class PatientsListScreen extends ConsumerStatefulWidget {
  const PatientsListScreen({super.key});

  @override
  ConsumerState<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends ConsumerState<PatientsListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _query = _searchController.text.trim();
        _page = 1;
      });
    });
  }

  void _refresh() {
    if (_query.isEmpty) {
      ref.invalidate(patientsPageProvider(_page));
    } else {
      ref.invalidate(patientsSearchProvider(_query));
    }
  }

  Future<void> _openForm({String? id}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PatientFormScreen(patientId: id)),
    );
    if (result == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = _query.isEmpty
        ? ref.watch(patientsPageProvider(_page))
        : ref.watch(patientsSearchProvider(_query));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name, phone, or CNIC',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Patient'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No patients found'));
                }
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 900),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Name')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Gender')),
                                DataColumn(label: Text('CNIC')),
                                DataColumn(label: Text('Created')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: rows.map((row) {
                                final dt = DateTime.fromMillisecondsSinceEpoch(
                                  ((row['created_at'] as int?) ?? 0) * 1000,
                                );
                                final created = DateFormat(
                                  'yyyy-MM-dd HH:mm',
                                ).format(dt);
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text((row['full_name'] as String?) ?? ''),
                                    ),
                                    DataCell(
                                      Text((row['phone'] as String?) ?? ''),
                                    ),
                                    DataCell(
                                      Text((row['gender'] as String?) ?? ''),
                                    ),
                                    DataCell(
                                      Text((row['cnic'] as String?) ?? ''),
                                    ),
                                    DataCell(Text(created)),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: 'View / Edit',
                                            icon: const Icon(Icons.edit),
                                            onPressed: () => _openForm(
                                              id: row['id'] as String,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            tooltip: 'Soft Delete',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                    'Delete Patient',
                                                  ),
                                                  content: const Text(
                                                    'Are you sure you want to soft delete this patient?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Delete',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true) {
                                                final repo = ref.read(
                                                  patientsRepositoryProvider,
                                                );
                                                await repo.softDeletePatient(
                                                  row['id'] as String,
                                                );
                                                _refresh();
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Patient deleted',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_query.isEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('Page $_page'),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _page > 1
                                ? () {
                                    setState(() {
                                      _page -= 1;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed: rows.length >= _pageSize
                                ? () {
                                    setState(() {
                                      _page += 1;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
