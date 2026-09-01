import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../audit/models/audit_event_model.dart';
import '../../audit/providers/audit_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../../reports/domain/maintenance_ticket_dossier.dart';
import '../../reports/presentation/report_provenance_builder.dart';
import '../../reports/presentation/structured_report_pdf_screen.dart';
import '../data/maintenance_model.dart';
import '../domain/issue_lane_plan.dart';
import 'maintenance_ticket_correction_history.dart';

class MaintenanceTicketDetailScreen extends ConsumerWidget {
  const MaintenanceTicketDetailScreen({
    super.key,
    required this.ticket,
    this.onCorrect,
  });

  final MaintenanceRecord ticket;
  final VoidCallback? onCorrect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actor = ref.watch(currentAppUserProvider).asData?.value;
    final cleanTicketId = ticket.firestoreId?.trim();
    final correctionAudit =
        cleanTicketId == null || cleanTicketId.isEmpty
            ? const AsyncData<List<AuditEvent>>(<AuditEvent>[])
            : ref.watch(
              maintenanceTicketCorrectionAuditProvider(cleanTicketId),
            );
    final laneRead = ticket.issueLanePlanReadResult;
    final lanePlan = laneRead.value;
    final actionsRead = ticket.actionsReadResult;
    final historyRead = ticket.resolutionHistoryReadResult;
    final hierarchy = ticket.assetHierarchyReference;
    final innerCover = hierarchy?.innerCoverAssociation;
    final administrativeClosure = ticket.administrativeClosure;
    final closedAt = ticket.endDate;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Issue record',
          subtitle: 'Full maintenance evidence and accountability',
          icon: Icons.assignment_outlined,
          accent: BafColors.maintenance,
        ),
        actions: [
          if (actor?.canViewReports == true)
            IconButton(
              key: const ValueKey('ticket-detail-pdf'),
              tooltip:
                  correctionAudit.isLoading
                      ? 'Verifying correction evidence'
                      : correctionAudit.hasError
                      ? 'Correction evidence is unavailable'
                      : 'Create complete PDF dossier',
              onPressed:
                  correctionAudit.asData == null
                      ? null
                      : () => _openPdfDossier(
                        context,
                        ref,
                        actor!.name,
                        correctionAudit.requireValue,
                      ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (onCorrect != null)
            IconButton(
              key: const ValueKey('ticket-detail-correct'),
              tooltip: 'Record an audited correction',
              onPressed: onCorrect,
              icon: const Icon(Icons.edit_note_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: BafSpacing.xl),
        children: [
          _IssueIdentityHeader(ticket: ticket),
          _DetailSection(
            title: 'Issue context',
            icon: Icons.tune_rounded,
            children: [
              _DetailValue(
                label: 'Maintenance type',
                value: _enumLabel(ticket.maintenanceType.name),
              ),
              if (_hasText(ticket.classification))
                _DetailValue(
                  label: 'Classification',
                  value: maintenanceIssueClassificationLabel(
                    ticket.classification!,
                  ),
                ),
              if (ticket.chargeNoAtEvent != null)
                _DetailValue(
                  label: 'Charge at event',
                  value: '${ticket.chargeNoAtEvent}',
                ),
              if (_hasText(ticket.component))
                _DetailValue(label: 'Component', value: ticket.component!),
              if (_hasText(ticket.subsystem))
                _DetailValue(label: 'Subsystem', value: ticket.subsystem!),
              if (_hasText(ticket.tag))
                _DetailValue(label: 'Tag', value: ticket.tag!),
              if (hierarchy != null)
                _DetailValue(
                  label: 'Governed hierarchy',
                  value: [
                    hierarchy.assetClassName,
                    ...hierarchy.hierarchyPath,
                  ].where((value) => value.trim().isNotEmpty).join(' / '),
                ),
              if (innerCover != null)
                _DetailValue(
                  label: 'Inner Cover at event',
                  value:
                      innerCover.innerCoverSerialNumber == null
                          ? 'No Inner Cover was linked'
                          : '${innerCover.innerCoverSerialNumber} on Base ${innerCover.baseAssetNumber}',
                ),
            ],
          ),
          _DetailSection(
            title: 'Accountability',
            icon: Icons.account_tree_outlined,
            children: [
              if (lanePlan == null)
                _EvidenceWarning(
                  text:
                      'Lane evidence cannot be displayed safely: ${laneRead.error}',
                )
              else
                for (final lane in lanePlan.assignedLanes)
                  _LaneProgressRow(
                    lane: lane,
                    acknowledged: lanePlan.acknowledgedLanes.contains(lane),
                    completed: lanePlan.completedLanes.contains(lane),
                    completionEvidence: lanePlan.completionEvidence[lane],
                  ),
              if (_hasText(ticket.otherDepartment))
                _DetailValue(
                  label: 'Other department',
                  value: ticket.otherDepartment!,
                ),
              if (_hasText(ticket.acknowledgedByName))
                _DetailValue(
                  label: 'First acknowledgement',
                  value:
                      '${ticket.acknowledgedByName}${ticket.acknowledgedAt == null ? '' : ' · ${_dateTime(ticket.acknowledgedAt!)}'}',
                ),
              if (ticket.teamsInvolved.isNotEmpty)
                _DetailValue(
                  label: 'Teams involved',
                  value: ticket.teamsInvolved.join(', '),
                ),
            ],
          ),
          _DetailSection(
            title: 'Timeline and people',
            icon: Icons.history_rounded,
            children: [
              _DetailValue(
                label: 'Issue started',
                value: _dateTime(ticket.startDate),
              ),
              _DetailValue(
                label: 'Raised',
                value:
                    '${_dateTime(ticket.createdAt)} · ${_firstText(ticket.loggedByName, ticket.reportedBy, 'Unknown')}',
              ),
              if (ticket.reopenedAt != null)
                _DetailValue(
                  label: 'Reopened',
                  value:
                      '${_dateTime(ticket.reopenedAt!)} · ${_firstText(ticket.reopenedByName, ticket.reopenedByUid, 'Unknown')}',
                ),
              if (_hasText(ticket.reopenReason))
                _DetailValue(
                  label: 'Reopen reason',
                  value: ticket.reopenReason!,
                ),
              if (closedAt != null)
                _DetailValue(
                  label: 'Closed',
                  value:
                      '${_dateTime(closedAt)} · ${_firstText(ticket.closedByName, null, 'Unknown')}',
                ),
              if (ticket.downtimeHours != null)
                _DetailValue(
                  label: 'Recorded downtime',
                  value: '${ticket.downtimeHours!.toStringAsFixed(2)} hours',
                ),
              if (_hasText(ticket.performedBy))
                _DetailValue(
                  label: 'Work performed by',
                  value: ticket.performedBy!,
                ),
              _DetailValue(
                label: 'Last record update',
                value: _dateTime(ticket.updatedAt),
              ),
            ],
          ),
          _DetailSection(
            title: 'Work recorded',
            icon: Icons.engineering_outlined,
            children: [
              if (!actionsRead.isValid)
                _EvidenceWarning(
                  text:
                      'Work-action evidence needs repair before it can be displayed: ${actionsRead.error}',
                )
              else if (actionsRead.entries.isEmpty)
                const _EmptyEvidence(
                  text: 'No structured component actions were recorded.',
                )
              else
                for (var index = 0; index < actionsRead.entries.length; index++)
                  _ComponentActionView(
                    action: actionsRead.entries[index],
                    sequence: index + 1,
                  ),
              if (_hasText(ticket.remarks))
                _DetailValue(label: 'Final remarks', value: ticket.remarks!),
            ],
          ),
          if (ticket.isClosed ||
              !historyRead.isValid ||
              historyRead.entries.isNotEmpty)
            _DetailSection(
              title:
                  ticket.isClosed
                      ? 'Closure evidence'
                      : 'Previous closure evidence',
              icon:
                  administrativeClosure == null
                      ? Icons.task_alt_rounded
                      : Icons.inventory_2_outlined,
              children: [
                if (ticket.isClosed)
                  _DetailValue(
                    label: 'Outcome',
                    value:
                        administrativeClosure == null
                            ? 'Technically resolved'
                            : administrativeClosure.disposition.name ==
                                'stillRelevant'
                            ? 'Closed without resolution; still relevant'
                            : 'Closed without resolution; relevance ended',
                  ),
                if (ticket.isClosed && administrativeClosure != null)
                  _DetailValue(
                    label: 'Administrative reason',
                    value: administrativeClosure.reason,
                  ),
                if (!historyRead.isValid)
                  _EvidenceWarning(
                    text:
                        'Previous resolution evidence needs repair: ${historyRead.error}',
                  )
                else if (historyRead.entries.isNotEmpty)
                  for (
                    var index = 0;
                    index < historyRead.entries.length;
                    index++
                  )
                    _ResolutionHistoryView(
                      entry: historyRead.entries[index],
                      sequence: index + 1,
                    ),
              ],
            ),
          if (ticket.isWorkflowLinked ||
              ticket.operationalEventIssueLinkIds.isNotEmpty)
            _DetailSection(
              title: 'Connected controls',
              icon: Icons.hub_outlined,
              children: [
                if (ticket.isWorkflowLinked)
                  _DetailValue(
                    label: 'Coordination workflow',
                    value:
                        '${ticket.workflowStateLabel}${_hasText(ticket.workflowCorrectionReason) ? ' · ${ticket.workflowCorrectionReason}' : ''}',
                  ),
                if (ticket.operationalEventIssueLinkIds.isNotEmpty)
                  _DetailValue(
                    label: 'Operational event links',
                    value:
                        '${ticket.operationalEventIssueLinkIds.length} linked event record${ticket.operationalEventIssueLinkIds.length == 1 ? '' : 's'}',
                  ),
              ],
            ),
          MaintenanceTicketCorrectionHistorySection(
            ticketId: ticket.firestoreId,
          ),
          _DetailSection(
            title: 'Record assurance',
            icon: Icons.verified_user_outlined,
            children: [
              _DetailValue(
                label: 'Synchronization',
                value: ticket.isSynced ? 'Verified server record' : 'Pending',
              ),
              _DetailValue(label: 'Record version', value: '${ticket.version}'),
              if (_hasText(ticket.firestoreId))
                _DetailValue(
                  label: 'Governed record ID',
                  value: ticket.firestoreId!,
                ),
              if (onCorrect != null)
                Container(
                  margin: const EdgeInsets.only(top: BafSpacing.sm),
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Admin/SI corrections retain before-and-after values, actor, time, and reason in the audit trail.',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: BafSpacing.sm),
                      IconButton.filledTonal(
                        tooltip: 'Record an audited correction',
                        onPressed: onCorrect,
                        icon: const Icon(Icons.edit_note_rounded),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openPdfDossier(
    BuildContext context,
    WidgetRef ref,
    String actorName,
    List<AuditEvent> correctionEvents,
  ) {
    try {
      final report = buildMaintenanceTicketDossier(
        ticket: ticket,
        correctionEvents: correctionEvents,
        generatedAt: DateTime.now(),
        generatedByName: actorName,
        provenance: readApplicationReportProvenance(
          ref,
          completenessNotes: const <String>[
            'This dossier preserves the complete locally available issue '
                'lifecycle, structured work actions and correction evidence; '
                'its synchronization and version state are stated in the document.',
          ],
        ),
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StructuredReportPdfPreviewScreen(report: report),
        ),
      );
    } on Object catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The issue dossier could not be generated: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    }
  }

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;

  static String _firstText(String? first, String? second, String fallback) =>
      _hasText(first)
          ? first!.trim()
          : _hasText(second)
          ? second!.trim()
          : fallback;

  static String _dateTime(DateTime value) =>
      DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());

  static String _enumLabel(String value) {
    final words = value.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return words[0].toUpperCase() + words.substring(1);
  }
}

class _IssueIdentityHeader extends StatelessWidget {
  const _IssueIdentityHeader({required this.ticket});

  final MaintenanceRecord ticket;

  @override
  Widget build(BuildContext context) {
    final accent = _laneColor(ticket.routedTo);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.lg,
        BafSpacing.xl,
        BafSpacing.lg,
        BafSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: accent, width: 6),
          bottom: const BorderSide(color: BafColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(_assetIcon(ticket.assetType), color: accent),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_assetLabel(ticket.assetType)} ${ticket.assetNumber}',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticket.description,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(
                label: ticket.lifecycleSummaryLabel,
                color:
                    ticket.isClosed
                        ? ticket.wasTechnicallyResolved
                            ? BafColors.success
                            : BafColors.warning
                        : BafColors.maintenance,
                icon:
                    ticket.isClosed
                        ? Icons.task_alt_rounded
                        : Icons.timelapse_rounded,
              ),
              StatusBadge(
                label: _routeLabel(ticket.routedTo),
                color: accent,
                icon: Icons.engineering_rounded,
              ),
              if (ticket.isCritical)
                const StatusBadge(
                  label: 'Critical',
                  color: BafColors.danger,
                  icon: Icons.priority_high_rounded,
                ),
              StatusBadge(
                label: ticket.isSynced ? 'Server verified' : 'Sync pending',
                color: ticket.isSynced ? BafColors.sync : BafColors.warning,
                icon:
                    ticket.isSynced
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: BafColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: BafColors.maintenance, size: 21),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          ..._spaced(children),
        ],
      ),
    );
  }

  static List<Widget> _spaced(List<Widget> children) {
    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) result.add(const SizedBox(height: 10));
      result.add(children[index]);
    }
    return result;
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 126,
          child: Text(
            label,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _LaneProgressRow extends StatelessWidget {
  const _LaneProgressRow({
    required this.lane,
    required this.acknowledged,
    required this.completed,
    required this.completionEvidence,
  });

  final String lane;
  final bool acknowledged;
  final bool completed;
  final IssueLaneCompletionEvidence? completionEvidence;

  @override
  Widget build(BuildContext context) {
    final state =
        completed
            ? 'Completed'
            : acknowledged
            ? 'Acknowledged'
            : 'Awaiting acknowledgement';
    final color =
        completed
            ? BafColors.success
            : acknowledged
            ? BafColors.warning
            : BafColors.textSecondary;
    final evidenceText =
        !completed
            ? null
            : completionEvidence == null
            ? 'Exact lane completion time was not retained for this record'
            : '${MaintenanceTicketDetailScreen._dateTime(completionEvidence!.completedAt)} · ${completionEvidence!.completedByName}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            completed
                ? Icons.task_alt_rounded
                : acknowledged
                ? Icons.verified_rounded
                : Icons.schedule_rounded,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _routeLabel(RoutedTo.values.byName(lane)),
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (evidenceText != null) ...[
                const SizedBox(height: 2),
                Text(
                  evidenceText,
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: BafSpacing.sm),
        Text(
          state,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ComponentActionView extends StatelessWidget {
  const _ComponentActionView({required this.action, required this.sequence});

  final ComponentAction action;
  final int sequence;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (_text(action.resolution) != null) action.resolution!.trim(),
      if (_text(action.issue) != null) action.issue!.trim(),
      if (_text(action.remarks) != null) action.remarks!.trim(),
    ];
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$sequence. ${action.component}',
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              details.join(' · '),
              style: const TextStyle(
                color: BafColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final locator in _actionLocatorLabels(action))
                _SmallEvidenceChip(label: locator),
              _SmallEvidenceChip(label: _enumLabel(action.actionType.name)),
              if (action.replacement != null)
                _SmallEvidenceChip(
                  label: 'Replacement: ${_enumLabel(action.replacement!.name)}',
                ),
              _SmallEvidenceChip(
                label: 'Action time ${_evidenceDateTime(action.createdAt)}',
              ),
              if (action.updatedAt != null &&
                  !_sameInstant(action.createdAt, action.updatedAt!))
                _SmallEvidenceChip(
                  label: 'Updated ${_evidenceDateTime(action.updatedAt!)}',
                ),
              if (_text(action.performedBy) != null)
                _SmallEvidenceChip(label: action.performedBy!),
              if (action.burnerPosition != null)
                _SmallEvidenceChip(label: 'Burner ${action.burnerPosition}'),
              if (_text(action.burnerActionCode) != null)
                _SmallEvidenceChip(label: _enumLabel(action.burnerActionCode!)),
              if (_text(action.burnerOutcome) != null)
                _SmallEvidenceChip(label: _enumLabel(action.burnerOutcome!)),
              if (action.burnerMicroampReading != null)
                _SmallEvidenceChip(
                  label:
                      '${action.burnerMicroampReading!.toStringAsFixed(3)} µA',
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _text(String? value) =>
      value?.trim().isNotEmpty == true ? value : null;
}

class _ResolutionHistoryView extends StatelessWidget {
  const _ResolutionHistoryView({required this.entry, required this.sequence});

  final ResolutionHistory entry;
  final int sequence;

  @override
  Widget build(BuildContext context) {
    final actions = ComponentAction.decode(
      entry.actionsJson,
      source: 'earlier closure $sequence',
    );
    return Container(
      key: ValueKey('earlier-closure-$sequence'),
      padding: const EdgeInsets.only(top: BafSpacing.md),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BafColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Earlier closure $sequence',
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: BafSpacing.sm),
          ..._DetailSection._spaced([
            _DetailValue(
              label: 'Closed',
              value: [
                if (entry.resolvedAt != null)
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
                  ).format(entry.resolvedAt!.toLocal()),
                if (_text(entry.resolvedByName) != null)
                  entry.resolvedByName!.trim(),
              ].join(' · '),
            ),
            if (entry.downtimeHours != null)
              _DetailValue(
                label: 'Downtime',
                value: '${entry.downtimeHours!.toStringAsFixed(2)} hours',
              ),
            if (entry.teamsInvolved.isNotEmpty)
              _DetailValue(
                label: 'Teams involved',
                value: entry.teamsInvolved.join(', '),
              ),
            if (entry.lanePlan != null) ...[
              const _DetailValue(
                label: 'Lane accountability',
                value: 'Completion evidence retained for this closure',
              ),
              for (final lane in entry.lanePlan!.assignedLanes)
                _LaneProgressRow(
                  lane: lane,
                  acknowledged: entry.lanePlan!.acknowledgedLanes.contains(
                    lane,
                  ),
                  completed: entry.lanePlan!.completedLanes.contains(lane),
                  completionEvidence: entry.lanePlan!.completionEvidence[lane],
                ),
            ],
            if (_text(entry.remarks) != null)
              _DetailValue(
                label: 'Closure remarks',
                value: entry.remarks!.trim(),
              ),
            if (entry.reopenedAt != null)
              _DetailValue(
                label:
                    entry.reopenedByWorkflow
                        ? 'Reopened for correction'
                        : 'Reopened',
                value: [
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
                  ).format(entry.reopenedAt!.toLocal()),
                  if (_text(entry.reopenedByName) != null)
                    entry.reopenedByName!.trim(),
                ].join(' · '),
              ),
            if (_text(entry.reopenReason) != null)
              _DetailValue(
                label: 'Reopen reason',
                value: entry.reopenReason!.trim(),
              ),
            if (entry.reopenedByWorkflow && entry.reopenedAt == null)
              const _DetailValue(
                label: 'Reopened for correction',
                value: 'Governed workflow (legacy event)',
              ),
            if (actions.isEmpty)
              const _EmptyEvidence(
                text:
                    'No structured work actions were recorded in this closure.',
              )
            else
              for (var index = 0; index < actions.length; index++)
                _DetailValue(
                  label: 'Work action ${index + 1}',
                  value: _actionSummary(actions[index]),
                ),
          ]),
        ],
      ),
    );
  }

  static String? _text(String? value) =>
      value?.trim().isNotEmpty == true ? value : null;

  static String _actionSummary(ComponentAction action) => <String>[
    action.component,
    _enumLabel(action.actionType.name),
    if (action.replacement != null)
      'Replacement: ${_enumLabel(action.replacement!.name)}',
    'Action time ${_evidenceDateTime(action.createdAt)}',
    if (action.updatedAt != null &&
        !_sameInstant(action.createdAt, action.updatedAt!))
      'Updated ${_evidenceDateTime(action.updatedAt!)}',
    ..._actionLocatorLabels(action),
    if (_text(action.performedBy) != null) action.performedBy!.trim(),
    if (action.burnerPosition != null) 'Burner ${action.burnerPosition}',
    if (_text(action.burnerActionCode) != null)
      _enumLabel(action.burnerActionCode!),
    if (_text(action.burnerOutcome) != null) _enumLabel(action.burnerOutcome!),
    if (action.burnerMicroampReading != null)
      '${action.burnerMicroampReading!.toStringAsFixed(3)} µA',
    if (_text(action.issue) != null) action.issue!.trim(),
    if (_text(action.resolution) != null) action.resolution!.trim(),
    if (_text(action.remarks) != null) action.remarks!.trim(),
  ].join(' · ');
}

