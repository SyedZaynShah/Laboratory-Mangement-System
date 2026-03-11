import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/invoices_providers.dart';
import '../data/payments_providers.dart';
import 'package:printing/printing.dart';
import '../pdf/invoice_template.dart';
import '../../settings/data/lab_profile_repository.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/floating_dropdown_form_field.dart';

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
  String _discountMode = 'percent';

  String _money(int cents) =>
      NumberFormat('###,##0.00').format((cents) / 100.0);
  String _toRupeesString(int cents) => (cents / 100.0).toStringAsFixed(2);
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
      labName: (lab?['lab_name'] as String?) ?? 'AL-MUNEER Clinical Laboratory',
      address:
          (lab?['address'] as String?) ??
          "Main Road People's Colony Mumtazabad Multan",
      phone:
          (lab?['phone'] as String?) ??
          '03007319167 , 03012222861,  0301609884',
      email: (lab?['email'] as String?) ?? '',
      logoBytes: logo,
      invoiceNo: (inv['invoice_no'] as String?) ?? '',
      status: (inv['status'] as String?) ?? '',
      issuedAtSec: (inv['issued_at'] as int?) ?? 0,
      patientName: (inv['patient_name'] as String?) ?? '',
      orderNumber: inv['order_number'] as String?,
      referredBy: inv['referred_by'] as String?,
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
              resultText: r['result_text'] as String?,
              resultNum: r['result_num'] as num?,
              isAbnormal: ((r['result_abnormal'] as int?) ?? 0) == 1,
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
    final subtotal = (inv['subtotal_cents'] as int?) ?? 0;
    final discCents = (inv['discount_cents'] as int?) ?? 0;
    final taxCents = (inv['tax_cents'] as int?) ?? 0;
    final discPct = subtotal > 0 ? (discCents * 100.0) / subtotal : 0.0;
    final net = subtotal - discCents;
    final taxPct = (net > 0) ? (taxCents * 100.0) / net : 0.0;
    _discountCtrl.text = discPct.toStringAsFixed(2);
    _taxCtrl.text = taxPct.toStringAsFixed(2);
  }

  Future<void> _saveHeader(String invoiceId, Map<String, Object?> inv) async {
    final repo = ref.read(invoicesRepositoryProvider);
    final subtotal = (inv['subtotal_cents'] as int?) ?? 0;
    final taxPct = double.tryParse(_taxCtrl.text.trim()) ?? 0.0;
    int discCents = 0;
    int taxCents = 0;
    if (subtotal > 0) {
      if (_discountMode == 'percent') {
        final discPct = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
        discCents = ((subtotal * discPct) / 100.0).round();
      } else {
        final flat = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
        discCents = (flat * 100).round();
      }
      if (discCents < 0) discCents = 0;
      if (discCents > subtotal) discCents = subtotal;
      final net = subtotal - discCents;
      if (net > 0) {
        taxCents = ((net * taxPct) / 100.0).round();
      }
    }
    if (taxCents < 0) taxCents = 0;
    await repo.updateInvoice(
      invoiceId: invoiceId,
      discountCents: discCents,
      taxCents: taxCents,
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
      text: _toRupeesString((row['unit_price_cents'] as int?) ?? 0),
    );
    final discCtrl = TextEditingController(
      text: _toRupeesString((row['discount_cents'] as int?) ?? 0),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Unit Price (PKR)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: discCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Discount (PKR)'),
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
              final unitRp = double.tryParse(unitCtrl.text.trim());
              final discRp = double.tryParse(discCtrl.text.trim());
              final unit = unitRp == null ? null : (unitRp * 100).round();
              final disc = discRp == null ? null : (discRp * 100).round();
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

  Future<void> _markBillPaid(String invoiceId, int currentBalanceCents) async {
    if (currentBalanceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice is already fully paid.')),
      );
      return;
    }

    final repo = ref.read(paymentsRepositoryProvider);
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      await repo.createPayment(
        invoiceId: invoiceId,
        amountCents: currentBalanceCents,
        method: 'cash',
        reference: null,
        receivedAt: ts,
      );
      ref.invalidate(invoiceByIdProvider(invoiceId));
      ref.invalidate(paymentsByInvoiceProvider(invoiceId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked as paid.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError
                ? e.message
                : 'Failed to mark as paid. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _addPaymentDialog(
    String invoiceId,
    int currentBalanceCents,
  ) async {
    final repo = ref.read(paymentsRepositoryProvider);
    final amountCtrl = TextEditingController();
    String method = 'cash';
    final refCtrl = TextEditingController();
    final dateCtrl = TextEditingController(
      text: _date(DateTime.now().millisecondsSinceEpoch ~/ 1000),
    );
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Add Payment'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount (PKR)'),
                ),
                const SizedBox(height: 16),
                FloatingDropdownFormField<String>(
                  value: method,
                  labelText: 'Method',
                  items: const [
                    FloatingDropdownItem(value: 'cash', label: 'Cash'),
                    FloatingDropdownItem(value: 'card', label: 'Card'),
                    FloatingDropdownItem(value: 'bank', label: 'Bank'),
                    FloatingDropdownItem(value: 'other', label: 'Other'),
                  ],
                  onChanged: (v) {
                    setLocalState(() => method = v ?? 'cash');
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(labelText: 'Reference'),
                ),
                const SizedBox(height: 16),
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
                final amtRupees = double.tryParse(amountCtrl.text.trim());
                final amt = (((amtRupees ?? 0) * 100)).round();
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a payment amount greater than 0.'),
                    ),
                  );
                  return;
                }
                if (amt > currentBalanceCents) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Payment cannot exceed the remaining balance.',
                      ),
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
                          if ((inv['order_number'] as String?)?.isNotEmpty ==
                              true)
                            Text('Order: ${inv['order_number']}'),
                          if ((inv['referred_by'] as String?)?.isNotEmpty ==
                              true)
                            Text('Referred by: ${inv['referred_by']}'),
                          Text(
                            'Issued: ${_date((inv['issued_at'] as int?) ?? 0)}',
                          ),
                          Text('Status: ${inv['status']}'),
                        ],
                      ),
                    ),
                    Flexible(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final maxW = constraints.maxWidth;
                          final double discWidth = maxW < 460
                              ? ((maxW - 32).clamp(120.0, 320.0)).toDouble()
                              : 140.0;
                          final double taxWidth = maxW < 460
                              ? ((maxW - 32).clamp(120.0, 320.0)).toDouble()
                              : 160.0;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DropdownButton<String>(
                                value: _discountMode,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'percent',
                                    child: Text('%'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'flat',
                                    child: Text('PKR'),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                  () => _discountMode = v ?? 'percent',
                                ),
                              ),
                              SizedBox(
                                width: discWidth,
                                child: TextField(
                                  controller: _discountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: InputDecoration(
                                    labelText: _discountMode == 'percent'
                                        ? 'Header Discount (%)'
                                        : 'Header Discount (PKR)',
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: taxWidth,
                                child: TextField(
                                  controller: _taxCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Header Tax (%)',
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _saveHeader(widget.invoiceId, inv),
                                child: const Text('Save'),
                              ),
                              FilledButton.icon(
                                onPressed: () {
                                  final its = ref
                                      .read(
                                        invoiceItemsProvider(widget.invoiceId),
                                      )
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
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Totals
                Builder(
                  builder: (context) {
                    final discCents = (inv['discount_cents'] as int?) ?? 0;
                    final taxCents = (inv['tax_cents'] as int?) ?? 0;
                    final subtotal = (inv['subtotal_cents'] as int?) ?? 0;
                    final discPct = subtotal > 0
                        ? (discCents * 100.0) / subtotal
                        : 0.0;
                    final net = subtotal - discCents;
                    final taxPct = net > 0 ? (taxCents * 100.0) / net : 0.0;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Subtotal: ${_money(subtotal)}')),
                        Chip(
                          label: Text(
                            'Discount: ${_money(discCents)} (${discPct.toStringAsFixed(2)}%)',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Tax: ${_money(taxCents)} (${taxPct.toStringAsFixed(2)}%)',
                          ),
                        ),
                        Chip(label: Text('Total: ${_money(total)}')),
                        Chip(label: Text('Paid: ${_money(paid)}')),
                        Chip(label: Text('Balance: ${_money(bal)}')),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Items
                      Expanded(
                        child: GlassSurface(
                          padding: const EdgeInsets.all(12),
                          child: itemsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, st) => Center(child: Text('Error: $e')),
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
                                        DataColumn(label: Text('Test Name')),
                                        DataColumn(label: Text('Result')),
                                        DataColumn(label: Text('Abnormal')),
                                        DataColumn(
                                          label: Text('Qty'),
                                          numeric: true,
                                        ),
                                        DataColumn(
                                          label: Text('Unit Price'),
                                          numeric: true,
                                        ),
                                        DataColumn(
                                          label: Text('Line Discount'),
                                          numeric: true,
                                        ),
                                        DataColumn(
                                          label: Text('Line Total'),
                                          numeric: true,
                                        ),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: items.asMap().entries.map((e) {
                                        final i = e.key;
                                        final it = e.value;
                                        final unit =
                                            (it['unit_price_cents'] as int?) ??
                                            0;
                                        final disc =
                                            (it['discount_cents'] as int?) ?? 0;
                                        final line =
                                            (it['line_total_cents'] as int?) ??
                                            0;
                                        final qty = (it['qty'] as int?) ?? 0;
                                        final resultText =
                                            (it['result_text'] as String?) ??
                                            '';
                                        final resultNum =
                                            (it['result_num'] as num?);
                                        final result = resultText.isNotEmpty
                                            ? resultText
                                            : (resultNum != null
                                                  ? resultNum.toString()
                                                  : '');
                                        final isAbnormal =
                                            ((it['result_abnormal'] as int?) ??
                                                0) ==
                                            1;
                                        return DataRow(
                                          color:
                                              MaterialStateProperty.resolveWith(
                                                (states) {
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
                                                },
                                              ),
                                          cells: [
                                            DataCell(
                                              Text(
                                                (it['test_name'] as String?) ??
                                                    '',
                                              ),
                                            ),
                                            DataCell(Text(result)),
                                            DataCell(
                                              Text(
                                                isAbnormal ? 'Yes' : 'No',
                                                style: TextStyle(
                                                  color: isAbnormal
                                                      ? Colors.red
                                                      : null,
                                                  fontWeight: isAbnormal
                                                      ? FontWeight.w600
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(qty.toString()),
                                              ),
                                            ),
                                            DataCell(
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(_money(unit)),
                                              ),
                                            ),
                                            DataCell(
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(_money(disc)),
                                              ),
                                            ),
                                            DataCell(
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(_money(line)),
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
                      const SizedBox(width: 12),
                      // Payments
                      Expanded(
                        child: GlassSurface(
                          padding: const EdgeInsets.all(12),
                          child: paysAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, st) => Center(child: Text('Error: $e')),
                            data: (pays) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (bal > 0)
                                        OutlinedButton.icon(
                                          onPressed: () => _markBillPaid(
                                            widget.invoiceId,
                                            bal,
                                          ),
                                          icon: const Icon(Icons.check_circle),
                                          label: const Text('Bill Paid'),
                                        ),
                                      if (bal > 0) const SizedBox(width: 8),
                                      FilledButton.icon(
                                        onPressed: () => _addPaymentDialog(
                                          widget.invoiceId,
                                          bal,
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
                                                numeric: true,
                                              ),
                                              DataColumn(label: Text('Method')),
                                              DataColumn(
                                                label: Text('Reference'),
                                              ),
                                              DataColumn(
                                                label: Text('Received At'),
                                              ),
                                            ],
                                            rows: pays.asMap().entries.map((e) {
                                              final i = e.key;
                                              final p = e.value;
                                              final amt =
                                                  (p['amount_cents'] as int?) ??
                                                  0;
                                              final meth =
                                                  (p['method'] as String?) ??
                                                  '';
                                              final refv =
                                                  (p['reference'] as String?) ??
                                                  '';
                                              final rat =
                                                  (p['received_at'] as int?) ??
                                                  0;
                                              return DataRow(
                                                color:
                                                    MaterialStateProperty.resolveWith(
                                                      (states) {
                                                        if (states.contains(
                                                          MaterialState.hovered,
                                                        )) {
                                                          return Theme.of(
                                                                context,
                                                              )
                                                              .colorScheme
                                                              .secondary
                                                              .withOpacity(
                                                                0.10,
                                                              );
                                                        }
                                                        return i.isEven
                                                            ? const Color(
                                                                0x0AFFFFFF,
                                                              )
                                                            : const Color(
                                                                0x06FFFFFF,
                                                              );
                                                      },
                                                    ),
                                                cells: [
                                                  DataCell(
                                                    Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Text(_money(amt)),
                                                    ),
                                                  ),
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
