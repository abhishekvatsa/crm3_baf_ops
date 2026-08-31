part of 'operational_events_screen.dart';

class _ResolveEventDialog extends StatefulWidget {
  const _ResolveEventDialog({required this.event});

  final OperationalEvent event;

  @override
  State<_ResolveEventDialog> createState() => _ResolveEventDialogState();
}

class _ResolveEventDialogState extends State<_ResolveEventDialog> {
  final _note = TextEditingController();
  DateTime? _resolvedAt;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickResolvedAt() async {
    final now = DateTime.now();
    final startedAt = widget.event.startedAt.toLocal();
    if (startedAt.isAfter(now)) {
      setState(
        () => _error = 'The recorded disruption start is in the future.',
      );
      return;
    }
    final date = await showDatePicker(
      context: context,
      initialDate:
          _resolvedAt == null || _resolvedAt!.isAfter(now) ? now : _resolvedAt!,
      firstDate: DateTime(startedAt.year, startedAt.month, startedAt.day),
      lastDate: now,
      helpText: 'Select closure date',
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_resolvedAt ?? now),
      helpText: 'Select closure time',
    );
    if (!mounted || time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isBefore(startedAt)) {
      setState(
        () => _error = 'Closure time cannot be before the disruption began.',
      );
      return;
    }
    if (selected.isAfter(DateTime.now())) {
      setState(() => _error = 'Closure time cannot be in the future.');
      return;
    }
    setState(() {
      _resolvedAt = selected;
      _error = null;
    });
  }

  void _submit() {
    final note = _note.text.trim();
    final now = DateTime.now();
    if (_resolvedAt?.isBefore(widget.event.startedAt.toLocal()) == true) {
      setState(
        () => _error = 'Closure time cannot be before the disruption began.',
      );
      return;
    }
    if (_resolvedAt?.isAfter(now) == true) {
      setState(() => _error = 'Closure time cannot be in the future.');
      return;
    }
    if (note.isEmpty || note.length > 1000) {
      setState(
        () => _error = 'Enter a restoration note within 1,000 characters.',
      );
      return;
    }
    Navigator.pop(
      context,
      _EventResolutionInput(note: note, resolvedAt: _resolvedAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd MMM yyyy, HH:mm');
    return AlertDialog(
      title: const Text('Resolve event'),
      content: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: const ValueKey('operational-event-resolution-time'),
                onTap: _pickResolvedAt,
                borderRadius: BorderRadius.circular(BafRadius.medium),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Closure time',
                    prefixIcon: Icon(Icons.schedule_rounded),
                    suffixIcon: Icon(Icons.edit_calendar_rounded),
                  ),
                  child: Text(
                    _resolvedAt == null
                        ? 'Verified server time (recommended)'
                        : format.format(_resolvedAt!),
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (_resolvedAt != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed:
                        () => setState(() {
                          _resolvedAt = null;
                          _error = null;
                        }),
                    icon: const Icon(Icons.cloud_done_outlined),
                    label: const Text('Use server time'),
                  ),
                ),
              const SizedBox(height: BafSpacing.md),
              TextField(
                key: const ValueKey('operational-event-resolution-note'),
                controller: _note,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Restoration and verification note',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: BafSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: BafColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const ValueKey('operational-event-resolution-submit'),
          onPressed: _submit,
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Resolve'),
        ),
      ],
    );
  }
}

class _EventResolutionInput {
  const _EventResolutionInput({required this.note, required this.resolvedAt});

  final String note;
  final DateTime? resolvedAt;
}
