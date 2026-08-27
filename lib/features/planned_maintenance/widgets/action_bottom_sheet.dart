// FILE: lib/features/planned_maintenance/widgets/action_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/presentation/widgets/governed_asset_target_picker.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/repositories/asset_hierarchy_repository.dart';
import '../models/component_action_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';

final class GovernedActionContext {
  const GovernedActionContext({
    required this.assetTypeKey,
    required this.assetNumber,
    this.assetClassId,
    this.assetInstanceId,
  });

  final String assetTypeKey;
  final int assetNumber;
  final String? assetClassId;
  final String? assetInstanceId;
}

class ActionBottomSheet extends ConsumerStatefulWidget {
  const ActionBottomSheet({super.key, required this.target, this.performedAt});

  final GovernedActionContext target;
  final DateTime? performedAt;

  @override
  ConsumerState<ActionBottomSheet> createState() => _ActionBottomSheetState();
}

class _ActionBottomSheetState extends ConsumerState<ActionBottomSheet> {
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _componentController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();

  String? asset;
  String? system;
  String? subsystem;
  List<String>? path;
  AssetHierarchyReference? hierarchyReference;
  String? ownership;
  int _resolutionGeneration = 0;
  AssetInstanceRecord? _assetRecord;
  List<AssetHierarchyNode> _hierarchyNodes = const <AssetHierarchyNode>[];
  String? _definitionAssetClassId;
  String? _selectedNodeId;
  String? _targetLoadError;
  String? _tagError;
  bool _loadingTarget = true;
  bool _resolvingTag = false;

  bool _isAutoResolved = false;

