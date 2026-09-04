part of 'quality_home_screen.dart';

class _LinkedCaseState extends StatelessWidget {
  const _LinkedCaseState({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BafSpacing.sm),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      border: Border.all(color: color.withValues(alpha: 0.24)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RaStateBand extends StatelessWidget {
  const _RaStateBand({required this.abnormality});

  final ChargeAbnormality abnormality;

  @override
  Widget build(BuildContext context) {
    final label = switch (abnormality.reannealingStatus) {
      ReannealingStatus.notApplicable => 'RA not applicable',
      ReannealingStatus.pendingDecision => 'RA decision pending',
      ReannealingStatus.required => 'RA required · awaiting new charge',
      ReannealingStatus.notRequired => 'RA not required',
      ReannealingStatus.completed =>
        'RA completed · Charge ${abnormality.reannealedToChargeNo}',
    };
    final chargeLink = switch (abnormality.reannealingStatus) {
      ReannealingStatus.required =>
        'Old charge ${abnormality.sourceChargeNo}  →  New RA charge awaiting entry',
      ReannealingStatus.completed =>
        'Old charge ${abnormality.sourceChargeNo}  →  New charge ${abnormality.reannealedToChargeNo}',
      _ => null,
    };
    final color = switch (abnormality.reannealingStatus) {
      ReannealingStatus.required => BafColors.danger,
      ReannealingStatus.pendingDecision => BafColors.warning,
      ReannealingStatus.completed ||
      ReannealingStatus.notRequired => BafColors.sync,
      ReannealingStatus.notApplicable => BafColors.textSecondary,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.repeat_rounded, size: 18, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (chargeLink != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    chargeLink,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final QualityWarningStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      QualityWarningStatus.open => 'Open',
      QualityWarningStatus.closureRequested => 'Review',
      QualityWarningStatus.closed => 'Closed',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _WarningCard._statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _WarningCard._statusColor(status),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: BafColors.textSecondary),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          text,
          softWrap: true,
          style: const TextStyle(fontSize: 12, color: BafColors.textSecondary),
        ),
      ),
    ],
  );
}

class _RecordedOpinion extends StatelessWidget {
  const _RecordedOpinion({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BafSpacing.sm),
    decoration: BoxDecoration(
      color: BafColors.charges.withValues(alpha: 0.06),
      border: Border.all(color: BafColors.charges.withValues(alpha: 0.18)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recorded operational opinion',
          style: TextStyle(
            color: BafColors.charges,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          reason,
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ],
    ),
  );
}

class _ClosureRequestEvidence extends StatelessWidget {
  const _ClosureRequestEvidence({
    required this.warning,
    required this.isRaCompletion,
  });

  final QualityWarning warning;
  final bool isRaCompletion;

