import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_registry_model.dart';
import '../data/furnace_stuckup_record.dart';
import '../data/inner_cover_lifecycle.dart';
import '../../maintenance/domain/furnace_stuckup_case.dart';
import 'widgets/inner_cover_registration_date_field.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../providers/furnace_stuckup_provider.dart';
import '../repositories/asset_hierarchy_repository.dart';

part 'inner_cover_lifecycle_screen.details.dart';
part 'inner_cover_lifecycle_screen.dialogs.dart';
part 'inner_cover_lifecycle_screen.registration_widgets.dart';

class InnerCoverLifecycleScreen extends ConsumerWidget {
  const InnerCoverLifecycleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Inner Covers',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.layers_outlined,
        accent: BafColors.maintenance,
        label: 'Checking Inner Cover access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Inner Covers',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.layers_outlined,
        accent: BafColors.maintenance,
        message: 'Inner Cover access could not be verified.',
      );
    }
    final user = actorAsync.value;
    if (user == null || !user.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Inner Covers',
        appBarSubtitle: 'Base pairing, spare pool and fabrication',
        appBarIcon: Icons.layers_outlined,
        accent: BafColors.maintenance,
        title: 'Inner Cover access required',
        message: 'An approved account is required to view Inner Cover records.',
      );
    }
    final profiles = ref.watch(innerCoverProfilesProvider);
    final assignments = ref.watch(innerCoverAssignmentsProvider);
    final classes = ref.watch(assetClassesProvider);
    final assets = ref.watch(allAssetInstancesProvider);
    final stuckupCases = ref.watch(furnaceStuckupCasesProvider);
    final conditionDeclarations = ref.watch(assetConditionDeclarationsProvider);
    final loading =
        profiles.isLoading ||
        assignments.isLoading ||
        classes.isLoading ||
        assets.isLoading;
    final error =
        profiles.error ?? assignments.error ?? classes.error ?? assets.error;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Inner Covers',
            subtitle: 'Base pairing, spare pool and fabrication',
            icon: Icons.layers_outlined,
            accent: BafColors.maintenance,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bases'),
              Tab(text: 'Pool'),
              Tab(text: 'All covers'),
            ],
          ),
          actions: [
            if (user.canManageAssetHierarchy)
              IconButton(
                tooltip: 'Register Inner Cover',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _registerCover(context, ref, user),
              ),
          ],
        ),
        body:
            loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? _LoadError(error: error)
                : _LifecycleBody(
                  user: user,
                  profiles: profiles.value ?? const <InnerCoverProfile>[],
                  assignments:
                      assignments.value ?? const <BaseInnerCoverAssignment>[],
                  assetClasses: classes.value ?? const <AssetClassRecord>[],
                  assets: assets.value ?? const <AssetInstanceRecord>[],
                  stuckupCases:
                      stuckupCases.value ?? const <FurnaceStuckupRecord>[],
                  conditionDeclarations:
                      conditionDeclarations.value ??
                      const <AssetConditionDeclarationRecord>[],
                  bulgeEvidenceAvailable:
                      !stuckupCases.hasError && !conditionDeclarations.hasError,
                ),
      ),
    );
  }
}

class _LifecycleBody extends ConsumerStatefulWidget {
  final AppUser? user;
  final List<InnerCoverProfile> profiles;
  final List<BaseInnerCoverAssignment> assignments;
  final List<AssetClassRecord> assetClasses;
  final List<AssetInstanceRecord> assets;
  final List<FurnaceStuckupRecord> stuckupCases;
  final List<AssetConditionDeclarationRecord> conditionDeclarations;
  final bool bulgeEvidenceAvailable;

  const _LifecycleBody({
    required this.user,
    required this.profiles,
    required this.assignments,
    required this.assetClasses,
    required this.assets,
    required this.stuckupCases,
    required this.conditionDeclarations,
    required this.bulgeEvidenceAvailable,
  });

  @override
  ConsumerState<_LifecycleBody> createState() => _LifecycleBodyState();
}

class _LifecycleBodyState extends ConsumerState<_LifecycleBody> {
  _BaseListFilter _baseFilter = _BaseListFilter.all;
  _CoverListFilter _poolFilter = _CoverListFilter.all;
  _CoverListFilter _allCoverFilter = _CoverListFilter.all;

  void _showBases(_BaseListFilter filter) {
    setState(() => _baseFilter = filter);
    DefaultTabController.of(context).animateTo(0);
  }

  void _showPool(_CoverListFilter filter) {
    setState(() => _poolFilter = filter);
    DefaultTabController.of(context).animateTo(1);
  }

