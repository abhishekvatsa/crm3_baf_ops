import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Requires an explicit date and time selection; never substitutes save time.
class RaPerformedAtField extends StatelessWidget {
  const RaPerformedAtField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    key: const ValueKey('ra-performed-at'),
    title: const Text('RA performed at'),
    subtitle: Text(
      value == null
          ? 'Choose the actual completion date and time'
          : DateFormat('dd MMM yyyy, HH:mm').format(value!.toLocal()),
    ),
    trailing: const Icon(Icons.calendar_month_outlined),
    onTap: () async {
      final now = DateTime.now();
      final initial = value?.toLocal() ?? now;
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: now,
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null || !context.mounted) return;
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (selected.isAfter(DateTime.now())) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Completion time cannot be in the future.'),
          ),
        );
        return;
      }
      onChanged(selected);
    },
  );
}
