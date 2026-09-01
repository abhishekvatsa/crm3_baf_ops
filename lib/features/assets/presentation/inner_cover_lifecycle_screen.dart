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
import '../data/inner_cover_lifecycle.dart';
import 'widgets/inner_cover_registration_date_field.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../repositories/asset_hierarchy_repository.dart';

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
                ),
      ),
    );
  }
}

class _LifecycleBody extends ConsumerWidget {
  final AppUser? user;
  final List<InnerCoverProfile> profiles;
  final List<BaseInnerCoverAssignment> assignments;
  final List<AssetClassRecord> assetClasses;
  final List<AssetInstanceRecord> assets;

  const _LifecycleBody({
    required this.user,
    required this.profiles,
    required this.assignments,
    required this.assetClasses,
    required this.assets,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final pool =
        profiles.where((profile) => !profile.isInstalled).toList()
          ..sort(_poolSort);
    final canManage = user?.canManageAssetHierarchy == true;

    return Column(
      children: [
        _SummaryBand(profiles: profiles, baseCount: bases.length),
        Expanded(
          child: TabBarView(
            children: [
              _BaseList(
                bases: bases,
                assignmentByBase: assignmentByBase,
                profileById: profileById,
                allProfiles: profiles,
                canManage: canManage,
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
                canManage: canManage,
                onOpen:
                    (cover) => _showCoverDetails(
                      context,
                      ref,
                      cover,
                      assignmentByBase,
                      user,
                    ),
              ),
              _CoverList(
                profiles: profiles,
                emptyMessage: 'No Inner Covers have been registered.',
                canManage: canManage,
                onOpen:
                    (cover) => _showCoverDetails(
                      context,
                      ref,
                      cover,
                      assignmentByBase,
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
  return state != 0
      ? state
      : left.normalizedSerialNumber.compareTo(right.normalizedSerialNumber);
}

class _SummaryBand extends StatelessWidget {
  final List<InnerCoverProfile> profiles;
  final int baseCount;

  const _SummaryBand({required this.profiles, required this.baseCount});

  @override
  Widget build(BuildContext context) {
    final installed = profiles.where((item) => item.isInstalled).length;
    final available = profiles.where((item) => item.isAvailable).length;
    final attention =
        profiles
            .where(
              (item) => const {
                InnerCoverLifecycleState.awaitingInspection,
                InnerCoverLifecycleState.underInspection,
                InnerCoverLifecycleState.underRepair,
                InnerCoverLifecycleState.quarantined,
                InnerCoverLifecycleState.rejected,
              }.contains(item.lifecycleState),
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
              StatusBadge(label: '$baseCount Bases', color: BafColors.assets),
              StatusBadge(
                label: '$installed installed',
                color: BafColors.success,
              ),
              StatusBadge(
                label: '$available available',
                color: BafColors.planned,
              ),
              StatusBadge(
                label: '$attention need attention',
                color:
                    attention == 0
                        ? BafColors.textSecondary
                        : BafColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaseList extends StatelessWidget {
  final List<AssetInstanceRecord> bases;
  final Map<String, BaseInnerCoverAssignment> assignmentByBase;
  final Map<String, InnerCoverProfile> profileById;
  final List<InnerCoverProfile> allProfiles;
  final bool canManage;
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
    required this.allProfiles,
    required this.canManage,
    required this.onDelink,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    if (bases.isEmpty) {
      return const _EmptyState(
        icon: Icons.foundation_outlined,
        message: 'Register governed Base assets before pairing Inner Covers.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(BafSpacing.lg),
      itemCount: bases.length,
      separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.sm),
      itemBuilder: (context, index) {
        final base = bases[index];
        final assignment = assignmentByBase[base.id];
        final profile =
            assignment == null ? null : profileById[assignment.innerCoverId];
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BafSpacing.lg,
              vertical: BafSpacing.sm,
            ),
            leading: CircleAvatar(
              backgroundColor: BafColors.assets.withValues(alpha: 0.12),
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
                      assignment == null ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ),
            trailing:
                canManage && !drift
                    ? assignment == null
                        ? IconButton(
                          tooltip: 'Link Inner Cover',
                          onPressed: () => onManage(base, assignment),
                          icon: const Icon(Icons.link_rounded),
                        )
                        : SizedBox(
                          width: 96,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Delink Inner Cover from Base',
                                onPressed: () => onDelink(assignment, profile!),
                                icon: const Icon(Icons.link_off_rounded),
                              ),
                              IconButton(
                                tooltip: 'Change Inner Cover',
                                onPressed: () => onManage(base, assignment),
                                icon: const Icon(Icons.swap_horiz_rounded),
                              ),
                            ],
                          ),
                        )
                    : null,
          ),
        );
      },
    );
  }
}

class _CoverList extends StatelessWidget {
  final List<InnerCoverProfile> profiles;
  final String emptyMessage;
  final bool canManage;
  final ValueChanged<InnerCoverProfile> onOpen;

  const _CoverList({
    required this.profiles,
    required this.emptyMessage,
    required this.canManage,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return _EmptyState(icon: Icons.layers_outlined, message: emptyMessage);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(BafSpacing.lg),
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.sm),
      itemBuilder: (context, index) {
        final cover = profiles[index];
        return Material(
          color: BafColors.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: BafColors.border),
            borderRadius: BorderRadius.circular(BafRadius.medium),
          ),
          child: ListTile(
            onTap: () => onOpen(cover),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: BafSpacing.lg,
              vertical: BafSpacing.sm,
            ),
            leading: Icon(
              cover.isInstalled ? Icons.link_rounded : Icons.layers_outlined,
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
                ].join('\n'),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        );
      },
    );
  }
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
  AppUser? user,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (sheetContext) => _CoverDetailsSheet(
          cover: cover,
          canManage: user?.canManageAssetHierarchy == true,
          onAccept: () => _acceptCover(sheetContext, ref, cover, user!),
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
          title: 'Change lifecycle state',
          states: states,
          initialState: states.first,
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

class _CoverDetailsSheet extends ConsumerWidget {
  final InnerCoverProfile cover;
  final bool canManage;
  final VoidCallback onAccept;
  final VoidCallback onDelink;
  final VoidCallback onState;

  const _CoverDetailsSheet({
    required this.cover,
    required this.canManage,
    required this.onAccept,
    required this.onDelink,
    required this.onState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(innerCoverHistoryProvider(cover.id));
    final fabrication = ref.watch(innerCoverFabricationProvider(cover.id));
    final date = DateFormat('dd MMM yyyy, HH:mm');
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.xl,
            BafSpacing.sm,
            BafSpacing.xl,
            BafSpacing.xl,
          ),
          children: [
            Text(
              cover.serialNumber,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: BafColors.textPrimary,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                StatusBadge(
                  label: cover.lifecycleState.label,
                  color: _stateColor(cover.lifecycleState),
                ),
                StatusBadge(
                  label: cover.traceabilityGrade.label,
                  color: BafColors.audit,
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            _DetailRow(
              label: 'Origin',
              value: cover.originClassification.label,
            ),
            if (cover.receivedOrCompletedOn != null)
              _DetailRow(
                label: cover.sourceType.receiptOrCompletionDateLabel,
                value: _formatInnerCoverDate(cover.receivedOrCompletedOn!),
              ),
            if (cover.incorporatedOn != null)
              _DetailRow(
                label: 'Date incorporated',
                value: _formatInnerCoverDate(cover.incorporatedOn!),
              ),
            if (cover.supplierOrFabricator != null)
              _DetailRow(
                label: 'Supplier / fabricator',
                value: cover.supplierOrFabricator!,
              ),
            if (cover.currentBaseAssetNumber != null)
              _DetailRow(
                label: 'Current position',
                value: 'Base ${cover.currentBaseAssetNumber}',
              ),
            if (cover.retirementCondition != null)
              _DetailRow(
                label: 'Retirement condition',
                value: cover.retirementCondition!.label,
              ),
            if (cover.drawingReference != null)
              _DetailRow(label: 'Drawing', value: cover.drawingReference!),
            if (cover.materialGrade != null)
              _DetailRow(label: 'Material', value: cover.materialGrade!),
            if (cover.acceptanceReference != null)
              _DetailRow(
                label: 'Acceptance',
                value: cover.acceptanceReference!,
              ),
            if (canManage) ...[
              const SizedBox(height: BafSpacing.lg),
              Wrap(
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.sm,
                children: [
                  if (const {
                    InnerCoverLifecycleState.awaitingInspection,
                    InnerCoverLifecycleState.underInspection,
                  }.contains(cover.lifecycleState))
                    FilledButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Accept'),
                    ),
                  if (cover.isInstalled)
                    OutlinedButton.icon(
                      onPressed: onDelink,
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Delink from Base'),
                    ),
                  if (!cover.isInstalled &&
                      cover.lifecycleState != InnerCoverLifecycleState.disposed)
                    OutlinedButton.icon(
                      onPressed: onState,
                      icon: const Icon(Icons.sync_alt_rounded),
                      label: const Text('Change state'),
                    ),
                ],
              ),
            ],
            fabrication.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _InlineError(message: '$error'),
              data:
                  (dossier) =>
                      dossier == null
                          ? const SizedBox.shrink()
                          : _FabricationSection(dossier: dossier),
            ),
            const SizedBox(height: BafSpacing.xl),
            const Text(
              'Base history',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: BafSpacing.sm),
            history.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _InlineError(message: '$error'),
              data:
                  (items) =>
                      items.isEmpty
                          ? const Text(
                            'This cover has not yet been linked to a Base.',
                            style: TextStyle(color: BafColors.textSecondary),
                          )
                          : Column(
                            children:
                                items
                                    .map(
                                      (item) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          item.active
                                              ? Icons.link_rounded
                                              : Icons.history_rounded,
                                          color:
                                              item.active
                                                  ? BafColors.success
                                                  : BafColors.textSecondary,
                                        ),
                                        title: Text(
                                          'Base ${item.baseAssetNumber}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          item.active
                                              ? 'Paired ${date.format(item.installedAt.toLocal())}'
                                              : 'Paired ${date.format(item.installedAt.toLocal())} – removed ${date.format(item.removedAt!.toLocal())}\n${item.removalReason}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _FabricationSection extends StatelessWidget {
  final InnerCoverFabricationDossier dossier;

  const _FabricationSection({required this.dossier});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BafSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fabrication genealogy',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: BafSpacing.sm),
        ...dossier.sections.map(
          (section) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(section.type.label),
            subtitle: Text(
              [
                section.materialSource.label,
                if (section.donorInnerCoverId != null)
                  'Donor ${section.donorInnerCoverId} / ${section.donorSectionKey}',
                if (section.lengthMm != null) '${section.lengthMm} mm',
                '${section.cutCount} cut${section.cutCount == 1 ? '' : 's'}',
              ].join(' · '),
            ),
          ),
        ),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BafSpacing.md),
    child: Text(message, style: const TextStyle(color: BafColors.danger)),
  );
}

class _PairingSelection {
  final InnerCoverProfile cover;
  final String reason;

  const _PairingSelection({required this.cover, required this.reason});
}

class _PairingDialog extends StatefulWidget {
  final AssetInstanceRecord base;
  final BaseInnerCoverAssignment? current;
  final List<InnerCoverProfile> candidates;

  const _PairingDialog({
    required this.base,
    required this.current,
    required this.candidates,
  });

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  late InnerCoverProfile _selected = widget.candidates.first;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.current == null
            ? 'Link to Base ${widget.base.assetNumber}'
            : 'Change cover on Base ${widget.base.assetNumber}';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<InnerCoverProfile>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Inner Cover'),
              items:
                  widget.candidates
                      .map(
                        (cover) => DropdownMenuItem(
                          value: cover,
                          child: Text(
                            cover.isInstalled
                                ? '${cover.serialNumber} · Base ${cover.currentBaseAssetNumber}'
                                : '${cover.serialNumber} · available',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  (value) => setState(() => _selected = value ?? _selected),
            ),
            const SizedBox(height: BafSpacing.md),
            if (_selected.isInstalled)
              const Padding(
                padding: EdgeInsets.only(bottom: BafSpacing.md),
                child: Text(
                  'This serial is already linked to another Base. Confirming will transfer it or swap both installed covers atomically.',
                  style: TextStyle(color: BafColors.warning),
                ),
              ),
            TextField(
              controller: _reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                alignLabelWithHint: true,
              ),
            ),
          ],
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
            if (reason.isEmpty) return;
            Navigator.pop(
              context,
              _PairingSelection(cover: _selected, reason: reason),
            );
          },
          child: Text(widget.current == null ? 'Link' : 'Confirm change'),
        ),
      ],
    );
  }
}

class _StateReasonResult {
  final InnerCoverLifecycleState state;
  final InnerCoverRetirementCondition? retirementCondition;
  final String reason;

