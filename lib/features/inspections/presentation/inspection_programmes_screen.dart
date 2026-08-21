import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/domain/workflow_command_contract.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../data/inspection_campaign.dart';
import '../providers/inspection_provider.dart';

part 'inspection_programmes_editors.dart';

class InspectionProgrammesScreen extends ConsumerWidget {
  const InspectionProgrammesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentAppUserProvider)
        .when(
          loading:
              () => BafScreenStateScaffold.loading(
                appBarTitle: 'Inspection programmes',
                appBarSubtitle: 'Component evidence across selected assets',
                appBarIcon: Icons.fact_check_outlined,
                accent: BafColors.instrument,
                label: 'Checking inspection authority',
              ),
          error:
              (_, _) => BafScreenStateScaffold.error(
                appBarTitle: 'Inspection programmes',
                appBarSubtitle: 'Component evidence across selected assets',
                appBarIcon: Icons.fact_check_outlined,
                accent: BafColors.instrument,
                message: 'Inspection authority could not be verified.',
              ),
          data:
              (actor) =>
                  actor == null
                      ? BafScreenStateScaffold.access(
                        appBarTitle: 'Inspection programmes',
                        appBarSubtitle:
                            'Component evidence across selected assets',
                        appBarIcon: Icons.fact_check_outlined,
                        accent: BafColors.instrument,
                        title: 'Sign in required',
                        message:
                            'Sign in with an approved account to view inspection programmes.',
                      )
                      : _InspectionProgrammeBody(actor: actor),
        );
  }
}

class _InspectionProgrammeBody extends ConsumerWidget {
  const _InspectionProgrammeBody({required this.actor});

  final AppUser actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Inspection programmes',
            subtitle: 'Component evidence across selected assets',
            icon: Icons.fact_check_outlined,
            accent: BafColors.instrument,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.radar_outlined), text: 'Active'),
              Tab(icon: Icon(Icons.task_alt_rounded), text: 'Closed'),
              Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Definitions'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CampaignList(actor: actor, closed: false),
            _CampaignList(actor: actor, closed: true),
            _DefinitionList(actor: actor),
          ],
        ),
      ),
    );
  }
}

class _CampaignList extends ConsumerWidget {
  const _CampaignList({required this.actor, required this.closed});

  final AppUser actor;
  final bool closed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final campaigns = ref.watch(inspectionCampaignsProvider);
    final definitions =
        ref.watch(inspectionDefinitionsProvider).value ??
        const <InspectionDefinition>[];
    final assets =
        ref.watch(allAssetInstancesProvider).value ??
        const <AssetInstanceRecord>[];
    return campaigns.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading inspection campaigns',
            color: BafColors.instrument,
          ),
      error:
          (_, _) => _InspectionError(
            message: 'Inspection campaigns could not be read safely.',
            onRetry: () => ref.invalidate(inspectionCampaignsProvider),
          ),
      data: (all) {
        final rows = all
            .where(
              (item) =>
                  closed
                      ? item.status == InspectionCampaignStatus.closed
                      : item.status != InspectionCampaignStatus.closed,
            )
            .toList(growable: false);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(inspectionCampaignsProvider);
            await ref.read(inspectionCampaignsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(BafSpacing.lg),
            children: [
              _ProgrammeHeader(
                closed: closed,
                count: rows.length,
                onCreate:
                    !closed &&
                            actor.canManageInspectionCampaigns &&
                            definitions.any((item) => item.isActive)
                        ? () => _createCampaign(
                          context,
                          ref,
                          definitions,
                          assets,
                          all
                              .where(
                                (item) =>
                                    item.status ==
                                    InspectionCampaignStatus.closed,
                              )
                              .toList(growable: false),
                        )
                        : null,
              ),
              const SizedBox(height: BafSpacing.lg),
              if (rows.isEmpty)
                _InspectionEmpty(
                  icon:
                      closed
                          ? Icons.inventory_2_outlined
                          : Icons.radar_outlined,
                  title:
                      closed
                          ? 'No completed inspection programmes'
                          : 'No active inspection programme',
                  message:
                      closed
                          ? 'Closed campaigns remain here with their coverage and immutable readings.'
                          : definitions.isEmpty
                          ? 'Create a governed definition first, then open a campaign for selected assets.'
                          : 'Open a campaign for all assets, a selected list, or a deliberately partial population.',
                )
              else
                ...rows.map(
                  (campaign) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: _CampaignCard(
                      campaign: campaign,
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder:
                                  (_) => InspectionCampaignDetailScreen(
                                    campaignId: campaign.id,
                                  ),
                            ),
                          ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgrammeHeader extends StatelessWidget {
  const _ProgrammeHeader({
    required this.closed,
    required this.count,
    required this.onCreate,
  });

  final bool closed;
  final int count;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.graphite,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        boxShadow: BafShadows.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  closed ? 'Completed evidence' : 'Field audit board',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  closed
                      ? '$count retained programme${count == 1 ? '' : 's'}'
                      : 'Audit one element across many assets without taking the class out of service.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onCreate != null) ...[
            const SizedBox(width: BafSpacing.md),
            FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: BafColors.teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign, required this.onTap});

  final InspectionCampaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = campaign.coverageFraction;
    final color =
        campaign.status == InspectionCampaignStatus.paused
            ? BafColors.warning
            : campaign.status == InspectionCampaignStatus.closed
            ? BafColors.success
            : BafColors.instrument;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        onTap: onTap,
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
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BafRadius.small),
                    ),
                    child: Icon(Icons.fact_check_outlined, color: color),
                  ),
                  const SizedBox(width: BafSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.definition.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_assetTypeLabel(campaign.assetTypeKey)} · ${campaign.purpose}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  _StatusPill(label: campaign.status.name, color: color),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(BafRadius.small),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: fraction,
                        backgroundColor: BafColors.surfaceStrong,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: BafSpacing.md),
                  Text(
                    '${campaign.accountedTargetCount}/${campaign.expectedPopulation} accounted',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: BafColors.textTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DefinitionList extends ConsumerWidget {
  const _DefinitionList({required this.actor});

  final AppUser actor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definitions = ref.watch(inspectionDefinitionsProvider);
    final classes =
        ref.watch(assetClassesProvider).value ?? const <AssetClassRecord>[];
    return definitions.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading inspection definitions',
            color: BafColors.instrument,
          ),
      error:
          (_, _) => _InspectionError(
            message: 'Inspection definitions could not be read safely.',
            onRetry: () => ref.invalidate(inspectionDefinitionsProvider),
          ),
      data:
          (rows) => ListView(
            padding: const EdgeInsets.all(BafSpacing.lg),
            children: [
              BafPageHeader(
                title: 'Governed inspection definitions',
                subtitle:
                    'Version the measurement, units, limits, preconditions and component scope once; freeze it into every campaign.',
                icon: Icons.rule_folder_outlined,
                accent: BafColors.instrument,
                trailing:
                    actor.canManageInspectionDefinitions
                        ? IconButton.filledTonal(
                          tooltip: 'Add inspection definition',
                          onPressed:
                              classes.any((item) => item.isActive)
                                  ? () => _editDefinition(context, ref, classes)
                                  : null,
                          icon: const Icon(Icons.add_rounded),
                        )
                        : null,
              ),
              const SizedBox(height: BafSpacing.lg),
              if (rows.isEmpty)
                const _InspectionEmpty(
                  icon: Icons.rule_folder_outlined,
                  title: 'No governed inspection definitions',
                  message:
                      'Create definitions such as Furnace pressure setting, cable replacement condition, or burner microamp reading.',
                )
              else
                ...rows.map(
                  (definition) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: _DefinitionCard(
                      definition: definition,
                      canManage: actor.canManageInspectionDefinitions,
                      onEdit:
                          () => _editDefinition(
                            context,
                            ref,
                            classes,
                            definition,
                          ),
                      onStatus:
                          () => _toggleDefinition(context, ref, definition),
                    ),
                  ),
                ),
            ],
          ),
    );
  }
}

