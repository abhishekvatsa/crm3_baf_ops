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
  const ActionBottomSheet({
    super.key,
    required this.target,
    this.performedAt,
    this.performedBy,
  });

  final GovernedActionContext target;
  final DateTime? performedAt;
  final String? performedBy;

  @override
  ConsumerState<ActionBottomSheet> createState() => _ActionBottomSheetState();
}

class _ActionBottomSheetState extends ConsumerState<ActionBottomSheet> {
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _componentController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _supplierController = TextEditingController();
  final TextEditingController _purchaseOrderController =
      TextEditingController();

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
  ReplacementType? _replacementType;
  int? _burnerPosition;
  BurnerBlockSupplyMode? _burnerBlockSupplyMode;

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
    _supplierController.dispose();
    _purchaseOrderController.dispose();
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
    _applyDefinitionTarget(node: node, reference: reference);
  }

  void _applyDefinitionTarget({
    required AssetHierarchyNode node,
    required AssetHierarchyReference reference,
    String? verifiedTag,
    bool populateDefinitionTag = true,
  }) {
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
      _tagController.text =
          verifiedTag ?? (populateDefinitionTag ? node.componentTag ?? '' : '');
      _tagError = null;
      _isAutoResolved = true;
    });
  }

  bool _definitionTagMatches(String rawTag) {
    final reference = hierarchyReference;
    final selectedNodeId = _selectedNodeId;
    if (reference?.scope !=
            AssetHierarchyReferenceScope.componentDefinitionOnAsset ||
        selectedNodeId == null) {
      return false;
    }
    for (final node in _hierarchyNodes) {
      if (node.id != selectedNodeId || node.componentTag == null) continue;
      return normalizeAssetComponentTag(node.componentTag!) ==
          normalizeAssetComponentTag(rawTag);
    }
    return false;
  }

  Future<void> _resolveTag(String rawTag) async {
    final generation = ++_resolutionGeneration;
    final tag = rawTag.trim();

    if (tag.isEmpty) {
      final targetAsset = _assetRecord;
      final selectedNode =
          _hierarchyNodes
              .where((node) => node.id == _selectedNodeId)
              .singleOrNull;
      if (targetAsset != null &&
          selectedNode != null &&
          hierarchyReference?.scope ==
              AssetHierarchyReferenceScope.installedComponent) {
        _applyDefinitionTarget(
          node: selectedNode,
          reference: componentDefinitionReferenceForAsset(
            asset: targetAsset,
            node: selectedNode,
            definitionAssetClassId: _definitionAssetClassId,
          ),
          populateDefinitionTag: false,
        );
      }
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
        final normalizedTag = normalizeAssetComponentTag(tag);
        final hierarchyMatches = _hierarchyNodes
            .where(
              (node) =>
                  node.isActive &&
                  (node.nodeType == AssetHierarchyNodeType.component ||
                      node.nodeType == AssetHierarchyNodeType.subcomponent) &&
                  node.componentTag != null &&
                  normalizeAssetComponentTag(node.componentTag!) ==
                      normalizedTag,
            )
            .toList(growable: false);
        if (hierarchyMatches.length > 1) {
          throw AssetHierarchyException(
            'Tag $normalizedTag identifies more than one active hierarchy component. Ask an Admin to reconcile the hierarchy.',
          );
        }
        if (hierarchyMatches.isEmpty) {
          throw AssetHierarchyException(
            'Tag $normalizedTag is not registered for ${targetAsset.name}.',
          );
        }
        final node = hierarchyMatches.single;
        final reference = componentDefinitionReferenceForAsset(
          asset: targetAsset,
          node: node,
          definitionAssetClassId: _definitionAssetClassId,
        );
        _applyDefinitionTarget(
          node: node,
          reference: reference,
          verifiedTag: node.componentTag,
        );
        setState(() => _resolvingTag = false);
        return;
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
    final replacementReady =
        _actionType != ActionType.replacement || _replacementType != null;
    final burnerBlockReady =
        !_isBurnerBlockReplacement ||
        (_burnerPosition != null && _burnerBlockSupplyMode != null);
    return !_loadingTarget &&
        _targetLoadError == null &&
        !_resolvingTag &&
        _tagError == null &&
        _componentController.text.trim().isNotEmpty &&
        asset != null &&
        hierarchyReference != null &&
        replacementReady &&
        burnerBlockReady &&
        (tag.isEmpty ||
            (hierarchyReference!.scope ==
                    AssetHierarchyReferenceScope.installedComponent &&
                hierarchyReference!.componentTag != null &&
                normalizeAssetComponentTag(tag) ==
                    normalizeAssetComponentTag(
                      hierarchyReference!.componentTag!,
                    )) ||
            _definitionTagMatches(tag));
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
      replacement:
          _actionType == ActionType.replacement ? _replacementType : null,
      status: _status,
      issue: _issueController.text.trim(),
      isAutoResolved: _isAutoResolved,
      createdAt: widget.performedAt ?? DateTime.now(),
      performedBy: widget.performedBy,
      burnerPosition: _isBurnerBlockReplacement ? _burnerPosition : null,
      burnerBlockSupplyMode:
          _isBurnerBlockReplacement ? _burnerBlockSupplyMode : null,
      burnerBlockSupplierName:
          _isPurchasedBurnerBlock ? _supplierController.text.trim() : null,
      burnerBlockPurchaseOrderNumber:
          _isPurchasedBurnerBlock ? _purchaseOrderController.text.trim() : null,
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
                  setState(() {
                    _actionType = val;
                    if (val == ActionType.replacement) {
                      _status = ActionStatus.resolved;
                    }
                    if (val != ActionType.replacement) {
                      _replacementType = null;
                      _burnerPosition = null;
                      _burnerBlockSupplyMode = null;
                      _supplierController.clear();
                      _purchaseOrderController.clear();
                    }
                  });
                },
              ),
              if (_actionType == ActionType.replacement) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<ReplacementType>(
                  initialValue: _replacementType,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    'Replacement disposition',
                    icon: Icons.swap_horiz_rounded,
                  ),
                  hint: const Text('Select new, repaired or revised part'),
                  items:
                      ReplacementType.values
                          .map(
                            (type) => DropdownMenuItem<ReplacementType>(
                              value: type,
                              child: Text(_replacementTypeLabel(type)),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() => _replacementType = value);
                  },
                ),
              ],
              if (_isBurnerBlockReplacement) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.instrument.withValues(alpha: 0.08),
                    border: Border.all(
                      color: BafColors.instrument.withValues(alpha: 0.24),
                    ),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                  ),
                  child: const Text(
                    'Burner blocks may be SAIL-made by RED or purchased, but physical installation is Mechanical. A completed replacement updates the numbered burner lifecycle and condition audit when the parent work is closed.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _burnerPosition,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    'Burner position',
                    icon: Icons.local_fire_department_outlined,
                  ),
                  hint: const Text('Select burner 1-8'),
                  items: <DropdownMenuItem<int>>[
                    for (var position = 1; position <= 8; position++)
                      DropdownMenuItem<int>(
                        value: position,
                        child: Text('Burner $position'),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => _burnerPosition = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<BurnerBlockSupplyMode>(
                  initialValue: _burnerBlockSupplyMode,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    'Burner-block source',
                    icon: Icons.factory_outlined,
                  ),
                  hint: const Text('Select SAIL/RED-made or purchased'),
                  items: const <DropdownMenuItem<BurnerBlockSupplyMode>>[
                    DropdownMenuItem<BurnerBlockSupplyMode>(
                      value: BurnerBlockSupplyMode.sailRed,
                      child: Text('SAIL-made by RED'),
                    ),
                    DropdownMenuItem<BurnerBlockSupplyMode>(
                      value: BurnerBlockSupplyMode.purchased,
                      child: Text('Purchased'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _burnerBlockSupplyMode = value;
                      if (value != BurnerBlockSupplyMode.purchased) {
                        _supplierController.clear();
                        _purchaseOrderController.clear();
                      }
                    });
                  },
                ),
                if (_isPurchasedBurnerBlock) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _supplierController,
                    maxLength: 160,
                    decoration: _inputDecoration(
                      'Supplier name (optional)',
                      icon: Icons.business_outlined,
                    ).copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _purchaseOrderController,
                    maxLength: 160,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _inputDecoration(
                      'PO number (optional)',
                      icon: Icons.receipt_long_outlined,
                    ).copyWith(counterText: ''),
                  ),
                ],
              ],
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

  String _replacementTypeLabel(ReplacementType type) {
    switch (type) {
      case ReplacementType.newPart:
        return 'New part';
      case ReplacementType.repaired:
        return 'Repaired part';
      case ReplacementType.revised:
        return 'Revised / modified part';
    }
  }

  bool get _isBurnerBlockReplacement {
    if (_actionType != ActionType.replacement ||
        widget.target.assetTypeKey != 'furnace') {
      return false;
    }
    final reference = hierarchyReference;
    if (reference == null) return false;
    final identity =
        <String>[
          reference.nodeName,
          ...reference.hierarchyPath,
        ].join(' ').toLowerCase();
    return identity.contains('burner block') ||
        identity.contains('firing tube');
  }

  bool get _isPurchasedBurnerBlock =>
      _isBurnerBlockReplacement &&
      _burnerBlockSupplyMode == BurnerBlockSupplyMode.purchased;
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
