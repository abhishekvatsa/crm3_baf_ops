import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/persistence/durable_submission.dart';
import '../../../core/serialization/command_timestamp.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../auth/data/user_model.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_registry_model.dart';
import '../data/furnace_stuckup_record.dart';
import '../data/inner_cover_lifecycle.dart';
import '../domain/inner_cover_acceptance_input.dart';
import '../domain/inner_cover_acceptance_submission.dart';
import '../../maintenance/domain/furnace_stuckup_case.dart';
import 'widgets/inner_cover_registration_date_field.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../providers/inner_cover_acceptance_provider.dart';
import '../providers/inner_cover_lifecycle_submission_provider.dart';
import '../providers/furnace_stuckup_provider.dart';
import '../repositories/asset_hierarchy_repository.dart';
import '../services/inner_cover_acceptance_controller.dart';

part 'inner_cover_lifecycle_screen.details.dart';
part 'inner_cover_lifecycle_screen.acceptance.dart';
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
    final profilesBatch = ref.watch(innerCoverProfileBatchProvider);
    final assignmentsBatch = ref.watch(innerCoverAssignmentBatchProvider);
    final classes = ref.watch(assetClassesProvider);
    final assets = ref.watch(allAssetInstancesProvider);
    final stuckupCases = ref.watch(furnaceStuckupCasesProvider);
    final conditionDeclarations = ref.watch(assetConditionDeclarationsProvider);
    final loading =
        profilesBatch.isLoading ||
        assignmentsBatch.isLoading ||
        classes.isLoading ||
        assets.isLoading;
    final error =
        profilesBatch.error ??
        assignmentsBatch.error ??
        classes.error ??
        assets.error;

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
            if (user.canManageAssetHierarchy)
              IconButton(
                tooltip: 'Saved pending Inner Cover registrations',
                icon: const Icon(Icons.pending_actions_rounded),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const _PendingInnerCoverRegistrationsPage(),
                  ),
                ),
              ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _LoadError(error: error)
            : _LifecycleBody(
                user: user,
                profiles:
                    profilesBatch.value?.records ?? const <InnerCoverProfile>[],
                assignments:
                    assignmentsBatch.value?.records ??
                    const <BaseInnerCoverAssignment>[],
                populationIncomplete:
                    _InnerCoverPairingEvidence.fromBatches(
                      profilesBatch,
                      assignmentsBatch,
                    ) ==
                    null,
                assetClasses: classes.value ?? const <AssetClassRecord>[],
                assets: assets.value ?? const <AssetInstanceRecord>[],
                stuckupCases:
                    stuckupCases.value ?? const <FurnaceStuckupRecord>[],
                conditionDeclarations:
                    conditionDeclarations.value ??
                    const <AssetConditionDeclarationRecord>[],
                bulgeEvidenceAvailable:
                    !stuckupCases.isLoading &&
                    !stuckupCases.hasError &&
                    !conditionDeclarations.isLoading &&
                    !conditionDeclarations.hasError,
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
  final bool populationIncomplete;

  const _LifecycleBody({
    required this.user,
    required this.profiles,
    required this.assignments,
    required this.assetClasses,
    required this.assets,
    required this.stuckupCases,
    required this.conditionDeclarations,
    required this.bulgeEvidenceAvailable,
    required this.populationIncomplete,
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
    final baseClassIds = assetClasses
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
    final pool = profiles.where((profile) => !profile.isInstalled).toList()
      ..sort(_poolSort);
    final canManage = user?.canManageAssetHierarchy == true;

    return Column(
      children: [
        _SummaryBand(
          profiles: profiles,
          baseCount: bases.length,
          occupiedBaseCount: bases
              .where((base) => assignmentByBase.containsKey(base.id))
              .length,
          bulgeEvidenceByCoverId: bulgeEvidenceByCoverId,
          bulgeEvidenceAvailable: widget.bulgeEvidenceAvailable,
          populationIncomplete: widget.populationIncomplete,
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
                onFilterChanged: (filter) => setState(() {
                  _baseFilter = filter;
                }),
                canManage: canManage,
                pairingPopulationComplete: !widget.populationIncomplete,
                onHistory: (base) => _showBaseHistory(context, base),
                onDelink: (assignment, cover) => _delinkCover(
                  context,
                  ref,
                  cover,
                  assignment,
                  user!,
                  closeSurfaceOnSuccess: false,
                ),
                onManage: (base, assignment) =>
                    _manageBaseCover(context, ref, user!, base),
              ),
              _CoverList(
                profiles: pool,
                populationComplete: !widget.populationIncomplete,
                emptyMessage: 'No Inner Covers are currently in the pool.',
                bulgeEvidenceByCoverId: bulgeEvidenceByCoverId,
                filter: _poolFilter,
                onFilterChanged: (filter) => setState(() {
                  _poolFilter = filter;
                }),
                onOpen: (cover) => _showCoverDetails(
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
                populationComplete: !widget.populationIncomplete,
                emptyMessage: 'No Inner Covers have been registered.',
                bulgeEvidenceByCoverId: bulgeEvidenceByCoverId,
                filter: _allCoverFilter,
                onFilterChanged: (filter) => setState(() {
                  _allCoverFilter = filter;
                }),
                onOpen: (cover) => _showCoverDetails(
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
    final number = _compareDecimalStrings(
      leftMatch.group(2)!,
      rightMatch.group(2)!,
    );
    if (number != 0) return number;
  }
  return left.normalizedSerialNumber.compareTo(right.normalizedSerialNumber);
}

int _compareDecimalStrings(String left, String right) {
  String withoutLeadingZeroes(String value) {
    var firstSignificantDigit = 0;
    while (firstSignificantDigit < value.length - 1 &&
        value.codeUnitAt(firstSignificantDigit) == 0x30) {
      firstSignificantDigit += 1;
    }
    return value.substring(firstSignificantDigit);
  }

  final normalizedLeft = withoutLeadingZeroes(left);
  final normalizedRight = withoutLeadingZeroes(right);
  final length = normalizedLeft.length.compareTo(normalizedRight.length);
  return length != 0 ? length : normalizedLeft.compareTo(normalizedRight);
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
  final bool populationIncomplete;
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
    required this.populationIncomplete,
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
    final retired = profiles
        .where((item) => _isRetirementState(item.lifecycleState))
        .length;
    final vacantBases = (baseCount - occupiedBaseCount).clamp(0, baseCount);
    final bulgeRecords = bulgeEvidenceByCoverId.values
        .where((evidence) => evidence.hasAnyRecord)
        .length;
    final attention = profiles
        .where(
          (item) => _needsLifecycleAttention(
            item.lifecycleState,
            requiresReacceptance: item.requiresReacceptance,
          ),
        )
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
                label: populationIncomplete
                    ? 'Installed unverified'
                    : '$occupiedBaseCount installed',
                color: BafColors.success,
                tooltip: 'Show Bases with an Inner Cover',
                onTap: onShowInstalled,
              ),
              _SummaryFilterBadge(
                label: populationIncomplete
                    ? 'Available unverified'
                    : '$available available',
                color: BafColors.planned,
                tooltip: 'Show available Inner Covers',
                onTap: onShowAvailable,
              ),
              _SummaryFilterBadge(
                label: populationIncomplete
                    ? 'Attention unverified'
                    : '$attention need attention',
                color: attention == 0
                    ? BafColors.textSecondary
                    : BafColors.warning,
                tooltip: 'Show Inner Covers needing attention',
                onTap: onShowAttention,
              ),
              if (!populationIncomplete)
                _SummaryFilterBadge(
                  label: '$vacantBases Bases with no Inner Covers',
                  color: vacantBases == 0
                      ? BafColors.textSecondary
                      : BafColors.audit,
                  tooltip: 'Show Bases with no Inner Cover',
                  onTap: onShowVacantBases,
                )
              else
                const StatusBadge(
                  label: 'Vacancy and totals unverified',
                  color: BafColors.warning,
                ),
              if (retired > 0)
                _SummaryFilterBadge(
                  label: populationIncomplete
                      ? 'Retired unverified'
                      : '$retired retired',
                  color: BafColors.textSecondary,
                  tooltip: 'Show retired Inner Covers',
                  onTap: onShowRetired,
                ),
              if (bulgeEvidenceAvailable && bulgeRecords > 0)
                _SummaryFilterBadge(
                  label: populationIncomplete
                      ? 'Bulge totals unverified'
                      : '$bulgeRecords with bulge history',
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
  final bool pairingPopulationComplete;
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
    required this.pairingPopulationComplete,
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
    final vacantCount = widget.pairingPopulationComplete
        ? widget.bases
              .where((base) => !widget.assignmentByBase.containsKey(base.id))
              .length
        : null;
    final filtered = widget.bases.where((base) {
      final assignment = widget.assignmentByBase[base.id];
      final matchesFilter = switch (widget.filter) {
        _BaseListFilter.all => true,
        _BaseListFilter.vacant =>
          widget.pairingPopulationComplete && assignment == null,
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
              label: Text(
                vacantCount == null
                    ? 'Vacant unverified'
                    : 'Vacant $vacantCount',
              ),
              selected: widget.filter == _BaseListFilter.vacant,
              onSelected: vacantCount == null
                  ? null
                  : (_) => widget.onFilterChanged(_BaseListFilter.vacant),
            ),
            ChoiceChip(
              label: Text(
                vacantCount == null
                    ? 'Occupied unverified'
                    : 'Occupied ${widget.bases.length - vacantCount}',
              ),
              selected: widget.filter == _BaseListFilter.occupied,
              onSelected: (_) =>
                  widget.onFilterChanged(_BaseListFilter.occupied),
            ),
          ],
        ),
        Expanded(
          child: filtered.isEmpty
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
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: BafSpacing.sm),
                  itemBuilder: (context, index) {
                    final base = filtered[index];
                    final assignment = widget.assignmentByBase[base.id];
                    final profile = assignment == null
                        ? null
                        : widget.profileById[assignment.innerCoverId];
                    final assignmentUnverified =
                        assignment == null && !widget.pairingPopulationComplete;
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
                          color: drift
                              ? BafColors.danger
                              : assignmentUnverified
                              ? BafColors.warning
                              : BafColors.border,
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
                            style: const TextStyle(fontWeight: FontWeight.w800),
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
                                : assignmentUnverified
                                ? 'Assignment data is incomplete; vacancy is unverified'
                                : assignment == null
                                ? 'No Inner Cover linked'
                                : profile?.incorporatedOn == null
                                ? 'Inner Cover ${assignment.innerCoverSerialNumber}'
                                : 'Inner Cover ${assignment.innerCoverSerialNumber}\n'
                                      'Incorporated ${_formatInnerCoverDate(profile!.incorporatedOn!)}',
                            style: TextStyle(
                              color: drift
                                  ? BafColors.danger
                                  : assignmentUnverified
                                  ? BafColors.warning
                                  : assignment == null
                                  ? BafColors.textSecondary
                                  : BafColors.success,
                              fontWeight: assignment == null
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        trailing:
                            widget.canManage &&
                                widget.pairingPopulationComplete &&
                                !drift &&
                                !assignmentUnverified
                            ? assignment == null
                                  ? IconButton(
                                      tooltip: 'Link Inner Cover',
                                      onPressed: () =>
                                          widget.onManage(base, assignment),
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
                                            onPressed: () => widget.onDelink(
                                              assignment,
                                              profile!,
                                            ),
                                            icon: const Icon(
                                              Icons.link_off_rounded,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Change Inner Cover',
                                            onPressed: () => widget.onManage(
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

bool _needsLifecycleAttention(
  InnerCoverLifecycleState state, {
  bool requiresReacceptance = false,
}) =>
    requiresReacceptance ||
    const {
      InnerCoverLifecycleState.awaitingInspection,
      InnerCoverLifecycleState.underInspection,
      InnerCoverLifecycleState.underRepair,
      InnerCoverLifecycleState.underFabrication,
      InnerCoverLifecycleState.quarantined,
      InnerCoverLifecycleState.rejected,
    }.contains(state);

class _CoverList extends StatefulWidget {
  final List<InnerCoverProfile> profiles;
  final bool populationComplete;
  final String emptyMessage;
  final Map<String, _InnerCoverBulgeEvidence> bulgeEvidenceByCoverId;
  final _CoverListFilter filter;
  final ValueChanged<_CoverListFilter> onFilterChanged;
  final ValueChanged<InnerCoverProfile> onOpen;

  const _CoverList({
    required this.profiles,
    required this.populationComplete,
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
        message: widget.populationComplete
            ? widget.emptyMessage
            : 'Inner Cover records are incomplete or unavailable. The pool cannot be confirmed.',
      );
    }
    final query = _search.text.trim().toLowerCase();
    final sorted = [...widget.profiles]..sort(_compareInnerCoverSerial);
    final filtered = sorted.where((cover) {
      final bulge = widget.bulgeEvidenceByCoverId[cover.id];
      final matchesFilter = switch (widget.filter) {
        _CoverListFilter.all => true,
        _CoverListFilter.available => cover.isAvailable,
        _CoverListFilter.installed => cover.isInstalled,
        _CoverListFilter.attention => _needsLifecycleAttention(
          cover.lifecycleState,
          requiresReacceptance: cover.requiresReacceptance,
        ),
        _CoverListFilter.retired => _isRetirementState(cover.lifecycleState),
        _CoverListFilter.bulge => bulge?.hasAnyRecord == true,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return cover.serialNumber.toLowerCase().contains(query) ||
          cover.normalizedSerialNumber.toLowerCase().contains(query) ||
          cover.lifecycleState.label.toLowerCase().contains(query) ||
          '${cover.currentBaseAssetNumber ?? ''}'.contains(query);
    }).toList();
    final availableCount = widget.profiles
        .where((item) => item.isAvailable)
        .length;
    final installedCount = widget.profiles
        .where((item) => item.isInstalled)
        .length;
    final attentionCount = widget.profiles
        .where(
          (item) => _needsLifecycleAttention(
            item.lifecycleState,
            requiresReacceptance: item.requiresReacceptance,
          ),
        )
        .length;
    final retiredCount = widget.profiles
        .where((item) => _isRetirementState(item.lifecycleState))
        .length;
    final bulgeCount = widget.profiles
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
              label: Text(
                widget.populationComplete
                    ? 'All ${widget.profiles.length}'
                    : 'All unverified',
              ),
              selected: widget.filter == _CoverListFilter.all,
              onSelected: (_) => widget.onFilterChanged(_CoverListFilter.all),
            ),
            ChoiceChip(
              label: Text(
                widget.populationComplete
                    ? 'Available $availableCount'
                    : 'Available unverified',
              ),
              selected: widget.filter == _CoverListFilter.available,
              onSelected: (_) =>
                  widget.onFilterChanged(_CoverListFilter.available),
            ),
            if (installedCount > 0)
              ChoiceChip(
                label: Text(
                  widget.populationComplete
                      ? 'Installed $installedCount'
                      : 'Installed unverified',
                ),
                selected: widget.filter == _CoverListFilter.installed,
                onSelected: (_) =>
                    widget.onFilterChanged(_CoverListFilter.installed),
              ),
            ChoiceChip(
              label: Text(
                widget.populationComplete
                    ? 'Attention $attentionCount'
                    : 'Attention unverified',
              ),
              selected: widget.filter == _CoverListFilter.attention,
              onSelected: (_) =>
                  widget.onFilterChanged(_CoverListFilter.attention),
            ),
            if (retiredCount > 0)
              ChoiceChip(
                label: Text(
                  widget.populationComplete
                      ? 'Retired $retiredCount'
                      : 'Retired unverified',
                ),
                selected: widget.filter == _CoverListFilter.retired,
                onSelected: (_) =>
                    widget.onFilterChanged(_CoverListFilter.retired),
              ),
            if (bulgeCount > 0)
              ChoiceChip(
                label: Text(
                  widget.populationComplete
                      ? 'Bulge history $bulgeCount'
                      : 'Bulge totals unverified',
                ),
                selected: widget.filter == _CoverListFilter.bulge,
                onSelected: (_) =>
                    widget.onFilterChanged(_CoverListFilter.bulge),
              ),
          ],
        ),
        Expanded(
          child: filtered.isEmpty
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
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: BafSpacing.sm),
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
                              color: bulge?.hasConfirmedRecord == true
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
            suffixIcon: controller.text.isEmpty
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
  final innerCoverClass = classes
      .where((item) => item.isActive && item.legacyAssetTypeKey == 'innerCover')
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
    builder: (_) => _RegistrationDialog(
      profiles:
          ref.read(innerCoverProfileBatchProvider).value?.records ?? const [],
    ),
  );
  if (result == null || !context.mounted) return;
  String? registeredId;
  final succeeded = await _runCommand(context, () async {
    final repository = ref.read(assetHierarchyRepositoryProvider);
    final innerCoverId = const Uuid().v4();
    String? clean(String? value) =>
        value == null || value.trim().isEmpty ? null : value.trim();
    registeredId = innerCoverId;
    await ref
        .read(innerCoverLifecycleSubmissionControllerProvider)
        .submit(
          originActorUid: user.uid,
          request: repository.newInnerCoverLifecycleRequest(
            requestId: const Uuid().v4(),
            operation: 'REGISTER_INNER_COVER',
            innerCoverId: innerCoverId,
            fields: {
              'innerCoverAssetClassId': innerCoverClass.id,
              'reason': result.reason,
              'registrationDraft': {
                'serialNumber': result.serialNumber,
                'sourceType': result.sourceType.name,
                'originClassification': result.originClassification.name,
                'supplierOrFabricator': clean(result.supplierOrFabricator),
                'receivedOrCompletedOn': result.receivedOrCompletedOn == null
                    ? null
                    : commandUtcMillis(result.receivedOrCompletedOn!),
                'incorporatedOn': result.incorporatedOn == null
                    ? null
                    : commandUtcMillis(result.incorporatedOn!),
                'drawingReference': clean(result.drawingReference),
                'materialGrade': clean(result.materialGrade),
                'notes': clean(result.notes),
                'fabricationSections': result.sections
                    .map(
                      (section) => {
                        'sectionId': const Uuid().v4(),
                        'sectionType': section.type.name,
                        'materialSource': section.materialSource.name,
                        'donorInnerCoverId': section.donor?.id,
                        'donorSectionKey': clean(section.donorSectionKey),
                        'donorExpectedVersion': section.donor?.version,
                        'lengthMm': section.lengthMm,
                        'cutCount': section.cutCount,
                        'notes': clean(section.notes),
                      },
                    )
                    .toList(growable: false),
              },
            },
          ),
        );
  }, success: 'Inner Cover registered for inspection.');
  if (succeeded && registeredId != null && context.mounted) {
    ref.invalidate(innerCoverProfileBatchProvider);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _InnerCoverIntakePage(innerCoverId: registeredId!),
      ),
    );
  }
}

const _pairingUnavailableMessage =
    'Pairing records are incomplete or unavailable. Check the current records before assigning an Inner Cover.';
const _pairingChangedMessage =
    'Pairing records changed. Close this form and review the current records before trying again.';

class _InnerCoverPairingEvidence {
  final Map<String, InnerCoverProfile> profiles;
  final Map<String, BaseInnerCoverAssignment> assignments;

  _InnerCoverPairingEvidence._({
    required this.profiles,
    required this.assignments,
  });

  static _InnerCoverPairingEvidence? fromBatches(
    AsyncValue<DecodedSnapshotBatch<InnerCoverProfile>> profiles,
    AsyncValue<DecodedSnapshotBatch<BaseInnerCoverAssignment>> assignments,
  ) {
    if (profiles.isLoading ||
        profiles.hasError ||
        assignments.isLoading ||
        assignments.hasError) {
      return null;
    }
    final profileBatch = profiles.valueOrNull;
    final assignmentBatch = assignments.valueOrNull;
    if (profileBatch == null ||
        !profileBatch.isComplete ||
        !profileBatch.isServerConfirmed ||
        assignmentBatch == null ||
        !assignmentBatch.isComplete ||
        !assignmentBatch.isServerConfirmed) {
      return null;
    }
    final profileById = {
      for (final item in profileBatch.records) item.id: item,
    };
    final assignmentByBase = {
      for (final item in assignmentBatch.records)
        item.baseAssetInstanceId: item,
    };
    final assignedCoverIds = <String>{};
    final assignedLinkageIds = <String>{};
    if (profileById.length != profileBatch.records.length ||
        assignmentByBase.length != assignmentBatch.records.length) {
      return null;
    }
    // Complete queries can still disagree. An installed profile remains a
    // custody claim even when its assignment projection is missing.
    for (final assignment in assignmentBatch.records) {
      final profile = profileById[assignment.innerCoverId];
      if (!assignedCoverIds.add(assignment.innerCoverId) ||
          !assignedLinkageIds.add(assignment.linkageId) ||
          profile == null ||
          !profile.isInstalled ||
          profile.currentBaseAssetInstanceId !=
              assignment.baseAssetInstanceId ||
          profile.currentLinkageId != assignment.linkageId) {
        return null;
      }
    }
    for (final profile in profileBatch.records.where(
      (item) => item.isInstalled,
    )) {
      final assignment = assignmentByBase[profile.currentBaseAssetInstanceId];
      if (assignment == null ||
          assignment.innerCoverId != profile.id ||
          assignment.linkageId != profile.currentLinkageId) {
        return null;
      }
    }
    return _InnerCoverPairingEvidence._(
      profiles: profileById,
      assignments: assignmentByBase,
    );
  }

  static _InnerCoverPairingEvidence? read(ProviderContainer container) =>
      fromBatches(
        container.read(innerCoverProfileBatchProvider),
        container.read(innerCoverAssignmentBatchProvider),
      );

  bool agreesWith(_InnerCoverPairingEvidence other) =>
      profiles.length == other.profiles.length &&
      assignments.length == other.assignments.length &&
      profiles.entries.every((entry) {
        final previous = other.profiles[entry.key];
        return previous != null &&
            previous.version == entry.value.version &&
            previous.lastMutationId == entry.value.lastMutationId &&
            previous.lifecycleState == entry.value.lifecycleState &&
            previous.currentBaseAssetInstanceId ==
                entry.value.currentBaseAssetInstanceId &&
            previous.currentBaseAssetNumber ==
                entry.value.currentBaseAssetNumber &&
            previous.currentLinkageId == entry.value.currentLinkageId &&
            previous.acceptedAt == entry.value.acceptedAt &&
            previous.assuranceInvalidatedAt ==
                entry.value.assuranceInvalidatedAt &&
            previous.assuranceEpisodeId == entry.value.assuranceEpisodeId;
      }) &&
      assignments.entries.every((entry) {
        final previous = other.assignments[entry.key];
        return previous != null &&
            previous.version == entry.value.version &&
            previous.innerCoverId == entry.value.innerCoverId &&
            previous.baseAssetNumber == entry.value.baseAssetNumber &&
            previous.linkageId == entry.value.linkageId &&
            previous.lastMutationId == entry.value.lastMutationId;
      });
}

void _requireReviewedPairingEvidence(
  ProviderContainer container,
  _InnerCoverPairingEvidence reviewed,
) {
  final current = _InnerCoverPairingEvidence.read(container);
  if (current == null) {
    throw const AssetHierarchyException(_pairingUnavailableMessage);
  }
  if (!current.agreesWith(reviewed)) {
    throw const AssetHierarchyException(_pairingChangedMessage);
  }
}

/// A modal has its own subscription so a later incomplete or changed snapshot
/// cannot leave the original vacancy choices actionable behind the main page.
class _InnerCoverPairingGuard extends ConsumerWidget {
  final _InnerCoverPairingEvidence reviewed;
  final Widget child;

  const _InnerCoverPairingGuard({required this.reviewed, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _InnerCoverPairingEvidence.fromBatches(
      ref.watch(innerCoverProfileBatchProvider),
      ref.watch(innerCoverAssignmentBatchProvider),
    );
    final message = current == null
        ? _pairingUnavailableMessage
        : !current.agreesWith(reviewed)
        ? _pairingChangedMessage
        : null;
    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeFocus(
          excluding: message != null,
          child: Offstage(offstage: message != null, child: child),
        ),
        if (message != null)
          AlertDialog(
            title: const Text('Pairing records need checking'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close form'),
              ),
            ],
          ),
      ],
    );
  }
}

Future<void> _manageBaseCover(
  BuildContext context,
  WidgetRef ref,
  AppUser user,
  AssetInstanceRecord base,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final reviewed = _InnerCoverPairingEvidence.read(container);
  if (reviewed == null) {
    _showError(context, _pairingUnavailableMessage);
    return;
  }
  final current = reviewed.assignments[base.id];
  final profiles = reviewed.profiles;
  final assignments = reviewed.assignments;
  final candidates = profiles.values
      .where(
        (cover) =>
            cover.isAvailable ||
            (cover.isInstalled && cover.currentBaseAssetInstanceId != base.id),
      )
      .toList();
  if (candidates.isEmpty) {
    _showError(context, 'No available or transferable Inner Cover was found.');
    return;
  }
  final selection = await showDialog<_PairingSelection>(
    context: context,
    builder: (_) => _InnerCoverPairingGuard(
      reviewed: reviewed,
      child: _PairingDialog(
        base: base,
        current: current,
        candidates: candidates,
      ),
    ),
  );
  if (selection == null || !context.mounted) return;
  final repository = container.read(assetHierarchyRepositoryProvider);
  final submissions = container.read(
    innerCoverLifecycleSubmissionControllerProvider,
  );
  final incoming = selection.cover;
  await _runCommand(context, () async {
    _requireReviewedPairingEvidence(container, reviewed);
    if (current == null) {
      if (incoming.isAvailable) {
        await submissions.submit(
          originActorUid: user.uid,
          request: repository.newInnerCoverLifecycleRequest(
            operation: 'LINK_INNER_COVER',
            innerCoverId: incoming.id,
            expectedVersion: incoming.version,
            fields: {
              'targetBaseAssetInstanceId': base.id,
              'reason': selection.reason,
            },
          ),
        );
      } else {
        final source = assignments[incoming.currentBaseAssetInstanceId];
        if (source == null) {
          throw const AssetHierarchyException(
            'The source Base assignment needs reconciliation.',
          );
        }
        await submissions.submit(
          originActorUid: user.uid,
          request: repository.newInnerCoverLifecycleRequest(
            operation: 'TRANSFER_INNER_COVER',
            innerCoverId: incoming.id,
            expectedVersion: incoming.version,
            fields: {
              'sourceBaseAssetInstanceId': source.baseAssetInstanceId,
              'expectedSourceAssignmentVersion': source.version,
              'targetBaseAssetInstanceId': base.id,
              'reason': selection.reason,
            },
          ),
        );
      }
      return;
    }
    final displaced = profiles[current.innerCoverId];
    if (displaced == null) {
      throw const AssetHierarchyException(
        'The installed Inner Cover profile needs reconciliation.',
      );
    }
    if (incoming.isAvailable) {
      await submissions.submit(
        originActorUid: user.uid,
        request: repository.newInnerCoverLifecycleRequest(
          operation: 'REPLACE_INNER_COVER',
          innerCoverId: incoming.id,
          expectedVersion: incoming.version,
          fields: {
            'targetBaseAssetInstanceId': current.baseAssetInstanceId,
            'expectedTargetAssignmentVersion': current.version,
            'displacedInnerCoverId': displaced.id,
            'expectedDisplacedVersion': displaced.version,
            'targetState': InnerCoverLifecycleState.awaitingInspection.name,
            'physicalEventAt': commandUtcMillis(selection.physicalEventAt!),
            'reason': selection.reason,
          },
        ),
      );
    } else {
      final source = assignments[incoming.currentBaseAssetInstanceId];
      if (source == null) {
        throw const AssetHierarchyException(
          'The source Base assignment needs reconciliation.',
        );
      }
      await submissions.submit(
        originActorUid: user.uid,
        request: repository.newInnerCoverLifecycleRequest(
          operation: 'SWAP_INNER_COVERS',
          innerCoverId: incoming.id,
          expectedVersion: incoming.version,
          fields: {
            'sourceBaseAssetInstanceId': source.baseAssetInstanceId,
            'expectedSourceAssignmentVersion': source.version,
            'targetBaseAssetInstanceId': current.baseAssetInstanceId,
            'expectedTargetAssignmentVersion': current.version,
            'displacedInnerCoverId': displaced.id,
            'expectedDisplacedVersion': displaced.version,
            'reason': selection.reason,
          },
        ),
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
    builder: (sheetContext) => _CoverDetailsSheet(
      cover: cover,
      bulgeEvidence: bulgeEvidence,
      canManage: user?.canManageAssetHierarchy == true,
      onAccept: () => _acceptCover(sheetContext, ref, cover, user!),
      onAssign: () =>
          _assignAvailableCover(sheetContext, ref, user!, cover, bases),
      onDelink: () => _delinkCover(
        sheetContext,
        ref,
        cover,
        assignments[cover.currentBaseAssetInstanceId],
        user!,
      ),
      onState: () => _changeCoverState(sheetContext, ref, cover, user!),
      onCheckSavedLifecycle: () =>
          _checkSavedInnerCoverLifecycle(sheetContext, ref, cover),
    ),
  );
}

Future<void> _checkSavedInnerCoverLifecycle(
  BuildContext context,
  WidgetRef ref,
  InnerCoverProfile cover,
) async {
  try {
    final controller = ref.read(
      innerCoverLifecycleSubmissionControllerProvider,
    );
    final saved = await controller.restore(cover.id);
    if (saved == null) {
      throw const AssetHierarchyException(
        'There is no saved Inner Cover lifecycle change to check.',
      );
    }
    await controller.check(saved.submissionId);
    ref.invalidate(innerCoverLifecyclePendingProvider(cover.id));
    ref.invalidate(innerCoverProfileBatchProvider);
    ref.invalidate(innerCoverAssignmentBatchProvider);
    ref.invalidate(innerCoverHistoryProvider(cover.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved Inner Cover change confirmed.')),
      );
    }
  } catch (error) {
    if (context.mounted) _showError(context, '$error');
  }
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
  InnerCoverProfile initialCover,
  List<AssetInstanceRecord> bases,
) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final reviewed = _InnerCoverPairingEvidence.read(container);
  if (reviewed == null) {
    _showError(context, _pairingUnavailableMessage);
    return;
  }
  final cover = reviewed.profiles[initialCover.id];
  if (cover == null || !cover.isAvailable) {
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
    builder: (_) => _InnerCoverPairingGuard(
      reviewed: reviewed,
      child: _BaseAssignmentDialog(
        cover: cover,
        bases: bases,
        assignments: reviewed.assignments,
      ),
    ),
  );
  if (selection == null || !context.mounted) return;
  final targetAssignment = reviewed.assignments[selection.base.id];
  final repository = container.read(assetHierarchyRepositoryProvider);
  final submissions = container.read(
    innerCoverLifecycleSubmissionControllerProvider,
  );
  final succeeded = await _runCommand(
    context,
    () async {
      _requireReviewedPairingEvidence(container, reviewed);
      if (targetAssignment == null) {
        await submissions.submit(
          originActorUid: user.uid,
          request: repository.newInnerCoverLifecycleRequest(
            operation: 'LINK_INNER_COVER',
            innerCoverId: cover.id,
            expectedVersion: cover.version,
            fields: {
              'targetBaseAssetInstanceId': selection.base.id,
              'reason': selection.reason,
            },
          ),
        );
        return;
      }
      final displaced = reviewed.profiles[targetAssignment.innerCoverId];
      if (displaced == null) {
        throw const AssetHierarchyException(
          'The installed Inner Cover profile needs reconciliation.',
        );
      }
      await submissions.submit(
        originActorUid: user.uid,
        request: repository.newInnerCoverLifecycleRequest(
          operation: 'REPLACE_INNER_COVER',
          innerCoverId: cover.id,
          expectedVersion: cover.version,
          fields: {
            'targetBaseAssetInstanceId': targetAssignment.baseAssetInstanceId,
            'expectedTargetAssignmentVersion': targetAssignment.version,
            'displacedInnerCoverId': displaced.id,
            'expectedDisplacedVersion': displaced.version,
            'targetState': InnerCoverLifecycleState.awaitingInspection.name,
            'physicalEventAt': commandUtcMillis(selection.physicalEventAt!),
            'reason': selection.reason,
          },
        ),
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
  final repository = ref.read(assetHierarchyRepositoryProvider);
  // The launching consumer can be replaced while account verification recovers.
  // The dialog must read live authority without retaining that disposed ref.
  final container = ProviderScope.containerOf(context, listen: false);
  AppUser requireOriginalActor() {
    final access = CurrentActorAccess.resolve(
      container.read(currentAppUserProvider),
    );
    if (!access.isReady) throw AssetHierarchyException(access.message);
    if (access.actor!.uid != user.uid) {
      throw const AssetHierarchyException(
        'Return to the original account to check this acceptance.',
      );
    }
    return access.actor!;
  }

  late final InnerCoverAcceptanceController controller;
  final DurableSubmission? pending;
  try {
    controller = container.read(innerCoverAcceptanceControllerProvider);
    requireOriginalActor();
    pending = await controller.restore(cover.id);
    requireOriginalActor();
  } catch (error) {
    if (context.mounted) _showError(context, '$error');
    return;
  }
  if (!context.mounted) return;
  final result = await showDialog<InnerCoverProfile>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AcceptanceDialog(
      initialCover: cover,
      initialSubmission: pending,
      originalActor: user,
      onRefreshSubject: (previous) async {
        requireOriginalActor();
        final current = await repository.readInnerCoverFromServer(
          cover.id,
          minimumVersion: previous.version,
        );
        requireOriginalActor();
        if (current.id != cover.id ||
            current.assetClassId != cover.assetClassId ||
            current.assetClassCode != cover.assetClassCode ||
            current.normalizedSerialNumber != cover.normalizedSerialNumber) {
          throw const AssetHierarchyException(
            'The current record does not match this cover. Your inspection is retained for review.',
          );
        }
        return current;
      },
      onSubmit: (draft, requestId, reviewedCover) async {
        requireOriginalActor();
        try {
          return await controller.submit(
            cover: reviewedCover,
            input: draft,
            requestId: requestId,
          );
        } finally {
          container.invalidate(innerCoverAcceptancePendingProvider(cover.id));
        }
      },
    ),
  );
  if (result == null || !context.mounted) return;
  container.invalidate(innerCoverProfileBatchProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${result.serialNumber}: ${result.lifecycleState.label}, confirmed from server.',
      ),
    ),
  );
  Navigator.pop(context);
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
    builder: (_) => const _StateReasonDialog(
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
    final repository = ref.read(assetHierarchyRepositoryProvider);
    await ref
        .read(innerCoverLifecycleSubmissionControllerProvider)
        .submit(
          originActorUid: user.uid,
          request: repository.newInnerCoverLifecycleRequest(
            operation: 'DELINK_INNER_COVER',
            innerCoverId: cover.id,
            expectedVersion: cover.version,
            fields: {
              'sourceBaseAssetInstanceId': assignment.baseAssetInstanceId,
              'expectedSourceAssignmentVersion': assignment.version,
              'targetState': result.state.name,
              'physicalEventAt': commandUtcMillis(result.physicalEventAt),
              'reason': result.reason,
            },
          ),
        );
  }, success: 'Inner Cover removed and returned to lifecycle control.');
  if (succeeded && context.mounted && closeSurfaceOnSuccess) {
    Navigator.pop(context);
  }
}

bool _canStartInnerCoverReinspection(InnerCoverProfile cover) =>
    cover.requiresReacceptance &&
    allowedInnerCoverStateChanges(
      cover.lifecycleState,
    ).contains(InnerCoverLifecycleState.underInspection);

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
    builder: (_) => _StateReasonDialog(
      title: cover.lifecycleState == InnerCoverLifecycleState.retiredForSalvage
          ? 'Return retired cover to inspection'
          : 'Change lifecycle state',
      states: states,
      initialState: _canStartInnerCoverReinspection(cover)
          ? InnerCoverLifecycleState.underInspection
          : states.first,
      supportingText:
          cover.lifecycleState == InnerCoverLifecycleState.retiredForSalvage
          ? 'The retirement record remains visible. Fresh inspection and acceptance are required before this cover can be linked again.'
          : null,
      requireHistoricalRetirementCondition:
          cover.lifecycleState == InnerCoverLifecycleState.retiredForSalvage &&
          cover.retirementCondition == null,
    ),
  );
  if (result == null || !context.mounted) return;
  final succeeded = await _runCommand(context, () async {
    final repository = ref.read(assetHierarchyRepositoryProvider);
    await ref
        .read(innerCoverLifecycleSubmissionControllerProvider)
        .submit(
          originActorUid: user.uid,
          request: repository.newInnerCoverLifecycleRequest(
            operation: 'SET_INNER_COVER_STATE',
            innerCoverId: cover.id,
            expectedVersion: cover.version,
            fields: {
              'targetState': result.state.name,
              if (result.retirementCondition != null)
                'retirementCondition': result.retirementCondition!.name,
              'physicalEventAt': commandUtcMillis(result.physicalEventAt),
              'reason': result.reason,
            },
          ),
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
