part of 'directives_screen.dart';

class _DirectiveClosureDraft {
  const _DirectiveClosureDraft({
    required this.remarks,
    required this.burnerDispositions,
  });

  final String remarks;
  final Map<int, BurnerDirectiveComplianceDisposition> burnerDispositions;
}

class _CloseDirectiveDialog extends StatefulWidget {
  const _CloseDirectiveDialog({required this.burnerBinding, this.onSave});
  final Future<void> Function(_DirectiveClosureDraft)? onSave;

  final BurnerRedHotDirectiveBinding? burnerBinding;

  @override
  State<_CloseDirectiveDialog> createState() => _CloseDirectiveDialogState();
}

class _CloseDirectiveDialogState extends State<_CloseDirectiveDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _saveError;
  late final TextEditingController _remarksController;
  final Map<int, BurnerDirectiveComplianceDisposition?> _dispositions = {};

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
    for (final position
        in widget.burnerBinding?.burnerPositions ?? const <int>[]) {
      _dispositions[position] = null;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Close Directive'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: const TextStyle(color: BafColors.danger),
                  ),
                Text(
                  widget.burnerBinding == null
                      ? 'Add a short closure note if useful for traceability.'
                      : 'Record the current UV disposition for every directed burner before closure. This creates a new governed condition round.',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                if (widget.burnerBinding != null) ...[
                  const SizedBox(height: 12),
                  for (final position
                      in widget.burnerBinding!.burnerPositions) ...[
                    DropdownButtonFormField<
                      BurnerDirectiveComplianceDisposition
                    >(
                      initialValue: _dispositions[position],
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Burner $position compliance',
                        prefixIcon: const Icon(Icons.sensors_outlined),
                      ),
                      items: [
                        for (final value
                            in BurnerDirectiveComplianceDisposition.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                      ],
                      validator: (value) =>
                          value == null ? 'Select the outcome.' : null,
                      onChanged: (value) => setState(() {
                        _dispositions[position] = value;
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _remarksController,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: 'Remarks (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.sync,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving
              ? null
              : () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  final draft = _DirectiveClosureDraft(
                    remarks: _remarksController.text,
                    burnerDispositions: {
                      for (final entry in _dispositions.entries)
                        entry.key: entry.value!,
                    },
                  );
                  setState(() => _saving = true);
                  try {
                    await widget.onSave?.call(draft);
                    if (context.mounted) Navigator.pop(context, draft);
                  } catch (error) {
                    if (mounted) {
                      setState(
                        () => _saveError = '$error Your entries remain here.',
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
