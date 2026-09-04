part of 'maintenance_form.dart';

class _FrequentIssueChoicePanel extends StatelessWidget {
  const _FrequentIssueChoicePanel({
    required this.definitions,
    required this.assetTypeKey,
    required this.assetClassId,
    required this.componentNodeId,
    required this.selected,
    required this.unlisted,
    required this.onSelected,
    required this.onRetry,
  });

  final AsyncValue<List<FrequentIssueDefinition>> definitions;
  final String assetTypeKey;
  final String? assetClassId;
  final String? componentNodeId;
  final FrequentIssueDefinition? selected;
  final bool unlisted;
  final ValueChanged<_FrequentIssueChoice> onSelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final classId = assetClassId;
    final enabled = classId != null;
    final label = selected?.title ?? (unlisted ? 'Other / not listed' : null);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BafColors.background,
        border: Border.all(color: BafColors.border),
        borderRadius: BorderRadius.circular(BafRadius.medium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BafColors.maintenance.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(BafRadius.small),
              ),
              child: const Icon(
                Icons.rule_folder_outlined,
                color: BafColors.maintenance,
              ),
            ),
            const SizedBox(width: BafSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frequent issue',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label ??
                        (enabled
                            ? 'Optional - no category selected'
                            : 'Choose an asset first'),
                    style: TextStyle(
                      color:
                          label == null
                              ? BafColors.textSecondary
                              : BafColors.textPrimary,
                      fontWeight:
                          label == null ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            definitions.when(
              loading:
                  () => const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              error:
                  (_, _) => IconButton(
                    tooltip: 'Retry catalogue',
                    onPressed: onRetry,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: BafColors.danger,
                    ),
                  ),
              data:
                  (values) => IconButton(
                    tooltip: label == null ? 'Choose issue' : 'Change issue',
                    onPressed:
                        !enabled ? null : () => _showPicker(context, values),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    List<FrequentIssueDefinition> values,
  ) async {
    final classId = assetClassId!;
    final applicable = values
        .where(
          (definition) =>
              !definition.isCodeOwned &&
              !definition.requiredEvidenceFields.any(
                const <String>{
                  'photo',
                  'measurement',
                  'alarmText',
                  'operatingContext',
                }.contains,
              ) &&
              definition.appliesTo(
                assetTypeKey: assetTypeKey,
                assetClassId: classId,
                componentNodeId: componentNodeId,
              ),
        )
        .toList(growable: false);
    final result = await showModalBottomSheet<_FrequentIssueChoice>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder:
          (context) => _FrequentIssuePickerSheet(
            definitions: applicable,
            selectedId: selected?.id,
            unlisted: unlisted,
          ),
    );
    if (!context.mounted || result == null) return;
    onSelected(result);
  }
}

class _FrequentIssueChoice {
  const _FrequentIssueChoice.none() : definition = null, unlisted = false;
  const _FrequentIssueChoice.definition(this.definition) : unlisted = false;
  const _FrequentIssueChoice.unlisted() : definition = null, unlisted = true;

  final FrequentIssueDefinition? definition;
  final bool unlisted;
}

class _FrequentIssuePickerSheet extends StatefulWidget {
  const _FrequentIssuePickerSheet({
    required this.definitions,
    required this.selectedId,
    required this.unlisted,
  });

  final List<FrequentIssueDefinition> definitions;
  final String? selectedId;
  final bool unlisted;

  @override
  State<_FrequentIssuePickerSheet> createState() =>
      _FrequentIssuePickerSheetState();
}

class _FrequentIssuePickerSheetState extends State<_FrequentIssuePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = widget.definitions
        .where((definition) {
          if (query.isEmpty) return true;
          return <String>[
            definition.title,
            definition.code,
            definition.description,
            ...definition.aliases,
          ].any((value) => value.toLowerCase().contains(query));
        })
        .toList(growable: false);
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose frequent issue',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.sm),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Search issue catalogue',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(BafSpacing.md),
              children: [
                ListTile(
                  selected: widget.selectedId == null && !widget.unlisted,
                  leading: const Icon(Icons.remove_circle_outline_rounded),
                  title: const Text(
                    'No frequent issue category',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Describe this issue without classifying it.',
                  ),
                  onTap:
                      () => Navigator.pop(
                        context,
                        const _FrequentIssueChoice.none(),
                      ),
                ),
                const Divider(),
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(BafSpacing.lg),
                    child: Text(
                      'No governed frequent issue matches this asset and component.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  )
                else
                  for (final definition in visible)
                    ListTile(
                      selected: definition.id == widget.selectedId,
                      leading: Icon(
                        definition.isCritical
                            ? Icons.priority_high_rounded
                            : Icons.build_circle_outlined,
                        color:
                            definition.isCritical
                                ? BafColors.danger
                                : BafColors.maintenance,
                      ),
                      title: Text(
                        definition.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${definition.description}\n${definition.code} · ${_issuePickerRouteLabel(definition.defaultRouteKey)}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap:
                          () => Navigator.pop(
                            context,
                            _FrequentIssueChoice.definition(definition),
                          ),
                    ),
                const Divider(),
                ListTile(
                  selected: widget.unlisted,
                  leading: const Icon(
                    Icons.add_comment_outlined,
                    color: BafColors.warning,
                  ),
                  title: const Text(
                    'Other / not listed',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Raise the issue now and send it for catalogue review.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap:
                      () => Navigator.pop(
                        context,
                        const _FrequentIssueChoice.unlisted(),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _issuePickerRouteLabel(String value) => switch (value) {
  'operations' => 'Operations',
  'electrical' => 'Electrical',
  'mechanical' => 'Mechanical',
  'instrumentation' => 'I&A',
  'refractory' => 'RED / Refractory',
  'emd' => 'EMD',
  'shiftInCharge' => 'Shift in-charge',
  _ => 'Others',
};
