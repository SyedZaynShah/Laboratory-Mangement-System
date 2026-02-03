import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tests_providers.dart';
import '../data/test_model.dart';

class TestFormScreen extends ConsumerStatefulWidget {
  final String? testId;
  const TestFormScreen({super.key, this.testId});

  @override
  ConsumerState<TestFormScreen> createState() => _TestFormScreenState();
}

class _TestFormScreenState extends ConsumerState<TestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  String? _sampleType;
  final _unitCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _unitCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String s) {
    if (s.trim().isEmpty) return null;
    return double.tryParse(s.trim());
  }

  int _parsePriceCents(String s) {
    if (s.trim().isEmpty) return 0;
    final d = double.tryParse(s.trim());
    if (d == null) return 0;
    return (d * 100).round();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final min = _parseDouble(_minCtrl.text);
    final max = _parseDouble(_maxCtrl.text);
    if (min != null && max != null && min > max) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Normal Range Min cannot be greater than Max')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final model = TestModel(
        id: widget.testId,
        testCode: _codeCtrl.text.trim(),
        testName: _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim(),
        sampleType: _sampleType!,
        unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
        normalRangeMin: min,
        normalRangeMax: max,
        priceCents: _parsePriceCents(_priceCtrl.text),
        clinicalNotes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        isActive: true,
      );

      final repo = ref.read(testsRepositoryProvider);
      if (widget.testId == null) {
        await repo.createTest(model);
      } else {
        await repo.updateTest(model);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.testId != null;
    final asyncTest = isEdit ? ref.watch(testByIdProvider(widget.testId!)) : const AsyncValue.data(null);

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Test' : 'Add Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncTest.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
          data: (t) {
            if (t != null && !_loaded) {
              _codeCtrl.text = t.testCode;
              _nameCtrl.text = t.testName;
              _categoryCtrl.text = t.category ?? '';
              _sampleType = t.sampleType;
              _unitCtrl.text = t.unit ?? '';
              _minCtrl.text = t.normalRangeMin?.toString() ?? '';
              _maxCtrl.text = t.normalRangeMax?.toString() ?? '';
              _priceCtrl.text = (t.priceCents / 100.0).toStringAsFixed(2);
              _notesCtrl.text = t.clinicalNotes ?? '';
              _loaded = true;
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(labelText: 'Test Code *'),
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Test Name *'),
                              textInputAction: TextInputAction.next,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _categoryCtrl,
                              decoration: const InputDecoration(labelText: 'Category'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _sampleType,
                              items: const [
                                DropdownMenuItem(value: 'Whole Blood', child: Text('Whole Blood')),
                                DropdownMenuItem(value: 'Serum', child: Text('Serum')),
                                DropdownMenuItem(value: 'Plasma', child: Text('Plasma')),
                                DropdownMenuItem(value: 'Urine', child: Text('Urine')),
                                DropdownMenuItem(value: 'Stool', child: Text('Stool')),
                              ],
                              decoration: const InputDecoration(labelText: 'Sample Type *'),
                              onChanged: (v) => setState(() => _sampleType = v),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _unitCtrl,
                              decoration: const InputDecoration(labelText: 'Unit'),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _priceCtrl,
                              decoration: const InputDecoration(labelText: 'Price'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minCtrl,
                              decoration: const InputDecoration(labelText: 'Normal Range Min'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxCtrl,
                              decoration: const InputDecoration(labelText: 'Normal Range Max'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(labelText: 'Clinical Notes'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: Text(_saving ? 'Saving...' : 'Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
