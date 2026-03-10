import 'package:flutter/material.dart';

class FloatingDropdownItem<T> {
  final T value;
  final String label;
  const FloatingDropdownItem({required this.value, required this.label});
}

class FloatingDropdownFormField<T> extends StatefulWidget {
  final T? value;
  final List<FloatingDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  final String labelText;
  final String? helperText;

  final FormFieldValidator<T?>? validator;
  final AutovalidateMode autovalidateMode;

  final bool enabled;
  final int maxVisibleItems;
  final double itemExtent;
  final double menuBorderRadius;
  final double menuElevation;
  final Duration animationDuration;

  const FloatingDropdownFormField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.labelText,
    this.helperText,
    this.validator,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.enabled = true,
    this.maxVisibleItems = 6,
    this.itemExtent = 48,
    this.menuBorderRadius = 12,
    this.menuElevation = 8,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<FloatingDropdownFormField<T>> createState() =>
      _FloatingDropdownFormFieldState<T>();
}

class _FloatingDropdownFormFieldState<T>
    extends State<FloatingDropdownFormField<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();

  OverlayEntry? _entry;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _removeEntry();
    _controller.dispose();
    super.dispose();
  }

  void _removeEntry() {
    _controller.stop();
    _entry?.remove();
    _entry = null;
  }

  bool get _isOpen => _entry != null;

  void _toggleMenu() {
    if (!widget.enabled) return;
    if (_isOpen) {
      _removeEntry();
      return;
    }

    final overlay = Overlay.of(context);

    final ctx = _fieldKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final fieldTopLeft = box.localToGlobal(Offset.zero);
    final size = box.size;

    _entry = OverlayEntry(
      builder: (context) {
        final mq = MediaQuery.of(context);
        final screenH = mq.size.height;

        final desiredHeight =
            widget.itemExtent * widget.maxVisibleItems.clamp(1, 12);
        final minHeight = widget.itemExtent * 2;

        const margin = 12.0;
        final below = screenH - (fieldTopLeft.dy + size.height) - margin;
        final above = fieldTopLeft.dy - margin;

        final showAbove = below < minHeight && above > below;
        final available = (showAbove ? above : below).clamp(0.0, desiredHeight);

        final height = available <= widget.itemExtent
            ? widget.itemExtent * 2
            : available;

        final yOffset = showAbove ? -(height + 6) : (size.height + 6);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeEntry,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, yOffset),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: Material(
                      elevation: widget.menuElevation,
                      borderRadius: BorderRadius.circular(
                        widget.menuBorderRadius,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: height),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemExtent: widget.itemExtent,
                          itemCount: widget.items.length,
                          itemBuilder: (context, index) {
                            final it = widget.items[index];
                            final selected = it.value == widget.value;
                            return InkWell(
                              onTap: () {
                                widget.onChanged(it.value);
                                _removeEntry();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                alignment: Alignment.centerLeft,
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.10)
                                    : null,
                                child: Text(it.label),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.items
        .where((e) => e.value == widget.value)
        .map((e) => e.label)
        .cast<String?>()
        .firstOrNull;

    return FormField<T>(
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      initialValue: widget.value,
      builder: (state) {
        final theme = Theme.of(context);
        final enabled = widget.enabled;
        final hasError = state.hasError;

        return CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            key: _fieldKey,
            behavior: HitTestBehavior.opaque,
            onTap: () {
              state.didChange(widget.value);
              _toggleMenu();
            },
            child: InputDecorator(
              isEmpty: widget.value == null,
              decoration: InputDecoration(
                labelText: widget.labelText,
                helperText: widget.helperText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                errorText: hasError ? state.errorText : null,
                enabled: enabled,
                suffixIcon: Icon(
                  _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                ),
              ),
              child: Text(
                selectedLabel ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: enabled
                      ? theme.colorScheme.onSurface
                      : theme.disabledColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension _FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