class _SmallEvidenceChip extends StatelessWidget {
  const _SmallEvidenceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BafColors.maintenance.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: BafColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EvidenceWarning extends StatelessWidget {
  const _EvidenceWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: BafColors.danger,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }
}

class _EmptyEvidence extends StatelessWidget {
  const _EmptyEvidence({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: BafColors.textSecondary, height: 1.35),
    );
  }
}

String _assetLabel(AssetType type) => switch (type) {
  AssetType.base => 'Base',
  AssetType.furnace => 'Furnace',
  AssetType.forceCooler => 'Forced Cooler',
  AssetType.innerCover => 'Inner Cover',
  AssetType.governedCustom => 'Asset',
};

IconData _assetIcon(AssetType type) => switch (type) {
  AssetType.base => Icons.grid_view_rounded,
  AssetType.furnace => Icons.local_fire_department_rounded,
  AssetType.forceCooler => Icons.air_rounded,
  AssetType.innerCover => Icons.layers_outlined,
  AssetType.governedCustom => Icons.precision_manufacturing_outlined,
};

String _routeLabel(RoutedTo route) => switch (route) {
  RoutedTo.operations => 'Operations',
  RoutedTo.electrical => 'Electrical',
  RoutedTo.mechanical => 'Mechanical',
  RoutedTo.instrumentation => 'I&A',
  RoutedTo.refractory => 'RED / Refractory',
  RoutedTo.emd => 'EMD',
  RoutedTo.shiftInCharge => 'Shift In-Charge',
  RoutedTo.others => 'Other department',
};

