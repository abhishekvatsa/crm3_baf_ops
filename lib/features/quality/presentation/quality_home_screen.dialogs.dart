part of 'quality_home_screen.dart';

class _MonitoringRequestDialog extends StatefulWidget {
  const _MonitoringRequestDialog({required this.bases, this.initial});

  final QualityMonitoringRequest? initial;

  final List<AssetInstanceRecord> bases;

  @override
  State<_MonitoringRequestDialog> createState() =>
      _MonitoringRequestDialogState();
}

class _MonitoringRequestDialogState extends State<_MonitoringRequestDialog> {
  final _grade = TextEditingController();
  final _cycle = TextEditingController();
  final _charges = TextEditingController();
  final _reason = TextEditingController();
  String? _selectedBaseId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _grade.text = initial.grade;
      _cycle.text = initial.cycleReference;
      _charges.text = initial.chargeNumbers.join(', ');
      if (widget.bases.any((base) => base.id == initial.baseAssetInstanceId)) {
        _selectedBaseId = initial.baseAssetInstanceId;
      }
    }
  }

  @override
  void dispose() {
    _grade.dispose();
    _cycle.dispose();
    _charges.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.initial == null
          ? 'New quality monitoring request'
          : 'Correct monitoring context',
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.initial != null)
            const Text(
              'The original context and reason remain in history. This correction does not transfer observations or certify a physical charge.',
            ),
          DropdownButtonFormField<String>(
            key: const ValueKey('quality-monitoring-governed-base'),
            initialValue: _selectedBaseId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Governed Base',
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
            ),
            items: [
              for (final base in widget.bases)
                DropdownMenuItem(
                  value: base.id,
                  child: Text(
                    base.displayLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() {
              _selectedBaseId = value;
              _error = null;
            }),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _grade,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Grade'),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _cycle,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Cycle reference'),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _charges,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Charge numbers',
              hintText: 'Optional, comma separated',
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            maxLength: 2000,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.initial == null
                  ? 'Monitoring reason'
                  : 'Correction reason',
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
          final selectedBases = widget.bases
              .where((base) => base.id == _selectedBaseId)
              .toList(growable: false);
          final grade = _grade.text.trim();
          final cycle = _cycle.text.trim();
          final reason = _reason.text.trim();
          final charges = _tryParsePositiveInts(_charges.text, maximum: 50);
          if (selectedBases.length != 1 ||
              grade.isEmpty ||
              cycle.isEmpty ||
              reason.isEmpty) {
            setState(
              () => _error =
                  'Select a governed Base and enter Grade, cycle and a reason.',
            );
            return;
          }
          if (charges == null) {
            setState(
              () => _error = 'Use up to 50 distinct five-digit charge numbers.',
            );
            return;
          }
          final base = selectedBases.single;
          Navigator.pop(
            context,
            _MonitoringInput(
              baseNumber: base.assetNumber,
              baseAssetClassId: base.assetClassId,
              baseAssetInstanceId: base.id,
              baseAssetInstanceVersion: base.version,
              grade: grade,
              cycleReference: cycle,
              chargeNumbers: charges,
              reason: reason,
            ),
          );
        },
        child: Text(
          widget.initial == null ? 'Create' : 'Save audited correction',
        ),
      ),
    ],
  );
}

class _WarningDecision {
  const _WarningDecision({
    required this.disposition,
    required this.reason,
    required this.raChargeNumbers,
    this.raPerformedAt,
  });

  final QualityWarningClosureDisposition disposition;
  final String reason;
  final List<int> raChargeNumbers;
  final DateTime? raPerformedAt;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    this.initialValue,
  });

  final String title;
  final String label;
  final String? initialValue;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLength: 2000,
      maxLines: 4,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label, errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isEmpty) {
            setState(() => _error = 'Enter a reason.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Submit'),
      ),
    ],
  );
}

class _MonitoringInput {
  const _MonitoringInput({
    required this.baseNumber,
    required this.baseAssetClassId,
    required this.baseAssetInstanceId,
    required this.baseAssetInstanceVersion,
    required this.grade,
    required this.cycleReference,
    required this.chargeNumbers,
    required this.reason,
  });

  final int baseNumber;
  final String baseAssetClassId;
  final String baseAssetInstanceId;
  final int baseAssetInstanceVersion;
  final String grade;
  final String cycleReference;
  final List<int> chargeNumbers;
  final String reason;
}

List<int>? _tryParsePositiveInts(String raw, {required int maximum}) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) return <int>[];
  final tokens = cleaned.split(RegExp(r'[,\s]+'));
  if (tokens.length > maximum) return null;
  final values = <int>[];
  for (final token in tokens) {
    final value = int.tryParse(token);
    if (value == null ||
        !isValidChargeNumber(value) ||
        values.contains(value)) {
      return null;
    }
    values.add(value);
  }
  values.sort();
  return values;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(icon, size: 44, color: BafColors.textSecondary),
        const SizedBox(height: BafSpacing.md),
        Text(
          title,
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _WindowScopeNotice extends StatelessWidget {
  const _WindowScopeNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.history_rounded,
        size: 16,
        color: BafColors.textSecondary,
      ),
      const SizedBox(width: BafSpacing.xs),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: BafColors.danger),
          const SizedBox(height: BafSpacing.md),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: BafSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
          const SizedBox(height: BafSpacing.md),
          IconButton(
            onPressed: onRetry,
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );
}
