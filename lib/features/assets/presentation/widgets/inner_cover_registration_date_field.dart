import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InnerCoverRegistrationDateField extends StatelessWidget {
  final String label;
  final String helperText;
  final DateTime? value;
  final String? errorText;
  final String clearTooltip;
  final String chooseTooltip;
  final VoidCallback onClear;
  final VoidCallback onChoose;

  const InnerCoverRegistrationDateField({
    super.key,
    required this.label,
    required this.helperText,
    required this.value,
    this.errorText,
    required this.clearTooltip,
    required this.chooseTooltip,
    required this.onClear,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      helperText: helperText,
      errorText: errorText,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            value == null
                ? 'Not recorded'
                : DateFormat('dd MMM yyyy').format(value!.toLocal()),
          ),
        ),
        if (value != null)
          IconButton(
            tooltip: clearTooltip,
            onPressed: onClear,
            icon: const Icon(Icons.clear_rounded),
          ),
        IconButton(
          tooltip: chooseTooltip,
          onPressed: onChoose,
          icon: const Icon(Icons.calendar_month_rounded),
        ),
      ],
    ),
  );
}