class _DefinitionCard extends StatelessWidget {
  const _DefinitionCard({
    required this.definition,
    required this.canManage,
    required this.onEdit,
    required this.onStatus,
  });

  final InspectionDefinition definition;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onStatus;

  @override
  Widget build(BuildContext context) {
    final value = definition.frozen;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    value.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusPill(
                  label: definition.status.name,
                  color:
                      definition.isActive
                          ? BafColors.success
                          : BafColors.textTertiary,
                ),
                if (canManage)
                  PopupMenuButton<String>(
                    tooltip: 'Definition actions',
                    onSelected:
                        (choice) => choice == 'edit' ? onEdit() : onStatus(),
                    itemBuilder:
                        (_) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit as new version'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'status',
                            child: ListTile(
                              leading: Icon(
                                definition.isActive
                                    ? Icons.archive_outlined
                                    : Icons.restore_rounded,
                              ),
                              title: Text(
                                definition.isActive ? 'Retire' : 'Restore',
                              ),
                            ),
                          ),
                        ],
                  ),
              ],
            ),
            Text(
              '${value.code} · version ${value.version}',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            Text(value.description),
            const SizedBox(height: BafSpacing.md),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                _InfoChip(
                  icon: Icons.data_object_rounded,
                  text: value.valueType.name,
                ),
                if (value.unit != null)
                  _InfoChip(icon: Icons.straighten_rounded, text: value.unit!),
                _InfoChip(
                  icon: Icons.precision_manufacturing_outlined,
                  text:
                      value.componentNodeIds.isEmpty
                          ? 'Asset level'
                          : '${value.componentNodeIds.length} component${value.componentNodeIds.length == 1 ? '' : 's'}',
                ),
                if (value.minimumValue != null || value.maximumValue != null)
                  _InfoChip(
                    icon: Icons.speed_rounded,
                    text:
                        '${value.minimumValue ?? '−∞'} to ${value.maximumValue ?? '∞'} ${value.unit ?? ''}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InspectionCampaignDetailScreen extends ConsumerWidget {
  const InspectionCampaignDetailScreen({super.key, required this.campaignId});

  final String campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentAppUserProvider).value;
    final campaigns = ref.watch(inspectionCampaignsProvider);
    if (actor == null) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Inspection programme',
        appBarSubtitle: 'Campaign targets, evidence and findings',
        appBarIcon: Icons.fact_check_outlined,
        accent: BafColors.instrument,
        title: 'Sign in required',
        message: 'Sign in with an approved account to inspect this campaign.',
      );
    }
    return campaigns.when(
      loading:
          () => BafScreenStateScaffold.loading(
            appBarTitle: 'Inspection programme',
            appBarSubtitle: 'Campaign targets, evidence and findings',
            appBarIcon: Icons.fact_check_outlined,
            accent: BafColors.instrument,
            label: 'Loading inspection campaign',
          ),
      error:
          (_, _) => BafScreenStateScaffold.error(
            appBarTitle: 'Inspection programme',
            appBarSubtitle: 'Campaign targets, evidence and findings',
            appBarIcon: Icons.fact_check_outlined,
            accent: BafColors.instrument,
            message: 'The campaign could not be read safely.',
          ),
      data: (rows) {
        InspectionCampaign? campaign;
        for (final row in rows) {
          if (row.id == campaignId) campaign = row;
        }
        if (campaign == null) {
          return BafScreenStateScaffold(
            appBarTitle: 'Inspection programme',
            appBarSubtitle: 'Campaign targets, evidence and findings',
            appBarIcon: Icons.fact_check_outlined,
            accent: BafColors.instrument,
            state: BafStatePanel.empty(
              title: 'Campaign not found',
              message: 'This inspection campaign is no longer available.',
              icon: Icons.find_in_page_outlined,
              color: BafColors.instrument,
            ),
          );
        }
        return _CampaignDetail(actor: actor, campaign: campaign);
      },
    );
  }
}

