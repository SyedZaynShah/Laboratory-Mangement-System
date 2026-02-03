import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../patients/data/patients_providers.dart';
import '../../tests/data/tests_providers.dart';
import '../../tests/data/test_model.dart';
import '../data/test_orders_providers.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  Map<String, Object?>? _patient;
  final List<TestModel> _selectedTests = [];
  bool _saving = false;

  int get _totalCents =>
      _selectedTests.fold(0, (sum, t) => sum + (t.priceCents));
  String _formatPrice(int cents) =>
      NumberFormat('###,##0.00').format(cents / 100.0);

  Future<void> _pickPatient() async {
    final res = await showDialog<Map<String, Object?>?>(
      context: context,
      builder: (ctx) => const _SelectPatientDialog(),
    );
    if (res != null) {
      setState(() => _patient = res);
    }
  }

  Future<void> _pickTests() async {
    final res = await showDialog<List<TestModel>?>(
      context: context,
      builder: (ctx) => _SelectTestsDialog(initial: _selectedTests),
    );
    if (res != null) {
      setState(() {
        _selectedTests
          ..clear()
          ..addAll(res);
      });
    }
  }

  Future<void> _createOrder() async {
    if (_patient == null || _selectedTests.isEmpty) return;
    final patientId = _patient!['id'] as String;
    final testIds = _selectedTests.map((t) => t.id!).toList();
    setState(() => _saving = true);
    try {
      await ref
          .read(testOrdersRepositoryProvider)
          .createOrder(patientId: patientId, testIds: testIds);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order created')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Test Order')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Patient'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _patient == null
                                      ? 'No patient selected'
                                      : (_patient!['full_name'] as String? ??
                                            ''),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: _pickPatient,
                                icon: const Icon(Icons.search),
                                label: Text(
                                  _patient == null
                                      ? 'Select Patient'
                                      : 'Change',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tests'),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedTests
                                .map(
                                  (t) => Chip(
                                    label: Text(
                                      '${t.testCode} - ${t.testName} (${_formatPrice(t.priceCents)})',
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedTests.removeWhere(
                                          (x) => x.id == t.id,
                                        );
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _pickTests,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Tests'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ${_formatPrice(_totalCents)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed:
                          _saving || _patient == null || _selectedTests.isEmpty
                          ? null
                          : _createOrder,
                      child: Text(_saving ? 'Creating...' : 'Create Order'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectPatientDialog extends ConsumerStatefulWidget {
  const _SelectPatientDialog();

  @override
  ConsumerState<_SelectPatientDialog> createState() =>
      _SelectPatientDialogState();
}

class _SelectPatientDialogState extends ConsumerState<_SelectPatientDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(() => _q = _ctrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = _q.isEmpty
        ? const AsyncValue<List<Map<String, Object?>>>.data([])
        : ref.watch(patientsSearchProvider(_q));
    return AlertDialog(
      title: const Text('Select Patient'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name, phone, or CNIC',
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (rows) {
                  if (rows.isEmpty)
                    return const Center(child: Text('No results'));
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final r = rows[i];
                      return ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text((r['full_name'] as String?) ?? ''),
                        subtitle: Text(
                          [r['phone'], r['cnic']]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                        ),
                        onTap: () => Navigator.of(context).pop(r),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SelectTestsDialog extends ConsumerStatefulWidget {
  final List<TestModel> initial;
  const _SelectTestsDialog({required this.initial});

  @override
  ConsumerState<_SelectTestsDialog> createState() => _SelectTestsDialogState();
}

class _SelectTestsDialogState extends ConsumerState<_SelectTestsDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';
  final Map<String, TestModel> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final t in widget.initial) {
      if (t.id != null) _selected[t.id!] = t;
    }
    _ctrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(() => _q = _ctrl.text.trim());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _formatPrice(int cents) =>
      NumberFormat('###,##0.00').format(cents / 100.0);

  @override
  Widget build(BuildContext context) {
    final async = _q.isEmpty
        ? const AsyncValue<List<TestModel>>.data([])
        : ref.watch(testsSearchProvider(_q));
    return AlertDialog(
      title: const Text('Add Tests'),
      content: SizedBox(
        width: 800,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search code, name, or category',
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (rows) {
                  if (rows.isEmpty)
                    return const Center(child: Text('No results'));
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final t = rows[i];
                      final id = t.id;
                      final checked = id != null && _selected.containsKey(id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              if (id != null) _selected[id] = t;
                            } else {
                              if (id != null) _selected.remove(id);
                            }
                          });
                        },
                        title: Text('${t.testCode} — ${t.testName}'),
                        subtitle: Text(
                          '${t.category ?? ''} · ${t.sampleType} · ${t.unit ?? ''} · ${_formatPrice(t.priceCents)}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text('Selected: ${_selected.length}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(
                  context,
                ).pop<List<TestModel>>(_selected.values.toList()),
          child: const Text('Add Selected'),
        ),
      ],
    );
  }
}
