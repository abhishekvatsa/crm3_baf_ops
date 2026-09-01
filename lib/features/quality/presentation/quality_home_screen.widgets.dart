part of 'quality_home_screen.dart';

class _RaStateBand extends StatelessWidget {
  const _RaStateBand({required this.abnormality});

  final ChargeAbnormality abnormality;

  @override
  Widget build(BuildContext context) {
    final label = switch (abnormality.reannealingStatus) {
      ReannealingStatus.notApplicable => 'RA not applicable',
      ReannealingStatus.pendingDecision => 'RA decision pending',
      ReannealingStatus.required => 'RA required',
      ReannealingStatus.notRequired => 'RA not required',
      ReannealingStatus.completed =>
        'RA completed · Charge ${abnormality.reannealedToChargeNo}',
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
        children: [
          Icon(Icons.repeat_rounded, size: 18, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
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
    children: [
      Icon(icon, size: 15, color: BafColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: BafColors.textSecondary),
      ),
    ],
  );
}

class _CloseWarningDialog extends StatefulWidget {
  const _CloseWarningDialog({required this.linkedAbnormality});

  final ChargeAbnormality? linkedAbnormality;

  @override
  State<_CloseWarningDialog> createState() => _CloseWarningDialogState();
}

class _CloseWarningDialogState extends State<_CloseWarningDialog> {
  QualityWarningClosureDisposition _disposition =
      QualityWarningClosureDisposition.coilFoundAcceptable;
  final _reason = TextEditingController();
  final _raCharges = TextEditingController();
  String? _error;

  bool get _hasLinkedAbnormality => widget.linkedAbnormality != null;

  bool get _canOfferRaCompletion =>
      !_hasLinkedAbnormality ||
      widget.linkedAbnormality!.reannealingStatus == ReannealingStatus.required;

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
          DropdownButtonFormField<QualityWarningClosureDisposition>(
            isExpanded: true,
            initialValue: _disposition,
            decoration: const InputDecoration(labelText: 'Disposition'),
            items: [
              const DropdownMenuItem(
                value: QualityWarningClosureDisposition.coilFoundAcceptable,
                child: Text('Coil found acceptable'),
              ),
              if (_canOfferRaCompletion)
                const DropdownMenuItem(
                  value: QualityWarningClosureDisposition.reannealingCompleted,
                  child: Text('Re-annealing completed'),
                ),
              const DropdownMenuItem(
                value: QualityWarningClosureDisposition.qualityAdjudication,
                child: Text('Quality adjudication'),
              ),
            ],
            onChanged: (value) => setState(() => _disposition = value!),
          ),
          if (_disposition ==
              QualityWarningClosureDisposition.reannealingCompleted) ...[
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _raCharges,
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
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Decision evidence'),
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