  void _showAllCovers(_CoverListFilter filter) {
    setState(() => _allCoverFilter = filter);
    DefaultTabController.of(context).animateTo(2);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final profiles = widget.profiles;
    final assignments = widget.assignments;
    final assetClasses = widget.assetClasses;
    final assets = widget.assets;
    final stuckupCases = widget.stuckupCases;
    final conditionDeclarations = widget.conditionDeclarations;
    final baseClassIds =
        assetClasses
            .where((item) => item.isActive && item.legacyAssetTypeKey == 'base')
            .map((item) => item.id)
            .toSet();
    final bases =
        assets
            .where(
              (item) =>
                  item.isActive && baseClassIds.contains(item.assetClassId),
            )
            .toList()
          ..sort(
            (left, right) => left.assetNumber.compareTo(right.assetNumber),
          );
    final assignmentByBase = {
      for (final assignment in assignments)
        assignment.baseAssetInstanceId: assignment,
    };
    final profileById = {for (final profile in profiles) profile.id: profile};
    final bulgeEvidenceByCoverId = _buildBulgeEvidence(
      profiles: profiles,
      cases: stuckupCases,
      declarations: conditionDeclarations,
    );
    final pool =
        profiles.where((profile) => !profile.isInstalled).toList()
          ..sort(_poolSort);
    final canManage = user?.canManageAssetHierarchy == true;

    return Column(
      children: [
        _SummaryBand(
          profiles: profiles,
          baseCount: bases.length,
          occupiedBaseCount:
              bases
                  .where((base) => assignmentByBase.containsKey(base.id))
                  .length,
          bulgeEvidenceByCoverId: bulgeEvidenceByCoverId,
          bulgeEvidenceAvailable: widget.bulgeEvidenceAvailable,
          onShowAllBases: () => _showBases(_BaseListFilter.all),
          onShowInstalled: () => _showBases(_BaseListFilter.occupied),
          onShowAvailable: () => _showPool(_CoverListFilter.available),
          onShowAttention: () => _showPool(_CoverListFilter.attention),
          onShowVacantBases: () => _showBases(_BaseListFilter.vacant),
          onShowRetired: () => _showAllCovers(_CoverListFilter.retired),
          onShowBulgeHistory: () => _showAllCovers(_CoverListFilter.bulge),
        ),
        Expanded(
          child: TabBarView(
            children: [
              _BaseList(
                bases: bases,
                assignmentByBase: assignmentByBase,
                profileById: profileById,
                filter: _baseFilter,
                onFilterChanged:
                    (filter) => setState(() {
                      _baseFilter = filter;
                    }),
                canManage: canManage,
                onHistory: (base) => _showBaseHistory(context, base),
                onDelink:
                    (assignment, cover) => _delinkCover(
                      context,
                      ref,
                      cover,
                      assignment,
                      user!,
                      closeSurfaceOnSuccess: false,
                    ),
                onManage:
                    (base, assignment) => _manageBaseCover(
                      context,
                      ref,
                      user!,
                      base,
                      assignment,
                      profiles,
                      assignmentByBase,
                    ),
              ),
              _CoverList(
                profiles: pool,
                emptyMessage: 'No Inner Covers are currently in the pool.',
                bulgeEvidenceByCoverId: bulgeEvidenceByCoverId,
                filter: _poolFilter,
                onFilterChanged:
                    (filter) => setState(() {
                      _poolFilter = filter;
                    }),
                onOpen:
                    (cover) => _showCoverDetails(
                      context,
                      ref,
                      cover,
                      assignmentByBase,
                      profileById,
                      bases,
                      bulgeEvidenceByCoverId[cover.id],
                      user,
                    ),
              ),
              _CoverList(
                profiles: profiles,
                emptyMessage: 'No Inner Covers have been registered.',
                bulgeEvidenceByCoverId: bulgeEvidenceByCoverId,
                filter: _allCoverFilter,
                onFilterChanged:
                    (filter) => setState(() {
                      _allCoverFilter = filter;
                    }),
                onOpen:
                    (cover) => _showCoverDetails(
                      context,
                      ref,
                      cover,
                      assignmentByBase,
                      profileById,
                      bases,
                      bulgeEvidenceByCoverId[cover.id],
                      user,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

int _poolSort(InnerCoverProfile left, InnerCoverProfile right) {
  final state = left.lifecycleState.index.compareTo(right.lifecycleState.index);
  return state != 0 ? state : _compareInnerCoverSerial(left, right);
}

int _compareInnerCoverSerial(InnerCoverProfile left, InnerCoverProfile right) {
  final expression = RegExp(r'^(.*?)(\d+)$');
  final leftMatch = expression.firstMatch(left.normalizedSerialNumber);
  final rightMatch = expression.firstMatch(right.normalizedSerialNumber);
  if (leftMatch != null && rightMatch != null) {
    final prefix = leftMatch.group(1)!.compareTo(rightMatch.group(1)!);
    if (prefix != 0) return prefix;
    final number = int.parse(
      leftMatch.group(2)!,
    ).compareTo(int.parse(rightMatch.group(2)!));
    if (number != 0) return number;
  }
  return left.normalizedSerialNumber.compareTo(right.normalizedSerialNumber);
}

bool _isBulgeCause(FurnaceStuckupCause? cause) => const {
  FurnaceStuckupCause.innerCoverBulging,
  FurnaceStuckupCause.combinedCondition,
}.contains(cause);

class _InnerCoverBulgeEvidence {
  final AssetConditionDeclarationRecord? declaration;
  final List<FurnaceStuckupRecord> cases;
  final bool retiredAsBulged;

  const _InnerCoverBulgeEvidence({
    required this.declaration,
    required this.cases,
    required this.retiredAsBulged,
  });

  bool get hasConfirmedRecord =>
      declaration != null ||
      retiredAsBulged ||
      cases.any(
        (item) =>
            item.adjudicationStatus ==
                FurnaceStuckupAdjudicationStatus.confirmed &&
            _isBulgeCause(item.confirmedCause),
      );

  bool get hasPendingSuspicion => cases.any(
    (item) =>
        item.adjudicationStatus == FurnaceStuckupAdjudicationStatus.pending &&
        _isBulgeCause(item.suspectedCause),
  );

  bool get hasAnyRecord => hasConfirmedRecord || hasPendingSuspicion;
}

Map<String, _InnerCoverBulgeEvidence> _buildBulgeEvidence({
  required List<InnerCoverProfile> profiles,
  required List<FurnaceStuckupRecord> cases,
  required List<AssetConditionDeclarationRecord> declarations,
}) {
  final declarationByCover = {
    for (final declaration in declarations) declaration.assetId: declaration,
  };
  final casesByCover = <String, List<FurnaceStuckupRecord>>{};
  for (final item in cases) {
    if (!_isBulgeCause(item.suspectedCause) &&
        !_isBulgeCause(item.confirmedCause)) {
      continue;
    }
    casesByCover.putIfAbsent(item.innerCoverId, () => []).add(item);
  }
  return {
    for (final profile in profiles)
      profile.id: _InnerCoverBulgeEvidence(
        declaration: declarationByCover[profile.id],
        cases: List<FurnaceStuckupRecord>.unmodifiable(
          <FurnaceStuckupRecord>[
            ...(casesByCover[profile.id] ?? const <FurnaceStuckupRecord>[]),
          ]..sort((left, right) => right.reportedAt.compareTo(left.reportedAt)),
        ),
        retiredAsBulged:
            profile.retirementCondition == InnerCoverRetirementCondition.bulged,
      ),
  };
}

class _SummaryBand extends StatelessWidget {
  final List<InnerCoverProfile> profiles;
  final int baseCount;
  final int occupiedBaseCount;
  final Map<String, _InnerCoverBulgeEvidence> bulgeEvidenceByCoverId;
  final bool bulgeEvidenceAvailable;
  final VoidCallback onShowAllBases;
  final VoidCallback onShowInstalled;
  final VoidCallback onShowAvailable;
  final VoidCallback onShowAttention;
  final VoidCallback onShowVacantBases;
  final VoidCallback onShowRetired;
  final VoidCallback onShowBulgeHistory;

  const _SummaryBand({
    required this.profiles,
    required this.baseCount,
    required this.occupiedBaseCount,
    required this.bulgeEvidenceByCoverId,
    required this.bulgeEvidenceAvailable,
    required this.onShowAllBases,
    required this.onShowInstalled,
    required this.onShowAvailable,
    required this.onShowAttention,
    required this.onShowVacantBases,
    required this.onShowRetired,
    required this.onShowBulgeHistory,
  });

  @override
  Widget build(BuildContext context) {
    final available = profiles.where((item) => item.isAvailable).length;
    final retired =
        profiles
            .where((item) => _isRetirementState(item.lifecycleState))
            .length;
    final vacantBases = (baseCount - occupiedBaseCount).clamp(0, baseCount);
    final bulgeRecords =
        bulgeEvidenceByCoverId.values
            .where((evidence) => evidence.hasAnyRecord)
            .length;
    final attention =
        profiles
            .where((item) => _needsLifecycleAttention(item.lifecycleState))
            .length;
    return Container(
      width: double.infinity,
      color: BafColors.card,
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.md,
        BafSpacing.lg,
        BafSpacing.lg,
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              _SummaryFilterBadge(
                label: '$baseCount Bases',
                color: BafColors.assets,
                tooltip: 'Show all Bases',
                onTap: onShowAllBases,
              ),
              _SummaryFilterBadge(
                label: '$occupiedBaseCount installed',
                color: BafColors.success,
                tooltip: 'Show Bases with an Inner Cover',
                onTap: onShowInstalled,
              ),
              _SummaryFilterBadge(
                label: '$available available',
                color: BafColors.planned,
                tooltip: 'Show available Inner Covers',
                onTap: onShowAvailable,
              ),
              _SummaryFilterBadge(
                label: '$attention need attention',
                color:
                    attention == 0
                        ? BafColors.textSecondary
                        : BafColors.warning,
                tooltip: 'Show Inner Covers needing attention',
                onTap: onShowAttention,
              ),
              _SummaryFilterBadge(
                label: '$vacantBases Bases with no Inner Covers',
                color:
                    vacantBases == 0
                        ? BafColors.textSecondary
                        : BafColors.audit,
                tooltip: 'Show Bases with no Inner Cover',
                onTap: onShowVacantBases,
              ),
              if (retired > 0)
                _SummaryFilterBadge(
                  label: '$retired retired',
                  color: BafColors.textSecondary,
                  tooltip: 'Show retired Inner Covers',
                  onTap: onShowRetired,
                ),
              if (bulgeEvidenceAvailable && bulgeRecords > 0)
                _SummaryFilterBadge(
                  label: '$bulgeRecords with bulge history',
                  color: BafColors.danger,
                  tooltip: 'Show Inner Covers with bulge history',
                  onTap: onShowBulgeHistory,
                ),
              if (!bulgeEvidenceAvailable)
                const StatusBadge(
                  label: 'Bulge evidence unavailable',
                  color: BafColors.danger,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryFilterBadge extends StatelessWidget {
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _SummaryFilterBadge({
    required this.label,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: tooltip,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(BafRadius.medium),
          onTap: onTap,
          child: StatusBadge(label: label, color: color),
        ),
      ),
    ),
  );
}

enum _BaseListFilter { all, vacant, occupied }

class _BaseList extends StatefulWidget {
  final List<AssetInstanceRecord> bases;
  final Map<String, BaseInnerCoverAssignment> assignmentByBase;
  final Map<String, InnerCoverProfile> profileById;
  final _BaseListFilter filter;
  final ValueChanged<_BaseListFilter> onFilterChanged;
  final bool canManage;
  final ValueChanged<AssetInstanceRecord> onHistory;
  final void Function(
    BaseInnerCoverAssignment assignment,
    InnerCoverProfile cover,
  )
  onDelink;
  final void Function(
    AssetInstanceRecord base,
    BaseInnerCoverAssignment? assignment,
  )
  onManage;

  const _BaseList({
    required this.bases,
    required this.assignmentByBase,
    required this.profileById,
    required this.filter,
    required this.onFilterChanged,
    required this.canManage,
    required this.onHistory,
    required this.onDelink,
    required this.onManage,
  });

  @override
  State<_BaseList> createState() => _BaseListState();
}

class _BaseListState extends State<_BaseList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bases.isEmpty) {
      return const _EmptyState(
        icon: Icons.foundation_outlined,
        message: 'Register governed Base assets before pairing Inner Covers.',
      );
    }
    final query = _search.text.trim().toLowerCase();
    final vacantCount =
        widget.bases
            .where((base) => !widget.assignmentByBase.containsKey(base.id))
            .length;
    final filtered =
        widget.bases.where((base) {
          final assignment = widget.assignmentByBase[base.id];
          final matchesFilter = switch (widget.filter) {
            _BaseListFilter.all => true,
            _BaseListFilter.vacant => assignment == null,
            _BaseListFilter.occupied => assignment != null,
          };
          if (!matchesFilter) return false;
          if (query.isEmpty) return true;
          final serial = assignment?.innerCoverSerialNumber.toLowerCase() ?? '';
          return '${base.assetNumber}'.contains(query) ||
              base.name.toLowerCase().contains(query) ||
              serial.contains(query);
        }).toList();

    return Column(
      children: [
        _ListFinder(
          controller: _search,
          hintText: 'Search Base number or Inner Cover serial',
          onChanged: (_) => setState(() {}),
          filters: [
            ChoiceChip(
              label: Text('All ${widget.bases.length}'),
              selected: widget.filter == _BaseListFilter.all,
              onSelected: (_) => widget.onFilterChanged(_BaseListFilter.all),
            ),
            ChoiceChip(
              label: Text('Vacant $vacantCount'),
              selected: widget.filter == _BaseListFilter.vacant,
              onSelected: (_) => widget.onFilterChanged(_BaseListFilter.vacant),
            ),
            ChoiceChip(
              label: Text('Occupied ${widget.bases.length - vacantCount}'),
              selected: widget.filter == _BaseListFilter.occupied,
              onSelected:
                  (_) => widget.onFilterChanged(_BaseListFilter.occupied),
            ),
          ],
        ),
        Expanded(
          child:
              filtered.isEmpty
                  ? const _EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No Base matches this search and filter.',
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      BafSpacing.lg,
                      BafSpacing.sm,
                      BafSpacing.lg,
                      BafSpacing.lg,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder:
                        (_, _) => const SizedBox(height: BafSpacing.sm),
                    itemBuilder: (context, index) {
                      final base = filtered[index];
                      final assignment = widget.assignmentByBase[base.id];
                      final profile =
                          assignment == null
                              ? null
                              : widget.profileById[assignment.innerCoverId];
                      final drift =
                          assignment != null &&
                          (profile == null ||
                              profile.currentBaseAssetInstanceId != base.id ||
                              profile.currentLinkageId != assignment.linkageId);
                      return Material(
                        color: BafColors.card,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: drift ? BafColors.danger : BafColors.border,
                          ),
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                        child: ListTile(
                          onTap: () => widget.onHistory(base),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: BafSpacing.lg,
                            vertical: BafSpacing.sm,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: BafColors.assets.withValues(
                              alpha: 0.12,
                            ),
                            foregroundColor: BafColors.assets,
                            child: Text(
                              '${base.assetNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            'Base ${base.assetNumber}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: BafSpacing.xs),
                            child: Text(
                              drift
                                  ? 'Pairing data needs reconciliation'
                                  : assignment == null
                                  ? 'No Inner Cover linked'
                                  : profile?.incorporatedOn == null
                                  ? 'Inner Cover ${assignment.innerCoverSerialNumber}'
                                  : 'Inner Cover ${assignment.innerCoverSerialNumber}\n'
                                      'Incorporated ${_formatInnerCoverDate(profile!.incorporatedOn!)}',
                              style: TextStyle(
                                color:
                                    drift
                                        ? BafColors.danger
                                        : assignment == null
                                        ? BafColors.textSecondary
                                        : BafColors.success,
                                fontWeight:
                                    assignment == null
                                        ? FontWeight.w400
                                        : FontWeight.w700,
                              ),
                            ),
                          ),
                          trailing:
                              widget.canManage && !drift
                                  ? assignment == null
                                      ? IconButton(
                                        tooltip: 'Link Inner Cover',
                                        onPressed:
                                            () => widget.onManage(
                                              base,
                                              assignment,
                                            ),
                                        icon: const Icon(Icons.link_rounded),
                                      )
                                      : SizedBox(
                                        width: 96,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              tooltip:
                                                  'Delink Inner Cover from Base',
                                              onPressed:
                                                  () => widget.onDelink(
                                                    assignment,
                                                    profile!,
                                                  ),
                                              icon: const Icon(
                                                Icons.link_off_rounded,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Change Inner Cover',
                                              onPressed:
                                                  () => widget.onManage(
                                                    base,
                                                    assignment,
                                                  ),
                                              icon: const Icon(
                                                Icons.swap_horiz_rounded,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                  : null,
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

enum _CoverListFilter { all, available, installed, attention, retired, bulge }

bool _isRetirementState(InnerCoverLifecycleState state) => const {
  InnerCoverLifecycleState.retiredForSalvage,
  InnerCoverLifecycleState.partiallyDismantled,
  InnerCoverLifecycleState.fullyConsumedAsDonor,
  InnerCoverLifecycleState.disposed,
}.contains(state);

bool _needsLifecycleAttention(InnerCoverLifecycleState state) => const {
  InnerCoverLifecycleState.awaitingInspection,
  InnerCoverLifecycleState.underInspection,
  InnerCoverLifecycleState.underRepair,
  InnerCoverLifecycleState.underFabrication,
  InnerCoverLifecycleState.quarantined,
  InnerCoverLifecycleState.rejected,
}.contains(state);

class _CoverList extends StatefulWidget {
  final List<InnerCoverProfile> profiles;
  final String emptyMessage;
  final Map<String, _InnerCoverBulgeEvidence> bulgeEvidenceByCoverId;
  final _CoverListFilter filter;
  final ValueChanged<_CoverListFilter> onFilterChanged;
  final ValueChanged<InnerCoverProfile> onOpen;

  const _CoverList({
    required this.profiles,
    required this.emptyMessage,
    required this.bulgeEvidenceByCoverId,
    required this.filter,
    required this.onFilterChanged,
    required this.onOpen,
  });

  @override
  State<_CoverList> createState() => _CoverListState();
}

class _CoverListState extends State<_CoverList> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profiles.isEmpty) {
      return _EmptyState(
        icon: Icons.layers_outlined,
        message: widget.emptyMessage,
      );
    }
    final query = _search.text.trim().toLowerCase();
    final sorted = [...widget.profiles]..sort(_compareInnerCoverSerial);
    final filtered =
        sorted.where((cover) {
          final bulge = widget.bulgeEvidenceByCoverId[cover.id];
          final matchesFilter = switch (widget.filter) {
            _CoverListFilter.all => true,
            _CoverListFilter.available => cover.isAvailable,
            _CoverListFilter.installed => cover.isInstalled,
            _CoverListFilter.attention => _needsLifecycleAttention(
              cover.lifecycleState,
            ),
            _CoverListFilter.retired => _isRetirementState(
              cover.lifecycleState,
            ),
            _CoverListFilter.bulge => bulge?.hasAnyRecord == true,
          };
          if (!matchesFilter) return false;
          if (query.isEmpty) return true;
          return cover.serialNumber.toLowerCase().contains(query) ||
              cover.normalizedSerialNumber.toLowerCase().contains(query) ||
              cover.lifecycleState.label.toLowerCase().contains(query) ||
              '${cover.currentBaseAssetNumber ?? ''}'.contains(query);
        }).toList();
    final availableCount =
        widget.profiles.where((item) => item.isAvailable).length;
    final installedCount =
        widget.profiles.where((item) => item.isInstalled).length;
    final attentionCount =
        widget.profiles
            .where((item) => _needsLifecycleAttention(item.lifecycleState))
            .length;
    final retiredCount =
        widget.profiles
            .where((item) => _isRetirementState(item.lifecycleState))
            .length;
    final bulgeCount =
        widget.profiles
            .where(
              (item) =>
                  widget.bulgeEvidenceByCoverId[item.id]?.hasAnyRecord == true,
            )
            .length;

    return Column(
      children: [
        _ListFinder(
          controller: _search,
          hintText: 'Search serial, Base or lifecycle state',
          onChanged: (_) => setState(() {}),
          filters: [
            ChoiceChip(
              label: Text('All ${widget.profiles.length}'),
              selected: widget.filter == _CoverListFilter.all,
              onSelected: (_) => widget.onFilterChanged(_CoverListFilter.all),
            ),
            ChoiceChip(
              label: Text('Available $availableCount'),
              selected: widget.filter == _CoverListFilter.available,
              onSelected:
                  (_) => widget.onFilterChanged(_CoverListFilter.available),
            ),
            if (installedCount > 0)
              ChoiceChip(
                label: Text('Installed $installedCount'),
                selected: widget.filter == _CoverListFilter.installed,
                onSelected:
                    (_) => widget.onFilterChanged(_CoverListFilter.installed),
              ),
            ChoiceChip(
              label: Text('Attention $attentionCount'),
              selected: widget.filter == _CoverListFilter.attention,
              onSelected:
                  (_) => widget.onFilterChanged(_CoverListFilter.attention),
            ),
            if (retiredCount > 0)
              ChoiceChip(
                label: Text('Retired $retiredCount'),
                selected: widget.filter == _CoverListFilter.retired,
                onSelected:
                    (_) => widget.onFilterChanged(_CoverListFilter.retired),
              ),
            if (bulgeCount > 0)
              ChoiceChip(
                label: Text('Bulge history $bulgeCount'),
                selected: widget.filter == _CoverListFilter.bulge,
                onSelected:
                    (_) => widget.onFilterChanged(_CoverListFilter.bulge),
              ),
          ],
        ),
        Expanded(
          child:
              filtered.isEmpty
                  ? const _EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No Inner Cover matches this search and filter.',
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      BafSpacing.lg,
                      BafSpacing.sm,
                      BafSpacing.lg,
                      BafSpacing.lg,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder:
                        (_, _) => const SizedBox(height: BafSpacing.sm),
                    itemBuilder: (context, index) {
                      final cover = filtered[index];
                      final bulge = widget.bulgeEvidenceByCoverId[cover.id];
                      return Material(
                        color: BafColors.card,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: BafColors.border),
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                        child: ListTile(
                          onTap: () => widget.onOpen(cover),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: BafSpacing.lg,
                            vertical: BafSpacing.sm,
                          ),
                          leading: Icon(
                            cover.isInstalled
                                ? Icons.link_rounded
                                : Icons.layers_outlined,
                            color: _stateColor(cover.lifecycleState),
                          ),
                          title: Text(
                            cover.serialNumber,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: BafSpacing.xs),
                            child: Text(
                              [
                                cover.isInstalled
                                    ? '${cover.lifecycleState.label} on Base ${cover.currentBaseAssetNumber}'
                                    : '${cover.lifecycleState.label} · ${cover.originClassification.label}',
                                if (cover.incorporatedOn != null)
                                  'Incorporated ${_formatInnerCoverDate(cover.incorporatedOn!)}',
                                if (bulge?.hasConfirmedRecord == true)
                                  'Confirmed bulge record',
                                if (bulge?.hasConfirmedRecord != true &&
                                    bulge?.hasPendingSuspicion == true)
                                  'Bulge confirmation pending',
                              ].join('\n'),
                              style: TextStyle(
                                color:
                                    bulge?.hasConfirmedRecord == true
                                        ? BafColors.danger
                                        : BafColors.textSecondary,
                              ),
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _ListFinder extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final List<Widget> filters;

  const _ListFinder({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.filters,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BafSpacing.lg,
      BafSpacing.md,
      BafSpacing.lg,
      BafSpacing.xs,
    ),
    child: Column(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon:
                controller.text.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            filled: true,
            fillColor: BafColors.card,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: BafSpacing.sm),
            itemBuilder: (context, index) => filters[index],
          ),
        ),
      ],
    ),
  );
}

Color _stateColor(InnerCoverLifecycleState state) => switch (state) {
  InnerCoverLifecycleState.available => BafColors.success,
  InnerCoverLifecycleState.installed => BafColors.assets,
  InnerCoverLifecycleState.awaitingInspection ||
  InnerCoverLifecycleState.underInspection => BafColors.warning,
  InnerCoverLifecycleState.underRepair ||
  InnerCoverLifecycleState.underFabrication => BafColors.maintenance,
  InnerCoverLifecycleState.quarantined ||
  InnerCoverLifecycleState.rejected ||
  InnerCoverLifecycleState.disposed => BafColors.danger,
  _ => BafColors.textSecondary,
};

String _formatInnerCoverDate(DateTime value) =>
    DateFormat('dd MMM yyyy').format(value.toLocal());

String _bulgeCaseSummary(FurnaceStuckupRecord item, DateFormat date) {
  final status = switch (item.adjudicationStatus) {
    FurnaceStuckupAdjudicationStatus.pending =>
      'Suspected ${item.suspectedCause.label}; confirmation pending',
    FurnaceStuckupAdjudicationStatus.confirmed =>
      'Confirmed ${item.confirmedCause?.label ?? item.suspectedCause.label}',
    FurnaceStuckupAdjudicationStatus.inconclusive =>
      'Inspection was inconclusive',
  };
  return '$status\nReported ${date.format(item.reportedAt.toLocal())} by ${item.reportedByName}'
      '${item.adjudicationNotes == null ? '' : '\n${item.adjudicationNotes}'}';
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: BafColors.textSecondary),
            const SizedBox(height: BafSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BafColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object error;

  const _LoadError({required this.error});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.xl),
      child: Text(
        'Inner Cover data could not be loaded: $error',
        textAlign: TextAlign.center,
        style: const TextStyle(color: BafColors.danger),
      ),
    ),
  );
}

Future<void> _registerCover(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
) async {
  final classes = ref.read(assetClassesProvider).value ?? const [];
  final innerCoverClass =
      classes
          .where(
            (item) => item.isActive && item.legacyAssetTypeKey == 'innerCover',
          )
          .firstOrNull;
  if (innerCoverClass == null) {
    _showError(
      context,
      'Create and activate the governed Inner Cover asset class first.',
    );
    return;
  }
  final result = await showDialog<_RegistrationResult>(
    context: context,
    builder:
        (_) => _RegistrationDialog(
          profiles: ref.read(innerCoverProfilesProvider).value ?? const [],
        ),
  );
  if (result == null || !context.mounted) return;
  await _runCommand(context, () async {
    await ref
        .read(assetHierarchyRepositoryProvider)
        .registerInnerCover(
          innerCoverClass: innerCoverClass,
          serialNumber: result.serialNumber,
          sourceType: result.sourceType,
          originClassification: result.originClassification,
          actor: user,
          reason: result.reason,
          supplierOrFabricator: result.supplierOrFabricator,
          receivedOrCompletedOn: result.receivedOrCompletedOn,
          incorporatedOn: result.incorporatedOn,
          drawingReference: result.drawingReference,
          materialGrade: result.materialGrade,
          notes: result.notes,
          fabricationSections: result.sections,
        );
  }, success: 'Inner Cover registered for inspection.');
}

Future<void> _manageBaseCover(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
  AssetInstanceRecord base,
  BaseInnerCoverAssignment? current,
  List<InnerCoverProfile> profiles,
  Map<String, BaseInnerCoverAssignment> assignments,
) async {
  final candidates =
      profiles
          .where(
            (cover) =>
                cover.isAvailable ||
                (cover.isInstalled &&
                    cover.currentBaseAssetInstanceId != base.id),
          )
          .toList();
  if (candidates.isEmpty) {
    _showError(context, 'No available or transferable Inner Cover was found.');
    return;
  }
  final selection = await showDialog<_PairingSelection>(
    context: context,
    builder:
        (_) => _PairingDialog(
          base: base,
          current: current,
          candidates: candidates,
        ),
  );
  if (selection == null || !context.mounted) return;
  final repository = ref.read(assetHierarchyRepositoryProvider);
  final incoming = selection.cover;
  await _runCommand(context, () async {
    if (current == null) {
      if (incoming.isAvailable) {
        await repository.linkInnerCover(
          cover: incoming,
          base: base,
          actor: user,
          reason: selection.reason,
        );
      } else {
        final source = assignments[incoming.currentBaseAssetInstanceId];
        if (source == null) {
          throw const AssetHierarchyException(
            'The source Base assignment needs reconciliation.',
          );
        }
        await repository.transferInnerCover(
          cover: incoming,
          sourceAssignment: source,
          targetBase: base,
          actor: user,
          reason: selection.reason,
        );
      }
      return;
    }
    final displaced =
        profiles
            .where((profile) => profile.id == current.innerCoverId)
            .firstOrNull;
    if (displaced == null) {
      throw const AssetHierarchyException(
        'The installed Inner Cover profile needs reconciliation.',
      );
    }
    if (incoming.isAvailable) {
      await repository.replaceInnerCover(
        incoming: incoming,
        displaced: displaced,
        targetAssignment: current,
        displacedState: InnerCoverLifecycleState.awaitingInspection,
        actor: user,
        reason: selection.reason,
      );
    } else {
      final source = assignments[incoming.currentBaseAssetInstanceId];
      if (source == null) {
        throw const AssetHierarchyException(
          'The source Base assignment needs reconciliation.',
        );
      }
      await repository.swapInnerCovers(
        incoming: incoming,
        sourceAssignment: source,
        displaced: displaced,
        targetAssignment: current,
        actor: user,
        reason: selection.reason,
      );
    }
  }, success: 'Base and Inner Cover pairing updated.');
}

Future<void> _showCoverDetails(
  BuildContext context,
  WidgetRef ref,
  InnerCoverProfile cover,
  Map<String, BaseInnerCoverAssignment> assignments,
  Map<String, InnerCoverProfile> profiles,
  List<AssetInstanceRecord> bases,
  _InnerCoverBulgeEvidence? bulgeEvidence,
  AppUser? user,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder:
        (sheetContext) => _CoverDetailsSheet(
          cover: cover,
          bulgeEvidence: bulgeEvidence,
          canManage: user?.canManageAssetHierarchy == true,
          onAccept: () => _acceptCover(sheetContext, ref, cover, user!),
          onAssign:
              () => _assignAvailableCover(
                sheetContext,
                ref,
                user!,
                cover,
                bases,
                assignments,
                profiles,
              ),
          onDelink:
              () => _delinkCover(
                sheetContext,
                ref,
                cover,
                assignments[cover.currentBaseAssetInstanceId],
                user!,
              ),
          onState: () => _changeCoverState(sheetContext, ref, cover, user!),
        ),
  );
}

Future<void> _showBaseHistory(
  BuildContext context,
  AssetInstanceRecord base,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _BaseHistorySheet(base: base),
  );
}

Future<void> _assignAvailableCover(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
  InnerCoverProfile cover,
  List<AssetInstanceRecord> bases,
  Map<String, BaseInnerCoverAssignment> assignments,
  Map<String, InnerCoverProfile> profiles,
) async {
  if (!cover.isAvailable) {
    _showError(
      context,
      'Complete inspection and acceptance before assigning this Inner Cover.',
    );
    return;
  }
  if (bases.isEmpty) {
    _showError(context, 'No active governed Base is available for assignment.');
    return;
  }
  final selection = await showDialog<_BaseAssignmentSelection>(
    context: context,
    builder:
        (_) => _BaseAssignmentDialog(
          cover: cover,
          bases: bases,
          assignments: assignments,
        ),
  );
  if (selection == null || !context.mounted) return;
  final targetAssignment = assignments[selection.base.id];
  final repository = ref.read(assetHierarchyRepositoryProvider);
  final succeeded = await _runCommand(
    context,
    () async {
      if (targetAssignment == null) {
        await repository.linkInnerCover(
          cover: cover,
          base: selection.base,
          actor: user,
          reason: selection.reason,
        );
        return;
      }
      final displaced = profiles[targetAssignment.innerCoverId];
      if (displaced == null) {
        throw const AssetHierarchyException(
          'The installed Inner Cover profile needs reconciliation.',
        );
      }
      await repository.replaceInnerCover(
        incoming: cover,
        displaced: displaced,
        targetAssignment: targetAssignment,
        displacedState: InnerCoverLifecycleState.awaitingInspection,
        actor: user,
        reason: selection.reason,
      );
    },
    success: 'Inner Cover assigned to Base ${selection.base.assetNumber}.',
  );
  if (succeeded && context.mounted) Navigator.pop(context);
}

Future<void> _acceptCover(
  BuildContext context,
  WidgetRef ref,
  InnerCoverProfile cover,
  AppUser user,
) async {
  final result = await showDialog<_AcceptanceResult>(
    context: context,
    builder: (_) => const _AcceptanceDialog(),
  );
  if (result == null || !context.mounted) return;
  final succeeded = await _runCommand(context, () async {
    await ref
        .read(assetHierarchyRepositoryProvider)
        .acceptInnerCover(
          cover: cover,
          inspectedOn: result.inspectedOn,
          acceptanceReference: result.acceptanceReference,
          leakTestReference: result.leakTestReference,
          ndtReference: result.ndtReference,
          notes: result.notes,
          actor: user,
          reason: result.reason,
        );
  }, success: 'Inner Cover accepted into the available pool.');
  if (succeeded && context.mounted) Navigator.pop(context);
}

Future<void> _delinkCover(
  BuildContext context,
  WidgetRef ref,
  InnerCoverProfile cover,
  BaseInnerCoverAssignment? assignment,
  AppUser user, {
  bool closeSurfaceOnSuccess = true,
}) async {
  if (assignment == null) {
    _showError(context, 'The Base assignment needs reconciliation.');
    return;
  }
  final result = await showDialog<_StateReasonResult>(
    context: context,
    builder:
        (_) => const _StateReasonDialog(
          title: 'Remove from Base',
          states: [
            InnerCoverLifecycleState.available,
            InnerCoverLifecycleState.awaitingInspection,
            InnerCoverLifecycleState.underRepair,
            InnerCoverLifecycleState.quarantined,
          ],
          initialState: InnerCoverLifecycleState.awaitingInspection,
        ),
  );
  if (result == null || !context.mounted) return;
  final succeeded = await _runCommand(context, () async {
    await ref
        .read(assetHierarchyRepositoryProvider)
        .delinkInnerCover(
          cover: cover,
          assignment: assignment,
          targetState: result.state,
          actor: user,
          reason: result.reason,
        );
  }, success: 'Inner Cover removed and returned to lifecycle control.');
  if (succeeded && context.mounted && closeSurfaceOnSuccess) {
    Navigator.pop(context);
  }
}

Future<void> _changeCoverState(
  BuildContext context,
  WidgetRef ref,
  InnerCoverProfile cover,
  AppUser user,
) async {
  final states = allowedInnerCoverStateChanges(cover.lifecycleState);
  if (states.isEmpty) {
    _showError(context, 'No further lifecycle transition is available.');
    return;
  }
  final result = await showDialog<_StateReasonResult>(
    context: context,
    builder:
        (_) => _StateReasonDialog(
          title:
              cover.lifecycleState == InnerCoverLifecycleState.retiredForSalvage
                  ? 'Return retired cover to inspection'
                  : 'Change lifecycle state',
          states: states,
          initialState: states.first,
          supportingText:
              cover.lifecycleState == InnerCoverLifecycleState.retiredForSalvage
                  ? 'The retirement record remains visible. Fresh inspection and acceptance are required before this cover can be linked again.'
                  : null,
          requireHistoricalRetirementCondition:
              cover.lifecycleState ==
                  InnerCoverLifecycleState.retiredForSalvage &&
              cover.retirementCondition == null,
        ),
  );
  if (result == null || !context.mounted) return;
  final succeeded = await _runCommand(context, () async {
    await ref
        .read(assetHierarchyRepositoryProvider)
        .setInnerCoverState(
          cover: cover,
          targetState: result.state,
          retirementCondition: result.retirementCondition,
          actor: user,
          reason: result.reason,
        );
  }, success: 'Inner Cover lifecycle state updated.');
  if (succeeded && context.mounted) Navigator.pop(context);
}

List<InnerCoverLifecycleState> allowedInnerCoverStateChanges(
  InnerCoverLifecycleState current,
) => switch (current) {
  InnerCoverLifecycleState.awaitingInspection => const [
    InnerCoverLifecycleState.underInspection,
    InnerCoverLifecycleState.quarantined,
    InnerCoverLifecycleState.rejected,
  ],
  InnerCoverLifecycleState.underInspection => const [
    InnerCoverLifecycleState.underRepair,
    InnerCoverLifecycleState.quarantined,
    InnerCoverLifecycleState.rejected,
  ],
  InnerCoverLifecycleState.underRepair => const [
    InnerCoverLifecycleState.awaitingInspection,
    InnerCoverLifecycleState.quarantined,
  ],
  InnerCoverLifecycleState.underFabrication => const [
    InnerCoverLifecycleState.awaitingInspection,
    InnerCoverLifecycleState.quarantined,
  ],
  InnerCoverLifecycleState.available => const [
    InnerCoverLifecycleState.reserved,
    InnerCoverLifecycleState.underInspection,
    InnerCoverLifecycleState.underRepair,
    InnerCoverLifecycleState.quarantined,
    InnerCoverLifecycleState.retiredForSalvage,
  ],
  InnerCoverLifecycleState.reserved => const [
    InnerCoverLifecycleState.available,
    InnerCoverLifecycleState.quarantined,
  ],
  InnerCoverLifecycleState.quarantined => const [
    InnerCoverLifecycleState.underInspection,
    InnerCoverLifecycleState.underRepair,
    InnerCoverLifecycleState.rejected,
    InnerCoverLifecycleState.retiredForSalvage,
  ],
  InnerCoverLifecycleState.rejected => const [
    InnerCoverLifecycleState.retiredForSalvage,
    InnerCoverLifecycleState.disposed,
  ],
  InnerCoverLifecycleState.retiredForSalvage => const [
    InnerCoverLifecycleState.awaitingInspection,
    InnerCoverLifecycleState.partiallyDismantled,
    InnerCoverLifecycleState.disposed,
  ],
  InnerCoverLifecycleState.partiallyDismantled => const [
    InnerCoverLifecycleState.fullyConsumedAsDonor,
    InnerCoverLifecycleState.disposed,
  ],
  InnerCoverLifecycleState.fullyConsumedAsDonor => const [
    InnerCoverLifecycleState.disposed,
  ],
  InnerCoverLifecycleState.installed ||
  InnerCoverLifecycleState.disposed => const [],
};

Future<bool> _runCommand(
  BuildContext context,
  Future<void> Function() action, {
  required String success,
}) async {
  try {
    await action();
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success), backgroundColor: BafColors.success),
    );
    return true;
  } catch (error) {
    if (!context.mounted) return false;
    _showError(context, '$error');
    return false;
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: BafColors.danger),
  );
}
