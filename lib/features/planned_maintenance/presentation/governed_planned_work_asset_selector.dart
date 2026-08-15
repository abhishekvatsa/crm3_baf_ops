import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../domain/governed_planned_work_asset_selection.dart';

class GovernedPlannedWorkAssetSelector extends StatelessWidget {
  const GovernedPlannedWorkAssetSelector({
    super.key,
    required this.assetType,
    required this.classesValue,
    required this.route,
    required this.assetsValue,
    required this.innerCoverAssignmentsValue,
    required this.linkedInnerCoversByBase,
    required this.eligibleAssets,
    required this.selectedAssetInstanceId,
    required this.onAssetChanged,
    this.missingTargetMessage =
        'Select a valid template before choosing an asset.',
  });

  final AssetType? assetType;
  final AsyncValue<List<AssetClassRecord>> classesValue;
  final GovernedPlannedWorkAssetRoute? route;
  final AsyncValue<List<AssetInstanceRecord>>? assetsValue;
  final AsyncValue<List<BaseInnerCoverAssignment>>? innerCoverAssignmentsValue;
  final Map<String, BaseInnerCoverAssignment> linkedInnerCoversByBase;
  final List<AssetInstanceRecord> eligibleAssets;
  final String? selectedAssetInstanceId;
  final ValueChanged<AssetInstanceRecord?>? onAssetChanged;
  final String missingTargetMessage;

