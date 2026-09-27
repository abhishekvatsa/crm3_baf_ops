part of 'charge_abnormalities_screen.dart';

bool _isResultType(AbnormalityType type) =>
    type.category == AbnormalityCategory.resultQuality ||
    type.category == AbnormalityCategory.reannealing;

extension on _ChargeAbnormalityFormDialogState {
  List<AbnormalityType> get _matchingTypes => _availableTypes
      .where(
        (type) => _observationKind == AbnormalityObservationKind.resultFinding
            ? _isResultType(type)
            : _observationKind == AbnormalityObservationKind.processEquipment
            ? type.category == AbnormalityCategory.process ||
                  type.category == AbnormalityCategory.equipment ||
                  type.category == AbnormalityCategory.other
            : true,
      )
      .toList();

  List<AbnormalityType> get _visibleTypes {
    final values = _matchingTypes;
    // Retain historical selection visibly; do not rewrite its classification.
    if (!values.contains(_selectedType)) values.insert(0, _selectedType);
    return values;
  }

  List<Widget> _assessmentCauseWidgets() => [
    const _SectionTitle(
      icon: Icons.search_outlined,
      title: 'Possible causes',
      subtitle:
          'Optional hypotheses. Linking an issue or observation does not establish causation.',
    ),
    for (var index = 0; index < _candidateCauses.length; index++)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(_candidateCauses[index].description),
        subtitle: Text(_causeLabel(_candidateCauses[index].assessment)),
        onTap: () => _editCause(index),
        trailing: IconButton(
          tooltip: 'Remove candidate cause',
          icon: const Icon(Icons.close),
          onPressed: () =>
              _updateAssessment(() => _candidateCauses.removeAt(index)),
        ),
      ),
    TextButton.icon(
      key: const ValueKey('abnormality-add-cause'),
      onPressed: _candidateCauses.length >= 20 ? null : () => _editCause(null),
      icon: const Icon(Icons.add),
      label: const Text('Add possible cause'),
    ),
    const SizedBox(height: BafSpacing.lg),
  ];

  Future<void> _editCause(int? index) async {
    final value = await showDialog<CandidateProcessCause>(
      context: context,
      builder: (_) => _CauseDialog(
        sourceChargeNo: widget.sourceChargeNo,
        abnormalityId: widget.existing?.firestoreId,
        existing: index == null ? null : _candidateCauses[index],
      ),
    );
    if (!mounted || value == null) return;
    _updateAssessment(() {
      if (index == null) {
        _candidateCauses.add(value);
      } else {
        _candidateCauses[index] = value;
      }
    });
  }
}

String _causeLabel(CauseAssessment value) => switch (value) {
  CauseAssessment.suspected => 'Suspected',
  CauseAssessment.confirmed => 'Confirmed with evidence',
  CauseAssessment.ruledOut => 'Ruled out with evidence',
};

class _CauseDialog extends StatefulWidget {
  const _CauseDialog({
    required this.sourceChargeNo,
    required this.abnormalityId,
    this.existing,
  });
  final int sourceChargeNo;
  final String? abnormalityId;
  final CandidateProcessCause? existing;
  @override
  State<_CauseDialog> createState() => _CauseDialogState();
}

class _CauseDialogState extends State<_CauseDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _evidence;
  late CauseAssessment _assessment;
  String? _ticket;
  String? _process;
  bool _loading = false;
  String? _linkError;
  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.existing?.description);
    _evidence = TextEditingController(text: widget.existing?.evidence);
    _assessment = widget.existing?.assessment ?? CauseAssessment.suspected;
    _ticket = widget.existing?.maintenanceTicketId;
    _process = widget.existing?.processAbnormalityId;
  }

  @override
  void dispose() {
    _description.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _chooseLink(bool maintenance) async {
    setState(() {
      _loading = true;
      _linkError = null;
    });
    try {
      final records = await AbnormalityCauseEvidenceReader().load(
        sourceChargeNo: widget.sourceChargeNo,
        maintenance: maintenance,
        abnormalityId: widget.abnormalityId,
      );
      if (!mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        builder: (context) => ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                maintenance
                    ? 'Maintenance issue on this charge'
                    : 'Existing process observation on this charge',
              ),
            ),
            if (records.isEmpty)
              const ListTile(
                title: Text('No matching recorded evidence available'),
              ),
            for (final record in records)
              ListTile(
                title: Text(record.label),
                onTap: () => Navigator.pop(context, record.id),
              ),
          ],
        ),
      );
      if (mounted && selected != null) {
        setState(() {
          if (maintenance) {
            _ticket = selected;
          } else {
            _process = selected;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _linkError =
              'Recorded evidence could not be loaded. Retry when online.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.existing == null ? 'Add possible cause' : 'Review possible cause',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('abnormality-cause-description'),
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Possible cause'),
              validator: (value) => _requiredTextValidation(
                value,
                label: 'Possible cause',
                maximum: 1000,
              ),
            ),
            DropdownButtonFormField<CauseAssessment>(
              isExpanded: true,
              key: const ValueKey('abnormality-cause-assessment'),
              initialValue: _assessment,
              decoration: const InputDecoration(labelText: 'Assessment'),
              items: CauseAssessment.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_causeLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _assessment = value!),
            ),
            TextFormField(
              key: const ValueKey('abnormality-cause-evidence'),
              controller: _evidence,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Assessment evidence',
                helperText: 'Required for confirmed or ruled-out causes',
              ),
              validator: (value) => _assessment == CauseAssessment.suspected
                  ? _optionalTextValidation(
                      value,
                      label: 'Assessment evidence',
                      maximum: 2000,
                    )
                  : _requiredTextValidation(
                      value,
                      label: 'Assessment evidence',
                      maximum: 2000,
                    ),
            ),
            TextButton(
              key: const ValueKey('abnormality-link-maintenance'),
              onPressed: _loading ? null : () => _chooseLink(true),
              child: Text(
                _ticket == null
                    ? 'Link maintenance issue (optional)'
                    : 'Maintenance issue linked — change',
              ),
            ),
            if (_ticket != null)
              TextButton(
                onPressed: () => setState(() => _ticket = null),
                child: const Text('Remove maintenance link'),
              ),
            TextButton(
              key: const ValueKey('abnormality-link-process'),
              onPressed: _loading ? null : () => _chooseLink(false),
              child: Text(
                _process == null
                    ? 'Link existing process observation (optional)'
                    : 'Process observation linked — change',
              ),
            ),
            if (_process != null)
              TextButton(
                onPressed: () => setState(() => _process = null),
                child: const Text('Remove process link'),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_linkError != null) Text(_linkError!),
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
        key: const ValueKey('abnormality-keep-cause'),
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            CandidateProcessCause(
              id: widget.existing?.id ?? const Uuid().v4(),
              description: _description.text.trim(),
              assessment: _assessment,
              evidence: _emptyToNull(_evidence.text),
              maintenanceTicketId: _ticket,
              processAbnormalityId: _process,
            ),
          );
        },
        child: const Text('Keep assessment'),
      ),
    ],
  );
}
