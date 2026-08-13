import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(
        title: Text(
          laneLabel == null || laneLabel.isEmpty
              ? 'Compliance inbox'
              : '$laneLabel compliance inbox',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_ComplianceInboxView>(
                segments: [
                  const ButtonSegment(
                    value: _ComplianceInboxView.forMyLane,
                    icon: Icon(Icons.inbox_outlined),
                    label: Text('For my lane'),
                  ),
                  const ButtonSegment(
                    value: _ComplianceInboxView.raisedByMe,
                    icon: Icon(Icons.outbox_outlined),
                    label: Text('Raised by me / my lane'),
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
          ),
          Expanded(
            child: asyncRows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('$error')),
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
                  return const Center(
                    child: Text('No actionable obligations in this view.'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(workflowPullServiceProvider).pull(),
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder:
                        (context, index) => _tile(context, visible[index]),
                  ),
                );
              },
            ),
          ),
        ],
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        child: Icon(
          row.statusKey == 'complied'
              ? Icons.fact_check_outlined
              : row.becameDueAt == null
              ? Icons.schedule_outlined
              : Icons.assignment_late_outlined,
        ),
      ),
      title: Text(row.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Text(
            '${row.requestPurposeLabel} · '
            '${row.originLaneKey?.toUpperCase() ?? 'UNATTRIBUTED'} -> '
            '${row.targetLaneKey.toUpperCase()} · ${row.statusKey}',
          ),
          if (row.raisedUnderCoordination)
            const Text('Raised under supervisory coordination'),
          Text(dueText),
          if (row.description.trim().isNotEmpty)
            Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (row.escalationTier > 0)
            Chip(
              avatar: const Icon(Icons.priority_high, size: 16),
              label: Text('T${row.escalationTier}'),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ComplianceDetailScreen(record: row),
            ),
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