class _CampaignDetail extends ConsumerWidget {
  const _CampaignDetail({required this.actor, required this.campaign});

  final AppUser actor;
  final InspectionCampaign campaign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observations = ref.watch(inspectionObservationsProvider(campaign.id));
    final findings =
        ref.watch(inspectionFindingsProvider(campaign.id)).value ??
        const <InspectionFinding>[];
    final classId = campaign.assetClassId;
    final nodes =
        ref.watch(assetHierarchyNodesProvider(classId)).value ??
        const <AssetHierarchyNode>[];
    final instances = (ref.watch(allAssetInstancesProvider).value ??
            const <AssetInstanceRecord>[])
        .where((item) => item.assetClassId == classId)
        .toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: BafAppBarTitle(
          title: campaign.definition.title,
          subtitle: '${_assetTypeLabel(campaign.assetTypeKey)} inspection',
          icon: Icons.fact_check_outlined,
          accent: BafColors.instrument,
        ),
        actions: [
          if (actor.canManageInspectionCampaigns &&
              campaign.status != InspectionCampaignStatus.closed)
            PopupMenuButton<String>(
              tooltip: 'Campaign actions',
              onSelected: (action) {
                if (action == 'addTargets') {
                  _addCampaignTargets(context, ref, campaign, instances);
                } else {
                  _transitionCampaign(context, ref, campaign, action);
                }
              },
              itemBuilder:
                  (_) => [
                    const PopupMenuItem(
                      value: 'addTargets',
                      child: ListTile(
                        leading: Icon(Icons.playlist_add_rounded),
                        title: Text('Add governed targets'),
                      ),
                    ),
                    PopupMenuItem(
                      value:
                          campaign.status == InspectionCampaignStatus.paused
                              ? 'open'
                              : 'paused',
                      child: ListTile(
                        leading: Icon(
                          campaign.status == InspectionCampaignStatus.paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        title: Text(
                          campaign.status == InspectionCampaignStatus.paused
                              ? 'Resume campaign'
                              : 'Pause campaign',
                        ),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'closed',
                      child: ListTile(
                        leading: Icon(Icons.task_alt_rounded),
                        title: Text('Close campaign'),
                      ),
                    ),
                  ],
            ),
        ],
      ),
      floatingActionButton:
          campaign.status == InspectionCampaignStatus.open &&
                  actor.canObserveInspectionCampaign(campaign.observerRoleKeys)
              ? FloatingActionButton.extended(
                onPressed:
                    () => _recordObservation(
                      context,
                      ref,
                      campaign,
                      nodes,
                      instances,
                    ),
                icon: const Icon(Icons.add_chart_rounded),
                label: const Text('Add reading'),
              )
              : null,
      body: observations.when(
        loading:
            () => const BafLoadingPanel(
              label: 'Loading campaign readings',
              color: BafColors.instrument,
            ),
        error:
            (_, _) => _InspectionError(
              message: 'Campaign readings could not be decoded safely.',
              onRetry:
                  () => ref.invalidate(
                    inspectionObservationsProvider(campaign.id),
                  ),
            ),
        data: (rows) {
          final supersededIds =
              rows
                  .map((item) => item.supersedesObservationId)
                  .whereType<String>()
                  .toSet();
          final currentRows = rows
              .where((item) => !supersededIds.contains(item.id))
              .toList(growable: false);
          final blockingFindings =
              findings.where((finding) => finding.blocksCampaignClosure).length;
          final dispositionTargets = campaign.targets
              .where(
                (target) =>
                    target.disposition != InspectionTargetDisposition.observed,
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.lg,
              96,
            ),
            children: [
              _CampaignSummary(
                campaign: campaign,
                currentFindingCount: blockingFindings,
              ),
              const SizedBox(height: BafSpacing.lg),
              if (campaign.definition.preconditions.isNotEmpty)
                _DetailBand(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Before observing',
                  body: campaign.definition.preconditions.join(' · '),
                  color: BafColors.warning,
                ),
              if (dispositionTargets.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.md),
                _TargetPopulationPanel(
                  campaign: campaign,
                  targets: dispositionTargets,
                  nodes: nodes,
                  canManage: actor.canManageInspectionCampaigns,
                  onDisposition:
                      (target, disposition) => _setTargetDisposition(
                        context,
                        ref,
                        campaign,
                        target,
                        disposition,
                      ),
                ),
              ],
              if (findings.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.xl),
                BafSectionHeading(
                  title: 'Findings and verification',
                  subtitle:
                      '${findings.length} finding${findings.length == 1 ? '' : 's'} · $blockingFindings still need an accountable outcome',
                  icon: Icons.rule_rounded,
                ),
                const SizedBox(height: BafSpacing.md),
                ...findings.map(
                  (finding) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: _FindingCard(
                      finding: finding,
                      observations: currentRows,
                      canSupervise: actor.canSuperviseInspectionObservations,
                      onVerify:
                          () => _verifyFinding(
                            context,
                            ref,
                            campaign,
                            finding,
                            currentRows,
                          ),
                      onAdjudicate:
                          (status) => _adjudicateFinding(
                            context,
                            ref,
                            campaign,
                            finding,
                            status,
                          ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: BafSpacing.xl),
              BafSectionHeading(
                title: 'Readings and corrections',
                subtitle:
                    '${rows.length} immutable record${rows.length == 1 ? '' : 's'} · ${currentRows.length} current result${currentRows.length == 1 ? '' : 's'}',
                icon: Icons.timeline_rounded,
              ),
              const SizedBox(height: BafSpacing.md),
              if (rows.isEmpty)
                const _InspectionEmpty(
                  icon: Icons.add_chart_rounded,
                  title: 'No reading recorded',
                  message:
                      'Record only the assets reached in this round. Partial coverage is visible and valid.',
                )
              else
                ...rows.map(
                  (observation) => Padding(
                    padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                    child: _ObservationCard(
                      observation: observation,
                      isSuperseded: supersededIds.contains(observation.id),
                      canCorrect:
                          campaign.status == InspectionCampaignStatus.open &&
                          (actor.canSuperviseInspectionObservations ||
                              actor.uid == observation.observerUid),
                      canLink:
                          actor.canSuperviseInspectionObservations ||
                          actor.canObserveInspectionCampaign(
                            campaign.observerRoleKeys,
                          ),
                      onCorrect:
                          () => _recordObservation(
                            context,
                            ref,
                            campaign,
                            nodes,
                            instances,
                            correction: observation,
                          ),
                      onLink:
                          () => _linkIssue(context, ref, campaign, observation),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CampaignSummary extends StatelessWidget {
  const _CampaignSummary({
    required this.campaign,
    required this.currentFindingCount,
  });

  final InspectionCampaign campaign;
  final int currentFindingCount;

  @override
  Widget build(BuildContext context) {
    final coverage = campaign.coverageFraction;
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.graphite,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        boxShadow: BafShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.purpose,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
              _StatusPill(
                label: campaign.status.name,
                color:
                    campaign.status == InspectionCampaignStatus.closed
                        ? BafColors.success
                        : campaign.status == InspectionCampaignStatus.paused
                        ? BafColors.warning
                        : BafColors.instrument,
                onDark: true,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          Row(
            children: [
              _SummaryMetric(
                value: '${campaign.distinctTargetCount}',
                label: 'targets',
              ),
              _SummaryMetric(
                value: '${campaign.observationCount}',
                label: 'records',
              ),
              _SummaryMetric(
                value: '$currentFindingCount',
                label: 'findings',
                valueColor:
                    currentFindingCount > 0
                        ? const Color(0xFFFFB4A7)
                        : const Color(0xFF9BE4BC),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(BafRadius.small),
            child: LinearProgressIndicator(
              value: coverage,
              minHeight: 8,
              color: BafColors.teal,
              backgroundColor: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(coverage * 100).round()}% observed · ${campaign.accountedTargetCount}/${campaign.expectedPopulation} accounted · ${campaign.remainingPopulation} pending',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({
    required this.observation,
    required this.isSuperseded,
    required this.canCorrect,
    required this.canLink,
    required this.onCorrect,
    required this.onLink,
  });

  final InspectionObservation observation;
  final bool isSuperseded;
  final bool canCorrect;
  final bool canLink;
  final VoidCallback onCorrect;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final color =
        isSuperseded
            ? BafColors.textTertiary
            : observation.outOfRange
            ? BafColors.danger
            : BafColors.success;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BafRadius.small),
              ),
              child: Icon(
                isSuperseded
                    ? Icons.history_rounded
                    : observation.outOfRange
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: BafSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_assetTypeLabel(observation.assetTypeKey)} ${observation.assetNumber} · ${observation.componentName ?? 'Asset level'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${observation.displayValue} · ${DateFormat('dd MMM, HH:mm').format(observation.observedAt.toLocal())}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  if (observation.physicalPosition != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      observation.physicalPosition!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (observation.note != null) ...[
                    const SizedBox(height: BafSpacing.sm),
                    Text(observation.note!),
                  ],
                  const SizedBox(height: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.xs,
                    children: [
                      _InfoChip(
                        icon: Icons.person_outline_rounded,
                        text: observation.observerName,
                      ),
                      if (observation.chargeNo != null)
                        _InfoChip(
                          icon: Icons.numbers_rounded,
                          text: 'Charge ${observation.chargeNo}',
                        ),
                      if (isSuperseded)
                        const _InfoChip(
                          icon: Icons.history_rounded,
                          text: 'Superseded',
                        )
                      else if (observation.supersedesObservationId != null)
                        const _InfoChip(
                          icon: Icons.edit_note_rounded,
                          text: 'Correction',
                        ),
                      if (observation.comparisonOutcome != null)
                        _InfoChip(
                          icon: Icons.compare_arrows_rounded,
                          text: _comparisonLabel(
                            observation.comparisonOutcome!,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Reading actions',
              onSelected:
                  (choice) => choice == 'correct' ? onCorrect() : onLink(),
              itemBuilder:
                  (_) => [
                    if (canCorrect && !isSuperseded)
                      const PopupMenuItem(
                        value: 'correct',
                        child: ListTile(
                          leading: Icon(Icons.edit_note_rounded),
                          title: Text('Record correction'),
                        ),
                      ),
                    if (canLink && !isSuperseded)
                      const PopupMenuItem(
                        value: 'link',
                        child: ListTile(
                          leading: Icon(Icons.link_rounded),
                          title: Text('Link maintenance issue'),
                        ),
                      ),
                  ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetPopulationPanel extends StatelessWidget {
  const _TargetPopulationPanel({
    required this.campaign,
    required this.targets,
    required this.nodes,
    required this.canManage,
    required this.onDisposition,
  });

  final InspectionCampaign campaign;
  final List<InspectionCampaignTarget> targets;
  final List<AssetHierarchyNode> nodes;
  final bool canManage;
  final void Function(
    InspectionCampaignTarget target,
    InspectionTargetDisposition disposition,
  )
  onDisposition;

  @override
  Widget build(BuildContext context) {
    final pending =
        targets
            .where(
              (target) =>
                  target.disposition == InspectionTargetDisposition.pending,
            )
            .length;
    return Container(
      decoration: BoxDecoration(
        color: BafColors.instrument.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.instrument.withValues(alpha: 0.2)),
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.pending_actions_outlined,
          color: BafColors.instrument,
        ),
        title: Text(
          '$pending target${pending == 1 ? '' : 's'} still need accounting',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Record evidence or give each target an explicit field disposition.',
        ),
        children: [
          const Divider(height: 1),
          for (final target in targets)
            ListTile(
              dense: true,
              leading: const Icon(Icons.my_location_rounded, size: 20),
              title: Text(_targetLabel(target, nodes)),
              subtitle: Text(
                [
                  _targetDispositionLabel(target.disposition),
                  if (target.dispositionReason != null)
                    target.dispositionReason!,
                  if (target.addedLater) 'Added after campaign opening',
                ].join(' · '),
              ),
              trailing:
                  canManage &&
                          campaign.status != InspectionCampaignStatus.closed
                      ? PopupMenuButton<InspectionTargetDisposition>(
                        tooltip: 'Account for target',
                        onSelected: (value) => onDisposition(target, value),
                        itemBuilder:
                            (_) => [
                              if (target.disposition !=
                                  InspectionTargetDisposition.pending)
                                const PopupMenuItem(
                                  value: InspectionTargetDisposition.pending,
                                  child: Text('Return to pending'),
                                ),
                              const PopupMenuItem(
                                value: InspectionTargetDisposition.deferred,
                                child: Text('Defer to another window'),
                              ),
                              const PopupMenuItem(
                                value: InspectionTargetDisposition.unavailable,
                                child: Text('Asset unavailable'),
                              ),
                              const PopupMenuItem(
                                value:
                                    InspectionTargetDisposition
                                        .excludedWithReason,
                                child: Text('Exclude with reason'),
                              ),
                              const PopupMenuItem(
                                value:
                                    InspectionTargetDisposition.requiresReaudit,
                                child: Text('Requires re-audit'),
                              ),
                            ],
                      )
                      : null,
            ),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({
    required this.finding,
    required this.observations,
    required this.canSupervise,
    required this.onVerify,
    required this.onAdjudicate,
  });

  final InspectionFinding finding;
  final List<InspectionObservation> observations;
  final bool canSupervise;
  final VoidCallback onVerify;
  final ValueChanged<String> onAdjudicate;

  @override
  Widget build(BuildContext context) {
    final color =
        finding.blocksCampaignClosure ? BafColors.danger : BafColors.success;
    final hasLaterObservation = observations.any(
      (observation) =>
          observation.targetKey == finding.targetKey &&
          observation.id == finding.currentObservationId &&
          observation.observedAt.isAtSameMomentAs(finding.latestObservedAt) &&
          observation.observedAt.isAfter(finding.firstObservedAt),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(BafRadius.small),
              ),
              child: Icon(Icons.rule_rounded, color: color),
            ),
            const SizedBox(width: BafSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_assetTypeLabel(finding.assetTypeKey)} ${finding.assetNumber} · ${finding.componentName ?? 'Asset level'}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _findingStatusLabel(finding.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                  if (finding.physicalPosition != null)
                    Text(
                      finding.physicalPosition!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.xs,
                    children: [
                      _InfoChip(
                        icon: Icons.replay_rounded,
                        text:
                            '${finding.recurrenceCount} abnormal reading${finding.recurrenceCount == 1 ? '' : 's'}',
                      ),
                      if (finding.linkedTicketId != null)
                        const _InfoChip(
                          icon: Icons.link_rounded,
                          text: 'Corrective issue linked',
                        ),
                      if (finding.verificationCount > 0)
                        _InfoChip(
                          icon: Icons.verified_outlined,
                          text:
                              '${finding.verificationCount} verification${finding.verificationCount == 1 ? '' : 's'}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (canSupervise)
              PopupMenuButton<String>(
                tooltip: 'Finding actions',
                onSelected:
                    (value) =>
                        value == 'verify' ? onVerify() : onAdjudicate(value),
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'verify',
                        enabled: hasLaterObservation,
                        child: const ListTile(
                          leading: Icon(Icons.verified_outlined),
                          title: Text('Verify from later reading'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'acceptedCondition',
                        child: ListTile(
                          leading: Icon(Icons.fact_check_outlined),
                          title: Text('Accept continuing condition'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'invalidated',
                        child: ListTile(
                          leading: Icon(Icons.block_outlined),
                          title: Text('Invalidate with reason'),
                        ),
                      ),
                      if (!finding.blocksCampaignClosure)
                        const PopupMenuItem(
                          value: 'open',
                          child: ListTile(
                            leading: Icon(Icons.replay_rounded),
                            title: Text('Reopen finding'),
                          ),
                        ),
                    ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailBand extends StatelessWidget {
  const _DetailBand({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(BafSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border(left: BorderSide(color: color, width: 4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(body, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    this.valueColor = Colors.white,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: BafColors.surfaceMuted,
      borderRadius: BorderRadius.circular(BafRadius.small),
      border: Border.all(color: BafColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: BafColors.textSecondary),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.onDark = false,
  });

  final String label;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: onDark ? 0.24 : 0.09),
      borderRadius: BorderRadius.circular(BafRadius.small),
      border: Border.all(color: color.withValues(alpha: 0.34)),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        color: onDark ? Colors.white : color,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _InspectionEmpty extends StatelessWidget {
  const _InspectionEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(BafSpacing.xl),
    decoration: BoxDecoration(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 42, color: BafColors.textTertiary),
        const SizedBox(height: BafSpacing.md),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _InspectionError extends StatelessWidget {
  const _InspectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gpp_bad_outlined, size: 42, color: BafColors.danger),
          const SizedBox(height: BafSpacing.md),
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

String _assetTypeLabel(String value) => switch (value) {
  'base' => 'Base',
  'furnace' => 'Furnace',
  'forceCooler' => 'Forced Cooler',
  'innerCover' => 'Inner Cover',
  _ => 'Asset',
};

Future<WorkflowCommandReceipt?> _runInspectionCommand(
  BuildContext context,
  WidgetRef ref,
  WorkflowCommand command,
  String success,
) async {
  try {
    final receipt = await ref
        .read(workflowCommandControllerProvider.notifier)
        .execute(command);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: BafColors.sync),
      );
    }
    return receipt;
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not apply change: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
    return null;
  }
}

Future<void> _editDefinition(
  BuildContext context,
  WidgetRef ref,
  List<AssetClassRecord> classes, [
  InspectionDefinition? existing,
]) async {
  if (!classes.any((item) => item.isActive)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Create or restore an active asset class before defining an inspection.',
        ),
        backgroundColor: BafColors.danger,
      ),
    );
    return;
  }
  final draft = await showDialog<_InspectionDefinitionDraft>(
    context: context,
    builder:
        (_) =>
            _InspectionDefinitionEditor(classes: classes, existing: existing),
  );
  if (draft == null || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'upsertInspectionDefinition_${const Uuid().v4()}',
      type: WorkflowCommandType.upsertInspectionDefinition,
      aggregateId: existing?.id ?? 'inspection-definition-${const Uuid().v4()}',
      expectedVersion: existing?.version ?? 0,
      payload: {'definition': draft.toPayload(), 'reason': draft.reason},
    ),
    existing == null
        ? 'Inspection definition created.'
        : 'Inspection definition version updated.',
  );
}

Future<void> _toggleDefinition(
  BuildContext context,
  WidgetRef ref,
  InspectionDefinition definition,
) async {
  final status = definition.isActive ? 'retired' : 'active';
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'setInspectionDefinitionStatus_${const Uuid().v4()}',
      type: WorkflowCommandType.setInspectionDefinitionStatus,
      aggregateId: definition.id,
      expectedVersion: definition.version,
      payload: {
        'status': status,
        'reason': 'Move the governed inspection definition to $status.',
      },
    ),
    'Inspection definition moved to $status.',
  );
}

Future<void> _createCampaign(
  BuildContext context,
  WidgetRef ref,
  List<InspectionDefinition> definitions,
  List<AssetInstanceRecord> assets,
  List<InspectionCampaign> closedCampaigns,
) async {
  final draft = await showDialog<_InspectionCampaignDraft>(
    context: context,
    builder:
        (_) => _InspectionCampaignEditor(
          definitions: definitions.where((item) => item.isActive).toList(),
          assets: assets.where((item) => item.isActive).toList(),
          closedCampaigns: closedCampaigns,
        ),
  );
  if (draft == null || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'createInspectionCampaign_${const Uuid().v4()}',
      type: WorkflowCommandType.createInspectionCampaign,
      aggregateId: 'inspection-campaign-${const Uuid().v4()}',
      expectedVersion: 0,
      payload: draft.toPayload(),
    ),
    'Inspection campaign opened.',
  );
}

Future<void> _transitionCampaign(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  String status,
) async {
  if (status == 'closed' && !campaign.canClose) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${campaign.remainingPopulation} target${campaign.remainingPopulation == 1 ? '' : 's'} still need evidence or an explicit disposition.',
        ),
        backgroundColor: BafColors.warning,
      ),
    );
    return;
  }
  final confirmed =
      status != 'closed' ||
      await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Close this programme?'),
                  content: const Text(
                    'All targets are accounted. The campaign will become read-only, while findings and verification evidence remain available.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep open'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          ) ==
          true;
  if (!confirmed || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'setInspectionCampaignStatus_${const Uuid().v4()}',
      type: WorkflowCommandType.setInspectionCampaignStatus,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {
        'status': status,
        'reason': 'Move the inspection programme to $status.',
      },
    ),
    'Inspection campaign moved to $status.',
  );
}

Future<void> _setTargetDisposition(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  InspectionCampaignTarget target,
  InspectionTargetDisposition disposition,
) async {
  final reason =
      disposition == InspectionTargetDisposition.pending
          ? ''
          : await showDialog<String>(
            context: context,
            builder:
                (_) => _InspectionReasonDialog(
                  title: _targetDispositionLabel(disposition),
                  message:
                      '${target.assetInstanceName}${target.physicalPosition == null ? '' : ' · ${target.physicalPosition}'} remains visible in the campaign population.',
                ),
          );
  if ((disposition != InspectionTargetDisposition.pending && reason == null) ||
      !context.mounted) {
    return;
  }
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'setInspectionTargetDisposition_${const Uuid().v4()}',
      type: WorkflowCommandType.setInspectionTargetDisposition,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {
        'targetKey': target.targetKey,
        'disposition': disposition.name,
        'reason':
            disposition == InspectionTargetDisposition.pending ? null : reason,
      },
    ),
    'Target recorded as ${_targetDispositionLabel(disposition).toLowerCase()}.',
  );
}

Future<void> _addCampaignTargets(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  List<AssetInstanceRecord> instances,
) async {
  final draft = await showDialog<_AddedTargetDraft>(
    context: context,
    builder:
        (_) => _AddInspectionTargetsDialog(
          availableNumbers:
              instances
                  .where(
                    (asset) =>
                        asset.isActive &&
                        asset.assetClassId == campaign.assetClassId,
                  )
                  .map((asset) => asset.assetNumber)
                  .toList(),
        ),
  );
  if (draft == null || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'addInspectionCampaignTargets_${const Uuid().v4()}',
      type: WorkflowCommandType.addInspectionCampaignTargets,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {
        'assetNumbers': draft.assetNumbers,
        'physicalPositionLabels': draft.physicalPositions,
        'reason': draft.reason,
      },
    ),
    'New targets added without changing the original population history.',
  );
}

Future<void> _verifyFinding(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  InspectionFinding finding,
  List<InspectionObservation> observations,
) async {
  final candidates =
      observations
          .where(
            (observation) =>
                observation.targetKey == finding.targetKey &&
                observation.id == finding.currentObservationId &&
                observation.observedAt.isAtSameMomentAs(
                  finding.latestObservedAt,
                ) &&
                observation.observedAt.isAfter(finding.firstObservedAt),
          )
          .toList()
        ..sort((left, right) => right.observedAt.compareTo(left.observedAt));
  if (candidates.isEmpty) return;
  final draft = await showDialog<_FindingVerificationDraft>(
    context: context,
    builder:
        (_) => _FindingVerificationDialog(
          observations: candidates,
          suggestedOutcome:
              candidates.first.outOfRange ? 'recurred' : 'resolved',
        ),
  );
  if (draft == null || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'verifyInspectionFinding_${const Uuid().v4()}',
      type: WorkflowCommandType.verifyInspectionFinding,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {
        'findingId': finding.id,
        'observationId': draft.observationId,
        'outcome': draft.outcome,
        'reason': draft.reason,
      },
    ),
    'Finding verification recorded.',
  );
}

Future<void> _adjudicateFinding(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  InspectionFinding finding,
  String status,
) async {
  final reason = await showDialog<String>(
    context: context,
    builder:
        (_) => _InspectionReasonDialog(
          title:
              status == 'open'
                  ? 'Reopen finding'
                  : status == 'invalidated'
                  ? 'Invalidate finding'
                  : 'Accept continuing condition',
          message:
              'This is an SI/Admin adjudication. The original reading remains immutable.',
          minimumLength: 10,
        ),
  );
  if (reason == null || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'adjudicateInspectionFinding_${const Uuid().v4()}',
      type: WorkflowCommandType.adjudicateInspectionFinding,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {'findingId': finding.id, 'status': status, 'reason': reason},
    ),
    'Finding adjudication recorded.',
  );
}

Future<void> _recordObservation(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  List<AssetHierarchyNode> nodes,
  List<AssetInstanceRecord> instances, {
  InspectionObservation? correction,
}) async {
  final draft = await showDialog<_InspectionObservationDraft>(
    context: context,
    builder:
        (_) => _InspectionObservationEditor(
          campaign: campaign,
          nodes: nodes,
          instances: instances,
          correction: correction,
        ),
  );
  if (draft == null || !context.mounted) return;
  final receipt = await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'recordInspectionObservation_${const Uuid().v4()}',
      type: WorkflowCommandType.recordInspectionObservation,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: draft.toPayload(),
    ),
    correction == null
        ? 'Inspection reading recorded.'
        : 'Correction recorded.',
  );
  if (receipt?.result['issueRecommended'] == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This result is outside the governed range. Raise a maintenance issue, then link its ID from this reading.',
        ),
        backgroundColor: BafColors.warning,
        duration: Duration(seconds: 6),
      ),
    );
  }
}

Future<void> _linkIssue(
  BuildContext context,
  WidgetRef ref,
  InspectionCampaign campaign,
  InspectionObservation observation,
) async {
  final ticketId = await showDialog<String>(
    context: context,
    builder: (_) => const _LinkInspectionIssueDialog(),
  );
  if (ticketId == null || ticketId.isEmpty || !context.mounted) return;
  await _runInspectionCommand(
    context,
    ref,
    WorkflowCommand(
      commandId: 'linkInspectionObservationIssue_${const Uuid().v4()}',
      type: WorkflowCommandType.linkInspectionObservationIssue,
      aggregateId: campaign.id,
      expectedVersion: campaign.version,
      payload: {
        'observationId': observation.id,
        'ticketId': ticketId,
        'reason': 'Link field inspection evidence to maintenance work.',
      },
    ),
    'Maintenance issue linked.',
  );
}

class _LinkInspectionIssueDialog extends StatefulWidget {
  const _LinkInspectionIssueDialog();

  @override
  State<_LinkInspectionIssueDialog> createState() =>
      _LinkInspectionIssueDialogState();
}

class _LinkInspectionIssueDialogState
    extends State<_LinkInspectionIssueDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Link maintenance issue'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Maintenance issue ID',
        helperText: 'The issue must identify the same asset.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        icon: const Icon(Icons.link_rounded),
        label: const Text('Link'),
      ),
    ],
  );
}

class _InspectionReasonDialog extends StatefulWidget {
  const _InspectionReasonDialog({
    required this.title,
    required this.message,
    this.minimumLength = 5,
  });

  final String title;
  final String message;
  final int minimumLength;

  @override
  State<_InspectionReasonDialog> createState() =>
      _InspectionReasonDialogState();
}

class _AddedTargetDraft {
  const _AddedTargetDraft({
    required this.assetNumbers,
    required this.physicalPositions,
    required this.reason,
  });

  final List<int> assetNumbers;
  final List<String> physicalPositions;
  final String reason;
}

class _AddInspectionTargetsDialog extends StatefulWidget {
  const _AddInspectionTargetsDialog({required this.availableNumbers});

  final List<int> availableNumbers;

  @override
  State<_AddInspectionTargetsDialog> createState() =>
      _AddInspectionTargetsDialogState();
}

class _AddInspectionTargetsDialogState
    extends State<_AddInspectionTargetsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numbers;
  final _positions = TextEditingController();
  final _reason = TextEditingController(
    text: 'Extend the live campaign through a governed population exception.',
  );

  @override
  void initState() {
    super.initState();
    _numbers = TextEditingController();
  }

  @override
  void dispose() {
    _numbers.dispose();
    _positions.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add inspection targets'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _numbers,
              decoration: InputDecoration(
                labelText: 'Asset numbers',
                hintText: _compactNumberRanges(widget.availableNumbers),
                helperText: 'Use comma-separated values or ranges.',
              ),
              validator: (value) {
                final parsed = _parseNumbers(value);
                if (parsed == null || parsed.isEmpty) return 'Add a target.';
                final available = widget.availableNumbers.toSet();
                return parsed.every(available.contains)
                    ? null
                    : 'One or more assets are absent or inactive.';
              },
            ),
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              controller: _positions,
              decoration: const InputDecoration(
                labelText: 'Physical positions (optional)',
                hintText: 'B01, B02',
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              validator:
                  (value) =>
                      (value?.trim().length ?? 0) >= 5
                          ? null
                          : 'Record a reason.',
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
      FilledButton.icon(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _AddedTargetDraft(
              assetNumbers: _parseNumbers(_numbers.text)!,
              physicalPositions: _commaValues(_positions.text),
              reason: _reason.text.trim(),
            ),
          );
        },
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('Add'),
      ),
    ],
  );
}

class _InspectionReasonDialogState extends State<_InspectionReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.message),
        const SizedBox(height: BafSpacing.md),
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Reason',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed:
            _controller.text.trim().length >= widget.minimumLength
                ? () => Navigator.pop(context, _controller.text.trim())
                : null,
        child: const Text('Record'),
      ),
    ],
  );
}

