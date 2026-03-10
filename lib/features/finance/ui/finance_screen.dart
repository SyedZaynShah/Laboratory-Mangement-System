import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/glass_surface.dart';
import '../data/finance_providers.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  int? _fromSec;
  int? _toSec;

  final _expCategory = TextEditingController(text: 'General');
  final _expAmount = TextEditingController();
  final _expNotes = TextEditingController();
  DateTime _expDate = DateTime.now();

  @override
  void dispose() {
    _expCategory.dispose();
    _expAmount.dispose();
    _expNotes.dispose();
    super.dispose();
  }

  String _fmtMoney(int cents) => NumberFormat('###,##0.00').format(cents / 100);

  FinanceQuery _query() {
    return FinanceQuery(
      groupBy: FinanceGroupBy.overall,
      fromSec: _fromSec,
      toSec: _toSec,
    );
  }

  void _refresh() {
    final q = _query();
    ref.invalidate(financeSummaryProvider(q));
    ref.invalidate(financePeriodsProvider(q));
    ref.invalidate(expensesListProvider(q));
  }

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

    if (picked == null) return;
    final dt = DateTime(
      picked.year,
      picked.month,
      picked.day,
      from ? 0 : 23,
      from ? 0 : 59,
    );
    setState(() {
      if (from) {
        _fromSec = dt.millisecondsSinceEpoch ~/ 1000;
      } else {
        _toSec = dt.millisecondsSinceEpoch ~/ 1000;
      }
    });
  }

  Future<void> _addExpense() async {
    final amount = double.tryParse(_expAmount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid expense amount')),
      );
      return;
    }

    final cents = (amount * 100).round();
    final occurredAt =
        DateTime(
          _expDate.year,
          _expDate.month,
          _expDate.day,
          12,
        ).millisecondsSinceEpoch ~/
        1000;

    await ref
        .read(expensesRepositoryProvider)
        .createExpense(
          category: _expCategory.text.trim().isEmpty
              ? 'General'
              : _expCategory.text.trim(),
          amountCents: cents,
          occurredAt: occurredAt,
          notes: _expNotes.text.trim().isEmpty ? null : _expNotes.text.trim(),
        );

    if (!mounted) return;
    ref.invalidate(expensesListProvider(_query()));
    ref.invalidate(financeSummaryProvider(_query()));
    ref.invalidate(financePeriodsProvider(_query()));

    _expAmount.clear();
    _expNotes.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Expense added')));
  }

  @override
  Widget build(BuildContext context) {
    final q = _query();
    final summaryAsync = ref.watch(financeSummaryProvider(q));
    final periodsAsync = ref.watch(financePeriodsProvider(q));
    final expensesAsync = ref.watch(expensesListProvider(q));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickDate(from: true),
                icon: const Icon(Icons.date_range),
                label: Text(
                  _fromSec == null
                      ? 'From'
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
                      ? 'To'
                      : DateFormat('yyyy-MM-dd').format(
                          DateTime.fromMillisecondsSinceEpoch(_toSec! * 1000),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text('Error: $e'),
            data: (s) {
              final invoicesTotal = (s['invoices_total_cents'] as int?) ?? 0;
              final paymentsReceived =
                  (s['payments_received_cents'] as int?) ?? 0;
              final expenses = (s['expenses_cents'] as int?) ?? 0;
              final profit = invoicesTotal - expenses;

              return Row(
                children: [
                  Expanded(
                    child: GlassSurface(
                      padding: const EdgeInsets.all(12),
                      child: _MetricTile(
                        title: 'Invoiced',
                        value: _fmtMoney(invoicesTotal),
                        subtitle: 'Invoices issued',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassSurface(
                      padding: const EdgeInsets.all(12),
                      child: _MetricTile(
                        title: 'Payments',
                        value: _fmtMoney(paymentsReceived),
                        subtitle: 'Payments received',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassSurface(
                      padding: const EdgeInsets.all(12),
                      child: _MetricTile(
                        title: 'Expenses',
                        value: _fmtMoney(expenses),
                        subtitle: 'Recorded expenses',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassSurface(
                      padding: const EdgeInsets.all(12),
                      child: _MetricTile(
                        title: 'Profit',
                        value: _fmtMoney(profit),
                        subtitle: 'Revenue - Expenses',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 62,
                  child: GlassSurface(
                    padding: const EdgeInsets.all(12),
                    child: periodsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('Error: $e')),
                      data: (rows) {
                        if (rows.isEmpty) {
                          return const Center(
                            child: Text(
                              'No finance data for selected filters.',
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 980),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Period')),
                                DataColumn(
                                  label: Text('Orders'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Invoices'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Payments'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Expenses'),
                                  numeric: true,
                                ),
                                DataColumn(
                                  label: Text('Profit'),
                                  numeric: true,
                                ),
                              ],
                              rows: rows.asMap().entries.map((e) {
                                final i = e.key;
                                final r = e.value;
                                final invoicesTotal =
                                    (r['invoices_total_cents'] as int?) ?? 0;
                                final payments =
                                    (r['payments_received_cents'] as int?) ?? 0;
                                final expenses =
                                    (r['expenses_cents'] as int?) ?? 0;
                                final profit = invoicesTotal - expenses;
                                return DataRow(
                                  color: MaterialStateProperty.resolveWith((
                                    states,
                                  ) {
                                    if (states.contains(
                                      MaterialState.hovered,
                                    )) {
                                      return Theme.of(
                                        context,
                                      ).colorScheme.secondary.withOpacity(0.10);
                                    }
                                    return i.isEven
                                        ? const Color(0x0AFFFFFF)
                                        : const Color(0x06FFFFFF);
                                  }),
                                  cells: [
                                    DataCell(
                                      Text((r['period'] as String?) ?? ''),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          ((r['orders_count'] as int?) ?? 0)
                                              .toString(),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(_fmtMoney(invoicesTotal)),
                                      ),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(_fmtMoney(payments)),
                                      ),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(_fmtMoney(expenses)),
                                      ),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(_fmtMoney(profit)),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 38,
                  child: GlassSurface(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add Expense',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _expCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _expAmount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _expNotes,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked == null) return;
                            setState(() => _expDate = picked);
                          },
                          icon: const Icon(Icons.event),
                          label: Text(
                            DateFormat('yyyy-MM-dd').format(_expDate),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: _addExpense,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Recent Expenses',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: expensesAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, st) => Center(child: Text('Error: $e')),
                            data: (rows) {
                              if (rows.isEmpty) {
                                return const Center(child: Text('No expenses'));
                              }
                              return ListView.separated(
                                itemCount: rows.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 12,
                                  color: Colors.white.withOpacity(0.10),
                                ),
                                itemBuilder: (context, i) {
                                  final r = rows[i];
                                  final id = r['id'] as String;
                                  final cat = (r['category'] as String?) ?? '';
                                  final amount =
                                      (r['amount_cents'] as int?) ?? 0;
                                  final ts = (r['occurred_at'] as int?) ?? 0;
                                  final dt = ts == 0
                                      ? ''
                                      : DateFormat('yyyy-MM-dd').format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            ts * 1000,
                                          ),
                                        );
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              cat,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              dt,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.72,
                                                ),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(_fmtMoney(amount)),
                                      IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          await ref
                                              .read(expensesRepositoryProvider)
                                              .deleteExpense(id);
                                          ref.invalidate(
                                            expensesListProvider(q),
                                          );
                                          ref.invalidate(
                                            financeSummaryProvider(q),
                                          );
                                          ref.invalidate(
                                            financePeriodsProvider(q),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  const _MetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 12),
        ),
      ],
    );
  }
}
