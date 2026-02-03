import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/tests_providers.dart';
import '../data/test_model.dart';
import 'test_form_screen.dart';

class TestsListScreen extends ConsumerStatefulWidget {
  const TestsListScreen({super.key});

  @override
  ConsumerState<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends ConsumerState<TestsListScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _query = _searchCtrl.text.trim();
        _page = 1;
      });
    });
  }

  void _refresh() {
    if (_query.isEmpty) {
      ref.invalidate(testsPageProvider(_page));
    } else {
      ref.invalidate(testsSearchProvider(_query));
    }
  }

  Future<void> _openForm({String? id}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TestFormScreen(testId: id)),
    );
    if (result == true) {
      _refresh();
    }
  }

  String _formatPrice(int cents) {
    final v = cents / 100.0;
    return NumberFormat('###,##0.00').format(v);
  }

  String _formatRange(double? min, double? max) {
    if (min == null && max == null) return '';
    final nf = NumberFormat('0.###');
    final a = min != null ? nf.format(min) : '';
    final b = max != null ? nf.format(max) : '';
    if (a.isEmpty) return '≤ $b';
    if (b.isEmpty) return '≥ $a';
    return '$a – $b';
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = _query.isEmpty
        ? ref.watch(testsPageProvider(_page))
        : ref.watch(testsSearchProvider(_query));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search code, name, or category',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Add Test'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (rows) {
                final List<TestModel> tests = rows;
                if (tests.isEmpty) {
                  return const Center(child: Text('No tests found'));
                }
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1100),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Code')),
                                DataColumn(label: Text('Test Name')),
                                DataColumn(label: Text('Category')),
                                DataColumn(label: Text('Sample')),
                                DataColumn(label: Text('Unit')),
                                DataColumn(label: Text('Normal Range')),
                                DataColumn(label: Text('Price')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: tests.map((t) {
                                return DataRow(cells: [
                                  DataCell(Text(t.testCode)),
                                  DataCell(Text(t.testName)),
                                  DataCell(Text(t.category ?? '')),
                                  DataCell(Text(t.sampleType)),
                                  DataCell(Text(t.unit ?? '')),
                                  DataCell(Text(_formatRange(t.normalRangeMin, t.normalRangeMax))),
                                  DataCell(Text(_formatPrice(t.priceCents))),
                                  DataCell(Text(t.isActive ? 'Active' : 'Inactive')),
                                  DataCell(Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _openForm(id: t.id),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: 'Soft Delete',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Test'),
                                              content: const Text('Soft delete this test? It will be hidden but not removed.'),
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
                                          if (confirm == true && t.id != null) {
                                            await ref.read(testsRepositoryProvider).softDeleteTest(t.id!);
                                            _refresh();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Test deleted')),
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
                    const SizedBox(height: 8),
                    if (_query.isEmpty)
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
                            onPressed: tests.length >= _pageSize
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
