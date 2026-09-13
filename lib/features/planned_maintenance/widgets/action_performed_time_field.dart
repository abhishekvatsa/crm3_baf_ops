import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/user_model.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/presentation/current_actor_gate.dart';
import '../../auth/providers/auth_provider.dart';

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
    this.originActorUid,
    this.originPermission,
  });

  final DateTime? value;
  final DateTime workStartedAt;
  final DateTime? workCompletedAt;
  final ValueChanged<DateTime?> onChanged;
  final String? originActorUid;
  final bool Function(AppUser)? originPermission;

  bool _canChange(BuildContext context) =>
      originActorUid == null ||
      currentActorActionMessage(
            CurrentActorAccess.resolve(
              ProviderScope.containerOf(
                context,
                listen: false,
              ).read(currentAppUserProvider),
            ),
            originUid: originActorUid,
            permission: originPermission,
          ) ==
          null;

  Widget _protect(Widget child) => originActorUid == null
      ? child
      : CurrentActorDialogGuard(
          originUid: originActorUid!,
          permission: originPermission ?? (actor) => actor.isApproved,
          child: child,
        );

  Future<void> _pick(BuildContext context) async {
    if (!_canChange(context)) return;
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
      builder: (_, child) => _protect(child!),
    );
    if (!context.mounted || date == null || !_canChange(context)) return;
    final time = await showTimePicker(
      context: context,
      helpText: 'Actual work time',
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (_, child) => _protect(child!),
    );
    if (!context.mounted || time == null || !_canChange(context)) return;
    final minute = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    // Reopening the picker at the same minute must retain an existing precise
    // instant. A different minute is an explicit new selection.
    var selected = previous != null && _sameMinute(previous, minute)
        ? previous
        : minute;
    final minuteEnd = minute
        .add(const Duration(minutes: 1))
        .subtract(const Duration(microseconds: 1));
    final intersectsWork =
        !minuteEnd.isBefore(start) && !minute.isAfter(latest);
    if (intersectsWork &&
        componentActionTimeError(
              performedAt: selected,
              workStartedAt: start,
              workCompletedAt: end,
              now: now,
            ) !=
            null) {
      // A minute boundary can be outside a valid, shorter work interval. Show
      // a precise candidate for explicit confirmation; never silently clamp it.
      final suggestion = selected.isBefore(start) ? start : latest;
      final precise = await _pickSeconds(context, suggestion);
      if (!context.mounted || precise == null || !_canChange(context)) return;
      selected = precise;
    }
    onChanged(selected);
  }

  Future<DateTime?> _pickSeconds(BuildContext context, DateTime initial) =>
      showDialog<DateTime>(
        context: context,
        builder: (_) => _protect(
          _ActionSecondsDialog(
            initial: initial,
            workStartedAt: workStartedAt,
            workCompletedAt: workCompletedAt,
          ),
        ),
      );

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
                  : _formatPhysicalTime(local),
            ),
          ),
          const Text(
            'Use when the work physically happened, even if entering it later. '
            'Choose local device time. Adjust seconds when needed. '
            'If unknown, confirm it before saving.',
          ),
          if (local != null)
            Wrap(
              children: [
                TextButton(
                  key: const ValueKey('edit-action-performed-seconds'),
                  onPressed: () async {
                    if (!_canChange(context)) return;
                    final precise = await _pickSeconds(context, local);
                    if (!context.mounted ||
                        precise == null ||
                        !_canChange(context)) {
                      return;
                    }
                    onChanged(precise);
                  },
                  child: const Text('Adjust seconds'),
                ),
                TextButton(
                  key: const ValueKey('clear-action-performed-time'),
                  onPressed: () {
                    if (_canChange(context)) onChanged(null);
                  },
                  child: const Text('Clear time'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

bool _sameMinute(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day &&
    left.hour == right.hour &&
    left.minute == right.minute;

String _secondsText(DateTime value) {
  final fraction = value.millisecond * 1000 + value.microsecond;
  return '${value.second.toString().padLeft(2, '0')}'
      '${fraction == 0 ? '' : '.${fraction.toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '')}'}';
}

String _formatPhysicalTime(DateTime value) =>
    '${DateFormat('dd MMM yyyy, HH:mm').format(value)}:${_secondsText(value)}';

class _ActionSecondsDialog extends StatefulWidget {
  const _ActionSecondsDialog({
    required this.initial,
    required this.workStartedAt,
    required this.workCompletedAt,
  });

  final DateTime initial;
  final DateTime workStartedAt;
  final DateTime? workCompletedAt;

  @override
  State<_ActionSecondsDialog> createState() => _ActionSecondsDialogState();
}

class _ActionSecondsDialogState extends State<_ActionSecondsDialog> {
  late final _seconds = TextEditingController(
    text: _secondsText(widget.initial),
  );

  @override
  void dispose() {
    _seconds.dispose();
    super.dispose();
  }

  DateTime? get _selected {
    final text = _seconds.text.trim();
    if (!RegExp(r'^[0-5]?[0-9](?:\.[0-9]{1,6})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    final fraction = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(6, '0'));
    final minute = widget.initial.toLocal();
    return DateTime(
      minute.year,
      minute.month,
      minute.day,
      minute.hour,
      minute.minute,
      int.parse(parts.first),
      fraction ~/ 1000,
      fraction % 1000,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final error = selected == null
        ? 'Enter seconds from 0 to 59, with up to six decimal places.'
        : componentActionTimeError(
            performedAt: selected,
            workStartedAt: widget.workStartedAt,
            workCompletedAt: widget.workCompletedAt,
            now: DateTime.now(),
          );
    return AlertDialog(
      title: const Text('Confirm actual work time'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat(
                  'dd MMM yyyy, HH:mm',
                ).format(widget.initial.toLocal()),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('action-performed-seconds'),
                controller: _seconds,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Seconds',
                  helperText: 'For example: 50 or 50.25',
                  errorText: error,
                  errorMaxLines: 3,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Work start: ${_formatPhysicalTime(widget.workStartedAt.toLocal())}',
              ),
              if (widget.workCompletedAt != null)
                Text(
                  'Work end: ${_formatPhysicalTime(widget.workCompletedAt!.toLocal())}',
                ),
              const Text(
                'Confirm the physical time; the suggested value is not saved until you choose Use time.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-action-performed-seconds'),
          onPressed: error == null
              ? () => Navigator.pop(context, selected)
              : null,
          child: const Text('Use time'),
        ),
      ],
    );
  }
}
