import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/filters/time_filter.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../patients/data/patients_providers.dart';
import '../../patients/data/patients_repository.dart';
import 'patient_form_screen.dart';
import 'patient_insights_detail_screen.dart';

enum _PatientsViewMode { records, insights }

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
  _PatientsViewMode _mode = _PatientsViewMode.records;

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
    if (_mode == _PatientsViewMode.insights) {
      ref.invalidate(patientInsightsProvider(_query));
      return;
    }
    if (_query.isEmpty) {
      ref.invalidate(patientsPageProvider(_page));
    } else {
      ref.invalidate(patientsSearchProvider(_query));
    }
  }

  String _presetLabel(TimeFilterPreset p) {
    switch (p) {
      case TimeFilterPreset.last7Days:
        return 'Last 7 Days';
      case TimeFilterPreset.last30Days:
        return 'Last 30 Days';
      case TimeFilterPreset.last90Days:
        return 'Last 90 Days';
      case TimeFilterPreset.last6Months:
        return 'Last 6 Months';
      case TimeFilterPreset.lastYear:
        return 'Last Year';
      case TimeFilterPreset.customRange:
        return 'Custom Range';
      case TimeFilterPreset.specificDate:
        return 'Specific Date';
    }
  }

  Future<void> _pickSpecificDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    ref.read(globalTimeFilterProvider.notifier).setSpecificDate(picked);
    _refresh();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initFrom = now.subtract(const Duration(days: 29));
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      initialDateRange: DateTimeRange(start: initFrom, end: now),
    );
    if (range == null) return;
    ref
        .read(globalTimeFilterProvider.notifier)
        .setCustomRange(from: range.start, to: range.end);
    _refresh();
  }

  Future<void> _openForm({String? id}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PatientFormScreen(patientId: id)),
    );
    if (result == true) {
      setState(() {
        _query = '';
        _searchController.clear();
        _page = 1;
      });
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = _mode == _PatientsViewMode.insights
        ? ref.watch(patientInsightsProvider(_query))
        : (_query.isEmpty
              ? ref.watch(patientsPageProvider(_page))
              : ref.watch(patientsSearchProvider(_query)));

    final tf = ref.watch(globalTimeFilterProvider);

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
              SegmentedButton<_PatientsViewMode>(
                segments: const [
                  ButtonSegment(
                    value: _PatientsViewMode.records,
                    label: Text('Records'),
                  ),
                  ButtonSegment(
                    value: _PatientsViewMode.insights,
                    label: Text('Insights'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) {
                  setState(() {
                    _mode = s.first;
                    _page = 1;
                  });
                  _refresh();
                },
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Patient'),
              ),
            ],
          ),
          if (_mode == _PatientsViewMode.insights) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                DropdownButton<TimeFilterPreset>(
                  value: tf.preset,
                  onChanged: (v) {
                    if (v == null) return;
                    if (v == TimeFilterPreset.customRange) {
                      ref
                          .read(globalTimeFilterProvider.notifier)
                          .setPreset(TimeFilterPreset.customRange);
                      _pickCustomRange();
                      return;
                    }
                    if (v == TimeFilterPreset.specificDate) {
                      ref
                          .read(globalTimeFilterProvider.notifier)
                          .setPreset(TimeFilterPreset.specificDate);
                      _pickSpecificDate();
                      return;
                    }
                    ref.read(globalTimeFilterProvider.notifier).setPreset(v);
                    _refresh();
                  },
                  items: TimeFilterPreset.values
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(_presetLabel(p)),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: tf.preset == TimeFilterPreset.customRange
                      ? _pickCustomRange
                      : (tf.preset == TimeFilterPreset.specificDate
                            ? _pickSpecificDate
                            : null),
                  icon: const Icon(Icons.date_range),
                  label: const Text('Change'),
                ),
                const Spacer(),
                Text(
                  'From: ${tf.fromSec == null ? '-' : DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(tf.fromSec! * 1000))}',
                ),
                const SizedBox(width: 12),
                Text(
                  'To: ${tf.toSec == null ? '-' : DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(tf.toSec! * 1000))}',
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No patients found'));
                }
                if (_mode == _PatientsViewMode.insights) {
                  int asInt(Object? v) {
                    if (v is int) return v;
                    if (v is num) return v.toInt();
                    return 0;
                  }

                  String money(int cents) {
                    final v = cents / 100.0;
                    return v.toStringAsFixed(2);
                  }

                  final totalPatients = rows.length;
                  final totalOrders = rows.fold<int>(
                    0,
                    (a, r) => a + asInt(r['total_orders']),
                  );
                  final totalTests = rows.fold<int>(
                    0,
                    (a, r) => a + asInt(r['total_tests']),
                  );
                  final totalCents = rows.fold<int>(
                    0,
                    (a, r) => a + asInt(r['total_cents']),
                  );
                  final receivedCents = rows.fold<int>(
                    0,
                    (a, r) => a + asInt(r['cash_received_cents']),
                  );

                  return Column(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 260,
                              child: KpiCard(
                                title: 'Patients',
                                value: '$totalPatients',
                                icon: Icons.people,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 260,
                              child: KpiCard(
                                title: 'Orders',
                                value: '$totalOrders',
                                icon: Icons.assignment,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 260,
                              child: KpiCard(
                                title: 'Tests',
                                value: '$totalTests',
                                icon: Icons.science,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 260,
                              child: KpiCard(
                                title: 'Total',
                                value: money(totalCents),
                                icon: Icons.receipt_long,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 260,
                              child: KpiCard(
                                title: 'Received',
                                value: money(receivedCents),
                                icon: Icons.payments,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1100),
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Patient')),
                                  DataColumn(label: Text('Total Orders')),
                                  DataColumn(label: Text('Tests Ordered')),
                                  DataColumn(label: Text('Total')),
                                  DataColumn(label: Text('Cash Received')),
                                  DataColumn(label: Text('Balance')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Last Order')),
                                ],
                                rows: rows
                                    .map((r) {
                                      final last =
                                          (r['last_order_at'] as int?) ?? 0;
                                      final lastStr = last <= 0
                                          ? '-'
                                          : DateFormat('yyyy-MM-dd').format(
                                              DateTime.fromMillisecondsSinceEpoch(
                                                last * 1000,
                                              ),
                                            );
                                      final total =
                                          (r['total_cents'] as int?) ?? 0;
                                      final cash =
                                          (r['cash_received_cents'] as int?) ??
                                          0;
                                      final bal =
                                          (r['balance_cents'] as int?) ?? 0;
                                      final status =
                                          (r['status'] as String?) ??
                                          'Not Completed';

                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            InkWell(
                                              onTap: () {
                                                final pid =
                                                    (r['patient_id']
                                                        as String?) ??
                                                    '';
                                                if (pid.isEmpty) return;
                                                final name =
                                                    (r['full_name']
                                                        as String?) ??
                                                    '';
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        PatientInsightsDetailScreen(
                                                          patientId: pid,
                                                          patientName: name,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Text(
                                                (r['full_name'] as String?) ??
                                                    '',
                                                style: const TextStyle(
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${(r['total_orders'] as int?) ?? 0}',
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${(r['total_tests'] as int?) ?? 0}',
                                            ),
                                          ),
                                          DataCell(Text(money(total))),
                                          DataCell(Text(money(cash))),
                                          DataCell(Text(money(bal))),
                                          DataCell(Text(status)),
                                          DataCell(Text(lastStr)),
                                        ],
                                      );
                                    })
                                    .toList(growable: false),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [Text('${rows.length} patients')],
                      ),
                    ],
                  );
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
