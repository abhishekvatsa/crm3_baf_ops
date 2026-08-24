import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../providers/asset_hierarchy_provider.dart';

class AssetRegistryScreen extends ConsumerWidget {
  const AssetRegistryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Operational access',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.verified_user_outlined,
        accent: BafColors.assets,
        label: 'Checking asset access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Operational access',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.verified_user_outlined,
        accent: BafColors.assets,
        message: 'Asset access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canViewOperationalAssets) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Operational access',
        appBarSubtitle: 'Approved plant records only',
        appBarIcon: Icons.verified_user_outlined,
        accent: BafColors.assets,
        title: 'Asset access required',
        message: 'Approved access is required.',
      );
    }
    return const _AssetRegistryBody();
  }
}

class _AssetRegistryBody extends ConsumerStatefulWidget {
  const _AssetRegistryBody();

  @override
  ConsumerState<_AssetRegistryBody> createState() => _AssetRegistryBodyState();
}

class _AssetRegistryBodyState extends ConsumerState<_AssetRegistryBody> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _assetClassId;
  bool _showRetired = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(allAssetInstancesProvider);
    final conditionsAsync = ref.watch(assetOperationalConditionsProvider);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Asset registry',
          subtitle: 'Equipment, components and lifecycle state',
          icon: Icons.precision_manufacturing_outlined,
          accent: BafColors.assets,
        ),
      ),
      body: assetsAsync.when(
        loading: () => const BafLoadingPanel(label: 'Loading asset registry'),
        error:
            (error, _) => _RegistryError(
              message: 'Could not load the asset registry.',
              onRetry: () => ref.invalidate(allAssetInstancesProvider),
            ),
        data: (assets) {
          if (conditionsAsync.isLoading && !conditionsAsync.hasValue) {
            return const BafLoadingPanel(
              label: 'Loading current equipment condition',
              color: BafColors.assets,
            );
          }
          if (conditionsAsync.hasError && !conditionsAsync.hasValue) {
            return _RegistryError(
              message: 'Could not load current asset conditions.',
              onRetry: () => ref.invalidate(assetOperationalConditionsProvider),
            );
          }
          return _buildRegistry(
            assets,
            conditionsAsync.value ?? const <AssetOperationalConditionRecord>[],
          );
        },
      ),
    );
  }

  Widget _buildRegistry(
    List<AssetInstanceRecord> assets,
    List<AssetOperationalConditionRecord> conditions,
  ) {
    final classNames = <String, String>{};
    for (final asset in assets) {
      classNames[asset.assetClassId] = asset.assetClassName;
    }
    final classIds =
        classNames.keys.toList()..sort(
          (left, right) => classNames[left]!.toLowerCase().compareTo(
            classNames[right]!.toLowerCase(),
          ),
        );
    final normalizedQuery = _query.trim().toLowerCase();
    final visible =
        assets.where((asset) {
          if (!_showRetired && !asset.isActive) return false;
          if (_assetClassId != null && asset.assetClassId != _assetClassId) {
            return false;
          }
          if (normalizedQuery.isEmpty) return true;
          return <String?>[
            asset.name,
            asset.assetClassName,
            asset.assetClassCode,
            asset.assetNumber.toString(),
            asset.plantTag,
            asset.location,
            asset.serialNumber,
          ].whereType<String>().any(
            (value) => value.toLowerCase().contains(normalizedQuery),
          );
        }).toList();
    final conditionByAsset = <String, AssetOperationalConditionRecord>{
      for (final condition in conditions) condition.assetInstanceId: condition,
    };

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allAssetInstancesProvider);
        ref.invalidate(assetOperationalConditionsProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _RegistryFilters(
              controller: _searchController,
              classIds: classIds,
              classNames: classNames,
              selectedClassId: _assetClassId,
              showRetired: _showRetired,
              onQueryChanged: (value) => setState(() => _query = value),
              onClassChanged: (value) => setState(() => _assetClassId = value),
              onShowRetiredChanged:
                  (value) => setState(() => _showRetired = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              0,
              BafSpacing.lg,
              BafSpacing.xl,
            ),
            sliver:
                visible.isEmpty
                    ? const SliverToBoxAdapter(child: _EmptyRegistry())
                    : SliverList.separated(
                      itemCount: visible.length + 1,
                      separatorBuilder:
                          (_, _) => const SizedBox(height: BafSpacing.sm),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: BafSpacing.xs,
                            ),
                            child: StatusBadge(
                              label: '${visible.length} assets',
                              color: BafColors.assets,
                              icon: Icons.inventory_2_outlined,
                            ),
                          );
                        }
                        final asset = visible[index - 1];
                        return _AssetRegistryCard(
                          asset: asset,
                          condition: conditionByAsset[asset.id],
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder:
                                      (_) => _AssetRegistryDetailScreen(
                                        assetInstanceId: asset.id,
                                      ),
                                ),
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _RegistryFilters extends StatelessWidget {
  final TextEditingController controller;
  final List<String> classIds;
  final Map<String, String> classNames;
  final String? selectedClassId;
  final bool showRetired;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<bool> onShowRetiredChanged;
  final VoidCallback onClear;

  const _RegistryFilters({
    required this.controller,
    required this.classIds,
    required this.classNames,
    required this.selectedClassId,
    required this.showRetired,
    required this.onQueryChanged,
    required this.onClassChanged,
    required this.onShowRetiredChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.md,
        BafSpacing.lg,
        BafSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Search number, tag, location or serial',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  controller.text.isEmpty
                      ? null
                      : IconButton(
                        tooltip: 'Clear search',
                        onPressed: onClear,
                        icon: const Icon(Icons.clear_rounded),
                      ),
              filled: true,
              fillColor: BafColors.card,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: BafSpacing.sm),
                  child: ChoiceChip(
                    label: const Text('All classes'),
                    selected: selectedClassId == null,
                    onSelected: (_) => onClassChanged(null),
                  ),
                ),
                ...classIds.map(
                  (id) => Padding(
                    padding: const EdgeInsets.only(right: BafSpacing.sm),
                    child: ChoiceChip(
                      label: Text(classNames[id]!),
                      selected: selectedClassId == id,
                      onSelected: (_) => onClassChanged(id),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Include retired assets',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(value: showRetired, onChanged: onShowRetiredChanged),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetRegistryCard extends StatelessWidget {
  final AssetInstanceRecord asset;
  final AssetOperationalConditionRecord? condition;
  final VoidCallback onTap;

  const _AssetRegistryCard({
    required this.asset,
    required this.condition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final operational = _effectiveCondition(condition);
    final conditionColor = _conditionColor(operational);
    return Material(
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: conditionColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(
                  operational == AssetOperationalCondition.available
                      ? Icons.precision_manufacturing_outlined
                      : Icons.warning_amber_rounded,
                  color: conditionColor,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      '${asset.assetClassCode} | Asset ${asset.assetNumber}',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    Wrap(
                      spacing: BafSpacing.xs,
                      runSpacing: BafSpacing.xs,
                      children: [
                        StatusBadge(
                          label: operational.label,
                          color: conditionColor,
                        ),
                        StatusBadge(
                          label: asset.serviceState.label,
                          color: BafColors.planned,
                        ),
                        if (!asset.isActive)
                          const StatusBadge(
                            label: 'Retired',
                            color: BafColors.textSecondary,
                          ),
                      ],
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    Text(
                      _assetSummary(asset),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: BafSpacing.sm),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: BafColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetRegistryDetailScreen extends ConsumerWidget {
  final String assetInstanceId;

  const _AssetRegistryDetailScreen({required this.assetInstanceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Asset details',
        appBarSubtitle: 'Identity, condition and installed components',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        label: 'Checking asset access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Asset details',
        appBarSubtitle: 'Identity, condition and installed components',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        message: 'Asset access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canViewOperationalAssets) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Asset details',
        appBarSubtitle: 'Identity, condition and installed components',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        title: 'Asset access required',
        message:
            'An approved operational role is required to inspect this asset.',
      );
    }
    final assetsAsync = ref.watch(allAssetInstancesProvider);
    final conditionsAsync = ref.watch(assetOperationalConditionsProvider);
    if ((assetsAsync.isLoading && !assetsAsync.hasValue) ||
        (conditionsAsync.isLoading && !conditionsAsync.hasValue)) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Asset details',
        appBarSubtitle: 'Identity, condition and installed components',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        label: 'Loading current asset state',
      );
    }
    if ((assetsAsync.hasError && !assetsAsync.hasValue) ||
        (conditionsAsync.hasError && !conditionsAsync.hasValue)) {
      return BafScreenStateScaffold(
        appBarTitle: 'Asset details',
        appBarSubtitle: 'Identity, condition and installed components',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        state: _RegistryError(
          message: 'Could not refresh the current asset state.',
          onRetry: () {
            ref.invalidate(allAssetInstancesProvider);
            ref.invalidate(assetOperationalConditionsProvider);
          },
        ),
      );
    }
    final asset = _findAsset(assetsAsync.value ?? const [], assetInstanceId);
    if (asset == null) {
      return BafScreenStateScaffold(
        appBarTitle: 'Asset details',
        appBarSubtitle: 'Identity, condition and installed components',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        state: BafStatePanel.empty(
          title: 'Asset no longer available',
          message: 'This asset is not present in the governed registry.',
          icon: Icons.inventory_2_outlined,
          color: BafColors.assets,
        ),
      );
    }
    final condition = _findCondition(
      conditionsAsync.value ?? const [],
      assetInstanceId,
    );
    final componentsAsync = ref.watch(
      installedComponentsProvider(assetInstanceId),
    );
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: BafAppBarTitle(
          title: asset.name,
          subtitle: '${asset.assetClassName} · ${asset.assetNumber}',
          icon: Icons.precision_manufacturing_outlined,
          accent: BafColors.assets,
        ),
      ),
      body: componentsAsync.when(
        loading:
            () => const BafLoadingPanel(
              label: 'Loading installed components',
              color: BafColors.assets,
            ),
        error:
            (_, _) => _RegistryError(
              message: 'Could not load installed components.',
              onRetry:
                  () => ref.invalidate(
                    installedComponentsProvider(assetInstanceId),
                  ),
            ),
        data: (components) {
          final current = components.where((item) => item.isActive).toList();
          final retired = components.where((item) => !item.isActive).toList();
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allAssetInstancesProvider);
              ref.invalidate(assetOperationalConditionsProvider);
              ref.invalidate(installedComponentsProvider(assetInstanceId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.lg,
                BafSpacing.md,
                BafSpacing.lg,
                BafSpacing.xl,
              ),
              children: [
                _AssetSummaryPanel(asset: asset, condition: condition),
                const SizedBox(height: BafSpacing.xl),
                _SectionHeader(
                  title: 'Installed components',
                  count: current.length,
                ),
                const SizedBox(height: BafSpacing.sm),
                if (current.isEmpty)
                  const _InlineEmpty(label: 'No active components recorded.')
                else
                  ...current.map(
                    (component) => Padding(
                      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                      child: _ComponentCard(
                        component: component,
                        allComponents: components,
                      ),
                    ),
                  ),
                if (retired.isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.lg),
                  _SectionHeader(
                    title: 'Retired component history',
                    count: retired.length,
                  ),
                  const SizedBox(height: BafSpacing.sm),
                  ...retired.map(
                    (component) => Padding(
                      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                      child: _ComponentCard(
                        component: component,
                        allComponents: components,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssetSummaryPanel extends StatelessWidget {
  final AssetInstanceRecord asset;
  final AssetOperationalConditionRecord? condition;

  const _AssetSummaryPanel({required this.asset, required this.condition});

  @override
  Widget build(BuildContext context) {
    final operational = _effectiveCondition(condition);
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: BafSpacing.xs,
            runSpacing: BafSpacing.xs,
            children: [
              StatusBadge(
                label: operational.label,
                color: _conditionColor(operational),
              ),
              StatusBadge(
                label: asset.serviceState.label,
                color: BafColors.planned,
              ),
              StatusBadge(
                label: '${asset.activeComponentCount} active components',
                color: BafColors.assets,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          _DetailLine(label: 'Asset class', value: asset.assetClassName),
          _DetailLine(label: 'Asset number', value: '${asset.assetNumber}'),
          if (asset.plantTag != null)
            _DetailLine(label: 'Plant tag', value: asset.plantTag!),
          if (asset.location != null)
            _DetailLine(label: 'Location', value: asset.location!),
          _DetailLine(label: 'Ownership', value: asset.ownershipStatus.label),
          if (asset.ownerDiscipline != null)
            _DetailLine(label: 'Discipline', value: asset.ownerDiscipline!),
          if (condition?.active == true) ...[
            _DetailLine(label: 'Condition reason', value: condition!.reason),
            if (condition!.causes.isNotEmpty)
              _DetailLine(
                label: 'Condition causes',
                value: condition!.causes.map((item) => item.label).join(', '),
              ),
          ],
        ],
      ),
    );
  }
}

class _ComponentCard extends StatelessWidget {
  final InstalledComponentRecord component;
  final List<InstalledComponentRecord> allComponents;

  const _ComponentCard({required this.component, required this.allComponents});

  @override
  Widget build(BuildContext context) {
    final lineage = _componentLineage(component, allComponents);
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  component.definitionName,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusBadge(
                label: component.isActive ? 'Installed' : 'Retired',
                color:
                    component.isActive
                        ? BafColors.success
                        : BafColors.textSecondary,
              ),
            ],
          ),
          if (component.componentTag != null) ...[
            const SizedBox(height: BafSpacing.xs),
            Text(
              component.componentTag!,
              style: const TextStyle(
                color: BafColors.assets,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.sm),
          Wrap(
            spacing: BafSpacing.xs,
            runSpacing: BafSpacing.xs,
            children: [
              StatusBadge(
                label: component.serviceState.label,
                color: BafColors.planned,
              ),
              StatusBadge(
                label: component.ownershipStatus.label,
                color: BafColors.admin,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          if (component.manufacturer != null)
            _DetailLine(label: 'Manufacturer', value: component.manufacturer!),
          if (component.model != null)
            _DetailLine(label: 'Model', value: component.model!),
          if (component.serialNumber != null)
            _DetailLine(label: 'Serial number', value: component.serialNumber!),
          if (component.installedOn != null)
            _DetailLine(
              label: 'Installed on',
              value: DateFormat('dd MMM yyyy').format(component.installedOn!),
            ),
          if (component.ownerDiscipline != null)
            _DetailLine(
              label: 'Responsible discipline',
              value: component.ownerDiscipline!,
            ),
          if (lineage.length > 1) ...[
            const SizedBox(height: BafSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    () => _showComponentLineage(
                      context,
                      component.definitionName,
                      lineage,
                    ),
                icon: const Icon(Icons.timeline_rounded),
                label: Text('Replacement lineage (${lineage.length})'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        StatusBadge(label: '$count', color: BafColors.assets),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final String label;

  const _InlineEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(color: BafColors.textSecondary),
      ),
    );
  }
}

class _EmptyRegistry extends StatelessWidget {
  const _EmptyRegistry();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 42,
            color: BafColors.textSecondary,
          ),
          SizedBox(height: BafSpacing.md),
          Text(
            'No assets match these filters.',
            style: TextStyle(color: BafColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RegistryError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RegistryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: BafColors.danger),
            const SizedBox(height: BafSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: BafSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

AssetInstanceRecord? _findAsset(
  List<AssetInstanceRecord> assets,
  String assetInstanceId,
) {
  for (final asset in assets) {
    if (asset.id == assetInstanceId) return asset;
  }
  return null;
}

AssetOperationalConditionRecord? _findCondition(
  List<AssetOperationalConditionRecord> conditions,
  String assetInstanceId,
) {
  for (final condition in conditions) {
    if (condition.assetInstanceId == assetInstanceId) return condition;
  }
  return null;
}

AssetOperationalCondition _effectiveCondition(
  AssetOperationalConditionRecord? record,
) =>
    record?.active == true
        ? record!.condition
        : AssetOperationalCondition.available;

Color _conditionColor(AssetOperationalCondition condition) =>
    switch (condition) {
      AssetOperationalCondition.available => BafColors.success,
      AssetOperationalCondition.down => BafColors.danger,
      AssetOperationalCondition.unfit => BafColors.warning,
    };

String _assetSummary(AssetInstanceRecord asset) {
  final details = <String>[
    '${asset.activeComponentCount} active components',
    if (asset.plantTag != null) asset.plantTag!,
    if (asset.location != null) asset.location!,
  ];
  return details.join('  |  ');
}

List<InstalledComponentRecord> _componentLineage(
  InstalledComponentRecord selected,
  List<InstalledComponentRecord> all,
) {
  final result =
      all.where((item) => item.lifecycleId == selected.lifecycleId).toList()
        ..sort((left, right) {
          final leftAt = left.installedOn ?? left.createdAt;
          final rightAt = right.installedOn ?? right.createdAt;
          return leftAt.compareTo(rightAt);
        });
  return result;
}

Future<void> _showComponentLineage(
  BuildContext context,
  String definitionName,
  List<InstalledComponentRecord> lineage,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder:
        (context) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.76,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.lg,
                0,
                BafSpacing.lg,
                BafSpacing.xl,
              ),
              itemCount: lineage.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.lg),
                    child: Text(
                      '$definitionName replacement lineage',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }
                final item = lineage[index - 1];
                final installedAt = item.installedOn ?? item.createdAt;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.isActive
                        ? Icons.check_circle_rounded
                        : Icons.history_rounded,
                    color:
                        item.isActive
                            ? BafColors.success
                            : BafColors.textSecondary,
                  ),
                  title: Text(item.componentTag ?? item.definitionName),
                  subtitle: Text(
                    [
                      if (item.serialNumber != null)
                        'Serial ${item.serialNumber}',
                      'Installed ${DateFormat('dd MMM yyyy').format(installedAt)}',
                    ].join(' | '),
                  ),
                  trailing: Text(item.isActive ? 'Current' : 'Replaced'),
                );
              },
            ),
          ),
        ),
  );
}
