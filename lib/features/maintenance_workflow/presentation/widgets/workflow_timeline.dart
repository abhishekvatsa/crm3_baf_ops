import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../data/workflow_event_record.dart';

class WorkflowTimeline extends StatelessWidget {
  const WorkflowTimeline({
    super.key,
    required this.events,
    this.complianceLabels = const <String, String>{},
    this.moduleLabels = const <String, String>{},
  });

  final List<WorkflowEventRecord> events;
  final Map<String, String> complianceLabels;
  final Map<String, String> moduleLabels;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(child: Text('No workflow events yet.'));
    }
    final ambiguousIds = _ambiguousTimelineIds(
      events: events,
      complianceLabels: complianceLabels,
      moduleLabels: moduleLabels,
    );
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: BafSpacing.sm),
      itemCount: events.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 58, endIndent: 16),
      itemBuilder: (_, index) => _WorkflowEventRow(
        event: events[index],
        complianceLabels: complianceLabels,
        moduleLabels: moduleLabels,
        ambiguousComplianceIds: ambiguousIds.compliance,
        ambiguousModuleIds: ambiguousIds.modules,
      ),
    );
  }
}

class _WorkflowEventRow extends StatelessWidget {
  const _WorkflowEventRow({
    required this.event,
    required this.complianceLabels,
    required this.moduleLabels,
    required this.ambiguousComplianceIds,
    required this.ambiguousModuleIds,
  });

  final WorkflowEventRecord event;
  final Map<String, String> complianceLabels;
  final Map<String, String> moduleLabels;
  final Set<String> ambiguousComplianceIds;
  final Set<String> ambiguousModuleIds;