class _FindingVerificationDraft {
  const _FindingVerificationDraft({
    required this.observationId,
    required this.outcome,
    required this.reason,
  });

  final String observationId;
  final String outcome;
  final String reason;
}

class _FindingVerificationDialog extends StatefulWidget {
  const _FindingVerificationDialog({
    required this.observations,
    required this.suggestedOutcome,
  });

  final List<InspectionObservation> observations;
  final String suggestedOutcome;

  @override
  State<_FindingVerificationDialog> createState() =>
      _FindingVerificationDialogState();
}

class _FindingVerificationDialogState
    extends State<_FindingVerificationDialog> {
  late String _observationId;
  late String _outcome;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _observationId = widget.observations.first.id;
    _outcome = widget.suggestedOutcome;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Verify inspection finding'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _observationId,
            decoration: const InputDecoration(
              labelText: 'Later verification reading',
            ),
            items:
                widget.observations
                    .map(
                      (observation) => DropdownMenuItem(
                        value: observation.id,
                        child: Text(
                          '${observation.displayValue} · ${DateFormat('dd MMM, HH:mm').format(observation.observedAt.toLocal())}',
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _observationId = value!),
          ),
          const SizedBox(height: BafSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _outcome,
            decoration: const InputDecoration(labelText: 'Outcome'),
            items: const [
              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              DropdownMenuItem(value: 'improved', child: Text('Improved')),
              DropdownMenuItem(value: 'unchanged', child: Text('Unchanged')),
              DropdownMenuItem(
                value: 'deteriorated',
                child: Text('Deteriorated'),
              ),
              DropdownMenuItem(value: 'recurred', child: Text('Recurred')),
              DropdownMenuItem(
                value: 'notComparable',
                child: Text('Not comparable'),
              ),
            ],
            onChanged: (value) => setState(() => _outcome = value!),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Verification reasoning',
              alignLabelWithHint: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed:
            _reason.text.trim().length >= 5
                ? () => Navigator.pop(
                  context,
                  _FindingVerificationDraft(
                    observationId: _observationId,
                    outcome: _outcome,
                    reason: _reason.text.trim(),
                  ),
                )
                : null,
        icon: const Icon(Icons.verified_outlined),
        label: const Text('Verify'),
      ),
    ],
  );
}