  const _StateReasonResult({
    required this.state,
    required this.retirementCondition,
    required this.reason,
  });
}

class _StateReasonDialog extends StatefulWidget {
  final String title;
  final List<InnerCoverLifecycleState> states;
  final InnerCoverLifecycleState initialState;

  const _StateReasonDialog({
    required this.title,
    required this.states,
    required this.initialState,
  });

  @override
  State<_StateReasonDialog> createState() => _StateReasonDialogState();
}

class _StateReasonDialogState extends State<_StateReasonDialog> {
  late InnerCoverLifecycleState _state = widget.initialState;
  InnerCoverRetirementCondition? _retirementCondition;
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<InnerCoverLifecycleState>(
            initialValue: _state,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Resulting state'),
            items:
                widget.states
                    .map(
                      (state) => DropdownMenuItem(
                        value: state,
                        child: Text(state.label),
                      ),
                    )
                    .toList(),
            onChanged:
                (value) => setState(() {
                  _state = value ?? _state;
                  if (_state != InnerCoverLifecycleState.retiredForSalvage) {
                    _retirementCondition = null;
                  }
                }),
          ),
          if (_state == InnerCoverLifecycleState.retiredForSalvage) ...[
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<InnerCoverRetirementCondition>(
              initialValue: _retirementCondition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Condition at retirement',
              ),
              items: [
                for (final condition in InnerCoverRetirementCondition.values)
                  DropdownMenuItem(
                    value: condition,
                    child: Text(condition.label),
                  ),
              ],
              onChanged:
                  (value) => setState(() => _retirementCondition = value),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              alignLabelWithHint: true,
            ),
          ),
        ],
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
          if (reason.isEmpty) return;
          if (_state == InnerCoverLifecycleState.retiredForSalvage &&
              _retirementCondition == null) {
            return;
          }
          Navigator.pop(
            context,
            _StateReasonResult(
              state: _state,
              retirementCondition: _retirementCondition,
              reason: reason,
            ),
          );
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

