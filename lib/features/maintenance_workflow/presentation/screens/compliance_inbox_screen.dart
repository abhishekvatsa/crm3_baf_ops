import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/compliance_request_record.dart';
import '../../providers/workflow_providers.dart';
import 'compliance_detail_screen.dart';

enum _ComplianceInboxView { forMyLane, raisedByMe, all }

class ComplianceInboxScreen extends ConsumerStatefulWidget {
  final String? laneKey;

  const ComplianceInboxScreen({super.key, this.laneKey});

  @override
  ConsumerState<ComplianceInboxScreen> createState() =>
      _ComplianceInboxScreenState();
}

class _ComplianceInboxScreenState extends ConsumerState<ComplianceInboxScreen> {
  _ComplianceInboxView _view = _ComplianceInboxView.forMyLane;

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(workflowAllComplianceProvider);
    final actor = ref.watch(currentAppUserProvider).value;
    final canViewAll = actor?.isModuleLifecycleSupervisor ?? false;
    final effectiveView =
        !canViewAll && _view == _ComplianceInboxView.all
            ? _ComplianceInboxView.forMyLane
            : _view;
    final laneLabel = widget.laneKey?.trim().toUpperCase();

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: BafAppBarTitle(
          title:
              laneLabel == null || laneLabel.isEmpty
                  ? 'Compliance inbox'
                  : '$laneLabel compliance inbox',
          subtitle: 'Assurance, deferment and operational support',
          icon: Icons.inbox_outlined,
          accent: BafColors.directives,
        ),
      ),
      body: BafContentFrame(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_ComplianceInboxView>(
                showSelectedIcon: false,
                segments: [
                  const ButtonSegment(
                    value: _ComplianceInboxView.forMyLane,
                    icon: Icon(Icons.inbox_outlined),
                    label: Text('For my lane'),
                  ),
                  const ButtonSegment(
                    value: _ComplianceInboxView.raisedByMe,
                    icon: Icon(Icons.outbox_outlined),
                    label: Text('Raised by us'),
                  ),
                  if (canViewAll)
                    const ButtonSegment(
                      value: _ComplianceInboxView.all,
                      icon: Icon(Icons.supervisor_account_outlined),
                      label: Text('All'),
                    ),
                ],
                selected: <_ComplianceInboxView>{effectiveView},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    setState(() => _view = selection.first);
                  }
                },
              ),
            ),
            const SizedBox(height: BafSpacing.md),
            Expanded(
              child: asyncRows.when(
                loading:
                    () => const BafLoadingPanel(
                      label: 'Loading compliance obligations',
                      color: BafColors.directives,
                    ),
                error:
                    (error, _) => BafStatePanel.error(
                      title: 'Compliance inbox is unavailable',
                      message: '$error',
                      onPrimary:
                          () => ref.invalidate(workflowAllComplianceProvider),
                    ),
                data: (rows) {
                  final visible = rows
                    .where(_isActionable)
                    .where(
                      (row) => _matchesView(
                        row,
                        view: effectiveView,
                        actorUid: actor?.uid,
                        canWorkLane:
                            (lane) =>
                                actor?.canAcknowledgeOrWorkMaintenanceLane(
                                  lane,
                                ) ??
                                false,
                        canViewAll: canViewAll,
                      ),
                    )
                    .toList(growable: false)..sort(_sortRows);
                  if (visible.isEmpty) {
                    return BafStatePanel.empty(
                      title: 'No actionable obligations',
                      message: 'No actionable obligations in this view.',
                      icon: Icons.task_alt_rounded,
                      color: BafColors.success,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh:
                        () => ref.read(workflowPullServiceProvider).pull(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: visible.length,
                      separatorBuilder:
                          (_, __) => const SizedBox(height: BafSpacing.sm),
                      itemBuilder:
                          (context, index) => _tile(context, visible[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesView(
    ComplianceRequestRecord row, {
    required _ComplianceInboxView view,
    required String? actorUid,
    required bool Function(String laneKey) canWorkLane,
    required bool canViewAll,
  }) {
    final restrictedLane = widget.laneKey?.trim().toLowerCase();
    switch (view) {
      case _ComplianceInboxView.forMyLane:
        if (restrictedLane != null &&
            restrictedLane.isNotEmpty &&
            row.targetLaneKey != restrictedLane) {
          return false;
        }
        return canWorkLane(row.targetLaneKey);
      case _ComplianceInboxView.raisedByMe:
        return (actorUid != null && row.raisedByUid == actorUid) ||
            (row.originLaneKey != null && canWorkLane(row.originLaneKey!));
      case _ComplianceInboxView.all:
        return canViewAll;
    }
  }

  bool _isActionable(ComplianceRequestRecord row) =>
      row.statusKey != 'confirmedClosed' &&
      row.statusKey != 'superseded' &&
      row.statusKey != 'cancelled';

  int _sortRows(ComplianceRequestRecord left, ComplianceRequestRecord right) {
    final tierCompare = right.escalationTier.compareTo(left.escalationTier);
    if (tierCompare != 0) return tierCompare;
    final leftDue = left.becameDueAt ?? DateTime(9999);
    final rightDue = right.becameDueAt ?? DateTime(9999);
    final dueCompare = leftDue.compareTo(rightDue);
    if (dueCompare != 0) return dueCompare;
    return right.updatedAt.compareTo(left.updatedAt);
  }

  Widget _tile(BuildContext context, ComplianceRequestRecord row) {
    final dueText = _dueText(row);
    final overdue =
        row.becameDueAt != null &&
        ((row.statusKey == 'raised'
                    ? row.acknowledgementDueAt
                    : row.complianceDueAt)
                ?.isBefore(DateTime.now()) ??
            false);
    final color =
        overdue
            ? BafColors.danger
            : row.statusKey == 'complied'
            ? BafColors.success
            : row.becameDueAt == null
            ? BafColors.steel
            : BafColors.warning;
    return BafRecordSurface(
      accent: color,
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ComplianceDetailScreen(record: row),
            ),
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(BafRadius.small),
            ),
            child: Icon(
              row.statusKey == 'complied'
                  ? Icons.fact_check_outlined
                  : row.becameDueAt == null
                  ? Icons.schedule_outlined
                  : Icons.assignment_late_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: BafSpacing.xs),
                Wrap(
                  spacing: BafSpacing.sm,
                  runSpacing: BafSpacing.xs,
                  children: [
                    StatusBadge(label: row.requestPurposeLabel, color: color),
                    StatusBadge(
                      label:
                          '${row.originLaneKey?.toUpperCase() ?? 'UNATTRIBUTED'} to ${row.targetLaneKey.toUpperCase()}',
                      color: BafColors.audit,
                    ),
                    if (row.escalationTier > 0)
                      StatusBadge(
                        label: 'Tier ${row.escalationTier}',
                        color: BafColors.danger,
                        icon: Icons.priority_high_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: BafSpacing.sm),
                Text(
                  dueText,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                if (row.raisedUnderCoordination)
                  const Text('Raised under supervisory coordination'),
                if (row.description.trim().isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.xs),
                  Text(
                    row.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          const Icon(
            Icons.chevron_right_rounded,
            color: BafColors.textSecondary,
          ),
        ],
      ),
    );
  }

  String _dueText(ComplianceRequestRecord row) {
    if (row.becameDueAt == null) {
      final reference = row.conditionRef?.trim();
      return reference == null || reference.isEmpty
          ? 'Dormant until its condition is confirmed'
          : 'Dormant until ${row.conditionTypeKey}: $reference';
    }
    final dueAt =
        row.statusKey == 'raised'
            ? row.acknowledgementDueAt
            : row.complianceDueAt;
    if (dueAt == null) return 'Due since ${_formatDate(row.becameDueAt!)}';
    final overdue = DateTime.now().isAfter(dueAt);
    return overdue
        ? 'Overdue since ${_formatDate(dueAt)}'
        : 'Due by ${_formatDate(dueAt)}';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}-${two(local.month)}-${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
