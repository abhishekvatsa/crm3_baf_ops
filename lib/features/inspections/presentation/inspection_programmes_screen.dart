import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/baf_design_system.dart';
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
              () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          error:
              (_, _) => const Scaffold(
                body: Center(
                  child: Text('Could not verify inspection authority.'),
                ),
              ),
          data:
              (actor) =>
                  actor == null
                      ? const Scaffold(
                        body: Center(child: Text('Sign in is required.')),
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
    return campaigns.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
                        ? () => _createCampaign(context, ref, definitions)
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
                    campaign.expectedPopulation == null
                        ? '${campaign.distinctTargetCount} targets'
                        : '${campaign.distinctTargetCount}/${campaign.expectedPopulation}',
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
      return const Scaffold(body: Center(child: Text('Sign in is required.')));
    }
    return campaigns.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Inspection programme')),
            body: const Center(
              child: Text('Campaign could not be read safely.'),
            ),
          ),
      data: (rows) {
        InspectionCampaign? campaign;
        for (final row in rows) {
          if (row.id == campaignId) campaign = row;
        }
        if (campaign == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Inspection programme')),
            body: const Center(child: Text('Campaign was not found.')),
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
    final classes =
        ref.watch(assetClassesProvider).value ?? const <AssetClassRecord>[];
    final classId =
        campaign.assetClassId ?? _legacyClassId(classes, campaign.assetTypeKey);
    final nodes =
        classId == null
            ? const <AssetHierarchyNode>[]
            : ref.watch(assetHierarchyNodesProvider(classId)).value ??
                const <AssetHierarchyNode>[];
    final instances = (ref.watch(allAssetInstancesProvider).value ??
            const <AssetInstanceRecord>[])
        .where(
          (item) =>
              classId == null
                  ? campaign.targetAssetNumbers.contains(item.assetNumber)
                  : item.assetClassId == classId,
        )
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
              onSelected:
                  (status) =>
                      _transitionCampaign(context, ref, campaign, status),
              itemBuilder:
                  (_) => [
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
          final findings = currentRows.where((item) => item.outOfRange).length;
          final observedAssets =
              currentRows.map((item) => item.assetNumber).toSet();
          final missing = campaign.targetAssetNumbers
              .where((number) => !observedAssets.contains(number))
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
                currentFindingCount: findings,
              ),
              const SizedBox(height: BafSpacing.lg),
              if (campaign.definition.preconditions.isNotEmpty)
                _DetailBand(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Before observing',
                  body: campaign.definition.preconditions.join(' · '),
                  color: BafColors.warning,
                ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.md),
                _MissingTargets(numbers: missing),
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
          if (coverage != null) ...[
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
              '${(coverage * 100).round()}% of expected population covered · ${campaign.remainingPopulation} remaining',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

class _MissingTargets extends StatelessWidget {
  const _MissingTargets({required this.numbers});

  final List<int> numbers;

  @override
  Widget build(BuildContext context) => _DetailBand(
    icon: Icons.pending_actions_outlined,
    title:
        '${numbers.length} listed asset${numbers.length == 1 ? '' : 's'} not yet observed',
    body:
        numbers.length <= 24
            ? numbers.join(', ')
            : '${numbers.take(24).join(', ')} and ${numbers.length - 24} more',
    color: BafColors.instrument,
  );
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

String? _legacyClassId(List<AssetClassRecord> classes, String type) {
  for (final item in classes) {
    if (item.isActive && item.legacyAssetTypeKey == type) return item.id;
  }
  return null;
}

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
) async {
  final draft = await showDialog<_InspectionCampaignDraft>(
    context: context,
    builder:
        (_) => _InspectionCampaignEditor(
          definitions: definitions.where((item) => item.isActive).toList(),
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
  final confirmed =
      status != 'closed' ||
      await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Close this programme?'),
                  content: Text(
                    campaign.remainingPopulation == null ||
                            campaign.remainingPopulation == 0
                        ? 'The campaign will become read-only. Its observations and correction history remain available.'
                        : '${campaign.remainingPopulation} expected targets remain unobserved. Partial closure is allowed and will remain visible.',
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