class _AcceptanceResult {
  final DateTime inspectedOn;
  final String acceptanceReference;
  final String? leakTestReference;
  final String? ndtReference;
  final String? notes;
  final String reason;

  const _AcceptanceResult({
    required this.inspectedOn,
    required this.acceptanceReference,
    this.leakTestReference,
    this.ndtReference,
    this.notes,
    required this.reason,
  });
}

class _AcceptanceDialog extends StatefulWidget {
  const _AcceptanceDialog();

  @override
  State<_AcceptanceDialog> createState() => _AcceptanceDialogState();
}

class _AcceptanceDialogState extends State<_AcceptanceDialog> {
  final _acceptance = TextEditingController();
  final _leak = TextEditingController();
  final _ndt = TextEditingController();
  final _notes = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _acceptance.dispose();
    _leak.dispose();
    _ndt.dispose();
    _notes.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Accept Inner Cover'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _acceptance,
              decoration: const InputDecoration(
                labelText: 'Acceptance reference',
              ),
            ),
            TextField(
              controller: _leak,
              decoration: const InputDecoration(
                labelText: 'Leak-test reference',
              ),
            ),
            TextField(
              controller: _ndt,
              decoration: const InputDecoration(labelText: 'NDT reference'),
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Inspection notes'),
            ),
            TextField(
              controller: _reason,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Acceptance reason'),
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
      FilledButton(
        onPressed: () {
          if (_acceptance.text.trim().isEmpty || _reason.text.trim().isEmpty) {
            return;
          }
          String? optional(TextEditingController controller) {
            final value = controller.text.trim();
            return value.isEmpty ? null : value;
          }

          Navigator.pop(
            context,
            _AcceptanceResult(
              inspectedOn: DateTime.now(),
              acceptanceReference: _acceptance.text.trim(),
              leakTestReference: optional(_leak),
              ndtReference: optional(_ndt),
              notes: optional(_notes),
              reason: _reason.text.trim(),
            ),
          );
        },
        child: const Text('Accept'),
      ),
    ],
  );
}