  @override
  Widget build(BuildContext context) {
    final actor =
        warning.closureRequestedByName ??
        warning.closureRequestedByUid ??
        'authorised user';
    final occurredAt = warning.closureRequestedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.sm),
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.07),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRaCompletion
                ? 'RA completion submitted for review'
                : 'Closure requested',
            style: const TextStyle(
              color: BafColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            warning.closureRequestReason!,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            occurredAt == null
                ? 'Submitted by $actor'
                : 'Submitted by $actor · ${DateFormat('dd MMM yyyy, HH:mm').format(occurredAt)}',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseWarningDialog extends StatefulWidget {
  const _CloseWarningDialog({
    required this.warning,
    required this.linkedAbnormality,
  });

  final QualityWarning warning;
  final ChargeAbnormality? linkedAbnormality;

  @override
  State<_CloseWarningDialog> createState() => _CloseWarningDialogState();
}

class _CloseWarningDialogState extends State<_CloseWarningDialog> {
  QualityWarningClosureDisposition _disposition =
      QualityWarningClosureDisposition.coilFoundAcceptable;
  late final TextEditingController _reason;
  late final TextEditingController _raCharges;
  String? _error;

  bool get _hasLinkedAbnormality => widget.linkedAbnormality != null;

  bool get _linkedAlreadyCompleted =>
      widget.linkedAbnormality?.reannealingStatus ==
      ReannealingStatus.completed;

  bool get _linkedRequiresRaClosure =>
      widget.linkedAbnormality?.reannealingStatus ==
          ReannealingStatus.required ||
      _linkedAlreadyCompleted;

  bool get _canOfferRaCompletion =>
      !_hasLinkedAbnormality ||
      widget.linkedAbnormality!.reannealingStatus ==
          ReannealingStatus.required ||
      widget.linkedAbnormality!.reannealingStatus ==
          ReannealingStatus.completed;

  @override
  void initState() {
    super.initState();
    final linked = widget.linkedAbnormality;
    _reason = TextEditingController(text: widget.warning.warningReason);
    _raCharges = TextEditingController(
      text: linked?.reannealedToChargeNo?.toString() ?? '',
    );
    if (linked?.reannealingStatus == ReannealingStatus.required ||
        linked?.reannealingStatus == ReannealingStatus.completed) {
      _disposition = QualityWarningClosureDisposition.reannealingCompleted;
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _raCharges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adjudicate quality warning'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecordedOpinion(reason: widget.warning.warningReason),
          const SizedBox(height: BafSpacing.md),
          DropdownButtonFormField<QualityWarningClosureDisposition>(
            isExpanded: true,
            initialValue: _disposition,
            decoration: const InputDecoration(labelText: 'Disposition'),
            items: [
              if (!_linkedRequiresRaClosure)
                const DropdownMenuItem(
                  value: QualityWarningClosureDisposition.coilFoundAcceptable,
                  child: Text('Coil found acceptable'),
                ),
              if (_canOfferRaCompletion)
                const DropdownMenuItem(
                  value: QualityWarningClosureDisposition.reannealingCompleted,
                  child: Text('Re-annealing completed'),
                ),
              if (!_linkedRequiresRaClosure)
                const DropdownMenuItem(
                  value: QualityWarningClosureDisposition.qualityAdjudication,
                  child: Text('Quality adjudication'),
                ),
            ],
            onChanged:
                _linkedRequiresRaClosure
                    ? null
                    : (value) => setState(() {
                      _disposition = value!;
                      if (value !=
                          QualityWarningClosureDisposition
                              .reannealingCompleted) {
                        _raCharges.clear();
                      }
                    }),
          ),
          if (_disposition ==
              QualityWarningClosureDisposition.reannealingCompleted) ...[
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _raCharges,
              readOnly: _linkedAlreadyCompleted,
              keyboardType:
                  _hasLinkedAbnormality
                      ? TextInputType.number
                      : TextInputType.text,
              decoration: InputDecoration(
                labelText:
                    _hasLinkedAbnormality
                        ? 'RA charge number'
                        : 'RA charge numbers',
                hintText: _hasLinkedAbnormality ? '13001' : '13001, 13002',
                helperText:
                    _linkedAlreadyCompleted
                        ? 'Recorded by Operations; correct it in the abnormality record if needed'
                        : null,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            maxLength: 2000,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Decision evidence',
              helperText: 'Pre-filled from the recorded operational opinion',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: BafColors.danger, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final reason = _reason.text.trim();
          final charges = _tryParsePositiveInts(
            _raCharges.text,
            maximum: _hasLinkedAbnormality ? 1 : 20,
          );
          if (reason.isEmpty) {
            setState(() => _error = 'Decision evidence is required.');
            return;
          }
          if (charges == null) {
            setState(
              () =>
                  _error =
                      _hasLinkedAbnormality
                          ? 'Enter one five-digit RA charge number.'
                          : 'Use up to 20 distinct five-digit charge numbers.',
            );
            return;
          }
          if (_disposition ==
                  QualityWarningClosureDisposition.reannealingCompleted &&
              charges.isEmpty) {
            setState(
              () =>
                  _error =
                      _hasLinkedAbnormality
                          ? 'The RA charge number is required.'
                          : 'At least one RA charge number is required.',
            );
            return;
          }
          if (_disposition !=
                  QualityWarningClosureDisposition.reannealingCompleted &&
              charges.isNotEmpty) {
            setState(
              () => _error = 'RA charges apply only to re-annealing closure.',
            );
            return;
          }
          Navigator.pop(
            context,
            _WarningDecision(
              disposition: _disposition,
              reason: reason,
              raChargeNumbers: charges,
            ),
          );
        },
        child: const Text('Close warning'),
      ),
    ],
  );
}

class _RaCompletionInput {
  const _RaCompletionInput({required this.newChargeNo, required this.evidence});

  final int newChargeNo;
  final String evidence;
}

class _RecordRaCompletionDialog extends StatefulWidget {
  const _RecordRaCompletionDialog({
    required this.warning,
    required this.abnormality,
  });

  final QualityWarning warning;
  final ChargeAbnormality abnormality;

  @override
  State<_RecordRaCompletionDialog> createState() =>
      _RecordRaCompletionDialogState();
}

class _RecordRaCompletionDialogState extends State<_RecordRaCompletionDialog> {
  final _newCharge = TextEditingController();
  final _evidence = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _newCharge.dispose();
    _evidence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record re-annealing completion'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecordedOpinion(reason: widget.warning.warningReason),
          const SizedBox(height: BafSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(BafSpacing.sm),
            decoration: BoxDecoration(
              color: BafColors.charges.withValues(alpha: 0.06),
              border: Border.all(
                color: BafColors.charges.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Old charge ${widget.abnormality.sourceChargeNo}  →  New RA charge awaiting entry',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _newCharge,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: chargeNumberInputFormatters,
            decoration: const InputDecoration(
              labelText: 'New RA charge number',
              hintText: '13001',
              helperText: 'Enter the distinct five-digit charge after RA.',
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _evidence,
            maxLength: 2000,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Completion evidence',
              helperText:
                  'The original operational opinion remains linked above.',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              _error!,
              style: const TextStyle(color: BafColors.danger, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final newCharge = int.tryParse(_newCharge.text.trim());
          final evidence = _evidence.text.trim();
          if (newCharge == null || !isValidChargeNumber(newCharge)) {
            setState(() => _error = 'Enter one five-digit RA charge number.');
            return;
          }
          if (newCharge == widget.abnormality.sourceChargeNo) {
            setState(
              () =>
                  _error = 'The new RA charge must differ from the old charge.',
            );
            return;
          }
          if (evidence.isEmpty) {
            setState(() => _error = 'Completion evidence is required.');
            return;
          }
          Navigator.pop(
            context,
            _RaCompletionInput(newChargeNo: newCharge, evidence: evidence),
          );
        },
        child: const Text('Record completion'),
      ),
    ],
  );
}