  @override
  Widget build(BuildContext context) {
    final currentAssetType = assetType;
    if (currentAssetType == null) {
      return AssetSelectionMessage(
        icon: Icons.policy_rounded,
        message: missingTargetMessage,
        color: BafColors.warning,
      );
    }
    if (classesValue.isLoading) {
      return const AssetSelectionMessage(
        icon: Icons.sync_rounded,
        message: 'Loading the governed asset register...',
        color: BafColors.planned,
        showProgress: true,
      );
    }
    if (classesValue.hasError) {
      return const AssetSelectionMessage(
        icon: Icons.error_outline_rounded,
        message:
            'The governed asset register could not be loaded. Sync and try again.',
        color: BafColors.danger,
      );
    }
    final currentRoute = route;
    if (currentRoute == null || !currentRoute.isAvailable) {
      return AssetSelectionMessage(
        icon: Icons.block_rounded,
        message:
            currentRoute?.blockingReason ??
            'This template does not have an assignable governed asset route.',
        color: BafColors.danger,
      );
    }
    if (assetsValue?.isLoading == true) {
      return const AssetSelectionMessage(
        icon: Icons.sync_rounded,
        message: 'Loading active physical assets...',
        color: BafColors.planned,
        showProgress: true,
      );
    }
    if (assetsValue?.hasError == true) {
      return const AssetSelectionMessage(
        icon: Icons.error_outline_rounded,
        message: 'Physical assets could not be loaded. Sync and try again.',
        color: BafColors.danger,
      );
    }
    if (currentRoute.innerCoverByBase &&
        innerCoverAssignmentsValue?.isLoading == true) {
      return const AssetSelectionMessage(
        icon: Icons.sync_rounded,
        message: 'Loading current Base and Inner Cover positions...',
        color: BafColors.planned,
        showProgress: true,
      );
    }
    if (currentRoute.innerCoverByBase &&
        innerCoverAssignmentsValue?.hasError == true) {
      return const AssetSelectionMessage(
        icon: Icons.error_outline_rounded,
        message:
            'Current Inner Cover positions could not be verified. Sync and try again.',
        color: BafColors.danger,
      );
    }
    final physicalClass = currentRoute.physicalAssetClass!;
    if (eligibleAssets.isEmpty) {
      return AssetSelectionMessage(
        icon: Icons.precision_manufacturing_outlined,
        message:
            currentRoute.innerCoverByBase
                ? 'No active ${physicalClass.name} currently has a governed Inner Cover linkage.'
                : 'No active ${physicalClass.name} assets match this template.',
        color: BafColors.warning,
      );
    }
    final selectedAsset =
        eligibleAssets
            .where((item) => item.id == selectedAssetInstanceId)
            .firstOrNull ??
        (currentRoute.fixedAssetInstanceId != null && eligibleAssets.length == 1
            ? eligibleAssets.single
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssetSelectionMessage(
          icon:
              currentRoute.innerCoverByBase
                  ? Icons.link_rounded
                  : Icons.account_tree_rounded,
          message:
              currentRoute.innerCoverByBase
                  ? 'This Inner Cover job is assigned by its current Base position. Select the Base carrying the Inner Cover.'
                  : currentRoute.fixedAssetInstanceId != null
                  ? 'This template is fixed to one governed physical asset.'
                  : '${plannedWorkAssetTypeLabel(currentAssetType)} work will be assigned to an exact active ${physicalClass.name} record.',
          color: BafColors.planned,
        ),
        const SizedBox(height: BafSpacing.md),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'planned-work-asset-${physicalClass.id}-${selectedAsset?.id ?? 'none'}-${eligibleAssets.length}',
          ),
          initialValue: selectedAsset?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText:
                currentRoute.innerCoverByBase
                    ? 'Base carrying Inner Cover'
                    : 'Physical asset',
            prefixIcon: const Icon(Icons.precision_manufacturing_rounded),
            filled: true,
            fillColor: BafColors.card,
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
              borderSide: const BorderSide(
                color: BafColors.planned,
                width: 1.5,
              ),
            ),
          ),
          items: eligibleAssets
              .map(
                (asset) => DropdownMenuItem<String>(
                  value: asset.id,
                  child: Text(
                    _assetLabel(
                      asset,
                      innerCoverAssignment: linkedInnerCoversByBase[asset.id],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged:
              onAssetChanged == null ||
                      currentRoute.fixedAssetInstanceId != null
                  ? null
                  : (assetId) => onAssetChanged!(
                    assetId == null
                        ? null
                        : eligibleAssets.firstWhere(
                          (item) => item.id == assetId,
                        ),
                  ),
          validator:
              (value) =>
                  value == null ? 'Choose the exact physical asset' : null,
        ),
        if (selectedAsset != null) ...[
          const SizedBox(height: BafSpacing.sm),
          Text(
            [
              if (selectedAsset.plantTag?.trim().isNotEmpty == true)
                'Tag ${selectedAsset.plantTag!.trim()}',
              if (selectedAsset.location?.trim().isNotEmpty == true)
                selectedAsset.location!.trim(),
              if (linkedInnerCoversByBase[selectedAsset.id] case final linkage?)
                'Inner Cover ${linkage.innerCoverSerialNumber}',
              'Registry v${selectedAsset.version}',
            ].join('  |  '),
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _assetLabel(
    AssetInstanceRecord asset, {
    BaseInnerCoverAssignment? innerCoverAssignment,
  }) {
    final numberLabel = '${asset.assetClassName} ${asset.assetNumber}';
    final name = asset.name.trim();
    final assetLabel =
        name.isEmpty || name.toLowerCase() == numberLabel.toLowerCase()
            ? numberLabel
            : '$numberLabel - $name';
    return innerCoverAssignment == null
        ? assetLabel
        : '$assetLabel | Inner Cover ${innerCoverAssignment.innerCoverSerialNumber}';
  }
}

class AssetSelectionMessage extends StatelessWidget {
  const AssetSelectionMessage({
    super.key,
    required this.icon,
    required this.message,
    required this.color,
    this.showProgress = false,
  });

  final IconData icon;
  final String message;
  final Color color;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          if (showProgress) ...[
            const SizedBox(width: BafSpacing.sm),
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

String plannedWorkAssetTypeLabel(AssetType assetType) => switch (assetType) {
  AssetType.base => 'Base',
  AssetType.furnace => 'Furnace',
  AssetType.forceCooler => 'Forced Cooler',
  AssetType.innerCover => 'Inner Cover',
  AssetType.governedCustom => 'Governed asset',
};