class _RegistrationResult {
  final String serialNumber;
  final InnerCoverSourceType sourceType;
  final InnerCoverOriginClassification originClassification;
  final String? supplierOrFabricator;
  final DateTime? receivedOrCompletedOn;
  final DateTime? incorporatedOn;
  final String? drawingReference;
  final String? materialGrade;
  final String? notes;
  final String reason;
  final List<InnerCoverFabricationSectionDraft> sections;

  const _RegistrationResult({
    required this.serialNumber,
    required this.sourceType,
    required this.originClassification,
    this.supplierOrFabricator,
    this.receivedOrCompletedOn,
    this.incorporatedOn,
    this.drawingReference,
    this.materialGrade,
    this.notes,
    required this.reason,
    required this.sections,
  });
}

class _RegistrationDialog extends StatefulWidget {
  final List<InnerCoverProfile> profiles;

  const _RegistrationDialog({required this.profiles});

  @override
  State<_RegistrationDialog> createState() => _RegistrationDialogState();
}

class _RegistrationDialogState extends State<_RegistrationDialog> {
  final _serial = TextEditingController();
  final _supplier = TextEditingController();
  final _drawing = TextEditingController();
  final _material = TextEditingController();
  final _notes = TextEditingController();
  final _reason = TextEditingController();
  String? _serialError;
  String? _reasonError;
  String? _sectionsError;
  String? _dateError;
  InnerCoverOriginClassification _origin =
      InnerCoverOriginClassification.documentedPurchase;
  DateTime? _receivedOrCompletedOn;
  DateTime? _incorporatedOn;
  late final Map<InnerCoverFabricationSectionType, _SectionEditorState>
  _sections = {
    for (final type in const [
      InnerCoverFabricationSectionType.lowerAssembly,
      InnerCoverFabricationSectionType.flatVertical,
      InnerCoverFabricationSectionType.corrugatedShell,
      InnerCoverFabricationSectionType.topCover,
    ])
      type: _SectionEditorState(type),
  };

