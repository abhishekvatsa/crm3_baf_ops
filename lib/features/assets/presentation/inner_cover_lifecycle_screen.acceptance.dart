part of 'inner_cover_lifecycle_screen.dart';

class _AcceptanceResult {
  final DateTime inspectedOn;
  final String acceptanceReference;
  final String? leakTestReference;
  final String? ndtReference;
  final String? notes;
  final String reason;

  const _AcceptanceResult({
    required this.inspectedOn,
    required this.acceptanceReference,
    this.leakTestReference,
    this.ndtReference,
    this.notes,
    required this.reason,
  });
}

class _AcceptanceDialog extends StatefulWidget {
  final Future<InnerCoverProfile> Function(_AcceptanceResult, String) onSubmit;
  const _AcceptanceDialog({required this.onSubmit});

  @override
  State<_AcceptanceDialog> createState() => _AcceptanceDialogState();
}

class _AcceptanceDialogState extends State<_AcceptanceDialog> {
  final _acceptance = TextEditingController();
  final _leak = TextEditingController();
  final _ndt = TextEditingController();
  final _notes = TextEditingController();
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _requestId;
  DateTime? _inspectedOn;
  String? _dateError;
  String? _error;
  bool _busy = false;
  _AcceptanceResult? _submitted;

  Future<void> _chooseInspectionTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _inspectedOn ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_inspectedOn ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _inspectedOn = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _dateError = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_submitted == null) {
      final valid = _formKey.currentState!.validate();
      setState(
        () => _dateError = _inspectedOn == null
            ? 'Choose when the inspection actually took place.'
            : _inspectedOn!.isAfter(DateTime.now())
            ? 'Inspection time cannot be in the future.'
            : null,
      );
      if (!valid || _dateError != null) return;
      String? optional(TextEditingController value) =>
          cleanHierarchyText(value.text);
      _submitted = _AcceptanceResult(
        inspectedOn: _inspectedOn!,
        acceptanceReference: _acceptance.text.trim(),
        leakTestReference: optional(_leak),
        ndtReference: optional(_ndt),
        notes: optional(_notes),
        reason: _reason.text.trim(),
      );
      _requestId = const Uuid().v4();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await widget.onSubmit(_submitted!, _requestId!);
      if (mounted) Navigator.pop(context, profile);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AssetHierarchyCommandRefused
              ? 'Acceptance was refused. Your entries are retained; review and correct them. ${error.message}'
              : '$error';
          if (error is AssetHierarchyCommandRefused) {
            _submitted = null;
            _requestId = null;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _acceptance.dispose();
    _leak.dispose();
    _ndt.dispose();
    _notes.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Accept Inner Cover'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Record the actual inspection time. The server records when acceptance is submitted separately.',
              ),
              TextButton.icon(
                onPressed: _submitted != null ? null : _chooseInspectionTime,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _inspectedOn == null
                      ? 'Choose inspection date and time'
                      : DateFormat('dd MMM yyyy, HH:mm').format(_inspectedOn!),
                ),
              ),
              if (_dateError != null)
                Text(
                  _dateError!,
                  style: const TextStyle(color: BafColors.danger),
                ),
              TextFormField(
                controller: _acceptance,
                readOnly: _submitted != null,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the inspection or acceptance reference.'
                    : value.trim().length > 240
                    ? 'Use at most 240 characters.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Acceptance reference',
                ),
              ),
              TextField(
                controller: _leak,
                readOnly: _submitted != null,
                decoration: const InputDecoration(
                  labelText: 'Leak-test reference',
                ),
              ),
              TextField(
                controller: _ndt,
                readOnly: _submitted != null,
                decoration: const InputDecoration(labelText: 'NDT reference'),
              ),
              TextField(
                controller: _notes,
                readOnly: _submitted != null,
                decoration: const InputDecoration(
                  labelText: 'Inspection notes',
                ),
              ),
              TextFormField(
                controller: _reason,
                readOnly: _submitted != null,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter why this cover is being accepted.'
                    : null,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Acceptance reason',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: BafSpacing.md),
                Text(_error!, style: const TextStyle(color: BafColors.danger)),
                if (_submitted != null)
                  const Text(
                    'Your input is retained while this form stays open. Check or retry this same acceptance before starting another one.',
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: Text(
          _busy
              ? 'Checking…'
              : _submitted == null
              ? 'Accept'
              : 'Check or retry',
        ),
      ),
    ],
  );
}
