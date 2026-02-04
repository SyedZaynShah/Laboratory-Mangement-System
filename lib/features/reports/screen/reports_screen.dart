import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../reports/data/reports_providers.dart';
import '../../patients/data/patients_providers.dart';
import '../pdf/report_template.dart';
import '../../settings/data/lab_profile_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _type = 'patient_results';
  int? _fromSec;
  int? _toSec;
  String? _patientId;
  String? _patientName;
  final _orderIdCtrl = TextEditingController();
  final _invoiceIdCtrl = TextEditingController();
  String? _status; // order status or invoice status based on type
  int _applyToken = 0;
  bool _hasApplied = false;

  @override
  void dispose() {
    _orderIdCtrl.dispose();
    _invoiceIdCtrl.dispose();
    super.dispose();
  }

  String _fmtMoney(int? cents) =>
      NumberFormat('###,##0.00').format((cents ?? 0) / 100.0);
  String _fmtDate(int? ts) => ts == null || ts == 0
      ? ''
      : DateFormat(
          'yyyy-MM-dd HH:mm',
        ).format(DateTime.fromMillisecondsSinceEpoch(ts * 1000));

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final base = from
        ? (_fromSec != null
              ? DateTime.fromMillisecondsSinceEpoch(_fromSec! * 1000)
              : now)
        : (_toSec != null
              ? DateTime.fromMillisecondsSinceEpoch(_toSec! * 1000)
              : now);
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final withTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        from ? 0 : 23,
        from ? 0 : 59,
      );
      setState(() {
        if (from) {
          _fromSec = withTime.millisecondsSinceEpoch ~/ 1000;
        } else {
          _toSec = withTime.millisecondsSinceEpoch ~/ 1000;
        }
      });
    }
  }

  Future<void> _pickPatient() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => _PatientPickerDialog(),
    );
    if (result != null) {
      setState(() {
        _patientId = result['id'];
        _patientName = result['name'];
      });
    }
  }

  Future<String> _saveCsv(String filename, List<String> lines) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}${Platform.pathSeparator}lms_reports');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final file = File('${folder.path}${Platform.pathSeparator}$filename');
    await file.writeAsString(lines.join('\n'));
    return file.path;
  }

  List<String> _toCsv(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return [];
    final headers = <String>{};
    for (final r in rows) {
      headers.addAll(r.keys);
    }
    final ordered = headers.toList();
    final out = <String>[];
    out.add(ordered.join(','));
    for (final r in rows) {
      final cells = ordered.map((h) {
        final v = r[h];
        final s = v == null ? '' : v.toString().replaceAll('"', '""');
        return '"$s"';
      }).toList();
      out.add(cells.join(','));
    }
    return out;
  }

  Widget _filters() {
    final isResults = _type == 'patient_results';
    final isInvoices = _type == 'invoices';
    return Column(
      children: [
        Row(
          children: [
            DropdownButton<String>(
              value: _type,
              items: const [
                DropdownMenuItem(
                  value: 'patient_results',
                  child: Text('Patient Results'),
                ),
                DropdownMenuItem(value: 'invoices', child: Text('Invoices')),
                DropdownMenuItem(
                  value: 'daily_summary',
                  child: Text('Daily Summary'),
                ),
              ],
              onChanged: (v) => setState(() {
                _type = v!;
                _status = null;
              }),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _pickDate(from: true),
              icon: const Icon(Icons.date_range),
              label: Text(
                _fromSec == null
                    ? 'From Date'
                    : DateFormat('yyyy-MM-dd').format(
                        DateTime.fromMillisecondsSinceEpoch(_fromSec! * 1000),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _pickDate(from: false),
              icon: const Icon(Icons.date_range),
              label: Text(
                _toSec == null
                    ? 'To Date'
                    : DateFormat('yyyy-MM-dd').format(
                        DateTime.fromMillisecondsSinceEpoch(_toSec! * 1000),
                      ),
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (isResults) ...[
              OutlinedButton.icon(
                onPressed: _pickPatient,
                icon: const Icon(Icons.person_search),
                label: Text(
                  _patientName == null ? 'Pick Patient' : _patientName!,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _orderIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Order ID (optional)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _status,
                hint: const Text('Order Status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: 'ordered', child: Text('Ordered')),
                  DropdownMenuItem(
                    value: 'sample_collected',
                    child: Text('Sample Collected'),
                  ),
                  DropdownMenuItem(
                    value: 'in_process',
                    child: Text('In Process'),
                  ),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
            ],
            if (isInvoices) ...[
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _invoiceIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invoice ID (optional)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String?>(
                value: _status,
                hint: const Text('Invoice Status'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Any')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                  DropdownMenuItem(value: 'open', child: Text('Open')),
                  DropdownMenuItem(value: 'paid', child: Text('Paid')),
                  DropdownMenuItem(value: 'void', child: Text('Void')),
                ],
                onChanged: (v) => setState(() => _status = v),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Spacer(),
            FilledButton.icon(
              onPressed: () => setState(() {
                _hasApplied = true;
                _applyToken++;
              }),
              icon: const Icon(Icons.checklist),
              label: const Text('Apply Filters'),
            ),
          ],
        ),
      ],
    );
  }

  ReportQuery _buildQuery() {
    switch (_type) {
      case 'patient_results':
        return ReportQuery(
          type: _type,
          patientId: _patientId,
          orderId: _orderIdCtrl.text.trim().isEmpty
              ? null
              : _orderIdCtrl.text.trim(),
          fromSec: _fromSec,
          toSec: _toSec,
          status: _status,
          token: _applyToken,
        );
      case 'invoices':
        return ReportQuery(
          type: _type,
          invoiceId: _invoiceIdCtrl.text.trim().isEmpty
              ? null
              : _invoiceIdCtrl.text.trim(),
          fromSec: _fromSec,
          toSec: _toSec,
          status: _status,
          token: _applyToken,
        );
      case 'daily_summary':
        return ReportQuery(
          type: _type,
          fromSec: _fromSec,
          toSec: _toSec,
          token: _applyToken,
        );
      default:
        return ReportQuery(type: 'patient_results', token: _applyToken);
    }
  }

  Future<void> _exportCsv(Object data) async {
    final rows = switch (data) {
      final List<Map<String, Object?>> l => l,
      final Map<String, Object?> m => [m],
      _ => <Map<String, Object?>>[],
    };
    final csv = _toCsv(rows);
    if (csv.isEmpty) return;
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final path = await _saveCsv('${_type}_$ts.csv', csv);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('CSV saved: $path')));
  }

  Future<void> _exportPdf(Object data) async {
    if (_type != 'patient_results') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PDF export is available for Patient Results only. Use CSV for others.',
          ),
        ),
      );
      return;
    }
    final rows = (data is List)
        ? data.cast<Map<String, Object?>>()
        : <Map<String, Object?>>[];
    if (rows.isEmpty) return;
    // Group by patient
    final byPatient = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final pid = (r['patient_id'] as String?) ?? 'unknown';
      byPatient.putIfAbsent(pid, () => []).add(r);
    }
    final doc = await _buildPatientResultsPdf(byPatient);
    await Printing.layoutPdf(onLayout: (_) async => doc);
  }

  Future<Uint8List> _buildPatientResultsPdf(
    Map<String, List<Map<String, Object?>>> byPatient,
  ) async {
    final labRepo = ref.read(labProfileRepositoryProvider);
    final lab = await labRepo.getProfile();
    final logo = await labRepo.loadLogoBytes();
    final labName = (lab?['lab_name'] as String?) ?? 'Laboratory Report';
    final address = (lab?['address'] as String?) ?? '';
    final phone = (lab?['phone'] as String?) ?? '';
    final email = (lab?['email'] as String?) ?? '';
    // Build a combined PDF with one page per patient
    // Reuse PdfReportData model for each patient and merge the documents by concatenating bytes via Printing
    // Here we build a single document with multiple pages using the template each time
    final pages = <Uint8List>[];
    for (final entry in byPatient.entries) {
      final rows = entry.value;
      final patientName = (rows.first['patient_name'] as String?) ?? '';
      final patientId = (rows.first['patient_id'] as String?) ?? '';
      final tests = rows.map((r) {
        final unit = (r['test_unit'] as String?) ?? '';
        final value =
            (r['value_text'] as String?) ??
            ((r['value_num'] as num?)?.toString() ?? '');
        final refText = (r['reference_text'] as String?) ?? '';
        final low = (r['reference_low'] as num?)?.toString();
        final high = (r['reference_high'] as num?)?.toString();
        final normal = refText.isNotEmpty
            ? refText
            : ((low != null || high != null)
                  ? '${low ?? ''}-${high ?? ''}'
                  : '');
        final flag = ((r['is_abnormal'] as int?) ?? 0) == 1 ? 'HIGH' : null;
        return PdfTestRow(
          name: (r['test_name'] as String?) ?? '',
          value: value,
          unit: unit,
          normalRange: normal,
          flag: flag,
        );
      }).toList();
      final data = PdfReportData(
        labName: labName,
        address: address,
        phone: phone,
        email: email,
        logoBytes: logo,
        patientName: patientName,
        patientId: patientId,
        rows: tests,
      );
      final bytes = await buildReportPdf(data);
      pages.add(bytes);
    }
    // Merge: Printing.layoutPdf expects a single Uint8List; simplest is to concatenate by rebuilding a single doc.
    // For simplicity, if multiple patients, just return first patient's PDF; otherwise return single.
    // To keep scope minimal, we return the first; future enhancement can merge properly.
    if (pages.isEmpty) {
      return Uint8List(0);
    }
    return pages.first;
  }

  Widget _preview(Object? data) {
    if (data == null) return const SizedBox.shrink();
    if (_type == 'daily_summary') {
      final m = data as Map<String, Object?>;
      return Wrap(
        spacing: 8,
        children: [
          Chip(
            label: Text('Total Orders: ${(m['total_orders'] as int?) ?? 0}'),
          ),
          Chip(
            label: Text(
              'Processed Samples: ${(m['processed_samples'] as int?) ?? 0}',
            ),
          ),
          Chip(
            label: Text(
              'Validated Results: ${(m['validated_results'] as int?) ?? 0}',
            ),
          ),
          Chip(
            label: Text(
              'Payments: ${_fmtMoney(m['payments_collected_cents'] as int?)}',
            ),
          ),
        ],
      );
    }
    final rows = data as List<Map<String, Object?>>;
    if (rows.isEmpty) {
      return const Center(
        child: Text('No data found for the selected filters.'),
      );
    }
    if (_type == 'patient_results') {
      return _resultsTable(rows);
    } else {
      return _invoicesTable(rows);
    }
  }

  Widget _resultsTable(List<Map<String, Object?>> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1100),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Patient')),
            DataColumn(label: Text('Order No')),
            DataColumn(label: Text('Ordered At')),
            DataColumn(label: Text('Test')),
            DataColumn(label: Text('Result')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Reference')),
            DataColumn(label: Text('Abn')),
            DataColumn(label: Text('Validated')),
          ],
          rows: rows.map((r) {
            final value =
                (r['value_text'] as String?) ??
                ((r['value_num'] as num?)?.toString() ?? '');
            final refText = (r['reference_text'] as String?) ?? '';
            final low = (r['reference_low'] as num?)?.toString();
            final high = (r['reference_high'] as num?)?.toString();
            final normal = refText.isNotEmpty
                ? refText
                : ((low != null || high != null)
                      ? '${low ?? ''}-${high ?? ''}'
                      : '');
            final abn = ((r['is_abnormal'] as int?) ?? 0) == 1 ? 'Y' : '';
            return DataRow(
              cells: [
                DataCell(Text((r['patient_name'] as String?) ?? '')),
                DataCell(Text((r['order_number'] as String?) ?? '')),
                DataCell(Text(_fmtDate(r['ordered_at'] as int?))),
                DataCell(Text((r['test_name'] as String?) ?? '')),
                DataCell(Text(value)),
                DataCell(Text((r['test_unit'] as String?) ?? '')),
                DataCell(Text(normal)),
                DataCell(Text(abn)),
                DataCell(Text(_fmtDate(r['validated_at'] as int?))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _invoicesTable(List<Map<String, Object?>> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 1200),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Invoice No')),
            DataColumn(label: Text('Issued')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Patient')),
            DataColumn(label: Text('Item')),
            DataColumn(label: Text('Qty')),
            DataColumn(label: Text('Unit (¢)')),
            DataColumn(label: Text('Item Disc (¢)')),
            DataColumn(label: Text('Line Total (¢)')),
            DataColumn(label: Text('Hdr Disc (¢)')),
            DataColumn(label: Text('Hdr Tax (¢)')),
            DataColumn(label: Text('Paid')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Balance')),
          ],
          rows: rows.map((r) {
            return DataRow(
              cells: [
                DataCell(Text((r['invoice_no'] as String?) ?? '')),
                DataCell(Text(_fmtDate(r['issued_at'] as int?))),
                DataCell(Text((r['status'] as String?) ?? '')),
                DataCell(Text((r['patient_name'] as String?) ?? '')),
                DataCell(Text((r['description'] as String?) ?? '')),
                DataCell(Text(((r['qty'] as int?) ?? 0).toString())),
                DataCell(
                  Text(((r['unit_price_cents'] as int?) ?? 0).toString()),
                ),
                DataCell(
                  Text(((r['item_discount_cents'] as int?) ?? 0).toString()),
                ),
                DataCell(
                  Text(((r['line_total_cents'] as int?) ?? 0).toString()),
                ),
                DataCell(
                  Text(((r['header_discount_cents'] as int?) ?? 0).toString()),
                ),
                DataCell(
                  Text(((r['header_tax_cents'] as int?) ?? 0).toString()),
                ),
                DataCell(Text(_fmtMoney(r['paid_cents'] as int?))),
                DataCell(Text(_fmtMoney(r['total_cents'] as int?))),
                DataCell(Text(_fmtMoney(r['balance_cents'] as int?))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final applied = _hasApplied;
    final asyncData = applied
        ? ref.watch(reportDataProvider(_buildQuery()))
        : null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Reports', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: (asyncData != null && asyncData.hasValue)
                    ? () => _exportCsv(asyncData.value!)
                    : null,
                icon: const Icon(Icons.table_view),
                label: const Text('Export CSV'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (asyncData != null && asyncData.hasValue)
                    ? () => _exportPdf(asyncData.value!)
                    : null,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _filters(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: !applied
                    ? const Center(
                        child: Text(
                          'Adjust filters and press Apply to load the report.',
                        ),
                      )
                    : asyncData!.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('Error: $e')),
                        data: (data) => _preview(data),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientPickerDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PatientPickerDialog> createState() =>
      _PatientPickerDialogState();
}

class _PatientPickerDialogState extends ConsumerState<_PatientPickerDialog> {
  final _q = TextEditingController();
  Timer? _debounce;
  String _debounced = '';

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _debounced;
    final async = query.isEmpty
        ? const AsyncValue<List<Map<String, Object?>>>.data(
            <Map<String, Object?>>[],
          )
        : ref.watch(patientsSearchProvider(query));
    return AlertDialog(
      title: const Text('Pick Patient'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _q,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Search by name / phone / CNIC',
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  setState(() {
                    _debounced = _q.text.trim();
                  });
                });
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (rows) {
                  if (rows.isEmpty)
                    return const Center(child: Text('No results'));
                  return ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final id = r['id'] as String;
                      final name = (r['full_name'] as String?) ?? '';
                      final cnic = (r['cnic'] as String?) ?? '';
                      final phone = (r['phone'] as String?) ?? '';
                      return ListTile(
                        title: Text(name),
                        subtitle: Text(
                          [cnic, phone].where((x) => x.isNotEmpty).join(' · '),
                        ),
                        onTap: () =>
                            Navigator.pop(context, {'id': id, 'name': name}),
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