  @override
  void dispose() {
    _serial.dispose();
    _supplier.dispose();
    _drawing.dispose();
    _material.dispose();
    _notes.dispose();
    _reason.dispose();
    for (final state in _sections.values) {
      state.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final donors =
        widget.profiles
            .where(
              (cover) => const {
                InnerCoverLifecycleState.retiredForSalvage,
                InnerCoverLifecycleState.partiallyDismantled,
              }.contains(cover.lifecycleState),
            )
            .toList();
    return AlertDialog(
      title: const Text('Register Inner Cover'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serial,
                textCapitalization: TextCapitalization.characters,
                onChanged:
                    (_) => setState(() {
                      _serialError = null;
                    }),
                decoration: InputDecoration(
                  labelText: 'Serial number',
                  errorText: _serialError,
                ),
              ),
              DropdownButtonFormField<InnerCoverOriginClassification>(
                initialValue: _origin,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Origin'),
                items:
                    InnerCoverOriginClassification.values
                        .map(
                          (origin) => DropdownMenuItem(
                            value: origin,
                            child: Text(origin.label),
                          ),
                        )
                        .toList(),
                onChanged:
                    (value) => setState(() {
                      final nextOrigin = value ?? _origin;
                      final sourceChanged =
                          _sourceTypeForOrigin(nextOrigin) != _sourceType;
                      _origin = nextOrigin;
                      if (sourceChanged) _receivedOrCompletedOn = null;
                      if (_origin ==
                          InnerCoverOriginClassification
                              .ownerDeclaredFabricated) {
                        for (final state in _sections.values) {
                          state.markAncestryUnknown();
                        }
                      } else if (_origin ==
                          InnerCoverOriginClassification
                              .documentedFabrication) {
                        for (final state in _sections.values) {
                          state.markNewFabricated();
                        }
                      }
                      _sectionsError = null;
                      _dateError = null;
                    }),
              ),
              const SizedBox(height: BafSpacing.sm),
              InnerCoverRegistrationDateField(
                label: _sourceType.receiptOrCompletionDateLabel,
                helperText: _sourceType.receiptOrCompletionDateHelp,
                value: _receivedOrCompletedOn,
                clearTooltip: 'Clear historical date',
                chooseTooltip: 'Choose historical date',
                onClear:
                    () => setState(() {
                      _receivedOrCompletedOn = null;
                      _dateError = null;
                    }),
                onChoose: _pickReceivedOrCompletedDate,
              ),
              InnerCoverRegistrationDateField(
                label: 'Date incorporated',
                helperText: 'Optional plant incorporation date',
                value: _incorporatedOn,
                errorText: _dateError,
                clearTooltip: 'Clear incorporation date',
                chooseTooltip: 'Choose incorporation date',
                onClear:
                    () => setState(() {
                      _incorporatedOn = null;
                      _dateError = null;
                    }),
                onChoose: _pickIncorporationDate,
              ),
              TextField(
                controller: _supplier,
                decoration: const InputDecoration(
                  labelText: 'Supplier / fabricator',
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _drawing,
                      decoration: const InputDecoration(
                        labelText: 'Drawing reference',
                      ),
                    ),
                  ),
                  const SizedBox(width: BafSpacing.md),
                  Expanded(
                    child: TextField(
                      controller: _material,
                      decoration: const InputDecoration(
                        labelText: 'Material grade',
                      ),
                    ),
                  ),
                ],
              ),
              if (_isFabricatedOrigin) ...[
                const SizedBox(height: BafSpacing.lg),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Fabrication sections',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                ..._sections.values.map(
                  (state) => _FabricationSectionEditor(
                    state: state,
                    donors: donors,
                    onChanged:
                        () => setState(() {
                          _sectionsError = null;
                        }),
                  ),
                ),
                if (_sectionsError != null) ...[
                  const SizedBox(height: BafSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _sectionsError!,
                      style: const TextStyle(
                        color: BafColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Registration notes',
                ),
              ),
              TextField(
                controller: _reason,
                maxLines: 2,
                onChanged:
                    (_) => setState(() {
                      _reasonError = null;
                    }),
                decoration: InputDecoration(
                  labelText: 'Registration reason',
                  errorText: _reasonError,
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
        FilledButton(onPressed: _submit, child: const Text('Register')),
      ],
    );
  }

  void _submit() {
    final serial = _serial.text.trim();
    final reason = _reason.text.trim();
    String? optional(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    final sections =
        _isFabricatedOrigin
            ? _sections.values.map((state) => state.toDraft()).toList()
            : const <InnerCoverFabricationSectionDraft>[];
    final sectionErrors = sections
        .expand((section) => section.validate())
        .toList(growable: false);
    final serialError =
        normalizeInnerCoverSerial(serial).length < 2
            ? 'Enter an Inner Cover serial number.'
            : null;
    final reasonError = reason.isEmpty ? 'Explain the registration.' : null;
    final dateError = innerCoverRegistrationChronologyError(
      receivedOrCompletedOn: _receivedOrCompletedOn,
      incorporatedOn: _incorporatedOn,
    );
    if (serialError != null ||
        reasonError != null ||
        sectionErrors.isNotEmpty ||
        dateError != null) {
      setState(() {
        _serialError = serialError;
        _reasonError = reasonError;
        _dateError = dateError;
        _sectionsError =
            sectionErrors.isEmpty
                ? null
                : 'Complete the fabrication evidence: ${sectionErrors.first}';
      });
      return;
    }
    Navigator.pop(
      context,
      _RegistrationResult(
        serialNumber: serial,
        sourceType: _sourceType,
        originClassification: _origin,
        supplierOrFabricator: optional(_supplier),
        receivedOrCompletedOn: _receivedOrCompletedOn,
        incorporatedOn: _incorporatedOn,
        drawingReference: optional(_drawing),
        materialGrade: optional(_material),
        notes: optional(_notes),
        reason: reason,
        sections: sections,
      ),
    );
  }

  Future<void> _pickReceivedOrCompletedDate() async {
    final now = DateTime.now();
    final current = _receivedOrCompletedOn?.toLocal() ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: _sourceType.receiptOrCompletionDateLabel,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _receivedOrCompletedOn = innerCoverRegistrationInstantForLocalDate(
        selected,
      );
      _dateError = null;
    });
  }

