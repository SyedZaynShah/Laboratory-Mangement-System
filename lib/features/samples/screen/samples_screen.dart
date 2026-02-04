import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/samples_providers.dart';

class SamplesScreen extends ConsumerStatefulWidget {
  const SamplesScreen({super.key});

  @override
  ConsumerState<SamplesScreen> createState() => _SamplesScreenState();
}

class _SamplesScreenState extends ConsumerState<SamplesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _statuses = const [
    'awaiting',
    'collected',
    'received',
    'processed',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTs(int? sec) {
    if (sec == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  String? _nextStatus(String status) {
    switch (status) {
      case 'awaiting':
        return 'collected';
      case 'collected':
        return 'received';
      case 'received':
        return 'processed';
      default:
        return null;
    }
  }

  Future<void> _bulkAdvance(String status) async {
    final next = _nextStatus(status);
    if (next == null) return;
    final rows = await ref.read(samplesQueueProvider(status).future);
    final byOrder = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final oid = r['order_id'] as String;
      byOrder.putIfAbsent(oid, () => <Map<String, Object?>>[]).add(r);
    }
    for (final entry in byOrder.entries) {
      await ref
          .read(samplesRepositoryProvider)
          .bulkUpdateSamplesForOrder(
            orderId: entry.key,
            fromStatuses: [status],
            toStatus: next,
          );
    }
    ref.invalidate(samplesQueueProvider(status));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Awaiting'),
              Tab(text: 'Collected'),
              Tab(text: 'Received'),
              Tab(text: 'Processed'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _statuses.map((status) {
                final async = ref.watch(samplesQueueProvider(status));
                final next = _nextStatus(status);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (next != null)
                          ElevatedButton.icon(
                            onPressed: () => _bulkAdvance(status),
                            icon: const Icon(Icons.fast_forward),
                            label: Text('Mark all $status → $next'),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Refresh',
                          icon: const Icon(Icons.refresh),
                          onPressed: () =>
                              ref.invalidate(samplesQueueProvider(status)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: async.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, st) => Center(child: Text('Error: $e')),
                        data: (rows) {
                          if (rows.isEmpty) {
                            return Center(child: Text('No $status samples'));
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 1100),
                              child: SingleChildScrollView(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Sample Code')),
                                    DataColumn(label: Text('Patient')),
                                    DataColumn(label: Text('Order No')),
                                    DataColumn(label: Text('Test')),
                                    DataColumn(label: Text('Status')),
                                    DataColumn(label: Text('Collected At')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: rows.map((r) {
                                    final sid = r['sample_id'] as String;
                                    final sampleCode =
                                        (r['sample_code'] as String?) ?? '';
                                    final patientName =
                                        (r['patient_name'] as String?) ?? '';
                                    final orderNo =
                                        (r['order_number'] as String?) ?? '';
                                    final testName =
                                        (r['test_name'] as String?) ?? '';
                                    final s = (r['status'] as String?) ?? '';
                                    final collectedAt =
                                        r['collected_at'] as int?;
                                    final nextS = _nextStatus(s);
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(sampleCode)),
                                        DataCell(Text(patientName)),
                                        DataCell(Text(orderNo)),
                                        DataCell(Text(testName)),
                                        DataCell(Text(s)),
                                        DataCell(Text(_formatTs(collectedAt))),
                                        DataCell(
                                          Row(
                                            children: [
                                              if (nextS != null)
                                                IconButton(
                                                  tooltip: 'Mark $s → $nextS',
                                                  icon: const Icon(
                                                    Icons.play_arrow,
                                                  ),
                                                  onPressed: () async {
                                                    await ref
                                                        .read(
                                                          samplesRepositoryProvider,
                                                        )
                                                        .updateSampleStatus(
                                                          sid,
                                                          nextS,
                                                        );
                                                    ref.invalidate(
                                                      samplesQueueProvider(
                                                        status,
                                                      ),
                                                    );
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
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
