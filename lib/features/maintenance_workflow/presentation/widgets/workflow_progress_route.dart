import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../data/compliance_request_record.dart';
import '../../data/job_lane_record.dart';

enum WorkflowProgressStepState {
  completed,
  current,
  upcoming,
  returned,
  stopped,
}

class WorkflowProgressStep {
  const WorkflowProgressStep({
    required this.label,
    required this.state,
    this.detail,
  });

  final String label;
  final WorkflowProgressStepState state;
  final String? detail;
}

class WorkflowProgressRoute extends StatelessWidget {
  const WorkflowProgressRoute({
    super.key,
    required this.steps,
    this.compact = false,
  });

  final List<WorkflowProgressStep> steps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('workflow-progress-route'),
      children: [
        for (var index = 0; index < steps.length; index++)
          _WorkflowProgressStepRow(
            step: steps[index],
            isLast: index == steps.length - 1,
            compact: compact,
          ),
      ],
    );
  }
}

class ComplianceProgressRoute extends StatelessWidget {
  const ComplianceProgressRoute({
    super.key,
    required this.record,
    this.compact = false,
  });

  final ComplianceRequestRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return WorkflowProgressRoute(
      steps: complianceProgressSteps(record),
      compact: compact,
    );
  }
}

class LaneProgressRoute extends StatelessWidget {
  const LaneProgressRoute({
    super.key,
    required this.lane,
    this.compact = false,
  });

  final JobLaneRecord lane;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return WorkflowProgressRoute(
      steps: laneProgressSteps(lane),
      compact: compact,
    );
  }
}

