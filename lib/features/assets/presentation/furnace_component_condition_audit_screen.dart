import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'burner_saved_submissions_panel.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../data/asset_hierarchy_model.dart';
import '../data/asset_registry_model.dart';
import '../data/burner_block_condition_projection.dart';
import '../domain/furnace_audit_draft.dart';
import '../data/burner_block_lifecycle_event.dart';
import '../data/burner_condition_round.dart';
import '../data/uv_detector_lifecycle_event.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../providers/burner_block_lifecycle_provider.dart';
import '../providers/burner_condition_round_provider.dart';
import '../providers/uv_detector_lifecycle_provider.dart';
import 'widgets/burner_block_correction_controls.dart';
import '../services/burner_condition_round_service.dart';
import 'widgets/uv_detector_lifecycle_list.dart';

part 'furnace_component_condition_audit_screen.totals.dart';
part 'furnace_component_condition_audit_screen.cells.dart';

class FurnaceComponentConditionAuditScreen extends ConsumerStatefulWidget {
  const FurnaceComponentConditionAuditScreen({super.key});

  @override
  ConsumerState<FurnaceComponentConditionAuditScreen> createState() =>
      _FurnaceComponentConditionAuditScreenState();
}

class _FurnaceComponentConditionAuditScreenState
    extends ConsumerState<FurnaceComponentConditionAuditScreen> {
  final Map<String, FurnaceAuditDraft> _drafts = {};
  final Map<String, FurnaceAuditSubmission> _submittedDrafts = {};
  int _savedRefresh = 0;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Furnace condition audit',
        appBarSubtitle: 'Verifying governed access',
        appBarIcon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
        label: 'Checking audit access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Furnace condition audit',
        appBarSubtitle: 'Verifying governed access',
        appBarIcon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
        message: 'Furnace audit access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canRecordBurnerConditionRound) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Furnace condition audit',
        appBarSubtitle: 'Burner blocks, draft seals and UV condition',
        appBarIcon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
        title: 'Audit access required',
        message: 'Approved Operations or I&A access is required.',
      );
    }

    final classesAsync = ref.watch(assetClassesProvider);
    final assetsAsync = ref.watch(allAssetInstancesProvider);
    final lifecycleAsync = ref.watch(
      burnerBlockLifecycleEventsProvider(actor.uid),
    );
    final lifecycleCurrentAsync = ref.watch(
      burnerBlockLifecycleCurrentProvider(actor.uid),
    );
    final uvLifecycleAsync = ref.watch(
      uvDetectorLifecycleEventsProvider(actor.uid),
    );
    final uvLifecycleCurrentAsync = ref.watch(
      uvDetectorLifecycleCurrentProvider(actor.uid),
    );
    final ticketsAsync = ref.watch(plantConditionTicketsProvider);
    final loading = <AsyncValue<Object?>>[
      classesAsync,
      assetsAsync,
      lifecycleAsync,
      lifecycleCurrentAsync,
      uvLifecycleAsync,
      uvLifecycleCurrentAsync,
      ticketsAsync,
    ].any((value) => value.isLoading);
    final error = <AsyncValue<Object?>>[
      classesAsync,
      assetsAsync,
      lifecycleAsync,
      lifecycleCurrentAsync,
      uvLifecycleAsync,
      uvLifecycleCurrentAsync,
      ticketsAsync,
    ].where((value) => value.hasError).firstOrNull;
    if (loading) {
      return _shell(
        const BafLoadingPanel(label: 'Loading furnace condition authority'),
      );
    }
    if (error != null) {
      return _shell(
        BafStatePanel.error(
          message: 'The complete furnace condition view could not be verified.',
          onPrimary: () {
            ref.invalidate(assetClassesProvider);
            ref.invalidate(allAssetInstancesProvider);
            ref.invalidate(latestBurnerConditionRoundsProvider);
            ref.invalidate(burnerBlockLifecycleEventsProvider(actor.uid));
            ref.invalidate(burnerBlockLifecycleCurrentProvider(actor.uid));
            ref.invalidate(uvDetectorLifecycleEventsProvider(actor.uid));
            ref.invalidate(uvDetectorLifecycleCurrentProvider(actor.uid));
            ref.invalidate(plantConditionTicketsProvider);
          },
        ),
      );
    }

    final classes = classesAsync.value ?? const <AssetClassRecord>[];
    final furnaceClasses = classes
        .where(
          (item) =>
              item.isActive &&
              item.legacyAssetTypeKey == AssetType.furnace.name,
        )
        .toList(growable: false);
    if (furnaceClasses.length != 1) {
      return _shell(
        const Center(
          child: Text('Exactly one active Furnace class is required.'),
        ),
      );
    }
    final furnaceClass = furnaceClasses.single;
    final furnaces =
        (assetsAsync.value ?? const <AssetInstanceRecord>[])
            .where(
              (asset) =>
                  asset.assetClassId == furnaceClass.id &&
                  asset.isActive &&
                  asset.assetNumber >= 1 &&
                  asset.assetNumber <= 26,
            )
            .toList()
          ..sort(
            (left, right) => left.assetNumber.compareTo(right.assetNumber),
          );
    final latestQuery = LatestBurnerConditionRoundsQuery(
      actorUid: actor.uid,
      assetInstanceIds: furnaces.map((furnace) => furnace.id),
    );
    final latestAsync = ref.watch(
      latestBurnerConditionRoundsProvider(latestQuery),
    );
    if (latestAsync.isLoading) {
      return _shell(
        const BafLoadingPanel(label: 'Resolving current furnace conditions'),
      );
    }
    if (latestAsync.hasError) {
      return _shell(
        BafStatePanel.error(
          message: 'Current furnace condition authority could not be verified.',
          onPrimary: () =>
              ref.invalidate(latestBurnerConditionRoundsProvider(latestQuery)),
        ),
      );
    }
    final latest = latestAsync.value ?? const <String, BurnerConditionRound>{};
    final lifecycleEvents =
        lifecycleAsync.value ?? const <BurnerBlockLifecycleEvent>[];
    final lifecycleCurrent =
        lifecycleCurrentAsync.value ?? const <BurnerBlockLifecycleEvent>[];
    final uvLifecycleEvents =
        uvLifecycleAsync.value ?? const <UvDetectorLifecycleEvent>[];
    final uvLifecycleCurrent =
        uvLifecycleCurrentAsync.value ?? const <UvDetectorLifecycleEvent>[];
    final tickets = ticketsAsync.value ?? const <MaintenanceRecord>[];

    try {
      for (final furnace in furnaces) {
        final round = latest[furnace.id];
        final issueEvidence = FurnaceAuditIssueEvidence.fromTickets(
          tickets: tickets,
          furnace: furnace,
          assetClasses: classes,
          assets: assetsAsync.value!,
          round: round,
        );
        final conditionProjection = projectBurnerBlockCondition(
          round: round,
          newerRedHotObservations: issueEvidence.newerRedHotObservations,
          lifecycleEvents: lifecycleEvents,
          currentLifecycleEvents: lifecycleCurrent,
          uvLifecycleEvents: uvLifecycleEvents,
          currentUvLifecycleEvents: uvLifecycleCurrent,
          currentCollectionsAuthoritative: true,
          assetInstanceId: furnace.id,
        );
        final current = _drafts[furnace.id];
        final fresh = FurnaceAuditDraft.fromSources(
          round: round,
          conditionProjection: conditionProjection,
          openIssueBasis: issueEvidence.basis,
        );
        if (current == null) {
          _drafts[furnace.id] = fresh;
        } else {
          current.updateBasis(
            fresh,
            roundId: round?.roundId,
            observedAt: round?.observedAt,
          );
        }
      }
    } on FormatException catch (formatError) {
      return _shell(
        BafStatePanel.error(
          message:
              'Burner-lockout evidence needs repair: ${formatError.message}',
          onPrimary: () => ref.invalidate(plantConditionTicketsProvider),
        ),
      );
    }

    final dirtyCount = furnaces
        .where((furnace) => _drafts[furnace.id]?.dirty == true)
        .length;
    final totals = _FurnaceAuditTotals(
      furnaces.map((furnace) => _drafts[furnace.id]!),
    );
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Furnace condition audit',
            subtitle: 'Burner blocks, draft seals and UV condition',
            icon: Icons.grid_on_rounded,
            accent: BafColors.maintenance,
          ),
          actions: [
            IconButton(
              tooltip: 'Condition totals',
              onPressed: () => _showConditionTotals(context, totals),
              icon: const Icon(Icons.summarize_outlined),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Burner blocks (${totals.redHotBlocks})'),
              Tab(text: 'Draft seal (${totals.draftSealFindings})'),
              Tab(
                text: 'UV melted (${totals.uvCount(BurnerUvCondition.melted)})',
              ),
              Tab(
                text:
                    'UV missing (${totals.uvCount(BurnerUvCondition.missing)})',
              ),
              Tab(
                text: 'UV hung (${totals.uvCount(BurnerUvCondition.hanging)})',
              ),
              Tab(text: 'Block lifecycle (${lifecycleEvents.length})'),
              Tab(text: 'UV lifecycle (${uvLifecycleEvents.length})'),
            ],
          ),
        ),
        body: Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .3,
              ),
              child: SingleChildScrollView(
                child: BurnerSavedSubmissionsPanel(
                  key: ValueKey('audit-saved-${actor.uid}'),
                  service: ref.read(burnerConditionRoundServiceProvider),
                  actorUid: actor.uid,
                  refreshKey: _savedRefresh,
                  onLoaded: (_) {},
                  onCheck: (row) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final result = await ref
                          .read(burnerConditionRoundServiceProvider)
                          .resumeRound(row);
                      if (!mounted) return;
                      final submitted = _submittedDrafts.remove(
                        row.aggregateId,
                      );
                      if (submitted != null) {
                        _drafts[row.aggregateId]?.acceptSubmission(
                          submitted,
                          result.roundId,
                          result.committedAt,
                        );
                      }
                      ref.invalidate(latestBurnerConditionRoundsProvider);
                      if (mounted) setState(() => _savedRefresh++);
                    } catch (error) {
                      if (!mounted) return;
                      if (error is BurnerConditionRoundException &&
                          error.definitiveRefusal) {
                        _submittedDrafts.remove(row.aggregateId);
                        _drafts[row.aggregateId]?.requiresReview = true;
                        ref.invalidate(latestBurnerConditionRoundsProvider);
                        ref.invalidate(
                          burnerBlockLifecycleCurrentProvider(actor.uid),
                        );
                        ref.invalidate(
                          uvDetectorLifecycleCurrentProvider(actor.uid),
                        );
                        ref.invalidate(openTicketsProvider);
                      }
                      messenger.showSnackBar(SnackBar(content: Text('$error')));
                    }
                  },
                ),
              ),
            ),
            _AuditStatusBand(
              furnaceCount: furnaces.length,
              dirtyCount: dirtyCount,
              onShowTotals: () => _showConditionTotals(context, totals),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _BurnerBlockMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    onChanged: _markChanged,
                  ),
                  _DraftSealMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    onChanged: _markChanged,
                  ),
                  _UvConditionMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    condition: BurnerUvCondition.melted,
                    onChanged: _markChanged,
                  ),
                  _UvConditionMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    condition: BurnerUvCondition.missing,
                    onChanged: _markChanged,
                  ),
                  _UvConditionMatrix(
                    furnaces: furnaces,
                    drafts: _drafts,
                    condition: BurnerUvCondition.hanging,
                    onChanged: _markChanged,
                  ),
                  _BurnerBlockLifecycleList(
                    events: lifecycleEvents,
                    currentEvents: lifecycleCurrent,
                  ),
                  UvDetectorLifecycleList(events: uvLifecycleEvents),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.sm,
            BafSpacing.lg,
            BafSpacing.md,
          ),
          child: FilledButton.icon(
            onPressed: _saving || dirtyCount == 0
                ? null
                : () => _save(furnaces, actor),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(
              _saving
                  ? 'Recording governed audit...'
                  : 'Record $dirtyCount changed furnace${dirtyCount == 1 ? '' : 's'}',
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _shell(Widget body) => Scaffold(
    backgroundColor: BafColors.background,
    appBar: AppBar(
      title: const BafAppBarTitle(
        title: 'Furnace condition audit',
        subtitle: 'Burner blocks, draft seals and UV condition',
        icon: Icons.grid_on_rounded,
        accent: BafColors.maintenance,
      ),
    ),
    body: body,
  );

  void _markChanged(String assetId, void Function(FurnaceAuditDraft) change) {
    final draft = _drafts[assetId];
    if (draft == null) return;
    setState(() {
      change(draft);
      draft.markEdited();
    });
  }

  Future<void> _save(List<AssetInstanceRecord> furnaces, AppUser actor) async {
    final changed = furnaces
        .where((furnace) => _drafts[furnace.id]?.dirty == true)
        .toList(growable: false);
    if (changed.isEmpty) return;
    setState(() => _saving = true);
    var saved = 0;
    var directives = 0;
    var stillPending = 0;
    String? submittingFurnaceId;
    try {
      final service = ref.read(burnerConditionRoundServiceProvider);
      for (final furnace in changed) {
        if (furnace.serviceState == AssetServiceState.outOfService) {
          throw BurnerConditionRoundException(
            '${furnace.name} is administratively out of service and cannot accept a new audit.',
            code: 'failed-precondition',
          );
        }
        final draft = _drafts[furnace.id]!;
        if (_submittedDrafts.containsKey(furnace.id)) {
          throw const BurnerConditionRoundException(
            'Check the saved original audit before recording the remaining edits. Its outcome is still unconfirmed.',
          );
        }
        if (draft.requiresReview) {
          if (!mounted) return;
          final keep = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Review ${furnace.name} changes'),
              content: Text(
                'Current furnace evidence changed. Your checked fields are retained${draft.conflicts.isEmpty ? '' : ': ${draft.conflicts.join(', ')}'}. Confirm them against the current equipment before recording a new request.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Use current records'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Keep my checked fields'),
                ),
              ],
            ),
          );
          if (keep == null || !mounted) break;
          draft.reviewCurrent(keepLocalEdits: keep);
          if (!draft.dirty) continue;
        }
        if (draft.requiresReview || draft.awaitingAcceptedBasis) {
          throw const BurnerConditionRoundException(
            'Wait for the current furnace evidence before submitting the remaining edits.',
          );
        }
        // What is being recorded is this revision of the draft, read before
        // the request goes out. The controls stay live while it is in flight.
        final submitted = draft.captureSubmission();
        submittingFurnaceId = furnace.id;
        _submittedDrafts[furnace.id] = submitted;
        final submittedObservations = List<BurnerConditionObservation>.of(
          draft.burnerObservations,
        );
        final submittedUvObservations = List<BurnerUvObservation>.of(
          draft.uvObservations,
        );
        final submittedDraftSealRedHot = draft.draftSealRedHotObserved;
        final submittedHotAirAtDraftSeal = draft.hotAirAtDraftSealObserved;
        final result = await service.record(
          furnace: furnace,
          observations: submittedObservations,
          draftSealRedHotObserved: submittedDraftSealRedHot,
          hotAirAtDraftSealObserved: submittedHotAirAtDraftSeal,
          uvObservations: submittedUvObservations,
          actor: actor,
          roundNote: 'Cross-furnace component condition audit.',
          // These eight positions were witnessed against the round this draft
          // was built from. If another operator has recorded one since, the
          // server refuses rather than clearing their work with observations
          // made before it existed.
          composedAgainst: ComposedAgainstRound(draft.composedAgainstRoundId),
          observedFields: submitted.observedFields,
          expectedInstallationBasis: submitted.installationBasis,
          expectedOpenIssueBasis: draft.openIssueBasis,
        );
        saved++;
        if (result.directiveId != null) directives++;
        // An observation recorded while this was in flight was not in the
        // envelope, so the draft stays pending and carries it into the next
        // save instead of being marked recorded and then replaced.
        draft.acceptSubmission(submitted, result.roundId, result.committedAt);
        _submittedDrafts.remove(furnace.id);
        submittingFurnaceId = null;
        if (draft.dirty) stillPending++;
      }
      ref.invalidate(latestBurnerConditionRoundsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$saved furnace audit${saved == 1 ? '' : 's'} recorded. '
            '$directives I&A directive${directives == 1 ? '' : 's'} created.'
            '${stillPending == 0 ? '' : ' $stillPending furnace'
                      '${stillPending == 1 ? '' : 's'} changed while this was '
                      'being recorded and ${stillPending == 1 ? 'is' : 'are'} '
                      'still pending.'}',
          ),
          backgroundColor: BafColors.success,
        ),
      );
      setState(() {});
    } on BurnerConditionRoundException catch (error) {
      if (error.definitiveRefusal) {
        if (submittingFurnaceId != null) {
          _submittedDrafts.remove(submittingFurnaceId);
          _drafts[submittingFurnaceId]?.requiresReview = true;
        }
        ref.invalidate(latestBurnerConditionRoundsProvider);
        ref.invalidate(burnerBlockLifecycleCurrentProvider(actor.uid));
        ref.invalidate(uvDetectorLifecycleCurrentProvider(actor.uid));
        ref.invalidate(openTicketsProvider);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$saved of ${changed.length} audits were committed before the next item stopped: ${error.message}',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _savedRefresh++;
        });
      }
    }
  }
}

