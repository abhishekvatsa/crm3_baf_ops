import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../data/asset_operational_condition.dart';
import '../data/asset_registry_model.dart';
import '../domain/plant_asset_overview.dart';
import '../providers/asset_hierarchy_provider.dart';
import '../providers/plant_asset_overview_provider.dart';

class AssetConditionBoard extends ConsumerWidget {
  const AssetConditionBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentAppUserProvider).value;
    final overview = ref.watch(plantAssetOverviewProvider);
    final openTickets = ref.watch(openTicketsProvider);
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ConditionLoadError(error: error),
              data:
                  (value) => _ConditionBoardBody(
                    overview: value,
                    user: user,
                    openTickets:
                        openTickets.value ?? const <MaintenanceRecord>[],
                    ticketLoadFailed: openTickets.hasError,
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

  const PlantOverviewPanel({
    super.key,
    required this.overview,
    required this.onOpen,
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
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.underMaintenance,
                                label: 'Maintenance',
                                color: BafColors.maintenance,
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.temporarilyBlocked,
                                label: 'Stuck-up',
                                color: BafColors.instrument,
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.down,
                                label: 'Down',
                                color: BafColors.danger,
                              ),
                              _PlantMetric(
                                width: width,
                                value: value.unfit,
                                label: 'Unfit',
                                color: BafColors.warning,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: BafSpacing.sm),
                      ...value.classes
                          .where((summary) => summary.total > 0)
                          .take(2)
                          .map(
                            (summary) => Padding(
                              padding: const EdgeInsets.only(
                                top: BafSpacing.xs,
                              ),
                              child: Text(
                                '${summary.assetClass.name}: ${summary.total} total, ${summary.underMaintenance} maintenance, ${summary.temporarilyBlocked} stuck-up, ${summary.down + summary.unfit} unavailable',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: BafColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

class _PlantMetric extends StatelessWidget {
  final double? width;
  final int value;
  final String label;
  final Color color;

  const _PlantMetric({
    this.width,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    constraints: const BoxConstraints(minHeight: 54),
    padding: const EdgeInsets.symmetric(
      horizontal: BafSpacing.xs,
      vertical: BafSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(BafRadius.small),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$value ${label.toLowerCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
      ],
    ),
  );
}

class _ConditionBoardBody extends StatelessWidget {
  final PlantAssetOverview overview;
  final AppUser? user;
  final List<MaintenanceRecord> openTickets;
  final bool ticketLoadFailed;

  const _ConditionBoardBody({
    required this.overview,
    required this.user,
    required this.openTickets,
    required this.ticketLoadFailed,
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
            StatusBadge(
              label: '${overview.total} registered',
              color: BafColors.assets,
            ),
            StatusBadge(
              label: '${overview.available} available',
              color: BafColors.success,
            ),
            StatusBadge(
              label: '${overview.underMaintenance} maintenance',
              color: BafColors.maintenance,
            ),
            StatusBadge(
              label: '${overview.temporarilyBlocked} stuck-up',
              color: BafColors.instrument,
            ),
            StatusBadge(
              label: '${overview.down} down',
              color: BafColors.danger,
            ),
            StatusBadge(
              label: '${overview.unfit} unfit',
              color: BafColors.warning,
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
        ...overview.classes
            .where((summary) => summary.total > 0)
            .map(
              (summary) => _AssetClassSection(
                summary: summary,
                user: user,
                openTickets: openTickets,
              ),
            ),
      ],
    );
  }
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
  final AppUser? user;
  final List<MaintenanceRecord> openTickets;

  const _AssetConditionRow({
    required this.state,
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
        (state.isDown || state.isUnfit);
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
                  const SizedBox(height: BafSpacing.xs),
                  Text(
                    'Declared ${DateFormat('dd MMM, HH:mm').format(state.operationalCondition!.declaredAt!.toLocal())} by ${state.operationalCondition!.declaredByName}',
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
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
                    if (canDeclare && !state.isUnfit)
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
      showDragHandle: true,
      builder:
          (context) => _DeclareConditionSheet(
            asset: state.asset,
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
  final String reason;
  final List<String> linkedIssueIds;

  const _ConditionDraft({
    required this.causes,
    required this.reason,
    required this.linkedIssueIds,
  });
}

class _DeclareConditionSheet extends StatefulWidget {
  final AssetInstanceRecord asset;
  final AssetOperationalCondition condition;
  final List<MaintenanceRecord> tickets;

  const _DeclareConditionSheet({
    required this.asset,
    required this.condition,
    required this.tickets,
  });

  @override
  State<_DeclareConditionSheet> createState() => _DeclareConditionSheetState();
}

class _DeclareConditionSheetState extends State<_DeclareConditionSheet> {
  final _reason = TextEditingController();
  final Set<AssetConditionCause> _causes = {};
  final Set<String> _tickets = {};

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
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
    if (_causes.isEmpty || reason.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose at least one cause and enter a clear reason.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      _ConditionDraft(
        causes: Set<AssetConditionCause>.unmodifiable(_causes),
        reason: reason,
        linkedIssueIds: _tickets.toList(growable: false),
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
            if (reason.length < 8) {
              setState(() => _error = 'Enter at least 8 characters.');
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
  if (state.isUnfit) return BafColors.warning;
  if (state.isUnderMaintenance) return BafColors.maintenance;
  if (state.isAdministrativelyOutOfService) return BafColors.admin;
  return BafColors.success;
}

IconData _primaryIcon(PlantAssetState state) {
  if (state.isTemporarilyBlocked) return Icons.link_off_rounded;
  if (state.isDown) return Icons.power_off_rounded;
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