List<WorkflowProgressStep> complianceProgressSteps(
  ComplianceRequestRecord record,
) {
  final status = record.statusKey;
  final conditionBased = record.conditionTypeKey != 'manual';
  final acknowledgementRecorded = record.acknowledgedAt != null;
  final acknowledged =
      acknowledgementRecorded ||
      (!conditionBased &&
          (status == 'acknowledged' ||
              status == 'complied' ||
              status == 'confirmedClosed'));
  final completed =
      record.compliedAt != null ||
      status == 'complied' ||
      status == 'confirmedClosed';
  final accepted = status == 'confirmedClosed' || record.confirmedAt != null;
  final stopped = status == 'cancelled' || status == 'superseded';
  final hasCounterProposal =
      record.counterRevisedDescription?.trim().isNotEmpty == true;
  final waitingOnCounterDecision =
      hasCounterProposal && record.counterDecisionAt == null && !stopped;
  final returnedForCorrection =
      record.lastCorrectionReason?.trim().isNotEmpty == true && !completed;

  final steps = <WorkflowProgressStep>[
    WorkflowProgressStep(
      label: 'Request raised',
      state: WorkflowProgressStepState.completed,
      detail: _actorAndTime(record.raisedByName, record.raisedAt),
    ),
  ];

  if (!conditionBased || acknowledgementRecorded) {
    steps.add(
      WorkflowProgressStep(
        label: 'Target lane acknowledged',
        state: acknowledged
            ? WorkflowProgressStepState.completed
            : stopped
            ? WorkflowProgressStepState.upcoming
            : WorkflowProgressStepState.current,
        detail: acknowledged
            ? _actorAndTime(record.acknowledgedByName, record.acknowledgedAt)
            : stopped
            ? null
            : 'Waiting for ${_laneLabel(record.targetLaneKey)}',
      ),
    );
  }

  if (hasCounterProposal) {
    final proposalEvidence = _actorAndTime(
      record.counterProposedByName,
      record.counterProposedAt,
    );
    steps.add(
      WorkflowProgressStep(
        label: 'Revised condition proposed',
        state: waitingOnCounterDecision
            ? WorkflowProgressStepState.current
            : WorkflowProgressStepState.completed,
        detail: waitingOnCounterDecision
            ? 'Waiting for origin decision'
            : record.counterDecisionAt != null
            ? _actorAndTime(
                record.counterDecisionByName,
                record.counterDecisionAt,
              )
            : proposalEvidence,
      ),
    );
  }

  final correctionEvidence = _actorAndTime(
    record.lastCorrectionByName,
    record.lastCorrectionAt,
  );
  if (record.lastCorrectionReason?.trim().isNotEmpty == true) {
    steps.add(
      WorkflowProgressStep(
        label: 'Returned for correction',
        state: WorkflowProgressStepState.returned,
        detail: <String>[
          if (correctionEvidence != null) correctionEvidence,
          record.lastCorrectionReason!.trim(),
        ].join(' - '),
      ),
    );
  }

  if (conditionBased) {
    steps.add(
      WorkflowProgressStep(
        label: returnedForCorrection
            ? 'Corrected release condition confirmed; linked work reactivated'
            : 'Release condition confirmed; linked work reactivated',
        state: completed
            ? WorkflowProgressStepState.completed
            : stopped || waitingOnCounterDecision
            ? WorkflowProgressStepState.upcoming
            : WorkflowProgressStepState.current,
        detail: completed
            ? _evidence(
                actor: record.dueMarkedByName ?? record.compliedByName,
                at: record.dueMarkedAt ?? record.compliedAt,
                note: record.complianceNote,
              )
            : stopped || waitingOnCounterDecision
            ? null
            : _conditionWaitingDetail(record),
      ),
    );
    steps.add(
      WorkflowProgressStep(
        label: 'Origin accepted release',
        state: accepted
            ? WorkflowProgressStepState.completed
            : stopped
            ? WorkflowProgressStepState.upcoming
            : completed
            ? WorkflowProgressStepState.current
            : WorkflowProgressStepState.upcoming,
        detail: accepted
            ? _evidence(
                actor: record.confirmedByName,
                at: record.confirmedAt,
                note: record.confirmNote,
              )
            : completed && !stopped
            ? 'Waiting for ${_laneLabel(record.originLaneKey ?? 'shared')}'
            : null,
      ),
    );
  } else {
    steps.add(
      WorkflowProgressStep(
        label: returnedForCorrection
            ? 'Corrected work reported'
            : 'Work reported',
        state: completed
            ? WorkflowProgressStepState.completed
            : stopped || waitingOnCounterDecision
            ? WorkflowProgressStepState.upcoming
            : acknowledged
            ? WorkflowProgressStepState.current
            : WorkflowProgressStepState.upcoming,
        detail: completed
            ? _evidence(
                actor: record.compliedByName,
                at: record.compliedAt,
                note: record.complianceNote,
              )
            : acknowledged && !stopped && !waitingOnCounterDecision
            ? 'Waiting for ${_laneLabel(record.targetLaneKey)} completion'
            : null,
      ),
    );
    steps.add(
      WorkflowProgressStep(
        label: 'Origin accepted completion',
        state: accepted
            ? WorkflowProgressStepState.completed
            : stopped
            ? WorkflowProgressStepState.upcoming
            : completed
            ? WorkflowProgressStepState.current
            : WorkflowProgressStepState.upcoming,
        detail: accepted
            ? _evidence(
                actor: record.confirmedByName,
                at: record.confirmedAt,
                note: record.confirmNote,
              )
            : completed && !stopped
            ? 'Waiting for ${_laneLabel(record.originLaneKey ?? 'shared')}'
            : null,
      ),
    );
  }

  if (status == 'cancelled') {
    steps.add(
      const WorkflowProgressStep(
        label: 'Request cancelled',
        state: WorkflowProgressStepState.stopped,
      ),
    );
  } else if (status == 'superseded') {
    steps.add(
      const WorkflowProgressStep(
        label: 'Replaced by revised request',
        state: WorkflowProgressStepState.stopped,
      ),
    );
  }

  return steps;
}

String _conditionWaitingDetail(ComplianceRequestRecord record) {
  final reference = record.conditionRef?.trim();
  final condition = record.conditionTypeKey == 'chargeComplete'
      ? reference == null || reference.isEmpty
            ? 'the recorded charge completion'
            : 'charge $reference completion'
      : reference == null || reference.isEmpty
      ? 'the recorded activity'
      : reference;
  return 'Waiting for Operations to confirm $condition';
}

