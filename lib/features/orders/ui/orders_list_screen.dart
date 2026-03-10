import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../orders/data/test_orders_providers.dart';
import '../../orders/data/test_order_models.dart';
import 'create_order_screen.dart';
import '../../samples/ui/collect_samples_screen.dart';
import '../../billing/data/invoices_providers.dart';
import '../../billing/ui/invoice_detail_screen.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/widgets/glass_surface.dart';

class OrdersListScreen extends ConsumerStatefulWidget {
  const OrdersListScreen({super.key});

  @override
  ConsumerState<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends ConsumerState<OrdersListScreen> {
  int _page = 1;
  static const int _pageSize = 20;

  void _refresh() {
    ref.invalidate(testOrdersPageProvider(_page));
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateOrderScreen()));
    if (ok == true) {
      setState(() {
        _page = 1;
      });
      _refresh();
    }
  }

  String _formatPrice(int? cents) {
    final v = (cents ?? 0) / 100.0;
    return NumberFormat('###,##0.00').format(v);
  }

  String _formatDate(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  // Removed manual nudge helpers to enforce status driven by samples/results only

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(testOrdersPageProvider(_page));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create Order'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (rows) {
                final List<TestOrder> orders = rows;
                if (orders.isEmpty) {
                  return const Center(child: Text('No orders found'));
                }
                return Column(
                  children: [
                    Expanded(
                      child: GlassSurface(
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1000),
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Order No')),
                                  DataColumn(label: Text('Patient Name')),
                                  DataColumn(
                                    label: Text('Tests Count'),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text('Samples')),
                                  DataColumn(
                                    label: Text('Total Amount'),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Ordered At')),
                                  DataColumn(label: Text('Actions')),
                                ],
                                rows: orders
                                    .asMap()
                                    .entries
                                    .map((e) {
                                      final i = e.key;
                                      final o = e.value;
                                      return DataRow(
                                        color:
                                            MaterialStateProperty.resolveWith((
                                              states,
                                            ) {
                                              if (states.contains(
                                                MaterialState.hovered,
                                              )) {
                                                return Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                    .withOpacity(0.10);
                                              }
                                              return i.isEven
                                                  ? const Color(0x0AFFFFFF)
                                                  : const Color(0x06FFFFFF);
                                            }),
                                        cells: [
                                          DataCell(Text(o.orderNumber)),
                                          DataCell(Text(o.patientName ?? '')),
                                          DataCell(
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                (o.testsCount ?? 0).toString(),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              '${o.collectedCount ?? 0}/${o.testsCount ?? 0}',
                                            ),
                                          ),
                                          DataCell(
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                _formatPrice(o.totalCents),
                                              ),
                                            ),
                                          ),
                                          DataCell(StatusPill(o.status)),
                                          DataCell(
                                            Text(_formatDate(o.orderedAt)),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                Tooltip(
                                                  message: 'Invoice',
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.receipt_long,
                                                    ),
                                                    onPressed: () async {
                                                      final repo = ref.read(
                                                        invoicesRepositoryProvider,
                                                      );
                                                      final invId = await repo
                                                          .createInvoice(o.id);
                                                      await Navigator.of(
                                                        context,
                                                      ).push(
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              InvoiceDetailScreen(
                                                                invoiceId:
                                                                    invId,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'View',
                                                  icon: const Icon(
                                                    Icons.visibility_outlined,
                                                  ),
                                                  onPressed: () async {
                                                    await showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: Text(
                                                          'Order ${o.orderNumber}',
                                                        ),
                                                        content: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Patient: ${o.patientName ?? ''}',
                                                            ),
                                                          ],
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  ctx,
                                                                ),
                                                            child: const Text(
                                                              'Close',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  tooltip: 'Collect Samples',
                                                  icon: const Icon(
                                                    Icons.biotech_outlined,
                                                  ),
                                                  onPressed: () async {
                                                    final ok =
                                                        await Navigator.of(
                                                          context,
                                                        ).push<bool>(
                                                          MaterialPageRoute(
                                                            builder: (_) =>
                                                                CollectSamplesScreen(
                                                                  orderId: o.id,
                                                                ),
                                                          ),
                                                        );
                                                    if (ok == true) {
                                                      _refresh();
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    })
                                    .toList(growable: false),
                              ),
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
                          onPressed: orders.length >= _pageSize
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
