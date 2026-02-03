import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/samples_providers.dart';

class CollectSamplesScreen extends ConsumerStatefulWidget {
  final String orderId;
  const CollectSamplesScreen({super.key, required this.orderId});

  @override
  ConsumerState<CollectSamplesScreen> createState() => _CollectSamplesScreenState();
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
      await ref.read(samplesRepositoryProvider).ensureSamplesForOrder(widget.orderId);
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
    await ref.read(samplesRepositoryProvider).updateSampleStatus(sampleId, status);
    ref.invalidate(samplesPageProvider(widget.orderId));
  }

  Future<void> _deleteSample(String sampleId) async {
    await ref.read(samplesRepositoryProvider).softDeleteSample(sampleId);
    await ref.read(samplesRepositoryProvider).ensureSamplesForOrder(widget.orderId);
    ref.invalidate(samplesPageProvider(widget.orderId));
  }

  Future<void> _collectAll(List<Map<String, Object?>> rows) async {
    setState(() => _bulkWorking = true);
    try {
      for (final r in rows) {
        final sid = r['sample_id'] as String;
        final status = r['status'] as String? ?? 'awaiting';
        if (status == 'awaiting') {
          await ref.read(samplesRepositoryProvider).updateSampleStatus(sid, 'collected');
        }
      }
      ref.invalidate(samplesPageProvider(widget.orderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All awaiting samples marked collected')),
        );
      }
    } finally {
      if (mounted) setState(() => _bulkWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(samplesPageProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collect Samples'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(samplesPageProvider(widget.orderId)),
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
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _bulkWorking ? null : () => _collectAll(rows),
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
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: rows.map((r) {
                                  final sid = r['sample_id'] as String;
                                  final testName = r['test_name'] as String? ?? '';
                                  final sampleCode = r['sample_code'] as String? ?? '';
                                  final status = r['status'] as String? ?? 'awaiting';
                                  final collectedAt = r['collected_at'] as int?;

                                  return DataRow(cells: [
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
                                    DataCell(Row(
                                      children: [
                                        IconButton(
                                          tooltip: 'Delete Sample',
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Sample'),
                                                content: const Text('Soft delete this sample?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await _deleteSample(sid);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Sample deleted')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    )),
                                  ]);
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
                      )
                    ],
                  );
                },
              ),
            ),
    );
  }
}