Color _laneColor(RoutedTo route) => switch (route) {
  RoutedTo.operations => BafColors.sync,
  RoutedTo.electrical => BafColors.warning,
  RoutedTo.mechanical => BafColors.planned,
  RoutedTo.instrumentation => BafColors.audit,
  RoutedTo.refractory => BafColors.directives,
  RoutedTo.emd => BafColors.assets,
  RoutedTo.shiftInCharge => BafColors.charges,
  RoutedTo.others => BafColors.admin,
};

String _enumLabel(String value) {
  final words = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return words[0].toUpperCase() + words.substring(1);
}

String _evidenceDateTime(DateTime value) =>
    DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());

bool _sameInstant(DateTime first, DateTime second) =>
    first.toUtc() == second.toUtc();

List<String> _actionLocatorLabels(ComponentAction action) {
  final hierarchy = (action.assetHierarchyRef?.hierarchyPath ??
          action.hierarchyPath ??
          const <String>[])
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return <String>[
    'Asset: ${action.asset.trim()}',
    if (hierarchy.isNotEmpty) 'Hierarchy: ${hierarchy.join(' / ')}',
    if (action.system?.trim().isNotEmpty == true)
      'System: ${action.system!.trim()}',
    if (action.subsystem?.trim().isNotEmpty == true)
      'Subsystem: ${action.subsystem!.trim()}',
    if (action.subComponent?.trim().isNotEmpty == true)
      'Subcomponent: ${action.subComponent!.trim()}',
    if (action.tag?.trim().isNotEmpty == true) 'Tag: ${action.tag!.trim()}',
    if (action.instance?.trim().isNotEmpty == true)
      'Instance: ${action.instance!.trim()}',
  ];
}
