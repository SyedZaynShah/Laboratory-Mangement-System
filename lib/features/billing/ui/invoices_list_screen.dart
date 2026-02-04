import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/invoices_providers.dart';
import 'invoice_detail_screen.dart';

class InvoicesListScreen extends ConsumerStatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  ConsumerState<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends ConsumerState<InvoicesListScreen> {
  int _page = 1;
  static const int _pageSize = 20;

  String _formatMoney(int cents) => NumberFormat('###,##0.00').format(cents / 100.0);
  String _formatDate(int ts) => DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts * 1000));

  void _refresh() => ref.invalidate(invoicesPageProvider(_page));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(invoicesPageProvider(_page));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Invoices', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) return const Center(child: Text('No invoices'));
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1000),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Invoice No')),
                                DataColumn(label: Text('Patient')),
                                DataColumn(label: Text('Total')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Issued At')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: rows.map((r) {
                                final id = r['id'] as String;
                                final invNo = (r['invoice_no'] as String?) ?? '';
                                final patient = (r['patient_name'] as String?) ?? '';
                                final total = (r['total_cents'] as int?) ?? 0;
                                final status = (r['status'] as String?) ?? '';
                                final issuedAt = (r['issued_at'] as int?) ?? 0;
                                return DataRow(cells: [
                                  DataCell(Text(invNo)),
                                  DataCell(Text(patient)),
                                  DataCell(Text(_formatMoney(total))),
                                  DataCell(Text(status)),
                                  DataCell(Text(_formatDate(issuedAt))),
                                  DataCell(Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Open',
                                        icon: const Icon(Icons.receipt_long),
                                        onPressed: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => InvoiceDetailScreen(invoiceId: id),
                                            ),
                                          );
                                          _refresh();
                                        },
                                      )
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Page $_page'),
                        IconButton(
                          onPressed: _page > 1
                              ? () {
                                  setState(() => _page -= 1);
                                  _refresh();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          onPressed: rows.length >= _pageSize
                              ? () {
                                  setState(() => _page += 1);
                                  _refresh();
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