List<WorkflowProgressStep> laneProgressSteps(JobLaneRecord lane) {
  final status = lane.statusKey;
  final acknowledged =
      lane.acknowledgedAt != null ||
      status == 'acknowledged' ||
      status == 'closed';
  final closed = status == 'closed' || lane.closedAt != null;
  final stopped = status == 'removed' || status == 'terminated';
  return <WorkflowProgressStep>[
    WorkflowProgressStep(
      label: 'Lane assigned',
      state: WorkflowProgressStepState.completed,
      detail: _actorAndTime(lane.createdByName, lane.createdAt),
    ),
    WorkflowProgressStep(
      label: 'Lane acknowledged',
      state: acknowledged
          ? WorkflowProgressStepState.completed
          : stopped
          ? WorkflowProgressStepState.upcoming
          : WorkflowProgressStepState.current,
      detail: acknowledged
          ? _actorAndTime(lane.acknowledgedByName, lane.acknowledgedAt)
          : stopped
          ? null
          : 'Waiting for ${_laneLabel(lane.laneKey)}',
    ),
    WorkflowProgressStep(
      label: 'Lane work completed',
      state: closed
          ? WorkflowProgressStepState.completed
          : stopped
          ? WorkflowProgressStepState.upcoming
          : acknowledged
          ? WorkflowProgressStepState.current
          : WorkflowProgressStepState.upcoming,
      detail: closed
          ? _evidence(
              actor: lane.closedByName,
              at: lane.closedAt,
              note: lane.closeNote,
            )
          : acknowledged && !stopped
          ? 'Work remains with ${_laneLabel(lane.laneKey)}'
          : null,
    ),
    if (status == 'removed')
      WorkflowProgressStep(
        label: 'Lane removed',
        state: WorkflowProgressStepState.stopped,
        detail: _evidence(
          actor: lane.removedByName,
          at: lane.removedAt,
          note: lane.removeReason,
        ),
      )
    else if (status == 'terminated')
      WorkflowProgressStep(
        label: 'Lane terminated',
        state: WorkflowProgressStepState.stopped,
        detail: _evidence(
          actor: lane.terminatedByName,
          at: lane.terminatedAt,
          note: lane.terminateReason,
        ),
      ),
  ];
}

class _WorkflowProgressStepRow extends StatelessWidget {
  const _WorkflowProgressStepRow({
    required this.step,
    required this.isLast,
    required this.compact,
  });

  final WorkflowProgressStep step;
  final bool isLast;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation(step.state);
    final detail = step.detail?.trim();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: compact ? 22 : 26,
                  height: compact ? 22 : 26,
                  decoration: BoxDecoration(
                    color: presentation.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: presentation.color, width: 1.5),
                  ),
                  child: Icon(
                    presentation.icon,
                    size: compact ? 13 : 15,
                    color: presentation.color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: presentation.connector),
                  ),
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : BafSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      color: step.state == WorkflowProgressStepState.upcoming
                          ? BafColors.textSecondary
                          : BafColors.textPrimary,
                      fontSize: compact ? 12 : 14,
                      fontWeight:
                          step.state == WorkflowProgressStepState.current
                          ? FontWeight.w900
                          : FontWeight.w700,
                    ),
                  ),
                  if (!compact && detail != null && detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

({Color color, Color background, Color connector, IconData icon}) _presentation(
  WorkflowProgressStepState state,
) {
  return switch (state) {
    WorkflowProgressStepState.completed => (
      color: BafColors.success,
      background: BafColors.success.withValues(alpha: 0.10),
      connector: BafColors.success.withValues(alpha: 0.35),
      icon: Icons.check_rounded,
    ),
    WorkflowProgressStepState.current => (
      color: BafColors.warning,
      background: BafColors.warning.withValues(alpha: 0.10),
      connector: BafColors.borderStrong,
      icon: Icons.schedule_rounded,
    ),
    WorkflowProgressStepState.upcoming => (
      color: BafColors.textTertiary,
      background: Colors.transparent,
      connector: BafColors.border,
      icon: Icons.circle_outlined,
    ),
    WorkflowProgressStepState.returned => (
      color: BafColors.warning,
      background: BafColors.warning.withValues(alpha: 0.10),
      connector: BafColors.warning.withValues(alpha: 0.35),
      icon: Icons.undo_rounded,
    ),
    WorkflowProgressStepState.stopped => (
      color: BafColors.danger,
      background: BafColors.danger.withValues(alpha: 0.10),
      connector: BafColors.border,
      icon: Icons.block_rounded,
    ),
  };
}

String? _actorAndTime(String? actor, DateTime? at) {
  final name = actor?.trim();
  final parts = <String>[
    if (name != null && name.isNotEmpty) name,
    if (at != null) DateFormat('dd MMM yyyy, HH:mm').format(at.toLocal()),
  ];
  return parts.isEmpty ? null : parts.join(' - ');
}

String? _evidence({String? actor, DateTime? at, String? note}) {
  final evidence = _actorAndTime(actor, at);
  final normalizedNote = note?.trim();
  final parts = <String>[
    if (evidence != null) evidence,
    if (normalizedNote != null && normalizedNote.isNotEmpty) normalizedNote,
  ];
  return parts.isEmpty ? null : parts.join(' - ');
}

String _laneLabel(String laneKey) {
  return switch (laneKey.trim().toLowerCase()) {
    'elec' => 'Electrical',
    'mech' => 'Mechanical',
    'inst' => 'Instrumentation',
    'oprn' => 'Operations',
    'red' => 'Refractory',
    'shared' => 'the origin lane',
    final value when value.isNotEmpty => value.toUpperCase(),
    _ => 'the responsible lane',
  };
}
