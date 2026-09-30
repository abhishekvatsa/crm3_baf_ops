part of 'critical_alarm_screen.dart';

class _RaiseAlarmSheet extends StatefulWidget {
  const _RaiseAlarmSheet({required this.definitions});

  final List<CriticalAlarmDefinition> definitions;

  @override
  State<_RaiseAlarmSheet> createState() => _RaiseAlarmSheetState();
}

class _RaiseAlarmSheetState extends State<_RaiseAlarmSheet> {
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _assetNumber = TextEditingController();
  final _details = TextEditingController();
  CriticalAlarmDefinition? _definition;
  String? _assetTypeKey;

  @override
  void dispose() {
    _location.dispose();
    _assetNumber.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      BafSpacing.lg,
      BafSpacing.md,
      BafSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + BafSpacing.lg,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notification_important,
                  color: BafColors.danger,
                  size: 32,
                ),
                const SizedBox(width: BafSpacing.sm),
                const Expanded(
                  child: Text(
                    'Raise critical safety alarm',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<CriticalAlarmDefinition>(
              key: const ValueKey('critical-alarm-reason'),
              initialValue: _definition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Alarm reason',
                border: OutlineInputBorder(),
              ),
              items: widget.definitions
                  .map(
                    (definition) => DropdownMenuItem(
                      value: definition,
                      child: Text(
                        '${definition.name} - ${definition.criticalityLabel}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _definition = value),
              validator: (value) =>
                  value == null ? 'Select the alarm reason' : null,
            ),
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              key: const ValueKey('critical-alarm-location'),
              controller: _location,
              textInputAction: TextInputAction.next,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Exact location or area',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter the location'
                  : null,
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _assetTypeKey,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Related asset class (optional)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('No specific asset')),
                DropdownMenuItem(value: 'base', child: Text('Base')),
                DropdownMenuItem(value: 'furnace', child: Text('Furnace')),
                DropdownMenuItem(
                  value: 'forceCooler',
                  child: Text('Forced Cooler'),
                ),
                DropdownMenuItem(
                  value: 'innerCover',
                  child: Text('Inner Cover'),
                ),
              ],
              onChanged: (value) => setState(() => _assetTypeKey = value),
            ),
            if (_assetTypeKey != null) ...[
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _assetNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Asset number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_assetTypeKey == null) return null;
                  final parsed = int.tryParse(value ?? '');
                  return parsed == null || parsed < 1
                      ? 'Enter a valid asset number'
                      : null;
                },
              ),
            ],
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              key: const ValueKey('critical-alarm-details'),
              controller: _details,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Reason and immediate details',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                if (length == 0) {
                  return 'Enter the reason and immediate details';
                }
                return null;
              },
            ),
            const SizedBox(height: BafSpacing.md),
            Container(
              padding: const EdgeInsets.all(BafSpacing.sm),
              color: BafColors.warning.withValues(alpha: 0.12),
              child: const Text(
                'Requires connectivity. Nothing is queued offline. Follow the plant emergency procedure first.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: BafSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('critical-alarm-review'),
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _AlarmDraft(
                      definition: _definition!,
                      location: _location.text.trim(),
                      assetTypeKey: _assetTypeKey,
                      assetNumber: _assetTypeKey == null
                          ? null
                          : int.parse(_assetNumber.text),
                      details: _details.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Review and confirm'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SupportDialog extends StatefulWidget {
  const _SupportDialog({required this.detailsRequired});

  final bool detailsRequired;

  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _details = TextEditingController();
  CriticalAlarmSupportBasis? _basis;

  @override
  void dispose() {
    _note.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm support response'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CriticalAlarmSupportBasis>(
                initialValue: _basis,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmation basis',
                ),
                items: CriticalAlarmSupportBasis.values
                    .map(
                      (basis) => DropdownMenuItem(
                        value: basis,
                        child: Text(
                          _supportBasisLabel(basis),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _basis = value),
                validator: (value) => value == null ? 'Select a basis' : null,
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Responder note',
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the support response'
                    : null,
              ),
              if (widget.detailsRequired) ...[
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Required incident details',
                    counterText: '',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Incident details are required'
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _SupportDraft(
              basis: _basis!,
              note: _note.text.trim(),
              details: widget.detailsRequired ? _details.text.trim() : null,
            ),
          );
        },
        child: const Text('Confirm support'),
      ),
    ],
  );
}

class _AlarmDraft {
  const _AlarmDraft({
    required this.definition,
    required this.location,
    required this.assetTypeKey,
    required this.assetNumber,
    required this.details,
  });

  final CriticalAlarmDefinition definition;
  final String location;
  final String? assetTypeKey;
  final int? assetNumber;
  final String details;
}

class _SupportDraft {
  const _SupportDraft({
    required this.basis,
    required this.note,
    required this.details,
  });

  final CriticalAlarmSupportBasis basis;
  final String note;
  final String? details;
}

Future<String?> _askText(
  BuildContext context, {
  required String originUid,
  required bool Function(AppUser) permission,
  required String title,
  required String label,
  required int minimum,
  required int maximum,
}) => showDialog<String>(
  context: context,
  builder: (_) => CurrentActorDialogGuard(
    originUid: originUid,
    permission: permission,
    child: _TextEntryDialog(
      title: title,
      label: label,
      minimum: minimum,
      maximum: maximum,
    ),
  ),
);

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.label,
    required this.minimum,
    required this.maximum,
  });

  final String title;
  final String label;
  final int minimum;
  final int maximum;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _value,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: widget.maximum,
          decoration: InputDecoration(
            labelText: widget.label,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final length = value?.trim().length ?? 0;
            if (length < widget.minimum) {
              return 'Enter at least ${widget.minimum} characters';
            }
            if (length > widget.maximum) {
              return 'Keep this within ${widget.maximum} characters';
            }
            return null;
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _value.text.trim());
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