  ActionType _actionType = ActionType.issue;
  ActionStatus _status = ActionStatus.issue;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadTarget);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _componentController.dispose();
    _issueController.dispose();
    super.dispose();
  }

  Future<void> _loadTarget() async {
    try {
      final repository = ref.read(assetHierarchyRepositoryProvider);
      final classes = await repository.watchAssetClasses().first;
      final explicitClassId = widget.target.assetClassId?.trim();
      final expectedLegacyType =
          widget.target.assetTypeKey == 'innerCover'
              ? 'base'
              : widget.target.assetTypeKey;
      final matchingClasses = classes
          .where(
            (item) =>
                item.isActive &&
                (explicitClassId?.isNotEmpty == true
                    ? item.id == explicitClassId
                    : item.legacyAssetTypeKey == expectedLegacyType),
          )
          .toList(growable: false);
      if (matchingClasses.length != 1) {
        throw const AssetHierarchyException(
          'The work asset class is unavailable or ambiguous.',
        );
      }
      final assetClass = matchingClasses.single;
      final hierarchyClass =
          widget.target.assetTypeKey == 'innerCover'
              ? classes
                  .where(
                    (item) =>
                        item.isActive &&
                        item.legacyAssetTypeKey == 'innerCover',
                  )
                  .singleOrNull
              : assetClass;
      if (hierarchyClass == null) {
        throw const AssetHierarchyException(
          'The active Inner Cover hierarchy is unavailable or ambiguous.',
        );
      }
      final assets = await repository.watchAssetInstances(assetClass.id).first;
      final explicitAssetId = widget.target.assetInstanceId?.trim();
      final matchingAssets = assets
          .where(
            (item) =>
                item.isActive &&
                item.assetNumber == widget.target.assetNumber &&
                (explicitAssetId?.isNotEmpty == true
                    ? item.id == explicitAssetId
                    : true),
          )
          .toList(growable: false);
      if (matchingAssets.length != 1) {
        throw const AssetHierarchyException(
          'The exact physical work asset is unavailable or ambiguous.',
        );
      }
      final nodes = await repository.watchNodes(hierarchyClass.id).first;
      if (!mounted) return;
      setState(() {
        _assetRecord = matchingAssets.single;
        _hierarchyNodes = nodes;
        _definitionAssetClassId = hierarchyClass.id;
        asset = matchingAssets.single.name;
        system = hierarchyClass.name;
        _loadingTarget = false;
        _targetLoadError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingTarget = false;
        _targetLoadError =
            error is AssetHierarchyException
                ? '$error'
                : 'The governed asset hierarchy could not be loaded.';
      });
    }
  }

  Future<void> _chooseHierarchyTarget() async {
    final assetRecord = _assetRecord;
    if (assetRecord == null) return;
    final selection = await showGovernedAssetTargetPicker(
      context: context,
      asset: assetRecord,
      nodes: _hierarchyNodes,
      selectedNodeId: _selectedNodeId,
      definitionAssetClassId: _definitionAssetClassId,
    );
    if (!mounted || selection == null) return;
    final reference = selection.reference;
    final node = selection.node;
    if (selection.unlisted || reference == null || node == null) return;
    setState(() {
      _selectedNodeId = node.id;
      hierarchyReference = reference;
      asset = reference.assetInstanceName;
      system = reference.assetClassName;
      subsystem =
          reference.hierarchyPath.length > 1
              ? reference.hierarchyPath[reference.hierarchyPath.length - 2]
              : null;
      path = List<String>.from(reference.hierarchyPath);
      ownership = <String>[
        reference.ownershipStatus.label,
        if (reference.ownerDiscipline != null) reference.ownerDiscipline!,
      ].join(' · ');
      _componentController.text = reference.nodeName;
      _tagController.clear();
      _tagError = null;
      _isAutoResolved = true;
    });
  }

  Future<void> _resolveTag(String rawTag) async {
    final generation = ++_resolutionGeneration;
    final tag = rawTag.trim();

    if (tag.isEmpty) {
      setState(() {
        _tagError = null;
        _resolvingTag = false;
      });
      return;
    }

    final targetAsset = _assetRecord;
    if (targetAsset == null) {
      setState(() => _tagError = 'Load the work asset before resolving a tag.');
      return;
    }
    setState(() {
      _resolvingTag = true;
      _tagError = null;
    });

    try {
      final repository = ref.read(assetHierarchyRepositoryProvider);
      final component = await repository.findActiveInstalledComponentByTag(tag);
      if (!mounted || generation != _resolutionGeneration) return;
      if (component == null) {
        throw AssetHierarchyException(
          'Tag ${normalizeAssetComponentTag(tag)} is not registered.',
        );
      }
      if (component.assetClassId != targetAsset.assetClassId ||
          component.assetInstanceId != targetAsset.id ||
          component.assetNumber != targetAsset.assetNumber) {
        throw AssetHierarchyException(
          'Tag ${component.componentTag ?? tag} belongs to ${component.assetInstanceName}, not ${targetAsset.name}.',
        );
      }
      final reference = component.toReference();
      setState(() {
        asset = component.assetInstanceName;
        system = component.assetClassName;
        subsystem =
            component.hierarchyPath.length > 1
                ? component.hierarchyPath[component.hierarchyPath.length - 2]
                : null;
        path = List<String>.from(component.hierarchyPath);
        hierarchyReference = reference;
        ownership = [
          component.ownershipStatus.label,
          if (component.ownerDiscipline != null) component.ownerDiscipline!,
        ].join(' · ');
        _selectedNodeId = component.definitionNodeId;
        _componentController.text = component.definitionName;
        _tagController.text = component.componentTag ?? tag;
        _tagError = null;
        _resolvingTag = false;
        _isAutoResolved = true;
      });
      return;
    } on AssetHierarchyException catch (error) {
      if (!mounted || generation != _resolutionGeneration) return;
      setState(() {
        _tagError = '$error';
        _resolvingTag = false;
      });
      return;
    }
  }

  bool _canSave() {
    final tag = _tagController.text.trim();
    return !_loadingTarget &&
        _targetLoadError == null &&
        !_resolvingTag &&
        _tagError == null &&
        _componentController.text.trim().isNotEmpty &&
        asset != null &&
        hierarchyReference != null &&
        (tag.isEmpty ||
            hierarchyReference!.scope ==
                AssetHierarchyReferenceScope.installedComponent);
  }

  void _save() {
    final component = _componentController.text.trim();
    final tag = _tagController.text.trim();

    if (asset == null || hierarchyReference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose a governed component or enter a valid tag for this asset.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    if (component.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Component is required'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final action = ComponentAction(
      component: component,
      asset: asset!,
      tag: tag.isEmpty ? null : tag,
      system: system,
      subsystem: subsystem,
      hierarchyPath: path,
      assetHierarchyRef: hierarchyReference,
      actionType: _actionType,
      status: _status,
      issue: _issueController.text.trim(),
      isAutoResolved: _isAutoResolved,
      createdAt: widget.performedAt ?? DateTime.now(),
    );

    Navigator.pop(context, action);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BafColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: BafColors.planned.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                    child: const Icon(
                      Icons.add_task_rounded,
                      color: BafColors.planned,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add action / observation',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _assetRecord == null
                              ? 'Loading the exact work asset.'
                              : 'Record work on ${_assetRecord!.name}.',
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_loadingTarget)
                const LinearProgressIndicator(color: BafColors.planned)
              else if (_targetLoadError != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.danger.withValues(alpha: 0.08),
                    border: Border.all(
                      color: BafColors.danger.withValues(alpha: 0.28),
                    ),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                  ),
                  child: Text(
                    _targetLoadError!,
                    style: const TextStyle(color: BafColors.danger),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _chooseHierarchyTarget,
                    icon: const Icon(Icons.account_tree_outlined),
                    label: Text(
                      _selectedNodeId == null
                          ? 'Choose from asset hierarchy'
                          : 'Change hierarchy target',
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagController,
                enabled: !_loadingTarget && _targetLoadError == null,
                decoration: _inputDecoration(
                  'Instrument tag (optional)',
                  hint: 'Use only when the tag is known',
                  icon: Icons.sell_rounded,
                ).copyWith(
                  errorText: _tagError,
                  suffixIcon:
                      _resolvingTag
                          ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                          : null,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: _resolveTag,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _componentController,
                decoration: _inputDecoration(
                  'Governed component',
                  hint: 'Choose hierarchy or resolve a tag',
                  icon: Icons.memory_rounded,
                ),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ActionType>(
                initialValue: _actionType,
                isExpanded: true,
                decoration: _inputDecoration(
                  'Action type',
                  icon: Icons.handyman_rounded,
                ),
                items:
                    ActionType.values.map((type) {
                      return DropdownMenuItem<ActionType>(
                        value: type,
                        child: Text(
                          _actionTypeLabel(type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _actionType = val);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ActionStatus>(
                initialValue: _status,
                isExpanded: true,
                decoration: _inputDecoration(
                  'Status',
                  icon: Icons.flag_rounded,
                ),
                items:
                    ActionStatus.values.map((status) {
                      return DropdownMenuItem<ActionStatus>(
                        value: status,
                        child: Text(
                          _statusLabel(status),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _status = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _issueController,
                maxLines: 3,
                decoration: _inputDecoration(
                  'Issue / observation',
                  hint: 'What did you notice or do?',
                  icon: Icons.notes_rounded,
                  alignLabelWithHint: true,
                ),
              ),
              if (_isAutoResolved) ...[
                const SizedBox(height: 14),
                _ResolvedTagPanel(
                  asset: asset,
                  system: system,
                  subsystem: subsystem,
                  path: path,
                  ownership: ownership,
                  governed: hierarchyReference != null,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BafColors.textPrimary,
                        side: const BorderSide(color: BafColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _canSave() ? _save : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.planned,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text(
                        'Save Action',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        borderSide: const BorderSide(color: BafColors.planned, width: 1.5),
      ),
    );
  }

  String _actionTypeLabel(ActionType type) {
    switch (type) {
      case ActionType.issue:
        return 'Issue / observation';
      case ActionType.repair:
        return 'Repair';
      case ActionType.replacement:
        return 'Replacement';
      case ActionType.inspection:
        return 'Inspection';
    }
  }

  String _statusLabel(ActionStatus status) {
    switch (status) {
      case ActionStatus.issue:
        return 'Issue';
      case ActionStatus.inProgress:
        return 'In progress';
      case ActionStatus.resolved:
        return 'Resolved';
    }
  }
}

class _ResolvedTagPanel extends StatelessWidget {
  final String? asset;
  final String? system;
  final String? subsystem;
  final List<String>? path;
  final String? ownership;
  final bool governed;

  const _ResolvedTagPanel({
    this.asset,
    this.system,
    this.subsystem,
    this.path,
    this.ownership,
    this.governed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BafColors.sync.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.sync.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusBadge(
            label: governed ? 'Governed component' : 'Tag resolved',
            color: BafColors.sync,
            icon:
                governed ? Icons.verified_outlined : Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 8),
          if (asset != null && asset!.trim().isNotEmpty)
            _ResolvedLine(label: 'Asset', value: asset!),
          if (system != null && system!.trim().isNotEmpty)
            _ResolvedLine(label: 'System', value: system!),
          if (subsystem != null && subsystem!.trim().isNotEmpty)
            _ResolvedLine(label: 'Subsystem', value: subsystem!),
          if (path != null && path!.isNotEmpty)
            _ResolvedLine(label: 'Path', value: path!.join(' › ')),
          if (ownership != null && ownership!.trim().isNotEmpty)
            _ResolvedLine(label: 'Ownership', value: ownership!),
        ],
      ),
    );
  }
}

class _ResolvedLine extends StatelessWidget {
  final String label;
  final String value;

  const _ResolvedLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.25,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