  Future<void> _pickIncorporationDate() async {
    final now = DateTime.now();
    final current = _incorporatedOn?.toLocal() ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Date incorporated',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _incorporatedOn = innerCoverIncorporationInstantForLocalDate(selected);
      _dateError = null;
    });
  }

  bool get _isFabricatedOrigin => const {
    InnerCoverOriginClassification.documentedFabrication,
    InnerCoverOriginClassification.ownerDeclaredFabricated,
  }.contains(_origin);

  InnerCoverSourceType get _sourceType => _sourceTypeForOrigin(_origin);
}

InnerCoverSourceType _sourceTypeForOrigin(
  InnerCoverOriginClassification origin,
) => switch (origin) {
  InnerCoverOriginClassification.documentedPurchase =>
    InnerCoverSourceType.purchased,
  InnerCoverOriginClassification.documentedFabrication ||
  InnerCoverOriginClassification
      .ownerDeclaredFabricated => InnerCoverSourceType.fabricated,
  InnerCoverOriginClassification.ownerDeclaredNew ||
  InnerCoverOriginClassification
      .legacyUndocumented => InnerCoverSourceType.legacyExisting,
};

class _SectionEditorState {
  final InnerCoverFabricationSectionType type;
  InnerCoverSectionMaterialSource source =
      InnerCoverSectionMaterialSource.newFabricated;
  InnerCoverProfile? donor;
  final donorKey = TextEditingController();
  final length = TextEditingController();
  final cuts = TextEditingController(text: '1');
  final notes = TextEditingController();