class _AuditStatusBand extends StatelessWidget {
  const _AuditStatusBand({
    required this.furnaceCount,
    required this.dirtyCount,
    required this.onShowTotals,
  });

  final int furnaceCount;
  final int dirtyCount;
  final VoidCallback onShowTotals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: BafColors.surfaceTint,
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.lg,
        vertical: BafSpacing.sm,
      ),
      child: Wrap(
        spacing: BafSpacing.sm,
        runSpacing: BafSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$furnaceCount Furnaces', style: const TextStyle(fontSize: 12)),
          Text(
            dirtyCount == 0
                ? 'Recorded conditions'
                : '$dirtyCount unsaved furnace${dirtyCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12),
          ),
          TextButton.icon(
            onPressed: onShowTotals,
            icon: const Icon(Icons.summarize_outlined, size: 18),
            label: const Text('Condition totals'),
          ),
        ],
      ),
    );
  }
}

typedef _DraftChange =
    void Function(String assetId, void Function(FurnaceAuditDraft) change);

class _BurnerBlockLifecycleList extends ConsumerWidget {
  const _BurnerBlockLifecycleList({
    required this.events,
    required this.currentEvents,
  });

  final List<BurnerBlockLifecycleEvent> events;
  final List<BurnerBlockLifecycleEvent> currentEvents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(BafSpacing.xl),
          child: Text(
            'No completed burner-block replacement has been recorded yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BafColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(BafSpacing.lg),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: BafSpacing.sm),
      itemBuilder: (context, index) {
        final event = events[index];
        final current = currentEvents
            .where(
              (candidate) =>
                  candidate.assetInstanceId == event.assetInstanceId &&
                  candidate.burnerPosition == event.burnerPosition,
            )
            .firstOrNull;
        final canCorrect =
            ref
                .watch(currentAppUserProvider)
                .valueOrNull
                ?.canAdjudicateFurnaceStuckup ==
            true;
        final sourceLabel = switch (event.sourceType) {
          BurnerBlockLifecycleSourceType.maintenanceIssue => 'Issue resolution',
          BurnerBlockLifecycleSourceType.legacyPlannedJob =>
            'Planned maintenance',
          BurnerBlockLifecycleSourceType.workflowPlannedJob =>
            'Governed planned maintenance',
        };
        return Container(
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            color: BafColors.card,
            border: Border.all(color: BafColors.border),
            borderRadius: BorderRadius.circular(BafRadius.small),
            boxShadow: BafShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BafColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BafRadius.small),
                    ),
                    child: const Icon(
                      Icons.handyman_outlined,
                      color: BafColors.success,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Furnace ${event.assetNumber.toString().padLeft(2, '0')} · Burner ${event.burnerPosition}',
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(event.actionPerformedAt.toLocal()),
                          style: const TextStyle(
                            color: BafColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canCorrect)
                    BurnerBlockCorrectionControls(
                      event: event,
                      currentEventId: current?.eventId,
                    ),
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: BafSpacing.xs,
                runSpacing: BafSpacing.xs,
                children: [
                  StatusBadge(
                    label:
                        event.supplyMode ==
                            BurnerBlockLifecycleSupplyMode.sailRed
                        ? 'SAIL-made by RED'
                        : 'Purchased',
                    color: BafColors.maintenance,
                  ),
                  StatusBadge(label: sourceLabel, color: BafColors.planned),
                  StatusBadge(
                    label: switch (event.replacementDisposition) {
                      BurnerBlockReplacementDisposition.newPart => 'New part',
                      BurnerBlockReplacementDisposition.repaired =>
                        'Repaired part',
                      BurnerBlockReplacementDisposition.revised =>
                        'Revised part',
                    },
                    color: BafColors.assets,
                  ),
                ],
              ),
              if (event.supplierName != null ||
                  event.purchaseOrderNumber != null) ...[
                const SizedBox(height: BafSpacing.sm),
                Text(
                  <String>[
                    if (event.supplierName != null)
                      'Supplier: ${event.supplierName}',
                    if (event.purchaseOrderNumber != null)
                      'PO: ${event.purchaseOrderNumber}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: BafSpacing.xs),
              Text(
                'Mechanical installation · performed by ${event.performedByName} · closure recorded by ${event.completedByName} · ${DateFormat('dd MMM yyyy, HH:mm').format(event.completedAt.toLocal())} · ${event.hierarchyPath.join(' › ')}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BurnerBlockMatrix extends StatelessWidget {
  const _BurnerBlockMatrix({
    required this.furnaces,
    required this.drafts,
    required this.onChanged,
  });

  final List<AssetInstanceRecord> furnaces;
  final Map<String, FurnaceAuditDraft> drafts;
  final _DraftChange onChanged;

  @override
  Widget build(BuildContext context) => _MatrixFrame(
    headers: const <String>['B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8'],
    furnaces: furnaces,
    drafts: drafts,
    confirmation:
        'Confirm all eight burner blocks were checked now. Marked positions are red hot; unmarked positions were checked with no red hot observed. Flame and signal readings are retained at their original ages.',
    onConfirm: (furnace) => onChanged(
      furnace.id,
      (draft) => draft.confirmFields([
        for (var position = 1; position <= 8; position++)
          'burners.$position.redHotObserved',
      ]),
    ),
    cellBuilder: (furnace, draft, position) {
      final selected = draft.redHotPositions.contains(position);
      final replacement = draft.replacementsByPosition[position];
      return _ConditionCell(
        key: ValueKey('block-${furnace.id}-$position'),
        selected: selected,
        unknown: !draft.isKnown('burners.$position.redHotObserved'),
        color: BafColors.danger,
        tooltip: !draft.isKnown('burners.$position.redHotObserved')
            ? 'Burner $position observation age is unknown. Check this position before confirming.'
            : selected
            ? 'Red hot observed'
            : replacement == null
            ? 'No red-hot observation'
            : 'Cleared by ${replacement.supplyMode == BurnerBlockLifecycleSupplyMode.sailRed ? 'SAIL/RED-made' : 'purchased'} block replacement on ${DateFormat('dd MMM yyyy, HH:mm').format(replacement.actionPerformedAt.toLocal())}',
        evidenceIcon: !selected && replacement != null
            ? Icons.handyman_outlined
            : null,
        onChanged: furnace.serviceState == AssetServiceState.outOfService
            ? null
            : (value) => onChanged(
                furnace.id,
                (current) => current.setRedHot(position, value),
              ),
      );
    },
  );
}

class _DraftSealMatrix extends StatelessWidget {
  const _DraftSealMatrix({
    required this.furnaces,
    required this.drafts,
    required this.onChanged,
  });

  final List<AssetInstanceRecord> furnaces;
  final Map<String, FurnaceAuditDraft> drafts;
  final _DraftChange onChanged;

  @override
  Widget build(BuildContext context) => _MatrixFrame(
    headers: const <String>['Red hot', 'Hot air'],
    cellWidth: 132,
    furnaces: furnaces,
    drafts: drafts,
    confirmation:
        'Confirm both draft seal conditions were checked now. Marked conditions were observed; unmarked conditions were checked and not observed.',
    onConfirm: (furnace) => onChanged(
      furnace.id,
      (draft) => draft.confirmFields([
        'draftSealRedHotObserved',
        'hotAirAtDraftSealObserved',
      ]),
    ),
    cellBuilder: (furnace, draft, position) {
      final selected = position == 1
          ? draft.draftSealRedHotObserved
          : draft.hotAirAtDraftSealObserved;
      return _ConditionCell(
        key: ValueKey('seal-${furnace.id}-$position'),
        selected: selected,
        unknown: !draft.isKnown(
          position == 1
              ? 'draftSealRedHotObserved'
              : 'hotAirAtDraftSealObserved',
        ),
        color: position == 1 ? BafColors.danger : BafColors.warning,
        tooltip: position == 1 ? 'Draft seal red hot' : 'Hot air at draft seal',
        onChanged: furnace.serviceState == AssetServiceState.outOfService
            ? null
            : (value) => onChanged(furnace.id, (current) {
                if (position == 1) {
                  current.draftSealRedHotObserved = value;
                } else {
                  current.hotAirAtDraftSealObserved = value;
                }
              }),
      );
    },
  );
}

class _UvConditionMatrix extends StatelessWidget {
  const _UvConditionMatrix({
    required this.furnaces,
    required this.drafts,
    required this.condition,
    required this.onChanged,
  });

  final List<AssetInstanceRecord> furnaces;
  final Map<String, FurnaceAuditDraft> drafts;
  final BurnerUvCondition condition;
  final _DraftChange onChanged;

  @override
  Widget build(BuildContext context) => _MatrixFrame(
    headers: const <String>[
      'UV1',
      'UV2',
      'UV3',
      'UV4',
      'UV5',
      'UV6',
      'UV7',
      'UV8',
    ],
    furnaces: furnaces,
    drafts: drafts,
    confirmation:
        'Confirm all eight UV detectors were checked now, including melted, missing and hanging conditions. Existing marked conditions are retained; positions with no recorded condition are confirmed serviceable. Physical UV condition does not confirm PLC isolation.',
    onConfirm: (furnace) => onChanged(furnace.id, (draft) {
      for (var position = 1; position <= 8; position++) {
        draft.uvByPosition.putIfAbsent(
          position,
          () => BurnerUvCondition.serviceable,
        );
      }
      draft.confirmFields([
        for (var position = 1; position <= 8; position++)
          'uv.$position.condition',
      ]);
    }),
    cellBuilder: (furnace, draft, position) {
      final selected = draft.uvByPosition[position] == condition;
      final replacement = draft.uvReplacementsByPosition[position];
      return _ConditionCell(
        key: ValueKey('uv-${condition.name}-${furnace.id}-$position'),
        selected: selected,
        unknown: !draft.isKnown('uv.$position.condition'),
        color: _uvColor(condition),
        tooltip: !draft.isKnown('uv.$position.condition')
            ? 'UV$position condition age is unknown. Check this detector before confirming.'
            : selected
            ? '${condition.label} at UV$position'
            : replacement == null
            ? '${condition.label} not recorded at UV$position'
            : 'Latest UV$position replacement on ${DateFormat('dd MMM yyyy, HH:mm').format(replacement.actionPerformedAt.toLocal())}',
        evidenceIcon: !selected && replacement != null
            ? Icons.sensors_rounded
            : null,
        onChanged: furnace.serviceState == AssetServiceState.outOfService
            ? null
            : (value) => onChanged(
                furnace.id,
                (current) => current.uvByPosition[position] = value
                    ? condition
                    : BurnerUvCondition.serviceable,
              ),
      );
    },
  );
}

typedef _MatrixCellBuilder =
    Widget Function(
      AssetInstanceRecord furnace,
      FurnaceAuditDraft draft,
      int position,
    );

class _MatrixFrame extends StatefulWidget {
  const _MatrixFrame({
    required this.headers,
    required this.furnaces,
    required this.drafts,
    required this.cellBuilder,
    required this.onConfirm,
    required this.confirmation,
    this.cellWidth = 68,
  });

  final List<String> headers;
  final List<AssetInstanceRecord> furnaces;
  final Map<String, FurnaceAuditDraft> drafts;
  final _MatrixCellBuilder cellBuilder;
  final ValueChanged<AssetInstanceRecord> onConfirm;
  final String confirmation;
  final double cellWidth;

  @override
  State<_MatrixFrame> createState() => _MatrixFrameState();
}

class _MatrixFrameState extends State<_MatrixFrame> {
  late final ScrollController _headerHorizontalController;
  late final ScrollController _bodyHorizontalController;
  late final ScrollController _verticalController;
  bool _synchronizingHorizontalScroll = false;

  @override
  void initState() {
    super.initState();
    _headerHorizontalController = ScrollController();
    _bodyHorizontalController = ScrollController();
    _verticalController = ScrollController();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
  }

  @override
  void dispose() {
    _headerHorizontalController
      ..removeListener(_syncHeaderToBody)
      ..dispose();
    _bodyHorizontalController
      ..removeListener(_syncBodyToHeader)
      ..dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() => _synchronizeHorizontalControllers(
    source: _headerHorizontalController,
    target: _bodyHorizontalController,
  );

  void _syncBodyToHeader() => _synchronizeHorizontalControllers(
    source: _bodyHorizontalController,
    target: _headerHorizontalController,
  );

  void _synchronizeHorizontalControllers({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_synchronizingHorizontalScroll ||
        !source.hasClients ||
        !target.hasClients ||
        !target.position.hasContentDimensions) {
      return;
    }
    final targetOffset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - targetOffset).abs() < 0.5) return;
    _synchronizingHorizontalScroll = true;
    target.jumpTo(targetOffset);
    _synchronizingHorizontalScroll = false;
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final identityWidth = (168.0 * textScale).clamp(168.0, 220.0);
    final headerHeight = 48 * textScale.clamp(1.0, double.infinity);
    final rowHeight = 58 * textScale.clamp(1.0, double.infinity);
    final gridWidth = widget.headers.length * widget.cellWidth;
    return Column(
      children: [
        SizedBox(
          height: headerHeight,
          child: Row(
            children: [
              Container(
                key: const ValueKey('furnace-audit-fixed-corner'),
                width: identityWidth,
                decoration: const BoxDecoration(
                  color: BafColors.surfaceStrong,
                  border: Border(
                    right: BorderSide(color: BafColors.borderStrong),
                    bottom: BorderSide(color: BafColors.border),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Furnace',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('furnace-audit-scrollable-header'),
                  controller: _headerHorizontalController,
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    width: gridWidth,
                    height: headerHeight,
                    decoration: const BoxDecoration(
                      color: BafColors.surfaceStrong,
                      border: Border(
                        bottom: BorderSide(color: BafColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (
                          var index = 0;
                          index < widget.headers.length;
                          index++
                        )
                          SizedBox(
                            key: ValueKey('furnace-audit-header-${index + 1}'),
                            width: widget.cellWidth,
                            child: Text(
                              widget.headers[index],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _verticalController,
            child: SingleChildScrollView(
              key: const ValueKey('furnace-audit-vertical-scroll'),
              controller: _verticalController,
              padding: const EdgeInsets.only(bottom: BafSpacing.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    key: const ValueKey('furnace-audit-fixed-furnace-column'),
                    width: identityWidth,
                    child: Column(
                      children: [
                        for (final furnace in widget.furnaces)
                          _buildFurnaceIdentityRow(
                            furnace: furnace,
                            draft: widget.drafts[furnace.id]!,
                            rowHeight: rowHeight,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('furnace-audit-scrollable-grid'),
                      controller: _bodyHorizontalController,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: gridWidth,
                        child: Column(
                          children: [
                            for (final furnace in widget.furnaces)
                              _buildConditionRow(
                                furnace: furnace,
                                draft: widget.drafts[furnace.id]!,
                                rowHeight: rowHeight,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFurnaceIdentityRow({
    required AssetInstanceRecord furnace,
    required FurnaceAuditDraft draft,
    required double rowHeight,
  }) {
    return Container(
      key: ValueKey('furnace-audit-row-label-${furnace.id}'),
      height: rowHeight,
      decoration: const BoxDecoration(
        color: BafColors.card,
        border: Border(
          right: BorderSide(color: BafColors.borderStrong),
          bottom: BorderSide(color: BafColors.border),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Furnace ${furnace.assetNumber.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  draft.sourceAt == null
                      ? 'No prior audit'
                      : DateFormat(
                          'dd MMM, HH:mm',
                        ).format(draft.sourceAt!.toLocal()),
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Tooltip(
            message: draft.dirty
                ? 'This Furnace is ready to record'
                : 'Confirm this Furnace as reviewed',
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: furnace.serviceState == AssetServiceState.outOfService
                  ? null
                  : () async {
                      final reviewedSourceKey = draft.sourceKey;
                      final reviewedRevision = draft.revision;
                      final messenger = ScaffoldMessenger.of(context);
                      final confirmed = await _confirmFurnaceChecks(
                        context,
                        furnace.name,
                        widget.confirmation,
                      );
                      if (!confirmed || !mounted) return;
                      final current = widget.drafts[furnace.id];
                      if (current == null ||
                          current.sourceKey != reviewedSourceKey ||
                          current.revision != reviewedRevision ||
                          current.requiresReview) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Furnace evidence changed. Review the current values and confirm again.',
                            ),
                          ),
                        );
                        return;
                      }
                      widget.onConfirm(furnace);
                    },
              icon: Icon(
                draft.dirty
                    ? Icons.task_alt_rounded
                    : Icons.fact_check_outlined,
                size: 19,
                color: draft.dirty
                    ? BafColors.success
                    : BafColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionRow({
    required AssetInstanceRecord furnace,
    required FurnaceAuditDraft draft,
    required double rowHeight,
  }) {
    return Container(
      height: rowHeight,
      decoration: const BoxDecoration(
        color: BafColors.card,
        border: Border(bottom: BorderSide(color: BafColors.border)),
      ),
      child: Row(
        children: [
          for (var position = 1; position <= widget.headers.length; position++)
            SizedBox(
              width: widget.cellWidth,
              child: widget.cellBuilder(furnace, draft, position),
            ),
        ],
      ),
    );
  }
}
