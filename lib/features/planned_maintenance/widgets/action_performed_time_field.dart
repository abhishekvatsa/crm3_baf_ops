import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String? componentActionTimeError({
  required DateTime? performedAt,
  required DateTime workStartedAt,
  required DateTime now,
  DateTime? workCompletedAt,
}) {
  if (workStartedAt.isAfter(now)) {
    return 'The work start is in the future. Check the work record and device clock.';
  }
  if (workCompletedAt != null && workCompletedAt.isBefore(workStartedAt)) {
    return 'The work end precedes its start. Check the work record.';
  }
  if (performedAt == null) return 'Choose when the work actually happened.';
  if (performedAt.isBefore(workStartedAt)) {
    return 'The work time cannot be before this job or work episode started.';
  }
  if (performedAt.isAfter(now)) {
    return 'The work time cannot be in the future. Check the device clock.';
  }
  if (workCompletedAt != null && performedAt.isAfter(workCompletedAt)) {
    return 'The work time cannot be after the recorded work end.';
  }
  return null;
}

/// The selected physical instant is owned by the form, never by a rebuild.
class ActionPerformedTimeField extends StatelessWidget {
  const ActionPerformedTimeField({
    super.key,
    required this.value,
    required this.workStartedAt,
    required this.onChanged,
    this.workCompletedAt,
  });

  final DateTime? value;
  final DateTime workStartedAt;
  final DateTime? workCompletedAt;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final start = workStartedAt.toLocal();
    final end = workCompletedAt;
    final latest = end != null && end.isBefore(now) ? end.toLocal() : now;
    if (start.isAfter(latest)) return;
    final previous = value?.toLocal();
    final initial = previous == null || previous.isAfter(latest)
        ? latest
        : previous.isBefore(start)
        ? start
        : previous;
    final date = await showDatePicker(
      context: context,
      helpText: 'When did the work happen?',
      initialDate: initial,
      firstDate: start,
      lastDate: latest,
    );
    if (!context.mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      helpText: 'Actual work time',
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!context.mounted || time == null) return;
    onChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = componentActionTimeError(
      performedAt: value,
      workStartedAt: workStartedAt,
      workCompletedAt: workCompletedAt,
      now: DateTime.now(),
    );
    final local = value?.toLocal();
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Actual work / installation time',
        errorText: error,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('action-performed-time'),
            onPressed: () => _pick(context),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              local == null
                  ? 'Choose date and time'
                  : DateFormat('dd MMM yyyy, HH:mm').format(local),
            ),
          ),
          const Text(
            'Use when the work physically happened, even if entering it later. '
            'Select local device time to the minute. If unknown, confirm it before saving.',
          ),
          if (local != null)
            TextButton(
              key: const ValueKey('clear-action-performed-time'),
              onPressed: () => onChanged(null),
              child: const Text('Clear time'),
            ),
        ],
      ),
    );
  }
}
