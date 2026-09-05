part of 'inspection_programmes_screen.dart';

class _InspectionTargetOption {
  const _InspectionTargetOption({
    required this.number,
    required this.label,
    required this.detail,
  });

  final int number;
  final String label;
  final String detail;
}

List<_InspectionTargetOption> _installedInnerCoverTargetOptions({
  required String subjectAssetClassId,
  required String hostAssetClassId,
  required List<AssetInstanceRecord> assets,
  required Map<String, InnerCoverProfile> profilesById,
  required List<BaseInnerCoverAssignment> assignments,
}) {
  final hostAssetsById = <String, AssetInstanceRecord>{
    for (final asset in assets)
      if (asset.isActive && asset.assetClassId == hostAssetClassId)
        asset.id: asset,
  };
  final options = <_InspectionTargetOption>[];
  for (final assignment in assignments) {
    final host = hostAssetsById[assignment.baseAssetInstanceId];
    final profile = profilesById[assignment.innerCoverId];
    if (host == null ||
        profile == null ||
        profile.assetClassId != subjectAssetClassId ||
        !profile.isInstalled ||
        host.assetNumber != assignment.baseAssetNumber ||
        assignment.baseAssetClassId != hostAssetClassId ||
        profile.currentBaseAssetInstanceId != assignment.baseAssetInstanceId ||
        profile.currentBaseAssetNumber != assignment.baseAssetNumber ||
        profile.currentLinkageId != assignment.linkageId ||
        profile.serialNumber != assignment.innerCoverSerialNumber) {
      continue;
    }
    options.add(
      _InspectionTargetOption(
        number: assignment.baseAssetNumber,
        label: 'Base ${assignment.baseAssetNumber} (${profile.serialNumber})',
        detail: 'Installed Inner Cover ${profile.serialNumber}',
      ),
    );
  }
  options.sort((left, right) => left.number.compareTo(right.number));
  return options;
}

class _GovernedInspectionTargetField extends StatelessWidget {
  const _GovernedInspectionTargetField({
    required this.options,
    required this.selectedNumbers,
    required this.installedInnerCovers,
    required this.onChoose,
  });

  final List<_InspectionTargetOption> options;
  final Set<int> selectedNumbers;
  final bool installedInnerCovers;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final selected = options
        .where((item) => selectedNumbers.contains(item.number))
        .toList(growable: false);
    final preview = selected.take(4).map((item) => item.label).join(' · ');
    final remainder = selected.length - 4;
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(
          color: options.isEmpty ? BafColors.danger : BafColors.borderStrong,
        ),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final enlargedText =
                  MediaQuery.textScalerOf(context).scale(14) > 18;
              final compact = constraints.maxWidth < 320 || enlargedText;
              final heading = Row(
                children: [
                  const Icon(Icons.account_tree_outlined),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: Text(
                      installedInnerCovers
                          ? 'Installed Inner Covers by Base'
                          : 'Governed target assets',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              );
              final choose = TextButton.icon(
                onPressed: options.isEmpty ? null : onChoose,
                icon: const Icon(Icons.checklist_rounded),
                label: const Text('Choose'),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    Align(alignment: Alignment.centerRight, child: choose),
                  ],
                );
              }
              return Row(children: [Expanded(child: heading), choose]);
            },
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            options.isEmpty
                ? installedInnerCovers
                    ? 'No active Base and installed Inner Cover pair is available.'
                    : 'No active governed asset is available for this definition.'
                : selected.isEmpty
                ? 'No target selected.'
                : '$preview${remainder > 0 ? ' · +$remainder more' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color:
                  options.isEmpty || selected.isEmpty
                      ? BafColors.danger
                      : BafColors.textSecondary,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            '${selected.length} of ${options.length} selected. Every selected target remains accountable in the campaign.',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _InspectionTargetPickerDialog extends StatefulWidget {
  const _InspectionTargetPickerDialog({
    required this.options,
    required this.selectedNumbers,
  });

  final List<_InspectionTargetOption> options;
  final Set<int> selectedNumbers;

  @override
  State<_InspectionTargetPickerDialog> createState() =>
      _InspectionTargetPickerDialogState();
}

