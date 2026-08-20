import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../data/frequent_issue_definition.dart';
import '../providers/frequent_issue_provider.dart';

class FrequentIssueCatalogueScreen extends ConsumerStatefulWidget {
  const FrequentIssueCatalogueScreen({super.key});

  @override
  ConsumerState<FrequentIssueCatalogueScreen> createState() =>
      _FrequentIssueCatalogueScreenState();
}

class _FrequentIssueCatalogueScreenState
    extends ConsumerState<FrequentIssueCatalogueScreen> {
  bool _showRetired = false;

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentAppUserProvider);
    return actor.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (_, _) => const Scaffold(
            body: Center(child: Text('Could not verify catalogue authority.')),
          ),
      data: (user) {
        if (user == null || !user.canManageFrequentIssueDefinitions) {
          return const Scaffold(
            body: Center(child: Text('Admin or SI authority is required.')),
          );
        }
        return _buildCatalogue();
      },
    );
  }

  Widget _buildCatalogue() {
    final definitions = ref.watch(frequentIssueDefinitionsProvider);
    final commandState = ref.watch(workflowCommandControllerProvider);
    final busy = commandState.isLoading;
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Frequent issues',
          subtitle: 'Governed issue choices and default routing',
          icon: Icons.rule_folder_outlined,
          accent: BafColors.maintenance,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => _editDefinition(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add issue'),
      ),
      body: definitions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, _) => _CatalogueError(
              onRetry: () => ref.invalidate(frequentIssueDefinitionsProvider),
            ),
        data: (values) {
          final visible = values
              .where((item) => _showRetired || item.isActive)
              .toList(growable: false);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(frequentIssueDefinitionsProvider);
              await ref.read(frequentIssueDefinitionsProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.lg,
                BafSpacing.md,
                BafSpacing.lg,
                104,
              ),
              children: [
                _CatalogueHeader(
                  activeCount: values.where((item) => item.isActive).length,
                  retiredCount: values.where((item) => !item.isActive).length,
                  showRetired: _showRetired,
                  onShowRetiredChanged:
                      (value) => setState(() => _showRetired = value),
                ),
                const SizedBox(height: BafSpacing.lg),
                if (visible.isEmpty)
                  const _EmptyCatalogue()
                else
                  for (final definition in visible) ...[
                    _DefinitionCard(
                      definition: definition,
                      busy: busy,
                      onEdit: () => _editDefinition(definition),
                      onStatusChanged: () => _changeStatus(definition),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editDefinition([FrequentIssueDefinition? existing]) async {
    final draft = await showDialog<_DefinitionDraft>(
      context: context,
      builder: (_) => _DefinitionEditor(existing: existing),
    );
    if (!mounted || draft == null) return;
    final id = existing?.id ?? 'frequent-${const Uuid().v4()}';
    final command = WorkflowCommand(
      commandId: 'upsertFrequentIssueDefinition_${const Uuid().v4()}',
      type: WorkflowCommandType.upsertFrequentIssueDefinition,
      aggregateId: id,
      expectedVersion: existing?.version ?? 0,
      payload: <String, Object?>{
        'definition': <String, Object?>{
          'schemaVersion': 1,
          'code': draft.code,
          'title': draft.title,
          'description': draft.description,
          'applicableAssetTypeKeys': draft.assetTypeKeys,
          'applicableAssetClassIds':
              existing?.applicableAssetClassIds ?? const <String>[],
          'applicableComponentNodeIds':
              existing?.applicableComponentNodeIds ?? const <String>[],
          'suggestedSeverityKey': draft.critical ? 'critical' : 'normal',
          'suggestedMaintenanceTypeKey': draft.maintenanceTypeKey,
          'defaultRouteKey': draft.routeKey,
          'requiredEvidenceFields': draft.requiredEvidenceFields,
          'aliases': draft.aliases,
          'codeOwnedWorkflowProfile': existing?.codeOwnedWorkflowProfile,
        },
        'reason': draft.reason,
      },
    );
    await _execute(
      command,
      success:
          existing == null
              ? 'Frequent issue added.'
              : 'Frequent issue updated.',
    );
  }

  Future<void> _changeStatus(FrequentIssueDefinition definition) async {
    final next = definition.isActive ? 'retired' : 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              definition.isActive
                  ? 'Retire this issue?'
                  : 'Restore this issue?',
            ),
            content: Text(
              definition.isActive
                  ? 'It will no longer appear when a new issue is raised. Existing tickets keep their frozen definition.'
                  : 'It will become available for new matching issues again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(definition.isActive ? 'Retire' : 'Restore'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    await _execute(
      WorkflowCommand(
        commandId: 'setFrequentIssueDefinitionStatus_${const Uuid().v4()}',
        type: WorkflowCommandType.setFrequentIssueDefinitionStatus,
        aggregateId: definition.id,
        expectedVersion: definition.version,
        payload: <String, Object?>{
          'status': next,
          'reason':
              definition.isActive
                  ? 'Retired through the governed catalogue.'
                  : 'Restored through the governed catalogue.',
        },
      ),
      success:
          definition.isActive
              ? 'Frequent issue retired.'
              : 'Frequent issue restored.',
    );
  }

  Future<void> _execute(
    WorkflowCommand command, {
    required String success,
  }) async {
    try {
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: BafColors.sync),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not apply the catalogue change: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }
}

class _DefinitionDraft {
  const _DefinitionDraft({
    required this.code,
    required this.title,
    required this.description,
    required this.assetTypeKeys,
    required this.critical,
    required this.maintenanceTypeKey,
    required this.routeKey,
    required this.requiredEvidenceFields,
    required this.aliases,
    required this.reason,
  });

  final String code;
  final String title;
  final String description;
  final List<String> assetTypeKeys;
  final bool critical;
  final String maintenanceTypeKey;
  final String routeKey;
  final List<String> requiredEvidenceFields;
  final List<String> aliases;
  final String reason;
}

class _DefinitionEditor extends StatefulWidget {
  const _DefinitionEditor({this.existing});

  final FrequentIssueDefinition? existing;

  @override
  State<_DefinitionEditor> createState() => _DefinitionEditorState();
}

class _DefinitionEditorState extends State<_DefinitionEditor> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _aliases;
  late final TextEditingController _reason;
  late Set<String> _assetTypes;
  late Set<String> _evidence;
  late bool _critical;
  late String _maintenanceType;
  late String _route;

  @override
  void initState() {
    super.initState();
    final value = widget.existing;
    _code = TextEditingController(text: value?.code);
    _title = TextEditingController(text: value?.title);
    _description = TextEditingController(text: value?.description);
    _aliases = TextEditingController(text: value?.aliases.join(', '));
    _reason = TextEditingController(
      text:
          value == null
              ? 'Create a governed frequent-issue choice.'
              : 'Update the governed frequent-issue definition.',
    );
    _assetTypes = {...?value?.applicableAssetTypeKeys};
    _evidence = {...?value?.requiredEvidenceFields};
    _critical = value?.isCritical ?? false;
    _maintenanceType = value?.suggestedMaintenanceTypeKey ?? 'breakdown';
    _route = value?.defaultRouteKey ?? 'mechanical';
  }

  @override
  void dispose() {
    _code.dispose();
    _title.dispose();
    _description.dispose();
    _aliases.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add frequent issue' : 'Edit issue'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Stable code'),
                validator: (value) {
                  final text = value?.trim().toUpperCase() ?? '';
                  return RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,39}$').hasMatch(text)
                      ? null
                      : 'Use 2-40 letters, numbers, hyphens or underscores';
                },
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Issue name'),
                validator: (value) => _lengthError(value, 3, 160),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Default description',
                  alignLabelWithHint: true,
                ),
                validator: (value) => _lengthError(value, 5, 1000),
              ),
              const SizedBox(height: BafSpacing.lg),
              const Text(
                'Applicable assets',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: BafSpacing.xs),
              Wrap(
                spacing: BafSpacing.sm,
                children:
                    const <(String, String)>[
                      ('base', 'Base'),
                      ('furnace', 'Furnace'),
                      ('forceCooler', 'Forced Cooler'),
                      ('innerCover', 'Inner Cover'),
                      ('governedCustom', 'Other governed class'),
                    ].map((entry) {
                      return FilterChip(
                        label: Text(entry.$2),
                        selected: _assetTypes.contains(entry.$1),
                        onSelected:
                            (selected) => setState(() {
                              if (selected) {
                                _assetTypes.add(entry.$1);
                              } else {
                                _assetTypes.remove(entry.$1);
                              }
                            }),
                      );
                    }).toList(),
              ),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _route,
                decoration: const InputDecoration(labelText: 'Default lane'),
                items:
                    const <(String, String)>[
                      ('operations', 'Operations'),
                      ('electrical', 'Electrical'),
                      ('mechanical', 'Mechanical'),
                      ('instrumentation', 'I&A'),
                      ('refractory', 'RED / Refractory'),
                      ('emd', 'EMD'),
                      ('shiftInCharge', 'Shift in-charge'),
                      ('others', 'Others'),
                    ].map((entry) {
                      return DropdownMenuItem(
                        value: entry.$1,
                        child: Text(entry.$2),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => _route = value ?? _route),
              ),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _maintenanceType,
                decoration: const InputDecoration(
                  labelText: 'Suggested work type',
                ),
                items:
                    const <(String, String)>[
                      ('breakdown', 'Breakdown'),
                      ('performance', 'Performance'),
                      ('inspection', 'Inspection'),
                      ('scheduled', 'Scheduled'),
                      ('overhaul', 'Overhaul'),
                    ].map((entry) {
                      return DropdownMenuItem(
                        value: entry.$1,
                        child: Text(entry.$2),
                      );
                    }).toList(),
                onChanged:
                    (value) => setState(
                      () => _maintenanceType = value ?? _maintenanceType,
                    ),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Suggest critical priority'),
                value: _critical,
                onChanged: (value) => setState(() => _critical = value),
              ),
              const Text(
                'Required evidence',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              Wrap(
                spacing: BafSpacing.sm,
                children:
                    const <(String, String)>[
                      ('observation', 'Observation'),
                      ('chargeNo', 'Charge number'),
                      ('alarmText', 'Alarm text'),
                      ('operatingContext', 'Operating context'),
                    ].map((entry) {
                      return FilterChip(
                        label: Text(entry.$2),
                        selected: _evidence.contains(entry.$1),
                        onSelected:
                            (selected) => setState(() {
                              if (selected) {
                                _evidence.add(entry.$1);
                              } else {
                                _evidence.remove(entry.$1);
                              }
                            }),
                      );
                    }).toList(),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _aliases,
                decoration: const InputDecoration(
                  labelText: 'Search aliases',
                  hintText: 'Comma separated',
                ),
              ),
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _reason,
                decoration: const InputDecoration(labelText: 'Change reason'),
                validator: (value) => _lengthError(value, 5, 500),
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
        onPressed: _submit,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Save'),
      ),
    ],
  );

  String? _lengthError(String? value, int minimum, int maximum) {
    final length = value?.trim().length ?? 0;
    return length >= minimum && length <= maximum
        ? null
        : 'Enter $minimum-$maximum characters';
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    if (_assetTypes.isEmpty &&
        (widget.existing?.applicableAssetClassIds.isEmpty ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one applicable asset.'),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }
    final aliases = _aliases.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    Navigator.pop(
      context,
      _DefinitionDraft(
        code: _code.text.trim().toUpperCase(),
        title: _title.text.trim(),
        description: _description.text.trim(),
        assetTypeKeys: _assetTypes.toList(growable: false)..sort(),
        critical: _critical,
        maintenanceTypeKey: _maintenanceType,
        routeKey: _route,
        requiredEvidenceFields: _evidence.toList(growable: false)..sort(),
        aliases: aliases,
        reason: _reason.text.trim(),
      ),
    );
  }
}

class _CatalogueHeader extends StatelessWidget {
  const _CatalogueHeader({
    required this.activeCount,
    required this.retiredCount,
    required this.showRetired,
    required this.onShowRetiredChanged,
  });

  final int activeCount;
  final int retiredCount;
  final bool showRetired;
  final ValueChanged<bool> onShowRetiredChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: BafColors.card,
      border: Border.all(color: BafColors.border),
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activeCount active choices',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  '$retiredCount retired',
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ],
            ),
          ),
          FilterChip(
            label: const Text('Show retired'),
            selected: showRetired,
            onSelected: onShowRetiredChanged,
          ),
        ],
      ),
    ),
  );
}

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({
    required this.definition,
    required this.busy,
    required this.onEdit,
    required this.onStatusChanged,
  });

  final FrequentIssueDefinition definition;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onStatusChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (definition.isActive
                          ? BafColors.maintenance
                          : BafColors.textSecondary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: Icon(
                  definition.isActive
                      ? Icons.build_circle_outlined
                      : Icons.archive_outlined,
                  color:
                      definition.isActive
                          ? BafColors.maintenance
                          : BafColors.textSecondary,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${definition.code} · v${definition.version}',
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit definition',
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: definition.isActive ? 'Retire' : 'Restore',
                onPressed: busy ? null : onStatusChanged,
                icon: Icon(
                  definition.isActive
                      ? Icons.archive_outlined
                      : Icons.restore_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Text(
            definition.description,
            style: const TextStyle(
              color: BafColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.xs,
            runSpacing: BafSpacing.xs,
            children: [
              _CatalogueChip(label: _routeLabel(definition.defaultRouteKey)),
              _CatalogueChip(
                label: _maintenanceLabel(
                  definition.suggestedMaintenanceTypeKey,
                ),
              ),
              if (definition.isCritical)
                const _CatalogueChip(label: 'Critical'),
              for (final type in definition.applicableAssetTypeKeys)
                _CatalogueChip(label: _assetLabel(type)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CatalogueChip extends StatelessWidget {
  const _CatalogueChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: BafColors.background,
      border: Border.all(color: BafColors.border),
      borderRadius: BorderRadius.circular(BafRadius.small),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}

class _CatalogueError extends StatelessWidget {
  const _CatalogueError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: BafColors.danger),
        const SizedBox(height: BafSpacing.sm),
        const Text('Could not load the frequent-issue catalogue.'),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(
          Icons.rule_folder_outlined,
          size: 48,
          color: BafColors.textSecondary,
        ),
        SizedBox(height: BafSpacing.md),
        Text(
          'No frequent issues are available.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

String _assetLabel(String value) => switch (value) {
  'base' => 'Base',
  'furnace' => 'Furnace',
  'forceCooler' => 'Forced Cooler',
  'innerCover' => 'Inner Cover',
  _ => 'Governed class',
};

String _routeLabel(String value) => switch (value) {
  'operations' => 'Operations',
  'electrical' => 'Electrical',
  'mechanical' => 'Mechanical',
  'instrumentation' => 'I&A',
  'refractory' => 'RED / Refractory',
  'emd' => 'EMD',
  'shiftInCharge' => 'Shift in-charge',
  _ => 'Others',
};

String _maintenanceLabel(String value) => switch (value) {
  'scheduled' => 'Scheduled',
  'performance' => 'Performance',
  'inspection' => 'Inspection',
  'overhaul' => 'Overhaul',
  _ => 'Breakdown',
};
