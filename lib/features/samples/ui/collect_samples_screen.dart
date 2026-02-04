import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/samples_providers.dart';
import '../../results/data/results_providers.dart';
import '../../../core/auth/auth_controller.dart';

class CollectSamplesScreen extends ConsumerStatefulWidget {
  final String orderId;
  const CollectSamplesScreen({super.key, required this.orderId});

  @override
  ConsumerState<CollectSamplesScreen> createState() =>
      _CollectSamplesScreenState();
}

class _CollectSamplesScreenState extends ConsumerState<CollectSamplesScreen> {
  bool _initializing = true;
  bool _bulkWorking = false;

  @override
  void initState() {
    super.initState();
    _initEnsure();
  }

  Future<void> _initEnsure() async {
    try {
      await ref
          .read(samplesRepositoryProvider)
          .ensureSamplesForOrder(widget.orderId);
      ref.invalidate(samplesPageProvider(widget.orderId));
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  String _formatTs(int? sec) {
    if (sec == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  List<DropdownMenuItem<String>> get _statusItems => const [
    DropdownMenuItem(value: 'awaiting', child: Text('Awaiting')),
    DropdownMenuItem(value: 'collected', child: Text('Collected')),
    DropdownMenuItem(value: 'received', child: Text('Received')),
    DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
    DropdownMenuItem(value: 'processed', child: Text('Processed')),
  ];

  Future<void> _setStatus(String sampleId, String status) async {
    await ref
        .read(samplesRepositoryProvider)
        .updateSampleStatus(sampleId, status);
    ref.invalidate(samplesPageProvider(widget.orderId));
  }

  Future<void> _deleteSample(String sampleId) async {
    await ref.read(samplesRepositoryProvider).softDeleteSample(sampleId);
    await ref
        .read(samplesRepositoryProvider)
        .ensureSamplesForOrder(widget.orderId);
    ref.invalidate(samplesPageProvider(widget.orderId));
  }

  Future<void> _collectAll(List<Map<String, Object?>> rows) async {
    setState(() => _bulkWorking = true);
    try {
      for (final r in rows) {
        final sid = r['sample_id'] as String;
        final status = r['status'] as String? ?? 'awaiting';
        if (status == 'awaiting') {
          await ref
              .read(samplesRepositoryProvider)
              .updateSampleStatus(sid, 'collected');
        }
      }
      ref.invalidate(samplesPageProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All awaiting samples marked collected'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(samplesPageProvider(widget.orderId));
    final resultsAsync = ref.watch(testResultsByOrderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Samples'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.invalidate(samplesPageProvider(widget.orderId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Error: $e')),
                data: (rows) {
                  if (rows.isEmpty) {
                    return const Center(child: Text('No samples'));
                  }
                  final resRows = resultsAsync.maybeWhen(
                    data: (v) => v,
                    orElse: () => const <Map<String, Object?>>[],
                  );
                  final resByItem = <String, Map<String, Object?>>{};
                  for (final r in resRows) {
                    final itemId = r['item_id'] as String?;
                    if (itemId != null) resByItem[itemId] = r;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _bulkWorking
                                ? null
                                : () => _collectAll(rows),
                            icon: const Icon(Icons.playlist_add_check),
                            label: const Text('Mark all Awaiting → Collected'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1100),
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Test')),
                                  DataColumn(label: Text('Sample Code')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Collected At')),
                                  DataColumn(label: Text('Result (Num)')),
                                  DataColumn(label: Text('Result (Text)')),
                                  DataColumn(label: Text('Reference')),
                                  DataColumn(label: Text('Abnormal')),
                                  DataColumn(label: Text('Validated')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: rows.map((r) {
                                  final sid = r['sample_id'] as String;
                                  final testName =
                                      r['test_name'] as String? ?? '';
                                  final sampleCode =
                                      r['sample_code'] as String? ?? '';
                                  final status =
                                      r['status'] as String? ?? 'awaiting';
                                  final collectedAt = r['collected_at'] as int?;
                                  final itemId = r['item_id'] as String;
                                  final res = resByItem[itemId];
                                  final valueNum = res?['value_num'] as num?;
                                  final valueText =
                                      res?['value_text'] as String?;
                                  final refLow = res?['reference_low'] as num?;
                                  final refHigh =
                                      res?['reference_high'] as num?;
                                  final refText =
                                      res?['reference_text'] as String?;
                                  final isAbn =
                                      (res?['is_abnormal'] as int?) == 1;
                                  final validatedAt =
                                      res?['validated_at'] as int?;
                                  final resultId = res?['result_id'] as String?;

                                  return DataRow(
                                    cells: [
                                      DataCell(Text(testName)),
                                      DataCell(Text(sampleCode)),
                                      DataCell(
                                        DropdownButton<String>(
                                          value: status,
                                          items: _statusItems,
                                          onChanged: (v) {
                                            if (v != null) {
                                              _setStatus(sid, v);
                                            }
                                          },
                                        ),
                                      ),
                                      DataCell(Text(_formatTs(collectedAt))),
                                      DataCell(
                                        Text(valueNum?.toString() ?? '—'),
                                      ),
                                      DataCell(Text(valueText ?? '—')),
                                      DataCell(
                                        Text(
                                          refText ??
                                              ((refLow != null ||
                                                      refHigh != null)
                                                  ? '${refLow ?? ''} - ${refHigh ?? ''}'
                                                  : '—'),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          isAbn ? 'Yes' : 'No',
                                          style: TextStyle(
                                            color: isAbn ? Colors.red : null,
                                            fontWeight: isAbn
                                                ? FontWeight.w600
                                                : null,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          validatedAt != null
                                              ? _formatTs(validatedAt)
                                              : '—',
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              tooltip: resultId == null
                                                  ? 'Enter Results'
                                                  : 'Edit Results',
                                              icon: const Icon(Icons.edit_note),
                                              onPressed: () async {
                                                await _openResultDialog(
                                                  itemId: itemId,
                                                  testName: testName,
                                                  sampleCode: sampleCode,
                                                  existing: res,
                                                );
                                                ref.invalidate(
                                                  testResultsByOrderProvider(
                                                    widget.orderId,
                                                  ),
                                                );
                                                ref.invalidate(
                                                  samplesPageProvider(
                                                    widget.orderId,
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              tooltip: 'Validate Result',
                                              icon: const Icon(
                                                Icons.verified_outlined,
                                              ),
                                              onPressed:
                                                  (resultId != null &&
                                                      validatedAt == null)
                                                  ? () async {
                                                      final uid = ref.read(
                                                        currentUserIdProvider,
                                                      );
                                                      if (uid == null) {
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                'Login required to validate',
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return;
                                                      }
                                                      await ref
                                                          .read(
                                                            testResultsRepositoryProvider,
                                                          )
                                                          .validateResult(
                                                            testResultId:
                                                                resultId,
                                                            validatorUserId:
                                                                uid,
                                                          );
                                                      ref.invalidate(
                                                        testResultsByOrderProvider(
                                                          widget.orderId,
                                                        ),
                                                      );
                                                      ref.invalidate(
                                                        samplesPageProvider(
                                                          widget.orderId,
                                                        ),
                                                      );
                                                    }
                                                  : null,
                                            ),
                                            IconButton(
                                              tooltip: 'Delete Sample',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      'Delete Sample',
                                                    ),
                                                    content: const Text(
                                                      'Soft delete this sample?',
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
                                                  await _deleteSample(sid);
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Sample deleted',
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
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Close'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

extension on _CollectSamplesScreenState {
  Future<void> _openResultDialog({
    required String itemId,
    required String testName,
    required String sampleCode,
    Map<String, Object?>? existing,
  }) async {
    final valueNumCtrl = TextEditingController(
      text: (existing?['value_num'] is num)
          ? (existing!['value_num']).toString()
          : '',
    );
    final valueTextCtrl = TextEditingController(
      text: (existing?['value_text'] as String?) ?? '',
    );
    final remarksCtrl = TextEditingController(
      text: (existing?['remarks'] as String?) ?? '',
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Results: $testName ($sampleCode)'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valueNumCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Numeric Value'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: valueTextCtrl,
                decoration: const InputDecoration(labelText: 'Text Value'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final numVal = double.tryParse(valueNumCtrl.text.trim());
              final textVal = valueTextCtrl.text.trim().isEmpty
                  ? null
                  : valueTextCtrl.text.trim();
              final remarks = remarksCtrl.text.trim().isEmpty
                  ? null
                  : remarksCtrl.text.trim();
              if (existing == null || existing['result_id'] == null) {
                await ref
                    .read(testResultsRepositoryProvider)
                    .createResult(
                      testOrderItemId: itemId,
                      valueNum: numVal,
                      valueText: textVal,
                      remarks: remarks,
                    );
              } else {
                await ref
                    .read(testResultsRepositoryProvider)
                    .updateResult(
                      testResultId: existing['result_id'] as String,
                      valueNum: numVal,
                      valueText: textVal,
                      remarks: remarks,
                    );
              }
              if (context.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