class _InspectionTargetPickerDialogState
    extends State<_InspectionTargetPickerDialog> {
  late final Set<int> _selected;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.selectedNumbers);
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = widget.options
        .where(
          (item) =>
              query.isEmpty ||
              item.label.toLowerCase().contains(query) ||
              item.detail.toLowerCase().contains(query) ||
              item.number.toString().contains(query),
        )
        .toList(growable: false);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(BafSpacing.md),
      title: const Text('Choose governed targets'),
      content: SizedBox(
        width: 520,
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search assets',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            Row(
              children: [
                Text('${_selected.length} selected'),
                const Spacer(),
                TextButton(
                  onPressed:
                      () => setState(
                        () => _selected.addAll(
                          widget.options.map((item) => item.number),
                        ),
                      ),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final option = visible[index];
                  return CheckboxListTile(
                    value: _selected.contains(option.number),
                    title: Text(option.label),
                    subtitle: Text(option.detail),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged:
                        (checked) => setState(() {
                          checked == true
                              ? _selected.add(option.number)
                              : _selected.remove(option.number);
                        }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, _selected),
          icon: const Icon(Icons.done_rounded),
          label: const Text('Use selection'),
        ),
      ],
    );
  }
}

class _AddedTargetDraft {
  const _AddedTargetDraft({
    required this.assetNumbers,
    required this.physicalPositions,
    required this.reason,
  });

  final List<int> assetNumbers;
  final List<String> physicalPositions;
  final String reason;
}

class _AddInspectionTargetsDialog extends StatefulWidget {
  const _AddInspectionTargetsDialog({
    required this.availableOptions,
    required this.installedInnerCovers,
    required this.initialPhysicalPositions,
  });

  final List<_InspectionTargetOption> availableOptions;
  final bool installedInnerCovers;
  final List<String> initialPhysicalPositions;

  @override
  State<_AddInspectionTargetsDialog> createState() =>
      _AddInspectionTargetsDialogState();
}

class _AddInspectionTargetsDialogState
    extends State<_AddInspectionTargetsDialog> {
  final _formKey = GlobalKey<FormState>();
  final Set<int> _selectedNumbers = <int>{};
  late final TextEditingController _positions;
  final _reason = TextEditingController(
    text: 'Extend the live campaign through a governed population exception.',
  );

  @override
  void initState() {
    super.initState();
    _positions = TextEditingController(
      text: widget.initialPhysicalPositions.join(', '),
    );
  }

  @override
  void dispose() {
    _positions.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add inspection targets'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GovernedInspectionTargetField(
                options: widget.availableOptions,
                selectedNumbers: _selectedNumbers,
                installedInnerCovers: widget.installedInnerCovers,
                onChoose: _chooseTargets,
              ),
              if (_selectedNumbers.isEmpty) ...[
                const SizedBox(height: BafSpacing.xs),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose at least one governed target.',
                    style: TextStyle(color: BafColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _positions,
                decoration: const InputDecoration(
                  labelText: 'Physical positions (optional)',
                  hintText: 'B01, B02',
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                validator:
                    (value) =>
                        (value?.trim().isNotEmpty ?? false)
                            ? null
                            : 'Record a reason.',
              ),
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
      FilledButton.icon(
        onPressed: () {
          if (_selectedNumbers.isEmpty || !_formKey.currentState!.validate()) {
            setState(() {});
            return;
          }
          final numbers = _selectedNumbers.toList()..sort();
          Navigator.pop(
            context,
            _AddedTargetDraft(
              assetNumbers: numbers,
              physicalPositions: _commaValues(_positions.text),
              reason: _reason.text.trim(),
            ),
          );
        },
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('Add'),
      ),
    ],
  );

  Future<void> _chooseTargets() async {
    final selected = await showDialog<Set<int>>(
      context: context,
      builder:
          (_) => _InspectionTargetPickerDialog(
            options: widget.availableOptions,
            selectedNumbers: _selectedNumbers,
          ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedNumbers
        ..clear()
        ..addAll(selected);
    });
  }
}
