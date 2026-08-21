part of 'maintenance_intelligence_screen.dart';

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.actor});

  final AppUser actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(maintenanceCompletionEventsProvider);
    final classes =
        ref.watch(maintenanceClassDefinitionsProvider).value ??
        const <MaintenanceClassDefinition>[];
    return events.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading maintenance history',
            color: BafColors.planned,
          ),
      error:
          (_, _) => _RetryState(
            message: 'Maintenance history could not be loaded.',
            onRetry: () => ref.invalidate(maintenanceCompletionEventsProvider),
          ),
      data:
          (rows) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(maintenanceCompletionEventsProvider);
              await ref.read(maintenanceCompletionEventsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(BafSpacing.lg),
              children: [
                _ActionHeader(
                  title: 'Previous maintenance records',
                  description:
                      'Every qualifying completion appears here. Admin may add earlier plant history against an exact asset and governed maintenance type; the original date, entry basis and recorder remain immutable.',
                  actionLabel: 'Add previous record',
                  actionIcon: Icons.history_toggle_off_rounded,
                  onPressed:
                      actor.canRecordHistoricalMaintenance &&
                              classes.any((item) => item.isActive)
                          ? () => _addHistoricalMaintenance(
                            context,
                            ref,
                            classes.where((item) => item.isActive).toList(),
                          )
                          : null,
                ),
                const SizedBox(height: BafSpacing.lg),
                if (rows.isEmpty)
                  const _EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No maintenance history yet',
                    message:
                        'Completed classified work and Admin-entered previous records will appear here.',
                  )
                else
                  ...rows.map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                      child: _CompletionEventCard(event: event),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

class _CompletionEventCard extends StatelessWidget {
  const _CompletionEventCard({required this.event});

  final MaintenanceCompletionEvent event;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (event.sourceType) {
      'historicalMaintenance' => 'Historical addition',
      'maintenanceIssue' => 'Resolved issue',
      'maintenancePlanDirect' => 'Direct plan completion',
      'workflowPlannedJob' || 'legacyPlannedJob' => 'Planned maintenance',
      _ => 'Maintenance completion',
    };
    final assetLabel =
        event.assetDisplayName ??
        '${_assetLabel(event.assetTypeKey)} ${event.assetNumber ?? event.assetInstanceId}';
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (event.isHistorical ? BafColors.audit : BafColors.planned)
                  .withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Icon(
              event.isHistorical
                  ? Icons.history_toggle_off_rounded
                  : Icons.task_alt_rounded,
              color: event.isHistorical ? BafColors.audit : BafColors.planned,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$assetLabel · ${event.maintenanceClass.title}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd MMM yyyy').format(event.completedAt.toLocal())} · $sourceLabel',
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
                if (event.completedByName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Performed by ${event.completedByName}',
                    style: const TextStyle(color: BafColors.textSecondary),
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

Future<void> _addHistoricalMaintenance(
  BuildContext context,
  WidgetRef ref,
  List<MaintenanceClassDefinition> classes,
) async {
  final draft = await showDialog<_HistoricalMaintenanceDraft>(
    context: context,
    builder: (_) => _HistoricalMaintenanceEditor(definitions: classes),
  );
  if (draft == null || !context.mounted) return;
  await _execute(
    context,
    ref,
    WorkflowCommand(
      commandId: 'recordHistoricalMaintenance_${const Uuid().v4()}',
      type: WorkflowCommandType.recordHistoricalMaintenance,
      aggregateId: 'historical-maintenance-${const Uuid().v4()}',
      expectedVersion: 0,
      payload: draft.toPayload(),
    ),
    'Previous maintenance record added.',
  );
  ref.invalidate(maintenanceCompletionEventsProvider);
  ref.invalidate(maintenanceDueStatesProvider);
}

class _HistoricalMaintenanceEditor extends ConsumerStatefulWidget {
  const _HistoricalMaintenanceEditor({required this.definitions});

  final List<MaintenanceClassDefinition> definitions;

  @override
  ConsumerState<_HistoricalMaintenanceEditor> createState() =>
      _HistoricalMaintenanceEditorState();
}

class _HistoricalMaintenanceEditorState
    extends ConsumerState<_HistoricalMaintenanceEditor> {
  String? _assetClassId;
  String? _assetInstanceId;
  String? _definitionId;
  DateTime _completedOn = DateTime.now();
  final _performedBy = TextEditingController();
  final _evidence = TextEditingController();
  final _sourceReference = TextEditingController();

  @override
  void dispose() {
    _performedBy.dispose();
    _evidence.dispose();
    _sourceReference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      initialDate: _completedOn,
    );
    if (date == null || !mounted) return;
    setState(() {
      // Noon preserves the selected plant date across local/UTC conversion
      // without pretending that an exact historical completion time is known.
      _completedOn = DateTime(date.year, date.month, date.day, 12);
    });
  }

  @override
  Widget build(BuildContext context) {
    final classValue = ref.watch(assetClassesProvider);
    final classes =
        classValue.asData?.value
            .where(
              (assetClass) =>
                  assetClass.isActive &&
                  widget.definitions.any(
                    (definition) => definition.appliesTo(
                      assetTypeKey:
                          assetClass.legacyAssetTypeKey ?? 'governedCustom',
                      assetClassId: assetClass.id,
                    ),
                  ),
            )
            .toList() ??
        const <AssetClassRecord>[];
    if (!classes.any((item) => item.id == _assetClassId)) {
      _assetClassId = classes.firstOrNull?.id;
      _assetInstanceId = null;
    }
    final selectedClass =
        classes.where((item) => item.id == _assetClassId).firstOrNull;
    final assetType = selectedClass?.legacyAssetTypeKey ?? 'governedCustom';
    final matching =
        selectedClass == null
            ? const <MaintenanceClassDefinition>[]
            : widget.definitions
                .where(
                  (definition) => definition.appliesTo(
                    assetTypeKey: assetType,
                    assetClassId: selectedClass.id,
                  ),
                )
                .toList();
    final AsyncValue<List<_PlanAssetChoice>>? assetsValue;
    if (selectedClass == null) {
      assetsValue = null;
    } else if (assetType == 'innerCover') {
      assetsValue = ref
          .watch(innerCoverProfilesProvider)
          .whenData(
            (profiles) =>
                profiles
                    .where(
                      (profile) =>
                          profile.assetClassId == selectedClass.id &&
                          _isMaintainableInnerCover(profile),
                    )
                    .map(
                      (profile) => _PlanAssetChoice(
                        id: profile.id,
                        version: profile.version,
                        name:
                            profile.isInstalled
                                ? 'Base ${profile.currentBaseAssetNumber} · Inner Cover ${profile.serialNumber}'
                                : 'Pool · Inner Cover ${profile.serialNumber}',
                        assetNumber: null,
                      ),
                    )
                    .toList(),
          );
    } else {
      assetsValue = ref
          .watch(assetInstancesProvider(selectedClass.id))
          .whenData(
            (assets) =>
                assets
                    .where((asset) => asset.isActive)
                    .map(
                      (asset) => _PlanAssetChoice(
                        id: asset.id,
                        version: asset.version,
                        name: asset.name,
                        assetNumber: asset.assetNumber,
                      ),
                    )
                    .toList(),
          );
    }
    final assets = assetsValue?.asData?.value ?? const <_PlanAssetChoice>[];
    if (!assets.any((item) => item.id == _assetInstanceId)) {
      _assetInstanceId = assets.firstOrNull?.id;
    }
    if (!matching.any((item) => item.id == _definitionId)) {
      _definitionId = matching.firstOrNull?.id;
    }

    return AlertDialog(
      title: const Text('Add previous maintenance'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Admin backfill records are immutable and immediately participate in maintenance history and due-date calculations.',
                  style: TextStyle(color: BafColors.textSecondary),
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _assetClassId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Asset class'),
                items:
                    classes
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                onChanged:
                    (value) => setState(() {
                      _assetClassId = value;
                      _assetInstanceId = null;
                      _definitionId = null;
                    }),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey('history-asset-${_assetClassId ?? ''}'),
                initialValue: _assetInstanceId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Asset number / serial',
                  helperText:
                      assetsValue?.isLoading == true
                          ? 'Loading governed assets…'
                          : 'Select the exact physical asset',
                ),
                items:
                    assets
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _assetInstanceId = value),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'history-type-${_assetClassId ?? ''}-${_definitionId ?? ''}',
                ),
                initialValue: _definitionId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Maintenance type',
                ),
                items:
                    matching
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _definitionId = value),
              ),
              const SizedBox(height: BafSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Maintenance date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_completedOn)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
              TextField(
                controller: _performedBy,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Performed by (optional)',
                  hintText: 'Team, contractor or person if known',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _sourceReference,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Source reference (optional)',
                  hintText: 'Paper register, work order or logbook reference',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _evidence,
                minLines: 3,
                maxLines: 5,
                maxLength: 1200,
                decoration: const InputDecoration(
                  labelText: 'Record basis / remarks',
                  hintText: 'What confirms that this maintenance occurred?',
                  alignLabelWithHint: true,
                ),
              ),
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
          onPressed: () {
            final definition =
                matching.where((item) => item.id == _definitionId).firstOrNull;
            final asset =
                assets.where((item) => item.id == _assetInstanceId).firstOrNull;
            final evidence = _evidence.text.trim();
            if (selectedClass == null ||
                definition == null ||
                asset == null ||
                evidence.length < 5 ||
                _completedOn.isAfter(DateTime.now())) {
              return;
            }
            String? optional(String value) =>
                value.trim().isEmpty ? null : value.trim();
            Navigator.pop(
              context,
              _HistoricalMaintenanceDraft(
                assetClass: selectedClass,
                asset: asset,
                definition: definition,
                completedOn: _completedOn,
                performedByName: optional(_performedBy.text),
                evidenceNote: evidence,
                sourceReference: optional(_sourceReference.text),
              ),
            );
          },
          icon: const Icon(Icons.history_toggle_off_rounded),
          label: const Text('Add record'),
        ),
      ],
    );
  }
}

bool _isMaintainableInnerCover(InnerCoverProfile profile) => const {
  InnerCoverLifecycleState.available,
  InnerCoverLifecycleState.reserved,
  InnerCoverLifecycleState.installed,
  InnerCoverLifecycleState.awaitingInspection,
  InnerCoverLifecycleState.underInspection,
  InnerCoverLifecycleState.underRepair,
  InnerCoverLifecycleState.quarantined,
}.contains(profile.lifecycleState);
