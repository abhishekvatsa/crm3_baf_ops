import 'package:flutter/material.dart';

/// Retains the open menu while a live catalogue changes and rejects a choice
/// that was withdrawn after the popup captured its original items.
class LiveDropdownFormField<T> extends StatefulWidget {
  const LiveDropdownFormField({
    super.key,
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.onInvalidSelection,
    this.validator,
    this.decoration = const InputDecoration(),
  });

  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final VoidCallback? onInvalidSelection;
  final FormFieldValidator<T>? validator;
  final InputDecoration decoration;

  @override
  State<LiveDropdownFormField<T>> createState() =>
      _LiveDropdownFormFieldState<T>();
}

class _LiveDropdownFormFieldState<T> extends State<LiveDropdownFormField<T>> {
  final _fieldKey = GlobalKey<FormFieldState<T>>();

  bool _available(T value) =>
      widget.items
          .where((item) => item.value == value && item.enabled)
          .length ==
      1;

  void _changed(T? value) {
    if (value != null && !_available(value)) {
      // DropdownButtonFormField has already updated its internal value before
      // this callback. Restore the current controlled value as well as rejecting
      // the old popup result, otherwise its next build can assert missing items.
      _fieldKey.currentState?.reset();
      widget.onInvalidSelection?.call();
      return;
    }
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: _fieldKey,
    initialValue:
        widget.initialValue != null && _available(widget.initialValue as T)
        ? widget.initialValue
        : null,
    items: widget.items,
    onChanged: widget.onChanged == null ? null : _changed,
    validator: widget.validator,
    decoration: widget.decoration,
    isExpanded: true,
  );
}
