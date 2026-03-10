import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/kpi_card.dart';
import '../data/patients_providers.dart';

class PatientInsightsDetailScreen extends ConsumerWidget {
  final String patientId;
  final String patientName;
  const PatientInsightsDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  String _money(int cents) =>
      NumberFormat('###,##0.00').format((cents) / 100.0);
  String _date(int ts) => DateFormat(
    'yyyy-MM-dd HH:mm',
  ).format(DateTime.fromMillisecondsSinceEpoch(ts * 1000));

  int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTimeline = ref.watch(patientInsightTimelineProvider(patientId));

    return Scaffold(
      appBar: AppBar(title: Text(patientName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncTimeline.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(child: Text('No activity in this period'));
            }

            final totalOrders = rows.length;
            final totalTests = rows.fold<int>(
              0,
              (a, r) => a + _asInt(r['tests_count']),
            );
            final totalCents = rows.fold<int>(
              0,
              (a, r) => a + _asInt(r['total_cents']),
            );
            final receivedCents = rows.fold<int>(
              0,
              (a, r) => a + _asInt(r['cash_received_cents']),
            );
            final balanceCents = rows.fold<int>(
              0,
              (a, r) => a + _asInt(r['balance_cents']),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: KpiCard(
                          title: 'Orders',
                          value: '$totalOrders',
                          icon: Icons.assignment,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
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
                          value: _money(totalCents),
                          icon: Icons.receipt_long,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: KpiCard(
                          title: 'Received',
                          value: _money(receivedCents),
                          icon: Icons.payments,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 260,
                        child: KpiCard(
                          title: 'Balance',
                          value: _money(balanceCents),
                          icon: Icons.account_balance_wallet,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final orderNo = (r['order_number'] as String?) ?? '';
                      final orderedAt = _asInt(r['ordered_at']);
                      final tests = _asInt(r['tests_count']);
                      final total = _asInt(r['total_cents']);
                      final received = _asInt(r['cash_received_cents']);
                      final bal = _asInt(r['balance_cents']);
                      final status = (r['status'] as String?) ?? '-';

                      return ListTile(
                        title: Text('Order $orderNo'),
                        subtitle: Text(
                          '${_date(orderedAt)}  •  $tests tests  •  $status',
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total: ${_money(total)}'),
                            Text('Paid: ${_money(received)}'),
                            Text('Bal: ${_money(bal)}'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
