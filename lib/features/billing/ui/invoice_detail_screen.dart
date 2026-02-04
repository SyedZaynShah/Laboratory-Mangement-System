import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/invoices_providers.dart';
import '../data/payments_providers.dart';
import 'package:printing/printing.dart';
import '../pdf/invoice_template.dart';
import '../../settings/data/lab_profile_repository.dart';

class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  final _discountCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();

  String _money(int cents) =>
      NumberFormat('###,##0.00').format((cents) / 100.0);
  String _date(int ts) => DateFormat(
    'yyyy-MM-dd HH:mm',
  ).format(DateTime.fromMillisecondsSinceEpoch(ts * 1000));

  @override
  void dispose() {
    _discountCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportPdf(
    Map<String, Object?> inv,
    List<Map<String, Object?>> items,
  ) async {
    final labRepo = ref.read(labProfileRepositoryProvider);
    final lab = await labRepo.getProfile();
    final logo = await labRepo.loadLogoBytes();
    final data = InvoicePdfData(
      labName: (lab?['lab_name'] as String?) ?? 'Laboratory',
      address: (lab?['address'] as String?) ?? '',
      phone: (lab?['phone'] as String?) ?? '',
      email: (lab?['email'] as String?) ?? '',
      logoBytes: logo,
      invoiceNo: (inv['invoice_no'] as String?) ?? '',
      status: (inv['status'] as String?) ?? '',
      issuedAtSec: (inv['issued_at'] as int?) ?? 0,
      patientName: (inv['patient_name'] as String?) ?? '',
      items: items
          .map(
            (r) => InvoicePdfItem(
              description:
                  (r['description'] as String?) ??
                  (r['test_name'] as String? ?? ''),
              qty: (r['qty'] as int?) ?? 0,
              unitPriceCents: (r['unit_price_cents'] as int?) ?? 0,
              discountCents: (r['discount_cents'] as int?) ?? 0,
              lineTotalCents: (r['line_total_cents'] as int?) ?? 0,
            ),
          )
          .toList(),
      headerDiscountCents: (inv['discount_cents'] as int?) ?? 0,
      headerTaxCents: (inv['tax_cents'] as int?) ?? 0,
      subtotalCents: (inv['subtotal_cents'] as int?) ?? 0,
      totalCents: (inv['total_cents'] as int?) ?? 0,
      paidCents: (inv['paid_cents'] as int?) ?? 0,
      balanceCents: (inv['balance_cents'] as int?) ?? 0,
    );
    final bytes = await buildInvoicePdf(data);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  void _prefillHeader(Map<String, Object?> inv) {
    _discountCtrl.text = ((inv['discount_cents'] as int?) ?? 0).toString();
    _taxCtrl.text = ((inv['tax_cents'] as int?) ?? 0).toString();
  }

  Future<void> _saveHeader(String invoiceId) async {
    final repo = ref.read(invoicesRepositoryProvider);
    final disc = int.tryParse(_discountCtrl.text.trim());
    final tax = int.tryParse(_taxCtrl.text.trim());
    await repo.updateInvoice(
      invoiceId: invoiceId,
      discountCents: disc,
      taxCents: tax,
    );
    ref.invalidate(invoiceByIdProvider(invoiceId));
  }

  Future<void> _editItemDialog(Map<String, Object?> row) async {
    final repo = ref.read(invoicesRepositoryProvider);
    final id = row['id'] as String;
    final qtyCtrl = TextEditingController(
      text: (row['qty'] as int?)?.toString() ?? '1',
    );
    final unitCtrl = TextEditingController(
      text: (row['unit_price_cents'] as int?)?.toString() ?? '0',
    );
    final discCtrl = TextEditingController(
      text: (row['discount_cents'] as int?)?.toString() ?? '0',
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Item'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: unitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unit Price (cents)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: discCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Discount (cents)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text.trim());
              final unit = int.tryParse(unitCtrl.text.trim());
              final disc = int.tryParse(discCtrl.text.trim());
              await repo.updateInvoiceItem(
                invoiceItemId: id,
                qty: qty,
                unitPriceCents: unit,
                discountCents: disc,
              );
              if (mounted) Navigator.pop(ctx);
              ref.invalidate(invoiceItemsProvider(row['invoice_id'] as String));
              ref.invalidate(invoiceByIdProvider(row['invoice_id'] as String));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPaymentDialog(String invoiceId) async {
    final repo = ref.read(paymentsRepositoryProvider);
    final amountCtrl = TextEditingController();
    String method = 'cash';
    final refCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: _date(DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (cents)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: method,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'card', child: Text('Card')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => method = v ?? 'cash',
                decoration: const InputDecoration(labelText: 'Method'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'Reference'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Received At'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a payment amount greater than 0.'),
                  ),
                );
                return;
              }
              final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              try {
                await repo.createPayment(
                  invoiceId: invoiceId,
                  amountCents: amt,
                  method: method,
                  reference: refCtrl.text.trim().isEmpty
                      ? null
                      : refCtrl.text.trim(),
                  receivedAt: ts,
                );
                if (mounted) Navigator.pop(ctx);
                ref.invalidate(invoiceByIdProvider(invoiceId));
                ref.invalidate(paymentsByInvoiceProvider(invoiceId));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e is StateError
                          ? e.message
                          : 'Failed to add payment. Please try again.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invAsync = ref.watch(invoiceByIdProvider(widget.invoiceId));
    final itemsAsync = ref.watch(invoiceItemsProvider(widget.invoiceId));
    final paysAsync = ref.watch(paymentsByInvoiceProvider(widget.invoiceId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invoice Detail')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: invAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (inv) {
            if (inv == null)
              return const Center(child: Text('Invoice not found'));
            _prefillHeader(inv);
            final total = (inv['total_cents'] as int?) ?? 0;
            final paid = (inv['paid_cents'] as int?) ?? 0;
            final bal = (inv['balance_cents'] as int?) ?? 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice ${inv['invoice_no']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text('Patient: ${inv['patient_name'] ?? ''}'),
                          Text(
                            'Issued: ${_date((inv['issued_at'] as int?) ?? 0)}',
                          ),
                          Text('Status: ${inv['status']}'),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 360,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _discountCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Header Discount (cents)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _taxCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Header Tax (cents)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _saveHeader(widget.invoiceId),
                            child: const Text('Save'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () {
                              final its = ref
                                  .read(invoiceItemsProvider(widget.invoiceId))
                                  .maybeWhen(
                                    data: (rows) => rows,
                                    orElse: () => <Map<String, Object?>>[],
                                  );
                              _exportPdf(inv, its);
                            },
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Totals
                Row(
                  children: [
                    Chip(label: Text('Total: ${_money(total)}')),
                    const SizedBox(width: 8),
                    Chip(label: Text('Paid: ${_money(paid)}')),
                    const SizedBox(width: 8),
                    Chip(label: Text('Balance: ${_money(bal)}')),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Items
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: itemsAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, st) =>
                                  Center(child: Text('Error: $e')),
                              data: (items) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minWidth: 800,
                                    ),
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('Test')),
                                          DataColumn(
                                            label: Text('Description'),
                                          ),
                                          DataColumn(label: Text('Qty')),
                                          DataColumn(label: Text('Unit (¢)')),
                                          DataColumn(
                                            label: Text('Discount (¢)'),
                                          ),
                                          DataColumn(
                                            label: Text('Line Total (¢)'),
                                          ),
                                          DataColumn(label: Text('Actions')),
                                        ],
                                        rows: items.map((it) {
                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  (it['test_name']
                                                          as String?) ??
                                                      '',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  (it['description']
                                                          as String?) ??
                                                      '',
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  ((it['qty'] as int?) ?? 0)
                                                      .toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  ((it['unit_price_cents']
                                                              as int?) ??
                                                          0)
                                                      .toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  ((it['discount_cents']
                                                              as int?) ??
                                                          0)
                                                      .toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  ((it['line_total_cents']
                                                              as int?) ??
                                                          0)
                                                      .toString(),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'Edit',
                                                      icon: const Icon(
                                                        Icons.edit,
                                                      ),
                                                      onPressed: () =>
                                                          _editItemDialog(it),
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Payments
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: paysAsync.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              error: (e, st) =>
                                  Center(child: Text('Error: $e')),
                              data: (pays) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: () => _addPaymentDialog(
                                            widget.invoiceId,
                                          ),
                                          icon: const Icon(Icons.attach_money),
                                          label: const Text('Add Payment'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            minWidth: 600,
                                          ),
                                          child: SingleChildScrollView(
                                            child: DataTable(
                                              columns: const [
                                                DataColumn(
                                                  label: Text('Amount'),
                                                ),
                                                DataColumn(
                                                  label: Text('Method'),
                                                ),
                                                DataColumn(
                                                  label: Text('Reference'),
                                                ),
                                                DataColumn(
                                                  label: Text('Received At'),
                                                ),
                                              ],
                                              rows: pays.map((p) {
                                                final amt =
                                                    (p['amount_cents']
                                                        as int?) ??
                                                    0;
                                                final meth =
                                                    (p['method'] as String?) ??
                                                    '';
                                                final refv =
                                                    (p['reference']
                                                        as String?) ??
                                                    '';
                                                final rat =
                                                    (p['received_at']
                                                        as int?) ??
                                                    0;
                                                return DataRow(
                                                  cells: [
                                                    DataCell(Text(_money(amt))),
                                                    DataCell(Text(meth)),
                                                    DataCell(Text(refv)),
                                                    DataCell(Text(_date(rat))),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
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