  _SectionEditorState(this.type);

  void markAncestryUnknown() {
    source = InnerCoverSectionMaterialSource.reusedUnknownLegacyDonor;
    donor = null;
    donorKey.clear();
  }

  void markNewFabricated() {
    source = InnerCoverSectionMaterialSource.newFabricated;
    donor = null;
    donorKey.clear();
  }

  InnerCoverFabricationSectionDraft toDraft() =>
      InnerCoverFabricationSectionDraft(
        type: type,
        materialSource: source,
        donor: donor,
        donorSectionKey:
            donorKey.text.trim().isEmpty ? null : donorKey.text.trim(),
        lengthMm: double.tryParse(length.text.trim()),
        cutCount: int.tryParse(cuts.text.trim()) ?? 1,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );

  void dispose() {
    donorKey.dispose();
    length.dispose();
    cuts.dispose();
    notes.dispose();
  }
}

class _FabricationSectionEditor extends StatelessWidget {
  final _SectionEditorState state;
  final List<InnerCoverProfile> donors;
  final VoidCallback onChanged;

  const _FabricationSectionEditor({
    required this.state,
    required this.donors,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final known =
        state.source == InnerCoverSectionMaterialSource.reusedKnownDonor;
    return Container(
      margin: const EdgeInsets.only(bottom: BafSpacing.sm),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: BafColors.border),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.type.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          DropdownButtonFormField<InnerCoverSectionMaterialSource>(
            initialValue: state.source,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Material source'),
            items:
                InnerCoverSectionMaterialSource.values
                    .map(
                      (source) => DropdownMenuItem(
                        value: source,
                        child: Text(source.label),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              state.source = value ?? state.source;
              if (state.source !=
                  InnerCoverSectionMaterialSource.reusedKnownDonor) {
                state.donor = null;
                state.donorKey.clear();
              }
              onChanged();
            },
          ),
          if (known) ...[
            DropdownButtonFormField<InnerCoverProfile>(
              initialValue: state.donor,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Known donor'),
              items:
                  donors
                      .map(
                        (donor) => DropdownMenuItem(
                          value: donor,
                          child: Text(donor.serialNumber),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                state.donor = value;
                onChanged();
              },
            ),
            TextField(
              controller: state.donorKey,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Donor section / cut ID',
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: state.length,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Length (mm)'),
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: TextField(
                  controller: state.cuts,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  decoration: const InputDecoration(labelText: 'Cuts used'),
                ),
              ),
            ],
          ),
          TextField(
            controller: state.notes,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(labelText: 'Section notes'),
          ),
        ],
      ),
    );
  }
}
