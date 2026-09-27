import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../domain/inner_cover_date_format.dart';
import 'inner_cover_date_picker.dart';

String? innerCoverPhysicalEventError(DateTime value, {DateTime? now}) =>
    value.isAfter(now ?? DateTime.now())
    ? 'Physical event time cannot be in the future. Correct the selected time.'
    : null;

class InnerCoverPhysicalEventField extends StatelessWidget {
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime Function()? clock;

  const InnerCoverPhysicalEventField({
    super.key,
    required this.value,
    required this.onChanged,
    this.clock,
  });

  DateTime _now() => clock?.call() ?? DateTime.now();

  Future<void> _pick(BuildContext context) async {
    final now = _now();
    final date = await showInnerCoverDatePicker(
      context: context,
      initialDate: value.isAfter(now) ? now : value,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'When did the physical change happen?',
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      helpText: 'Physical event time',
    );
    if (time == null || !context.mounted) return;
    // Retain the actual choice, including an invalid future time, so the user
    // can correct it. Never substitute a different occurrence time.
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = innerCoverPhysicalEventError(value, now: _now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.event_available_rounded),
          label: Text(
            'Physical event: ${DateFormat(innerCoverDateTimePattern).format(value.toLocal())}',
          ),
        ),
        const SizedBox(height: BafSpacing.xs),
        const Text(
          'Use when the physical change happened, not when it was recorded.',
          style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: BafSpacing.xs),
            child: Text(error, style: const TextStyle(color: BafColors.danger)),
          ),
      ],
    );
  }
}
