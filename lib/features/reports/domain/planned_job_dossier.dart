import 'dart:convert';

import '../../maintenance_workflow/data/compliance_request_record.dart';
import '../../maintenance_workflow/data/job_lane_record.dart';
import '../../maintenance_workflow/data/workflow_event_record.dart';
import '../../planned_maintenance/data/job_diary_model.dart';
import '../../planned_maintenance/data/job_module_model.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import 'report_provenance.dart';
import 'structured_report_document.dart';

StructuredReportDocument buildPlannedJobDossier({
  required JobExecution execution,
  required JobTemplate? template,
  required List<JobModuleInstance> modules,
  required List<JobDiaryEntry> diaryEntries,
  required List<JobLaneRecord> workflowLanes,
  required List<ComplianceRequestRecord> complianceRequests,
  required List<WorkflowEventRecord> workflowEvents,
  required DateTime generatedAt,
  required String generatedByName,
  required ReportProvenance provenance,
}) {
  final actionRead = execution.actionsReadResult;
  final responseRead = execution.responsesReadResult;
  final innerCoverRead = execution.assignmentInnerCoverPositionReadResult;
  if (!actionRead.isValid) {
    throw StateError(
      'The planned-job action evidence is malformed and cannot be reported.',
    );
  }
  if (!responseRead.isValid) {
    throw StateError(
      'The planned-job response evidence is malformed and cannot be reported.',
    );
  }
  if (!innerCoverRead.isValid) {
    throw StateError(
      'The planned-job Inner Cover evidence is malformed and cannot be reported.',
    );
  }

  final executionId = _clean(execution.firestoreId);
  final moduleRows = <List<String>>[];
  final moduleResponseRows = <List<String>>[];
  final moduleActionRows = <List<String>>[];
  for (final module in modules) {
    _requireParentMatch(
      parentId: executionId,
      childParentId: module.jobExecutionFirestoreId,
      childLabel: 'module ${module.firestoreId ?? module.id}',
    );
    final responses = module.responsesReadResult;
    final actions = module.actionsReadResult;
    final snapshot = module.moduleSnapshotReadResult;
    final definitions = module.fieldDefinitionsReadResult;
    if (!responses.isValid ||
        !actions.isValid ||
        !snapshot.isValid ||
        !definitions.isValid) {
      throw StateError(
        'Saved evidence for module ${module.moduleTitle} is malformed and cannot be reported.',
      );
    }
    moduleRows.add(_moduleRow(module));
    for (final response in responses.entries) {
      moduleResponseRows.add(<String>[
        module.moduleCode ?? module.moduleTitle,
        response.fieldLabel,
        _responseValue(response.value),
      ]);
    }
    for (final action in actions.entries) {
      moduleActionRows.add(
        _componentActionRow(module.moduleCode ?? module.moduleTitle, action),
      );
    }
  }

  final diary = [...diaryEntries]
    ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  for (final entry in diary) {
    _requireParentMatch(
      parentId: executionId,
      childParentId: entry.jobExecutionFirestoreId,
      childLabel: 'diary entry ${entry.firestoreId ?? entry.id}',
    );
  }

  final lanes = [...workflowLanes]..sort((left, right) {
    final order = left.displayOrder.compareTo(right.displayOrder);
    return order != 0 ? order : left.laneKey.compareTo(right.laneKey);
  });
  final compliance = [...complianceRequests]
    ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
  final events = [...workflowEvents]
    ..sort((left, right) => left.occurredAt.compareTo(right.occurredAt));
  _validateWorkflowScope(
    executionId: executionId,
    workflowLanes: lanes,
    complianceRequests: compliance,
    workflowEvents: events,
  );

  final innerCover = innerCoverRead.position;
  final physicalIdentity = execution.assignmentPhysicalAssetIdentity;
  final hierarchy = execution.assignmentAssetHierarchyReference;
  final assetLabel =
      '${_label(execution.assetType.name)} ${execution.assetNumber}';
  final terminalState =
      execution.isDeleted
          ? 'Deleted'
          : execution.isCancelled
          ? 'Cancelled'
          : execution.isCompleted
          ? 'Completed'
          : 'Open';
  final openModules = modules.where((module) => module.isOpenForWork).length;
  final openBlockers =
      diary.where((entry) => !entry.isDeleted && entry.isOpenBlocker).length;
  final activeCompliance =
      compliance
          .where(
            (request) =>
                !request.isDeleted &&
                request.statusKey != 'confirmed' &&
                request.statusKey != 'withdrawn' &&
                request.statusKey != 'cancelled',
          )
          .length;

  return StructuredReportDocument(
    title: 'Planned maintenance dossier',
    subtitle:
        'Execution, module, component, lane, diary and compliance evidence',
    reportId: createStructuredReportId('PM', generatedAt),
    generatedAt: generatedAt,
    generatedByName: generatedByName,
    scopeLabel: '$assetLabel / ${executionId ?? 'local-${execution.id}'}',
    provenance: provenance,
    orientation: StructuredReportOrientation.landscape,
    sections: <StructuredReportSection>[
      StructuredReportSection(
        title: 'Execution identity and status',
        metrics: <StructuredReportMetric>[
          StructuredReportMetric(
            label: 'State',
            value: terminalState,
            tone:
                execution.isCompleted
                    ? StructuredReportMetricTone.positive
                    : execution.isCancelled || execution.isDeleted
                    ? StructuredReportMetricTone.warning
                    : StructuredReportMetricTone.info,
          ),
          StructuredReportMetric(
            label: 'Modules',
            value: '${modules.length}',
            detail: '$openModules still open',
            tone:
                openModules == 0
                    ? StructuredReportMetricTone.positive
                    : StructuredReportMetricTone.warning,
          ),
          StructuredReportMetric(
            label: 'Diary',
            value: '${diary.length}',
            detail: '$openBlockers open blockers',
            tone:
                openBlockers == 0
                    ? StructuredReportMetricTone.neutral
                    : StructuredReportMetricTone.danger,
          ),
          StructuredReportMetric(
            label: 'Compliance',
            value: '${compliance.length}',
            detail: '$activeCompliance active',
            tone:
                activeCompliance == 0
                    ? StructuredReportMetricTone.neutral
                    : StructuredReportMetricTone.warning,
          ),
        ],
        fields: <StructuredReportField>[
          StructuredReportField(label: 'Asset', value: assetLabel),
          StructuredReportField(
            label: 'Charge at assignment',
            value: execution.chargeNoAtEvent?.toString() ?? 'Not recorded',
          ),
          StructuredReportField(
            label: 'Assigned by',
            value: _value(execution.assignedByName),
          ),
          StructuredReportField(
            label: 'Assigned lanes / agencies',
            value:
                execution.assignedAgencies.isEmpty
                    ? 'Not recorded'
                    : execution.assignedAgencies.map(_label).join(', '),
          ),
          StructuredReportField(
            label: 'Created',
            value: _dateTime(execution.createdAt),
          ),
          StructuredReportField(
            label: 'Last updated',
            value: _dateTime(execution.updatedAt),
          ),
          StructuredReportField(
            label: 'Completed',
            value:
                execution.completedAt == null
                    ? 'Not completed'
                    : '${_dateTime(execution.completedAt!)} by ${_value(execution.completedByName)}',
          ),
          StructuredReportField(
            label: 'Remarks',
            value: _value(execution.remarks),
          ),
          if (execution.isCancelled)
            StructuredReportField(
              label: 'Cancellation',
              value:
                  '${execution.cancelledAt == null ? 'Time not recorded' : _dateTime(execution.cancelledAt!)} by '
                  '${_value(execution.cancelledByName)}; ${_value(execution.cancellationReason)}',
            ),
        ],
      ),
      StructuredReportSection(
        title: 'Frozen template and asset authority',
        subtitle:
            'The identity captured at assignment is retained independently of later catalogue changes.',
        fields: <StructuredReportField>[
          StructuredReportField(
            label: 'Template',
            value:
                execution.templateName ?? template?.jobName ?? 'Not recorded',
          ),
          StructuredReportField(
            label: 'Assignment mode',
            value:
                execution.isGovernedTemplateAssignment
                    ? 'Published governed template version'
                    : 'Legacy / direct template assignment',
          ),
          StructuredReportField(
            label: 'Template reference',
            value: execution.templateFirestoreId,
          ),
          StructuredReportField(
            label: 'Package / version',
            value:
                '${_value(execution.templatePackageCode ?? execution.templatePackageId)} / '
                '${_value(execution.templateVersionLabel ?? execution.templateVersionId)}',
          ),
          StructuredReportField(
            label: 'Version number / content hash',
            value:
                '${execution.templateVersionNumber?.toString() ?? 'Not recorded'} / '
                '${_value(execution.templateContentHash)}',
          ),
          StructuredReportField(
            label: 'Physical asset identity',
            value:
                physicalIdentity == null
                    ? 'Legacy identity not frozen'
                    : '${physicalIdentity.assetClassId} / ${physicalIdentity.assetInstanceId}',
          ),
          StructuredReportField(
            label: 'Hierarchy target',
            value:
                hierarchy == null
                    ? 'Not recorded'
                    : hierarchy.hierarchyPath.join(' > '),
          ),
          if (innerCover != null)
            StructuredReportField(
              label: 'Inner Cover position at assignment',
              value:
                  '${innerCover.innerCoverSerialNumber} on Base ${innerCover.baseAssetNumber}; '
                  'linkage ${innerCover.linkageId}; assignment v${innerCover.assignmentVersion}',
            ),
          StructuredReportField(
            label: 'Workflow schema / lane set',
            value:
                '${execution.workflowSchemaVersion} / ${execution.laneSetVersion}',
          ),
          StructuredReportField(
            label: 'Lane set finalised',
            value:
                execution.laneSetFinalizedAt == null
                    ? 'Not recorded'
                    : '${_dateTime(execution.laneSetFinalizedAt!)} by ${_value(execution.laneSetFinalizedByName)}',
          ),
          if (execution.laneMappingReview)
            const StructuredReportField(
              label: 'Lane mapping',
              value: 'Requires governance review',
            ),
        ],
      ),
      StructuredReportSection(
        title: 'Execution responses and component work',
        tables: <StructuredReportTable>[
          StructuredReportTable(
            title: 'Execution responses',
            headers: const <String>['Field', 'Response'],
            rows: responseRead.entries
                .map(
                  (response) => <String>[
                    response.fieldLabel,
                    _responseValue(response.value),
                  ],
                )
                .toList(growable: false),
            columnFlex: const <double>[1.5, 3.5],
          ),
          StructuredReportTable(
            title: 'Execution-level component actions',
            headers: const <String>[
              'Source',
              'Time',
              'Target',
              'Action / replacement',
              'Outcome / remarks',
              'Performed by',
            ],
            rows: actionRead.entries
                .map((action) => _componentActionRow('Execution', action))
                .toList(growable: false),
            columnFlex: const <double>[0.8, 1.15, 1.8, 1.65, 2.35, 1.1],
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Runtime modules',
        subtitle:
            'Each module retains its source, lane, safety class, lifecycle and follow-up state.',
        tables: <StructuredReportTable>[
          StructuredReportTable(
            headers: const <String>[
              'Module',
              'Lane',
              'Status',
              'Use / safety',
              'Target',
              'Accountability',
            ],
            rows: moduleRows,
            columnFlex: const <double>[1.7, 0.9, 1, 1.5, 1.9, 2.1],
          ),
          StructuredReportTable(
            title: 'Module responses',
            headers: const <String>['Module', 'Field', 'Response'],
            rows: moduleResponseRows,
            columnFlex: const <double>[1.4, 1.5, 3],
          ),
          StructuredReportTable(
            title: 'Module component actions',
            headers: const <String>[
              'Source',
              'Time',
              'Target',
              'Action / replacement',
              'Outcome / remarks',
              'Performed by',
            ],
            rows: moduleActionRows,
            columnFlex: const <double>[0.9, 1.15, 1.8, 1.65, 2.35, 1.1],
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Job diary chronology',
        subtitle:
            'Observations, blockers, corrections, handovers and follow-up evidence are ordered by occurrence.',
        tables: <StructuredReportTable>[
          StructuredReportTable(
            headers: const <String>[
              'Time',
              'Type / severity',
              'Lane / target',
              'Entry',
              'Action / pending',
              'Actor',
            ],
            rows: diary.map(_diaryRow).toList(growable: false),
            columnFlex: const <double>[1.15, 1.2, 1.35, 2.6, 2.2, 1.1],
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Governed lanes and compliance',
        subtitle:
            execution.workflowSchemaVersion == 1
                ? 'Server-governed lane and coordination projections for this execution.'
                : 'This legacy execution does not declare the governed workflow schema.',
        tables: <StructuredReportTable>[
          StructuredReportTable(
            title: 'Lane progress',
            headers: const <String>[
              'Lane',
              'Status',
              'Acknowledged',
              'Closed / note',
              'Revision',
            ],
            rows: lanes.map(_laneRow).toList(growable: false),
            columnFlex: const <double>[1, 0.9, 1.9, 2.6, 0.65],
          ),
          StructuredReportTable(
            title: 'Compliance and operational support',
            headers: const <String>[
              'Raised',
              'Purpose / target',
              'Request',
              'Status',
              'Acknowledged / complied / confirmed',
            ],
            rows: compliance.map(_complianceRow).toList(growable: false),
            columnFlex: const <double>[1.05, 1.4, 2.5, 0.8, 2.6],
          ),
          StructuredReportTable(
            title: 'Workflow event ledger',
            headers: const <String>[
              'Time',
              'Event',
              'Lane',
              'Actor',
              'Payload',
            ],
            rows: events.map(_eventRow).toList(growable: false),
            columnFlex: const <double>[1.1, 1.2, 0.8, 1.1, 3.1],
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Record assurance',
        fields: <StructuredReportField>[
          StructuredReportField(
            label: 'Execution ID',
            value: executionId ?? 'Local record ${execution.id}',
          ),
          StructuredReportField(
            label: 'Version / sync state',
            value:
                'v${execution.version}; ${execution.isSynced ? 'synchronised' : 'local changes pending'}',
          ),
          StructuredReportField(
            label: 'Child evidence loaded',
            value:
                '${modules.length} modules, ${diary.length} diary entries, '
                '${lanes.length} lanes, ${compliance.length} compliance requests, '
                '${events.length} workflow events',
          ),
          if (execution.isDeleted)
            StructuredReportField(
              label: 'Deletion evidence',
              value:
                  '${execution.deletedAt == null ? 'Time not recorded' : _dateTime(execution.deletedAt!)} by '
                  '${_value(execution.deletedByName)}; ${_value(execution.deleteReason)}',
            ),
        ],
        paragraphs: const <String>[
          'This dossier reports the application evidence available to the signed-in user at generation time. It is not an independent server certification.',
        ],
      ),
    ],
  );
}

void _requireParentMatch({
  required String? parentId,
  required String? childParentId,
  required String childLabel,
}) {
  final child = _clean(childParentId);
  if (parentId != null && child != null && parentId != child) {
    throw StateError('$childLabel belongs to a different planned job.');
  }
}

void _validateWorkflowScope({
  required String? executionId,
  required List<JobLaneRecord> workflowLanes,
  required List<ComplianceRequestRecord> complianceRequests,
  required List<WorkflowEventRecord> workflowEvents,
}) {
  if (executionId == null) {
    if (workflowLanes.isNotEmpty ||
        complianceRequests.isNotEmpty ||
        workflowEvents.isNotEmpty) {
      throw StateError(
        'Local planned jobs cannot claim remote workflow evidence.',
      );
    }
    return;
  }
  for (final lane in workflowLanes) {
    if (lane.workflowFirestoreId != executionId ||
        lane.jobExecutionFirestoreId != executionId) {
      throw StateError('A lane record belongs to a different workflow.');
    }
  }
  for (final request in complianceRequests) {
    final linkedWorkflow = _clean(request.linkedWorkflowId);
    final linkedExecution = _clean(request.linkedExecutionFirestoreId);
    if ((linkedWorkflow != null && linkedWorkflow != executionId) ||
        (linkedExecution != null && linkedExecution != executionId)) {
      throw StateError('A compliance record belongs to a different workflow.');
    }
  }
  for (final event in workflowEvents) {
    if (event.aggregateId != executionId) {
      throw StateError('A workflow event belongs to a different aggregate.');
    }
  }
}

List<String> _moduleRow(JobModuleInstance module) {
  final accountability = <String>[
    if (module.submittedAt != null)
      'Submitted ${_dateTime(module.submittedAt!)} by ${_value(module.submittedByName)}',
    if (module.acceptedAt != null)
      'Accepted ${_dateTime(module.acceptedAt!)} by ${_value(module.acceptedByName)}',
    if (module.reopenedAt != null)
      'Reopened ${_dateTime(module.reopenedAt!)} by ${_value(module.reopenedByName)}: ${_value(module.reopenReason)}',
    if (module.notApplicableAt != null)
      'N/A ${_dateTime(module.notApplicableAt!)} by ${_value(module.notApplicableByName)}: ${_value(module.notApplicableReason)}',
    if (module.requiresFollowUp)
      'Follow-up required: ${_value(module.pendingIssue)}',
    if (module.isDeleted)
      'Deleted ${module.deletedAt == null ? 'time not recorded' : _dateTime(module.deletedAt!)}: ${_value(module.deleteReason)}',
  ];
  final target = <String>[
    if (_clean(module.functionalSection) != null) module.functionalSection!,
    if (_clean(module.componentGroup) != null) module.componentGroup!,
    if (_clean(module.subsystem) != null) module.subsystem!,
    if (_clean(module.targetRef) != null) module.targetRef!,
    ...module.targetRefs,
    ...module.tags.map((tag) => 'Tag $tag'),
  ];
  return <String>[
    '${_value(module.moduleCode)} / ${module.moduleTitle}',
    _label(module.effectiveLaneKey ?? module.discipline.name),
    _label(module.status.name),
    '${_label(module.useMode.name)} / ${_label(module.safetyClass.name)}',
    target.isEmpty ? 'Not recorded' : target.join(' > '),
    accountability.isEmpty
        ? 'No terminal evidence yet'
        : accountability.join('\n'),
  ];
}

List<String> _componentActionRow(String source, ComponentAction action) {
  final target = <String>[
    if (action.hierarchyPath != null) ...action.hierarchyPath!,
    if (action.hierarchyPath == null && _clean(action.system) != null)
      action.system!,
    if (action.hierarchyPath == null && _clean(action.subsystem) != null)
      action.subsystem!,
    if (action.hierarchyPath == null && _clean(action.subComponent) != null)
      action.subComponent!,
    if (action.hierarchyPath == null) action.component,
    if (_clean(action.tag) != null) 'Tag ${action.tag}',
    if (action.burnerPosition != null) 'Burner ${action.burnerPosition}',
  ];
  final actionLabel = <String>[
    _label(action.actionType.name),
    if (action.replacement != null) _label(action.replacement!.name),
    if (action.burnerActionCode != null) _label(action.burnerActionCode!),
    if (action.burnerBlockSupplyMode != null)
      'Supply ${_label(action.burnerBlockSupplyMode!.name)}',
  ];
  final outcome = <String>[
    if (_clean(action.issue) != null) 'Issue: ${action.issue}',
    if (_clean(action.resolution) != null) 'Resolution: ${action.resolution}',
    if (_clean(action.remarks) != null) 'Remarks: ${action.remarks}',
    if (action.status != null) 'Status: ${_label(action.status!.name)}',
    if (_clean(action.burnerOutcome) != null)
      'Burner outcome: ${_label(action.burnerOutcome!)}',
    if (action.burnerMicroampReading != null)
      'Flame signal: ${action.burnerMicroampReading} microamp',
    if (_clean(action.burnerBlockSupplierName) != null)
      'Supplier: ${action.burnerBlockSupplierName}',
    if (_clean(action.burnerBlockPurchaseOrderNumber) != null)
      'PO: ${action.burnerBlockPurchaseOrderNumber}',
  ];
  return <String>[
    source,
    _dateTime(action.createdAt),
    target.join(' > '),
    actionLabel.join(' / '),
    outcome.isEmpty ? 'No outcome text recorded' : outcome.join('\n'),
    _value(action.performedBy),
  ];
}

List<String> _diaryRow(JobDiaryEntry entry) {
  final target = <String>[
    _label(entry.discipline.name),
    if (_clean(entry.functionalSection) != null) entry.functionalSection!,
    if (_clean(entry.componentGroup) != null) entry.componentGroup!,
    if (_clean(entry.targetRef) != null) entry.targetRef!,
  ];
  final content = <String>[
    entry.displayTitle,
    entry.note,
    if (entry.blockerStatus != null)
      'Blocker: ${_label(entry.blockerStatus!.name)}',
  ];
  final followUp = <String>[
    if (_clean(entry.actionTaken) != null) 'Action: ${entry.actionTaken}',
    if (_clean(entry.pendingIssue) != null) 'Pending: ${entry.pendingIssue}',
    if (entry.requiresFollowUp) 'Follow-up required',
    if (entry.isDeleted)
      'Removed ${entry.deletedAt == null ? 'time not recorded' : _dateTime(entry.deletedAt!)} '
          'by ${_value(entry.deletedByName)}: ${_value(entry.deleteReason)}',
  ];
  return <String>[
    _dateTime(entry.createdAt),
    '${_label(entry.kind.name)} / ${_label(entry.severity.name)}',
    target.join(' > '),
    content.join('\n'),
    followUp.isEmpty ? 'None recorded' : followUp.join('\n'),
    _value(entry.createdByName),
  ];
}

List<String> _laneRow(JobLaneRecord lane) => <String>[
  _label(lane.laneKey),
  _label(lane.statusKey),
  lane.acknowledgedAt == null
      ? 'Not acknowledged'
      : '${_dateTime(lane.acknowledgedAt!)} by ${_value(lane.acknowledgedByName)}',
  lane.closedAt != null
      ? '${_dateTime(lane.closedAt!)} by ${_value(lane.closedByName)}; ${_value(lane.closeNote)}'
      : lane.removedAt != null
      ? 'Removed ${_dateTime(lane.removedAt!)}; ${_value(lane.removeReason)}'
      : lane.terminatedAt != null
      ? 'Terminated ${_dateTime(lane.terminatedAt!)}; ${_value(lane.terminateReason)}'
      : 'Open',
  '${lane.progressRevision} / v${lane.version}',
];

List<String> _complianceRow(ComplianceRequestRecord request) => <String>[
  request.raisedAt == null
      ? _dateTime(request.createdAt)
      : _dateTime(request.raisedAt!),
  '${request.requestPurposeLabel} / ${_label(request.targetLaneKey)}',
  '${request.title}\n${request.description}'
      '${_clean(request.operationsResourceKey) == null ? '' : '\nResource: ${_label(request.operationsResourceKey!)}'}'
      '${_clean(request.requestedLocation) == null ? '' : '\nLocation: ${request.requestedLocation}'}',
  _label(request.statusKey),
  <String>[
    if (request.acknowledgedAt != null)
      'Acknowledged ${_dateTime(request.acknowledgedAt!)} by ${_value(request.acknowledgedByName)}',
    if (request.compliedAt != null)
      'Complied ${_dateTime(request.compliedAt!)} by ${_value(request.compliedByName)}: ${_value(request.complianceNote)}',
    if (request.confirmedAt != null)
      'Confirmed ${_dateTime(request.confirmedAt!)} by ${_value(request.confirmedByName)}: ${_value(request.confirmNote)}',
  ].join('\n'),
];

List<String> _eventRow(WorkflowEventRecord event) => <String>[
  _dateTime(event.occurredAt),
  _label(event.eventTypeKey),
  _label(event.laneKey ?? 'aggregate'),
  _value(event.actorName),
  event.payloadJson,
];

String _responseValue(Object? value) {
  if (value == null) return 'Not answered';
  if (value is List) return value.map((item) => '$item').join(', ');
  if (value is Map) return const JsonEncoder.withIndent('  ').convert(value);
  if (value is bool) return value ? 'Yes' : 'No';
  final text = '$value'.trim();
  return text.isEmpty ? 'Blank response' : text;
}

String _dateTime(DateTime value) => value.toLocal().toIso8601String();

String _value(String? value) => _clean(value) ?? 'Not recorded';

String? _clean(String? value) {
  final cleaned = value?.trim();
  return cleaned == null || cleaned.isEmpty ? null : cleaned;
}

String _label(String value) {
  final spaced = value
      .trim()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      );
  if (spaced.isEmpty) return 'Not recorded';
  return spaced
      .split(RegExp(r'\s+'))
      .map(
        (word) =>
            word.length <= 2
                ? word.toUpperCase()
                : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
