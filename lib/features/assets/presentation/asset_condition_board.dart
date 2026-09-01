import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../data/inner_cover_lifecycle.dart';
import '../domain/plant_asset_overview.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../providers/plant_asset_overview_provider.dart';
import 'inner_cover_lifecycle_screen.dart';
import 'widgets/governed_asset_target_picker.dart';

part 'asset_condition_board.filters.dart';
part 'asset_condition_board.summary.dart';

enum AssetConditionFilter {
  all,
  available,
  unavailable,
  maintenance,
  stuckUp,
  down,
  unfit,
}

class AssetConditionBoard extends ConsumerStatefulWidget {
  final AssetConditionFilter initialFilter;
  final String? initialAssetClassId;

  const AssetConditionBoard({
    super.key,
    this.initialFilter = AssetConditionFilter.all,
    this.initialAssetClassId,
  });

  @override
  ConsumerState<AssetConditionBoard> createState() =>
      _AssetConditionBoardState();
}

class _AssetConditionBoardState extends ConsumerState<AssetConditionBoard> {
  late AssetConditionFilter _selectedFilter = widget.initialFilter;
  late String? _selectedAssetClassId = widget.initialAssetClassId;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Plant condition',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        label: 'Checking plant-condition access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Plant condition',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        message: 'Plant-condition access could not be verified.',
      );
    }
    final user = actorAsync.value;
    if (user == null || !user.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Plant condition',
        appBarSubtitle: 'Live availability and maintenance state',
        appBarIcon: Icons.precision_manufacturing_outlined,
        accent: BafColors.assets,
        title: 'Plant-condition access required',
        message: 'An approved account is required to view plant condition.',
      );
    }
    final overview = ref.watch(plantAssetOverviewProvider);
    final conditionTickets = ref.watch(plantConditionTicketsProvider);
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Plant condition',
          subtitle: 'Live availability and maintenance state',
          icon: Icons.precision_manufacturing_outlined,
          accent: BafColors.assets,
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: overview.when(
              loading:
                  () => const BafLoadingPanel(
                    label: 'Loading live plant condition',
                    color: BafColors.assets,
                  ),
              error: (error, _) => _ConditionLoadError(error: error),
              data:
                  (value) => _ConditionBoardBody(
                    overview: value,
                    user: user,
                    openTickets: (conditionTickets.value ??
                            const <MaintenanceRecord>[])
                        .where(
                          (ticket) => !ticket.isResolved && !ticket.isDeleted,
                        )
                        .toList(growable: false),
                    ticketLoadFailed: conditionTickets.hasError,
                    selectedFilter: _selectedFilter,
                    selectedAssetClassId: _selectedAssetClassId,
                    onFilterChanged:
                        (filter) => setState(() => _selectedFilter = filter),
                    onAssetClassChanged:
                        (assetClassId) => setState(
                          () => _selectedAssetClassId = assetClassId,
                        ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlantOverviewPanel extends StatelessWidget {
  final AsyncValue<PlantAssetOverview> overview;
  final VoidCallback onOpen;
  final ValueChanged<AssetConditionFilter>? onOpenFiltered;

  const PlantOverviewPanel({
    super.key,
    required this.overview,
    required this.onOpen,
    this.onOpenFiltered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BafColors.card,
        border: Border.all(color: BafColors.border),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        boxShadow: BafShadows.subtle,
      ),
      child: overview.when(
        loading:
            () => const SizedBox(
              height: 132,
              child: Center(child: CircularProgressIndicator()),
            ),
        error:
            (error, _) => InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(BafRadius.medium),
              child: const Padding(
                padding: EdgeInsets.all(BafSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: BafColors.danger),
                    SizedBox(width: BafSpacing.md),
                    Expanded(
                      child: Text(
                        'Plant condition data needs attention. Open the board for details.',
                        style: TextStyle(color: BafColors.textPrimary),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
        data:
            (value) => InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(BafRadius.medium),
              child: Padding(
                padding: const EdgeInsets.all(BafSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: BafColors.assets.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              BafRadius.small,
                            ),
                          ),
                          child: const Icon(
                            Icons.precision_manufacturing_outlined,
                            color: BafColors.assets,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: BafSpacing.sm),
                        const Expanded(
                          child: Text(
                            'Plant condition',
                            style: TextStyle(
                              color: BafColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${value.available}/${value.total}',
                          style: const TextStyle(
                            color: BafColors.assets,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: BafSpacing.xs),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: BafColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: BafSpacing.md),
                    if (value.total == 0)
                      const Text(
                        'No active physical assets are registered yet.',
                        style: TextStyle(color: BafColors.textSecondary),
                      )
                    else ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width =
                              (constraints.maxWidth - BafSpacing.xs * 2) / 3;
                          return Wrap(
                            spacing: BafSpacing.xs,
                            runSpacing: BafSpacing.xs,
                            children: [
                              _PlantMetric(
                                width: width,
                                value: value.available,
                                label: 'Available',
                                color: BafColors.success,
                                onTap:
                                    () => _openFilter(
                                      AssetConditionFilter.available,
                                    ),
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.issueUnavailable,
                                label: 'Unavailable',
                                color: BafColors.cobalt,
                                onTap:
                                    () => _openFilter(
                                      AssetConditionFilter.unavailable,
                                    ),
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.underMaintenance,
                                label: 'Maintenance',
                                color: BafColors.maintenance,
                                onTap:
                                    () => _openFilter(
                                      AssetConditionFilter.maintenance,
                                    ),
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.temporarilyBlocked,
                                label: 'Stuck-up',
                                color: BafColors.instrument,
                                onTap:
                                    () => _openFilter(
                                      AssetConditionFilter.stuckUp,
                                    ),
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.down,
                                label: 'Down',
                                color: BafColors.danger,
                                onTap:
                                    () =>
                                        _openFilter(AssetConditionFilter.down),
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.unfit,
                                label: 'Unfit',
                                color: BafColors.warning,
                                onTap:
                                    () =>
                                        _openFilter(AssetConditionFilter.unfit),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: BafSpacing.sm),
                      ...value.classes
                          .where((summary) => summary.total > 0)
                          .map(_PlantClassConditionSummary.new),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }

  void _openFilter(AssetConditionFilter filter) {
    final callback = onOpenFiltered;
    if (callback != null) {
      callback(filter);
    } else {
      onOpen();
    }
  }
}

class _ConditionBoardBody extends StatelessWidget {
  final PlantAssetOverview overview;
  final AppUser? user;
  final List<MaintenanceRecord> openTickets;
  final bool ticketLoadFailed;
  final AssetConditionFilter selectedFilter;
  final String? selectedAssetClassId;
  final ValueChanged<AssetConditionFilter> onFilterChanged;
  final ValueChanged<String?> onAssetClassChanged;

  const _ConditionBoardBody({
    required this.overview,
    required this.user,
    required this.openTickets,
    required this.ticketLoadFailed,
    required this.selectedFilter,
    required this.selectedAssetClassId,
    required this.onFilterChanged,
    required this.onAssetClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (overview.total == 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(BafSpacing.xl),
          child: Text(
            'No active physical assets are registered.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BafColors.textSecondary),
          ),
        ),
      );
    }
    final visibleClasses = overview.classes
        .where(
          (summary) =>
              summary.total > 0 &&
              (selectedAssetClassId == null ||
                  summary.assetClass.id == selectedAssetClassId),
        )
        .map(
          (summary) => PlantAssetClassSummary(
            assetClass: summary.assetClass,
            assets: summary.assets
                .where(_matchesSelectedCondition)
                .toList(growable: false),
          ),
        )
        .where((summary) => summary.total > 0)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.lg,
        BafSpacing.xl,
      ),
      children: [
        const Text(
          'Current asset scenario',
          style: TextStyle(
            color: BafColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: BafSpacing.xs),
        const Text(
          'Counts may overlap when an asset is both unavailable and under maintenance.',
          style: TextStyle(color: BafColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: BafSpacing.lg),
        Wrap(
          spacing: BafSpacing.sm,
          runSpacing: BafSpacing.sm,
          children: [
            _ConditionFilterChip(
              label: '${overview.total} registered',
              color: BafColors.assets,
              selected: selectedFilter == AssetConditionFilter.all,
              onSelected: () => onFilterChanged(AssetConditionFilter.all),
            ),
            _ConditionFilterChip(
              label: '${overview.available} available',
              color: BafColors.success,
              selected: selectedFilter == AssetConditionFilter.available,
              onSelected: () => onFilterChanged(AssetConditionFilter.available),
            ),
            _ConditionFilterChip(
              label: '${overview.issueUnavailable} unavailable',
              color: BafColors.cobalt,
              selected: selectedFilter == AssetConditionFilter.unavailable,
              onSelected:
                  () => onFilterChanged(AssetConditionFilter.unavailable),
            ),
            _ConditionFilterChip(
              label: '${overview.underMaintenance} maintenance',
              color: BafColors.maintenance,
              selected: selectedFilter == AssetConditionFilter.maintenance,
              onSelected:
                  () => onFilterChanged(AssetConditionFilter.maintenance),
            ),
            _ConditionFilterChip(
              label: '${overview.temporarilyBlocked} stuck-up',
              color: BafColors.instrument,
              selected: selectedFilter == AssetConditionFilter.stuckUp,
              onSelected: () => onFilterChanged(AssetConditionFilter.stuckUp),
            ),
            _ConditionFilterChip(
              label: '${overview.down} down',
              color: BafColors.danger,
              selected: selectedFilter == AssetConditionFilter.down,
              onSelected: () => onFilterChanged(AssetConditionFilter.down),
            ),
            _ConditionFilterChip(
              label: '${overview.unfit} unfit',
              color: BafColors.warning,
              selected: selectedFilter == AssetConditionFilter.unfit,
              onSelected: () => onFilterChanged(AssetConditionFilter.unfit),
            ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        Wrap(
          spacing: BafSpacing.xs,
          runSpacing: BafSpacing.xs,
          children: [
            ChoiceChip(
              key: const ValueKey('plant-asset-class-all'),
              label: const Text('All asset classes'),
              selected: selectedAssetClassId == null,
              onSelected: (_) => onAssetClassChanged(null),
            ),
            for (final summary in overview.classes.where(
              (item) => item.total > 0,
            ))
              ChoiceChip(
                key: ValueKey<String>(
                  'plant-asset-class-${summary.assetClass.id}',
                ),
                label: Text(summary.assetClass.name),
                selected: selectedAssetClassId == summary.assetClass.id,
                onSelected: (_) => onAssetClassChanged(summary.assetClass.id),
              ),
          ],
        ),
        if (ticketLoadFailed) ...[
          const SizedBox(height: BafSpacing.md),
          const Text(
            'Open issues could not be loaded, so issue linking is temporarily unavailable.',
            style: TextStyle(color: BafColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: BafSpacing.xl),
        if (visibleClasses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: BafSpacing.xl),
            child: Text(
              'No assets match the selected condition and asset class.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BafColors.textSecondary),
            ),
          )
        else
          ...visibleClasses.map(
            (summary) => _AssetClassSection(
              summary: summary,
              user: user,
              openTickets: openTickets,
            ),
          ),
      ],
    );
  }

  bool _matchesSelectedCondition(PlantAssetState asset) =>
      switch (selectedFilter) {
        AssetConditionFilter.all => true,
        AssetConditionFilter.available => asset.isAvailable,
        AssetConditionFilter.unavailable => asset.isIssueUnavailable,
        AssetConditionFilter.maintenance => asset.isUnderMaintenance,
        AssetConditionFilter.stuckUp => asset.isTemporarilyBlocked,
        AssetConditionFilter.down => asset.isDown,
        AssetConditionFilter.unfit => asset.isUnfit,
      };
}

class _AssetClassSection extends StatelessWidget {
  final PlantAssetClassSummary summary;
  final AppUser? user;
  final List<MaintenanceRecord> openTickets;

  const _AssetClassSection({
    required this.summary,
    required this.user,
    required this.openTickets,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.assetClass.name,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${summary.total} assets',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: BafColors.card,
              border: Border.all(color: BafColors.border),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: Column(
              children: List<Widget>.generate(summary.assets.length * 2 - 1, (
                index,
              ) {
                return index.isEven
                    ? _AssetConditionRow(
                      state: summary.assets[index ~/ 2],
                      assetClass: summary.assetClass,
                      user: user,
                      openTickets: openTickets,
                    )
                    : const Divider(height: 1, color: BafColors.border);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AssetConditionAction { declareDown, declareUnfit, restore }

class _AssetConditionRow extends ConsumerWidget {
  final PlantAssetState state;
  final AssetClassRecord assetClass;
  final AppUser? user;
  final List<MaintenanceRecord> openTickets;

  const _AssetConditionRow({
    required this.state,
    required this.assetClass,
    required this.user,
    required this.openTickets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDeclare =
        user?.canDeclareAssetOperationalCondition == true &&
        !state.isAdministrativelyOutOfService;
    final canRestore =
        user?.canRestoreAssetOperationalCondition == true &&
        (state.isDown || state.isManuallyUnfit);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.md,
        BafSpacing.md,
        BafSpacing.sm,
        BafSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _primaryColor(state).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Icon(
              _primaryIcon(state),
              color: _primaryColor(state),
              size: 20,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.asset.name,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Wrap(
                  spacing: BafSpacing.xs,
                  runSpacing: BafSpacing.xs,
                  children: _stateBadges(state),
                ),
                if (state.operationalCondition?.active == true) ...[
                  const SizedBox(height: BafSpacing.sm),
                  Text(
                    state.operationalCondition!.reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (state.operationalCondition!.basis case final basis?) ...[
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      <String>[
                        basis.label,
                        if (state.operationalCondition!.componentReference
                            case final reference?)
                          reference.hierarchyPath.join(' › '),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: BafSpacing.xs),
                  Text(
                    'Declared ${DateFormat('dd MMM, HH:mm').format(state.operationalCondition!.declaredAt!.toLocal())} by ${state.operationalCondition!.declaredByName}',
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (state.issueConditionContributions.isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.sm),
                  for (final contribution
                      in state.issueConditionContributions) ...[
                    Text(
                      contribution.comment,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            contribution.effect ==
                                    MaintenanceIssuePlantConditionEffect
                                        .unavailable
                                ? BafColors.cobalt
                                : BafColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Text(
                      <String>[
                        'Raised ${DateFormat('dd MMM, HH:mm').format(contribution.startedAt.toLocal())}',
                        if (contribution.raisedByName case final name?)
                          'by $name',
                      ].join(' '),
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (canDeclare || canRestore)
            PopupMenuButton<_AssetConditionAction>(
              tooltip: 'Asset condition actions',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => _runAction(context, ref, action),
              itemBuilder:
                  (context) => [
                    if (canDeclare && !state.isDown)
                      const PopupMenuItem(
                        value: _AssetConditionAction.declareDown,
                        child: Text('Declare down'),
                      ),
                    if (canDeclare && !state.isManuallyUnfit)
                      const PopupMenuItem(
                        value: _AssetConditionAction.declareUnfit,
                        child: Text('Declare unfit'),
                      ),
                    if (canRestore)
                      const PopupMenuItem(
                        value: _AssetConditionAction.restore,
                        child: Text('Restore availability'),
                      ),
                  ],
            ),
        ],
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    _AssetConditionAction action,
  ) async {
    final actor = user;
    if (actor == null) return;
    if (action == _AssetConditionAction.restore) {
      final reason = await _showReasonDialog(
        context,
        title: 'Restore ${state.asset.name}',
        actionLabel: 'Restore',
        hint: 'State the evidence that makes the asset safe and available.',
      );
      if (reason == null || !context.mounted) return;
      await _perform(
        context,
        () => ref
            .read(assetHierarchyRepositoryProvider)
            .restoreAssetCondition(
              asset: state.asset,
              current: state.operationalCondition!,
              reason: reason,
              actor: actor,
            ),
        'Availability restored.',
      );
      return;
    }
    final condition =
        action == _AssetConditionAction.declareDown
            ? AssetOperationalCondition.down
            : AssetOperationalCondition.unfit;
    final List<MaintenanceRecord> linkedTickets;
    try {
      linkedTickets = _ticketsForAsset(openTickets, state.asset.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Open issue data could not be verified: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    final draft = await showModalBottomSheet<_ConditionDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder:
          (context) => _DeclareConditionSheet(
            asset: state.asset,
            isBase: assetClass.legacyAssetTypeKey == 'base',
            condition: condition,
            tickets: linkedTickets,
          ),
    );
    if (draft == null || !context.mounted) return;
    await _perform(
      context,
      () => ref
          .read(assetHierarchyRepositoryProvider)
          .declareAssetCondition(
            asset: state.asset,
            condition: condition,
            causes: draft.causes,
            basis: draft.basis,
            componentReference: draft.componentReference,
            reason: draft.reason,
            linkedIssueIds: draft.linkedIssueIds,
            actor: actor,
            current: state.operationalCondition,
          ),
      '${condition.label} condition recorded.',
    );
  }
}

class _ConditionDraft {
  final Set<AssetConditionCause> causes;
  final AssetConditionBasis basis;
  final AssetHierarchyReference? componentReference;
  final String reason;
  final List<String> linkedIssueIds;

  const _ConditionDraft({
    required this.causes,
    required this.basis,
    required this.componentReference,
    required this.reason,
    required this.linkedIssueIds,
  });
}

class _DeclareConditionSheet extends ConsumerStatefulWidget {
  final AssetInstanceRecord asset;
  final bool isBase;
  final AssetOperationalCondition condition;
  final List<MaintenanceRecord> tickets;

  const _DeclareConditionSheet({
    required this.asset,
    required this.isBase,
    required this.condition,
    required this.tickets,
  });

  @override
  ConsumerState<_DeclareConditionSheet> createState() =>
      _DeclareConditionSheetState();
}

class _DeclareConditionSheetState
    extends ConsumerState<_DeclareConditionSheet> {
  final _reason = TextEditingController();
  final Set<AssetConditionCause> _causes = {};
  final Set<String> _tickets = {};
  AssetConditionBasis? _basis;
  AssetHierarchyReference? _componentReference;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final nodesAsync = ref.watch(
      assetHierarchyNodesProvider(widget.asset.assetClassId),
    );
    final assignmentsAsync =
        widget.isBase ? ref.watch(innerCoverAssignmentsProvider) : null;
    final linkedInnerCover =
        assignmentsAsync?.value
            ?.where(
              (assignment) => assignment.baseAssetInstanceId == widget.asset.id,
            )
            .firstOrNull;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.sm,
          BafSpacing.lg,
          BafSpacing.xl + bottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Declare ${widget.asset.name} ${widget.condition.label.toLowerCase()}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: BafSpacing.lg),
                DropdownButtonFormField<AssetConditionBasis>(
                  initialValue: _basis,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Why is the asset unavailable?',
                    prefixIcon: Icon(Icons.rule_folder_outlined),
                  ),
                  items: [
                    for (final basis in AssetConditionBasis.values)
                      if (widget.isBase ||
                          basis != AssetConditionBasis.innerCoverUnavailable)
                        DropdownMenuItem(
                          value: basis,
                          child: Text(basis.label),
                        ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _basis = value;
                      if (value == AssetConditionBasis.innerCoverUnavailable) {
                        _componentReference = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: BafSpacing.md),
                if (_basis == AssetConditionBasis.innerCoverUnavailable) ...[
                  _InnerCoverAvailabilityPanel(
                    assignment: linkedInnerCover,
                    loading: assignmentsAsync?.isLoading == true,
                    failed: assignmentsAsync?.hasError == true,
                    onOpenLifecycle:
                        () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const InnerCoverLifecycleScreen(),
                          ),
                        ),
                  ),
                ] else ...[
                  _ComponentConditionTarget(
                    reference: _componentReference,
                    loading: nodesAsync.isLoading,
                    failed: nodesAsync.hasError,
                    onChoose:
                        nodesAsync.hasValue
                            ? () async {
                              final selection =
                                  await showGovernedAssetTargetPicker(
                                    context: context,
                                    asset: widget.asset,
                                    nodes:
                                        nodesAsync.value ??
                                        const <AssetHierarchyNode>[],
                                    selectedNodeId: _componentReference?.nodeId,
                                  );
                              if (selection?.reference != null && mounted) {
                                setState(
                                  () =>
                                      _componentReference =
                                          selection!.reference,
                                );
                              }
                            }
                            : null,
                    onClear:
                        _componentReference == null
                            ? null
                            : () => setState(() => _componentReference = null),
                  ),
                ],
                const SizedBox(height: BafSpacing.lg),
                const Text(
                  'Causes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: BafSpacing.sm),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.sm,
                  children: AssetConditionCause.values
                      .map((cause) {
                        return FilterChip(
                          label: Text(cause.label),
                          selected: _causes.contains(cause),
                          onSelected:
                              (selected) => setState(() {
                                selected
                                    ? _causes.add(cause)
                                    : _causes.remove(cause);
                              }),
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: BafSpacing.lg),
                TextField(
                  controller: _reason,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Operational reason',
                    hintText: 'Describe why the asset cannot be safely used.',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                if (widget.tickets.isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.md),
                  const Text(
                    'Link open issues',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: BafSpacing.xs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 230),
                    child: ListView(
                      shrinkWrap: true,
                      children: widget.tickets
                          .map((ticket) {
                            final id = ticket.firestoreId!;
                            return CheckboxListTile(
                              value: _tickets.contains(id),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                ticket.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle:
                                  ticket.component == null
                                      ? null
                                      : Text(ticket.component!),
                              onChanged:
                                  (selected) => setState(() {
                                    selected == true
                                        ? _tickets.add(id)
                                        : _tickets.remove(id);
                                  }),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
                const SizedBox(height: BafSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.gpp_maybe_outlined),
                    label: Text('Declare ${widget.condition.label}'),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          widget.condition == AssetOperationalCondition.down
                              ? BafColors.danger
                              : BafColors.warning,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final reason = _reason.text.trim();
    final basis = _basis;
    final linkedAssignment =
        widget.isBase
            ? ref
                .read(innerCoverAssignmentsProvider)
                .value
                ?.where(
                  (assignment) =>
                      assignment.baseAssetInstanceId == widget.asset.id,
                )
                .firstOrNull
            : null;
    if (_causes.isEmpty || reason.isEmpty || basis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Choose the availability basis, at least one cause, and enter a reason.',
          ),
        ),
      );
      return;
    }
    if (basis == AssetConditionBasis.innerCoverUnavailable &&
        linkedAssignment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inner Cover ${linkedAssignment.innerCoverSerialNumber} is still linked. Delink or retire it first.',
          ),
        ),
      );
      return;
    }
    if (basis != AssetConditionBasis.innerCoverUnavailable &&
        _componentReference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose the affected governed component.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _ConditionDraft(
        causes: Set<AssetConditionCause>.unmodifiable(_causes),
        basis: basis,
        componentReference: _componentReference,
        reason: reason,
        linkedIssueIds: _tickets.toList(growable: false),
      ),
    );
  }
}

class _ComponentConditionTarget extends StatelessWidget {
  const _ComponentConditionTarget({
    required this.reference,
    required this.loading,
    required this.failed,
    required this.onChoose,
    required this.onClear,
  });

  final AssetHierarchyReference? reference;
  final bool loading;
  final bool failed;
  final VoidCallback? onChoose;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final selected = reference;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.surfaceMuted,
        border: Border.all(color: BafColors.border),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Affected component',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            selected == null
                ? failed
                    ? 'The governed hierarchy could not be verified.'
                    : loading
                    ? 'Loading the current governed hierarchy...'
                    : 'Choose the exact component or subcomponent making this asset unavailable.'
                : selected.hierarchyPath.join(' › '),
            style: TextStyle(
              color: failed ? BafColors.danger : BafColors.textSecondary,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChoose,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: Text(
                    selected == null ? 'Choose component' : 'Change component',
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: BafSpacing.sm),
                IconButton(
                  tooltip: 'Clear component',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InnerCoverAvailabilityPanel extends StatelessWidget {
  const _InnerCoverAvailabilityPanel({
    required this.assignment,
    required this.loading,
    required this.failed,
    required this.onOpenLifecycle,
  });

  final BaseInnerCoverAssignment? assignment;
  final bool loading;
  final bool failed;
  final VoidCallback onOpenLifecycle;

  @override
  Widget build(BuildContext context) {
    final linked = assignment;
    final blocked = loading || failed || linked != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color:
            blocked
                ? BafColors.warning.withValues(alpha: 0.09)
                : BafColors.success.withValues(alpha: 0.08),
        border: Border.all(
          color:
              blocked
                  ? BafColors.warning.withValues(alpha: 0.45)
                  : BafColors.success.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            failed
                ? 'Inner Cover assignment could not be verified'
                : loading
                ? 'Checking the current Inner Cover assignment'
                : linked == null
                ? 'No Inner Cover is linked to this Base'
                : 'Inner Cover ${linked.innerCoverSerialNumber} is still linked',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            linked == null && !loading && !failed
                ? 'The Base may be declared unavailable for want of an Inner Cover.'
                : 'Use the governed lifecycle to delink it, or retire it with the correct condition evidence, before declaring the Base unavailable.',
            style: const TextStyle(color: BafColors.textSecondary),
          ),
          const SizedBox(height: BafSpacing.sm),
          OutlinedButton.icon(
            onPressed: onOpenLifecycle,
            icon: const Icon(Icons.layers_outlined),
            label: const Text('Open Inner Cover lifecycle'),
          ),
        ],
      ),
    );
  }
}

List<MaintenanceRecord> _ticketsForAsset(
  List<MaintenanceRecord> tickets,
  String assetInstanceId,
) {
  final matches = <MaintenanceRecord>[];
  for (final ticket in tickets) {
    if (ticket.firestoreId == null || ticket.isDeleted || ticket.isResolved) {
      continue;
    }
    final reference = ticket.assetHierarchyReference;
    if (reference?.assetInstanceId == assetInstanceId) matches.add(ticket);
  }
  matches.sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return matches;
}

Future<String?> _showReasonDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required String hint,
}) {
  return showDialog<String>(
    context: context,
    builder:
        (_) =>
            _ReasonDialog(title: title, actionLabel: actionLabel, hint: hint),
  );
}

class _ReasonDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final String hint;

  const _ReasonDialog({
    required this.title,
    required this.actionLabel,
    required this.hint,
  });

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _reason,
        minLines: 3,
        maxLines: 6,
        maxLength: 1000,
        decoration: InputDecoration(
          hintText: widget.hint,
          errorText: _error,
          border: const OutlineInputBorder(),
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
            if (reason.isEmpty) {
              setState(() => _error = 'Enter a reason.');
              return;
            }
            Navigator.pop(context, reason);
          },
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

Future<void> _perform(
  BuildContext context,
  Future<void> Function() action,
  String success,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    messenger.showSnackBar(
      SnackBar(content: Text(success), backgroundColor: BafColors.success),
    );
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
    );
  }
}

List<Widget> _stateBadges(PlantAssetState state) {
  final output = <Widget>[];
  if (state.isDown) {
    output.add(const StatusBadge(label: 'Down', color: BafColors.danger));
  }
  if (state.isUnfit) {
    output.add(const StatusBadge(label: 'Unfit', color: BafColors.warning));
  }
  if (state.isIssueUnavailable) {
    output.add(
      const StatusBadge(label: 'Unavailable', color: BafColors.cobalt),
    );
  }
  if (state.isUnderMaintenance) {
    output.add(
      const StatusBadge(label: 'Maintenance', color: BafColors.maintenance),
    );
  }
  if (state.isTemporarilyBlocked) {
    output.add(
      const StatusBadge(label: 'Stuck-up', color: BafColors.instrument),
    );
  }
  if (state.isStandby) {
    output.add(const StatusBadge(label: 'Standby', color: BafColors.planned));
  }
  if (state.isAdministrativelyOutOfService) {
    output.add(
      const StatusBadge(label: 'Out of service', color: BafColors.admin),
    );
  }
  if (output.isEmpty) {
    output.add(const StatusBadge(label: 'Available', color: BafColors.success));
  }
  return output;
}

Color _primaryColor(PlantAssetState state) {
  if (state.isTemporarilyBlocked) return BafColors.instrument;
  if (state.isDown) return BafColors.danger;
  if (state.isIssueUnavailable) return BafColors.cobalt;
  if (state.isUnfit) return BafColors.warning;
  if (state.isUnderMaintenance) return BafColors.maintenance;
  if (state.isAdministrativelyOutOfService) return BafColors.admin;
  return BafColors.success;
}

IconData _primaryIcon(PlantAssetState state) {
  if (state.isTemporarilyBlocked) return Icons.link_off_rounded;
  if (state.isDown) return Icons.power_off_rounded;
  if (state.isIssueUnavailable) return Icons.block_outlined;
  if (state.isUnfit) return Icons.gpp_bad_outlined;
  if (state.isUnderMaintenance) return Icons.build_outlined;
  if (state.isAdministrativelyOutOfService) return Icons.block_outlined;
  return Icons.check_circle_outline_rounded;
}

class _ConditionLoadError extends StatelessWidget {
  final Object error;

  const _ConditionLoadError({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: BafColors.danger,
              size: 36,
            ),
            const SizedBox(height: BafSpacing.md),
            const Text(
              'Plant condition could not be verified.',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