String _targetDispositionLabel(InspectionTargetDisposition value) =>
    switch (value) {
      InspectionTargetDisposition.pending => 'Pending',
      InspectionTargetDisposition.observed => 'Observed',
      InspectionTargetDisposition.deferred => 'Deferred',
      InspectionTargetDisposition.unavailable => 'Unavailable',
      InspectionTargetDisposition.excludedWithReason => 'Excluded with reason',
      InspectionTargetDisposition.requiresReaudit => 'Requires re-audit',
    };

String _findingStatusLabel(InspectionFindingStatus value) => switch (value) {
  InspectionFindingStatus.open => 'Open finding',
  InspectionFindingStatus.correctiveActionLinked => 'Corrective action linked',
  InspectionFindingStatus.awaitingVerification => 'Awaiting verification',
  InspectionFindingStatus.verifiedResolved => 'Verified resolved',
  InspectionFindingStatus.acceptedCondition => 'Continuing condition accepted',
  InspectionFindingStatus.invalidated => 'Invalidated with audit evidence',
};

String _comparisonLabel(InspectionComparisonOutcome value) => switch (value) {
  InspectionComparisonOutcome.improved => 'Improved from baseline',
  InspectionComparisonOutcome.unchanged => 'Unchanged from baseline',
  InspectionComparisonOutcome.deteriorated => 'Deteriorated from baseline',
  InspectionComparisonOutcome.resolved => 'Resolved from baseline',
  InspectionComparisonOutcome.recurred => 'Recurred from baseline',
  InspectionComparisonOutcome.notComparable => 'Not comparable to baseline',
};