  @override
  Widget build(BuildContext context) {
    final presentation = _eventPresentation(event.eventTypeKey);
    final actor = event.actorName?.trim().isNotEmpty == true
        ? event.actorName!.trim()
        : event.actorUid?.trim().isNotEmpty == true
        ? event.actorUid!.trim()
        : 'Server';
    final delegated = event.representedLaneKey?.trim();
    final lane = event.laneKey?.trim();
    final payload = _payloadPresentation(
      event.payloadJson,
      complianceLabels: complianceLabels,
      moduleLabels: moduleLabels,
      ambiguousComplianceIds: ambiguousComplianceIds,
      ambiguousModuleIds: ambiguousModuleIds,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.lg,
        vertical: BafSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: presentation.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: presentation.color.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(presentation.icon, size: 17, color: presentation.color),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  presentation.label,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (payload.subjects.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  for (final subject in payload.subjects)
                    Text(
                      subject,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
                const SizedBox(height: 2),
                Text(
                  <String>[
                    actor,
                    if (lane != null && lane.isNotEmpty)
                      '${_laneLabel(lane)} lane',
                    if (delegated != null && delegated.isNotEmpty)
                      'for ${_laneLabel(delegated)}',
                  ].join(' - '),
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat(
                    'dd MMM yyyy, HH:mm',
                  ).format(event.occurredAt.toLocal()),
                  style: const TextStyle(
                    color: BafColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
                if (payload.details.isNotEmpty) ...[
                  const SizedBox(height: BafSpacing.xs),
                  Text(
                    payload.details,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

({String label, IconData icon, Color color}) _eventPresentation(String key) {
  return switch (key) {
    'workflow.jobCreatedPendingClassification' => (
      label: 'Job created; lane classification pending',
      icon: Icons.playlist_add_check_circle_outlined,
      color: BafColors.planned,
    ),
    'issue.coordinationStarted' => (
      label: 'Issue coordination started',
      icon: Icons.hub_outlined,
      color: BafColors.planned,
    ),
    'lane.created' || 'lane.added' => (
      label: key == 'lane.created' ? 'Lane assigned' : 'Lane added',
      icon: Icons.account_tree_outlined,
      color: BafColors.planned,
    ),
    'lane.acknowledged' => (
      label: 'Lane acknowledged',
      icon: Icons.verified_outlined,
      color: BafColors.info,
    ),
    'lane.closed' => (
      label: 'Lane work completed',
      icon: Icons.task_alt_rounded,
      color: BafColors.success,
    ),
    'lane.removed' => (
      label: 'Lane removed',
      icon: Icons.remove_circle_outline,
      color: BafColors.warning,
    ),
    'lane.terminated' => (
      label: 'Lane terminated',
      icon: Icons.block_outlined,
      color: BafColors.danger,
    ),
    'lane.escalated' => (
      label: 'Lane response escalated',
      icon: Icons.priority_high_rounded,
      color: BafColors.danger,
    ),
    'compliance.raised' => (
      label: 'Compliance request raised',
      icon: Icons.assignment_outlined,
      color: BafColors.planned,
    ),
    'compliance.acknowledged' => (
      label: 'Compliance request acknowledged',
      icon: Icons.verified_outlined,
      color: BafColors.info,
    ),
    'compliance.conditionConfirmedAndWorkReactivated' => (
      label: 'Release condition confirmed; work reactivated',
      icon: Icons.play_circle_outline_rounded,
      color: BafColors.success,
    ),
    'compliance.complied' => (
      label: 'Completion reported for acceptance',
      icon: Icons.pending_actions_outlined,
      color: BafColors.audit,
    ),
    'compliance.returnedForCorrection' => (
      label: 'Completion returned for correction',
      icon: Icons.undo_rounded,
      color: BafColors.warning,
    ),
    'compliance.confirmedClosed' => (
      label: 'Completion accepted and closed',
      icon: Icons.task_alt_rounded,
      color: BafColors.success,
    ),
    'compliance.counterProposed' => (
      label: 'Revised condition proposed',
      icon: Icons.swap_horiz_rounded,
      color: BafColors.warning,
    ),
    'compliance.counterAccepted' => (
      label: 'Revised condition accepted',
      icon: Icons.check_circle_outline_rounded,
      color: BafColors.success,
    ),
    'compliance.counterRejectedEscalated' => (
      label: 'Revised condition rejected and escalated',
      icon: Icons.report_problem_outlined,
      color: BafColors.danger,
    ),
    'compliance.acknowledgementEscalated' => (
      label: 'Acknowledgement overdue and escalated',
      icon: Icons.notification_important_outlined,
      color: BafColors.danger,
    ),
    'compliance.completionEscalated' => (
      label: 'Completion overdue and escalated',
      icon: Icons.notification_important_outlined,
      color: BafColors.danger,
    ),
    'red.awaitingPreparation' => (
      label: 'Refractory work awaiting preparation',
      icon: Icons.hourglass_top_rounded,
      color: BafColors.warning,
    ),
    'red.readyForWork' => (
      label: 'Refractory lane ready for work',
      icon: Icons.play_circle_outline_rounded,
      color: BafColors.success,
    ),
    'red.preparationConfirmed' => (
      label: 'Preparation confirmed',
      icon: Icons.fact_check_outlined,
      color: BafColors.success,
    ),
    'module.reopened' => (
      label: 'Work module reopened',
      icon: Icons.replay_rounded,
      color: BafColors.warning,
    ),
    'workflow.redSuccessorCreated' => (
      label: 'Refractory successor workflow created',
      icon: Icons.call_split_rounded,
      color: BafColors.planned,
    ),
    'workflow.finalized' => (
      label: 'Workflow finalized',
      icon: Icons.task_alt_rounded,
      color: BafColors.success,
    ),
    'workflow.cancelled' => (
      label: 'Workflow cancelled',
      icon: Icons.cancel_outlined,
      color: BafColors.danger,
    ),
    'issue.closedWithoutResolution' => (
      label: 'Issue closed without resolution',
      icon: Icons.inventory_2_outlined,
      color: BafColors.warning,
    ),
    'equipment.reconciled' => (
      label: 'Equipment state reconciled',
      icon: Icons.sync_alt_rounded,
      color: BafColors.info,
    ),
    'equipment.deployed' => (
      label: 'Equipment returned to service',
      icon: Icons.precision_manufacturing_outlined,
      color: BafColors.success,
    ),
    _ => (
      label: _humanizeEventKey(key),
      icon: Icons.history_rounded,
      color: BafColors.textSecondary,
    ),
  };
}

({List<String> subjects, String details}) _payloadPresentation(
  String jsonText, {
  required Map<String, String> complianceLabels,
  required Map<String, String> moduleLabels,
  required Set<String> ambiguousComplianceIds,
  required Set<String> ambiguousModuleIds,
}) {
  try {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      return (
        subjects: const <String>[],
        details: _storedPayloadDetails(jsonText),
      );
    }
    final subjects = <String>[];
    final complianceId = _payloadString(decoded['complianceId']);
    if (complianceId != null) {
      final title =
          _firstPayloadString(decoded, const <String>[
            'requestTitle',
            'complianceTitle',
            'title',
          ]) ??
          _mappedLabel(complianceLabels, complianceId);
      subjects.add(
        title == null
            ? 'Request reference: $complianceId'
            : ambiguousComplianceIds.contains(complianceId)
            ? 'Request: $title (reference $complianceId)'
            : 'Request: $title',
      );
    }
    final moduleId =
        _payloadString(decoded['moduleFirestoreId']) ??
        _payloadString(decoded['linkedModuleId']);
    if (moduleId != null) {
      final title =
          _firstPayloadString(decoded, const <String>[
            'moduleTitle',
            'moduleLabel',
          ]) ??
          _mappedLabel(moduleLabels, moduleId);
      subjects.add(
        title == null
            ? 'Module reference: $moduleId'
            : ambiguousModuleIds.contains(moduleId)
            ? 'Module: $title (reference $moduleId)'
            : 'Module: $title',
      );
    }
    final parentWorkflowId = _payloadString(decoded['parentWorkflowId']);
    if (parentWorkflowId != null) {
      subjects.add('Originating workflow: $parentWorkflowId');
    }
    final parentExecutionId = _payloadString(decoded['parentExecutionId']);
    if (parentExecutionId != null) {
      subjects.add('Originating job: $parentExecutionId');
    }
    final successorWorkflowId = _payloadString(decoded['successorWorkflowId']);
    if (successorWorkflowId != null) {
      subjects.add('Successor workflow: $successorWorkflowId');
    }
    final successorExecutionId = _payloadString(
      decoded['successorExecutionId'],
    );
    if (successorExecutionId != null) {
      subjects.add('Successor job: $successorExecutionId');
    }
    final preparationComplianceId = _payloadString(
      decoded['preparationComplianceId'],
    );
    if (preparationComplianceId != null) {
      final title =
          _firstPayloadString(decoded, const <String>[
            'preparationTitle',
            'preparationComplianceTitle',
          ]) ??
          _mappedLabel(complianceLabels, preparationComplianceId);
      subjects.add(
        title == null
            ? 'Preparation request: $preparationComplianceId'
            : ambiguousComplianceIds.contains(preparationComplianceId)
            ? 'Preparation request: $title '
                  '(reference $preparationComplianceId)'
            : 'Preparation request: $title',
      );
    }
    const labels = <String, String>{
      'note': 'Note',
      'reason': 'Reason',
      'revisedDescription': 'Revised condition',
      'equipmentState': 'Equipment state',
      'state': 'State',
      'openLaneKeys': 'Open lanes',
      'validatedModuleCount': 'Validated modules',
      'replacementGeneration': 'Replacement lane generation',
      'remappedModuleCount': 'Modules transferred',
    };
    final details = <String>[];
    final replacementLaneKey = _payloadString(decoded['replacementLaneKey']);
    if (replacementLaneKey != null) {
      details.add('Replacement lane: ${_laneLabel(replacementLaneKey)}');
    }
    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      final label = labels[key];
      if (label == null || entry.value == null) continue;
      final value = entry.value is Iterable
          ? (entry.value as Iterable).join(', ')
          : entry.value.toString();
      if (value.trim().isEmpty) continue;
      details.add('$label: $value');
    }
    return (subjects: subjects, details: details.join(' - '));
  } catch (_) {
    return (
      subjects: const <String>[],
      details: _storedPayloadDetails(jsonText),
    );
  }
}

String _storedPayloadDetails(String jsonText) {
  final stored = jsonText.trim();
  return 'Stored event details: ${stored.isEmpty ? '(empty)' : stored}';
}

({Set<String> compliance, Set<String> modules}) _ambiguousTimelineIds({
  required List<WorkflowEventRecord> events,
  required Map<String, String> complianceLabels,
  required Map<String, String> moduleLabels,
}) {
  final complianceTitles = <String, Set<String>>{};
  final moduleTitles = <String, Set<String>>{};

  void remember(Map<String, Set<String>> target, String? id, String? title) {
    final normalizedId = id?.trim();
    final normalizedTitle = title?.trim().toLowerCase();
    if (normalizedId == null ||
        normalizedId.isEmpty ||
        normalizedTitle == null ||
        normalizedTitle.isEmpty) {
      return;
    }
    target.putIfAbsent(normalizedId, () => <String>{}).add(normalizedTitle);
  }

  for (final entry in complianceLabels.entries) {
    remember(complianceTitles, entry.key, entry.value);
  }
  for (final entry in moduleLabels.entries) {
    remember(moduleTitles, entry.key, entry.value);
  }
  for (final event in events) {
    try {
      final decoded = jsonDecode(event.payloadJson);
      if (decoded is! Map) continue;
      remember(
        complianceTitles,
        _payloadString(decoded['complianceId']),
        _firstPayloadString(decoded, const <String>[
          'requestTitle',
          'complianceTitle',
          'title',
        ]),
      );
      remember(
        complianceTitles,
        _payloadString(decoded['preparationComplianceId']),
        _firstPayloadString(decoded, const <String>[
          'preparationTitle',
          'preparationComplianceTitle',
        ]),
      );
      remember(
        moduleTitles,
        _payloadString(decoded['moduleFirestoreId']) ??
            _payloadString(decoded['linkedModuleId']),
        _firstPayloadString(decoded, const <String>[
          'moduleTitle',
          'moduleLabel',
        ]),
      );
    } catch (_) {
      // Malformed legacy payloads are already handled by the row formatter.
    }
  }

  return (
    compliance: _ambiguousTitleIds(complianceTitles),
    modules: _ambiguousTitleIds(moduleTitles),
  );
}

Set<String> _ambiguousTitleIds(Map<String, Set<String>> titlesById) {
  final idsByTitle = <String, Set<String>>{};
  for (final entry in titlesById.entries) {
    for (final title in entry.value) {
      idsByTitle.putIfAbsent(title, () => <String>{}).add(entry.key);
    }
  }
  return <String>{
    for (final ids in idsByTitle.values)
      if (ids.length > 1) ...ids,
  };
}

String? _firstPayloadString(Map<dynamic, dynamic> payload, List<String> keys) {
  for (final key in keys) {
    final value = _payloadString(payload[key]);
    if (value != null) return value;
  }
  return null;
}

String? _payloadString(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String? _mappedLabel(Map<String, String> labels, String id) {
  final label = labels[id]?.trim();
  return label == null || label.isEmpty ? null : label;
}

String _humanizeEventKey(String key) {
  final leaf = key.split('.').last;
  final spaced = leaf.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  if (spaced.isEmpty) return 'Workflow event';
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}

String _laneLabel(String key) {
  return switch (key.toLowerCase()) {
    'elec' => 'Electrical',
    'mech' => 'Mechanical',
    'inst' => 'Instrumentation',
    'oprn' => 'Operations',
    'red' => 'Refractory',
    'shared' => 'Shared',
    _ => key.toUpperCase(),
  };
}
