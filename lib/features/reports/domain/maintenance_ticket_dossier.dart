import '../../audit/models/audit_event_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/domain/furnace_stuckup_case.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import 'report_provenance.dart';
import 'structured_report_document.dart';

StructuredReportDocument buildMaintenanceTicketDossier({
  required MaintenanceRecord ticket,
  required List<AuditEvent> correctionEvents,
  required DateTime generatedAt,
  required String generatedByName,
  required ReportProvenance provenance,
}) {
  final laneRead = ticket.issueLanePlanReadResult;
  final actionsRead = ticket.actionsReadResult;
  final historyRead = ticket.resolutionHistoryReadResult;
  if (!laneRead.isValid || laneRead.value == null) {
    throw StateError(
      'The issue lane evidence is malformed and cannot be reported.',
    );
  }
  if (!actionsRead.isValid) {
    throw StateError(
      'The issue action evidence is malformed and cannot be reported.',
    );
  }
  if (!historyRead.isValid) {
    throw StateError(
      'The issue lifecycle history is malformed and cannot be reported.',
    );
  }

  final lanePlan = laneRead.value!;
  final hierarchy = ticket.assetHierarchyReference;
  final innerCover = hierarchy?.innerCoverAssociation;
  final closure = ticket.administrativeClosure;
  final qualityIntent = ticket.qualityIntent;
  final burnerRead = ticket.burnerLockoutReadResult;
  if (!burnerRead.isValid) {
    throw StateError(
      'The Burner lockout evidence is malformed and cannot be reported.',
    );
  }
  final stuckup = ticket.furnaceStuckupCase;
  final assetLabel = _ticketAssetLabel(ticket);
  final orderedCorrectionEvents =
      maintenanceTicketCorrectionEventsInDossierOrder(correctionEvents);
  final currentActions = actionsRead.entries;
  final priorActions = <({int cycle, ComponentAction action})>[];
  for (var index = 0; index < historyRead.entries.length; index++) {
    final entry = historyRead.entries[index];
    final actions = ComponentAction.decode(
      entry.actionsJson ?? '[]',
      source: 'maintenance dossier prior closure ${index + 1}',
    );
    priorActions.addAll(
      actions.map((action) => (cycle: index + 1, action: action)),
    );
  }

  return StructuredReportDocument(
    title: 'Maintenance issue dossier',
    subtitle: 'Complete issue lifecycle, work, closure and correction evidence',
    reportId: createStructuredReportId('ISSUE', generatedAt),
    generatedAt: generatedAt,
    generatedByName: generatedByName,
    scopeLabel: '$assetLabel / ${ticket.firestoreId ?? 'local-${ticket.id}'}',
    provenance: provenance,
    sections: <StructuredReportSection>[
      StructuredReportSection(
        title: 'Issue identity and context',
        metrics: <StructuredReportMetric>[
          StructuredReportMetric(
            label: 'Lifecycle',
            value: ticket.lifecycleSummaryLabel,
            tone:
                ticket.isClosed
                    ? StructuredReportMetricTone.positive
                    : StructuredReportMetricTone.warning,
          ),
          StructuredReportMetric(
            label: 'Critical',
            value: ticket.isCritical ? 'Yes' : 'No',
            tone:
                ticket.isCritical
                    ? StructuredReportMetricTone.danger
                    : StructuredReportMetricTone.neutral,
          ),
          StructuredReportMetric(
            label: 'Lane count',
            value: '${lanePlan.assignedLanes.length}',
            tone: StructuredReportMetricTone.info,
          ),
          StructuredReportMetric(
            label: 'Recorded actions',
            value: '${currentActions.length + priorActions.length}',
            tone: StructuredReportMetricTone.info,
          ),
        ],
        fields: <StructuredReportField>[
          StructuredReportField(label: 'Asset', value: assetLabel),
          StructuredReportField(
            label: 'Maintenance type',
            value: _enumLabel(ticket.maintenanceType.name),
          ),
          StructuredReportField(
            label: 'Classification',
            value: _value(ticket.classification),
          ),
          StructuredReportField(
            label: 'Description',
            value: ticket.description,
          ),
          StructuredReportField(
            label: 'Component path',
            value: _componentPath(ticket),
          ),
          StructuredReportField(label: 'Tag', value: _value(ticket.tag)),
          StructuredReportField(
            label: 'Charge at event',
            value: ticket.chargeNoAtEvent?.toString() ?? 'Not recorded',
          ),
          if (innerCover != null)
            StructuredReportField(
              label: 'Inner Cover at event',
              value:
                  innerCover.innerCoverSerialNumber == null
                      ? 'No Inner Cover linked to Base ${innerCover.baseAssetNumber}'
                      : '${innerCover.innerCoverSerialNumber} linked to Base ${innerCover.baseAssetNumber}',
            ),
        ],
      ),
      StructuredReportSection(
        title: 'Lane accountability',
        subtitle:
            'Canonical lane revision ${lanePlan.revision}. Completion times are retained per lane for governed closures.',
        fields: <StructuredReportField>[
          StructuredReportField(
            label: 'First acknowledgement',
            value:
                ticket.acknowledgedAt == null
                    ? 'Not recorded'
                    : '${_dateTime(ticket.acknowledgedAt!)} by ${_value(ticket.acknowledgedByName)}',
          ),
          StructuredReportField(
            label: 'Teams involved',
            value:
                ticket.teamsInvolved.isEmpty
                    ? 'Not recorded'
                    : ticket.teamsInvolved.join(', '),
          ),
          if (_hasText(ticket.otherDepartment))
            StructuredReportField(
              label: 'Other department',
              value: ticket.otherDepartment!.trim(),
            ),
        ],
        tables: <StructuredReportTable>[
          StructuredReportTable(
            headers: const <String>[
              'Lane',
              'Acknowledged',
              'Completed',
              'Completion time / authority',
            ],
            rows: lanePlan.assignedLanes
                .map(
                  (lane) => <String>[
                    _enumLabel(lane),
                    lanePlan.acknowledgedLanes.contains(lane) ? 'Yes' : 'No',
                    lanePlan.completedLanes.contains(lane) ? 'Yes' : 'No',
                    !lanePlan.completedLanes.contains(lane)
                        ? '-'
                        : lanePlan.completionEvidence[lane] == null
                        ? 'Exact lane completion time was not retained for this record'
                        : '${_dateTime(lanePlan.completionEvidence[lane]!.completedAt)} by ${lanePlan.completionEvidence[lane]!.completedByName}',
                  ],
                )
                .toList(growable: false),
            columnFlex: const <double>[1.25, 0.8, 0.8, 2.4],
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Lifecycle chronology',
        tables: <StructuredReportTable>[
          StructuredReportTable(
            headers: const <String>['Time', 'Event', 'Actor / evidence'],
            rows: _timelineRows(ticket, historyRead.entries),
            columnFlex: const <double>[1.25, 1.1, 2.7],
          ),
          StructuredReportTable(
            title: 'Closure cycles',
            headers: const <String>[
              'Cycle',
              'Resolved',
              'Resolved by',
              'Reopened',
              'Reopened by / reason',
              'Downtime / teams',
            ],
            rows: _closureRows(ticket, historyRead.entries),
            columnFlex: const <double>[0.45, 1, 1, 1, 2, 1.4],
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Recorded maintenance actions',
        subtitle:
            'Action time, hierarchy, tag, replacement disposition and Burner evidence are retained.',
        tables: <StructuredReportTable>[
          StructuredReportTable(
            headers: const <String>[
              'Closure',
              'Action time',
              'Target',
              'Action / replacement',
              'Outcome / remarks',
              'Performed by',
            ],
            rows: <List<String>>[
              for (final row in priorActions)
                _actionRow('Cycle ${row.cycle}', row.action),
              for (final action in currentActions)
                _actionRow('Current', action),
            ],
            columnFlex: const <double>[0.7, 1.15, 1.8, 1.6, 2.2, 1.1],
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Closure and connected controls',
        fields: <StructuredReportField>[
          StructuredReportField(
            label: 'Current outcome',
            value:
                !ticket.isClosed
                    ? 'Issue remains open'
                    : closure == null
                    ? 'Technically resolved'
                    : closure.disposition.name == 'stillRelevant'
                    ? 'Closed without resolution; still relevant'
                    : 'Closed without resolution; relevance ended',
          ),
          if (closure != null)
            StructuredReportField(
              label: 'Administrative reason',
              value: closure.reason,
            ),
          StructuredReportField(
            label: 'Final remarks',
            value: _value(ticket.remarks),
          ),
          StructuredReportField(
            label: 'Coordination workflow',
            value:
                ticket.isWorkflowLinked
                    ? '${ticket.workflowStateLabel} / ${_value(ticket.workflowAggregateId)}'
                    : 'Independent',
          ),
          StructuredReportField(
            label: 'Operational event links',
            value: '${ticket.operationalEventIssueLinkIds.length}',
          ),
          StructuredReportField(
            label: 'Quality assessment',
            value:
                qualityIntent == null
                    ? 'No quality assessment retained'
                    : '${_enumLabel(qualityIntent.assessment.name)}; '
                        'reason ${_value(qualityIntent.warningReason)}; '
                        'abnormality ${_value(qualityIntent.abnormalityTypeId)}',
          ),
          if (burnerRead.value != null)
            StructuredReportField(
              label: 'Burner lockout case',
              value:
                  'Burners ${burnerRead.value!.positions.join(', ')}; '
                  'stage ${_enumLabel(burnerRead.value!.cycleStage.name)}; '
                  'attended ${burnerRead.value!.attendedPositions.join(', ')}; '
                  'remains locked out ${burnerRead.value!.remainsLockedOut ? 'yes' : 'no'}',
            ),
          if (stuckup != null)
            StructuredReportField(
              label: 'Furnace stuck-up case',
              value:
                  'Base ${stuckup.baseNumber}; ${stuckup.suspectedCause.label}; '
                  '${stuckup.operatingContext.label}; Inner Cover '
                  '${stuckup.innerCoverAssociation.innerCoverSerialNumber}',
            ),
        ],
      ),
      StructuredReportSection(
        title: 'Audited Admin / SI corrections',
        subtitle:
            'Before-and-after payloads are preserved verbatim from the available audit events.',
        paragraphs:
            orderedCorrectionEvents.isEmpty
                ? const <String>['No governed Admin/SI correction is recorded.']
                : <String>[
                  for (
                    var index = 0;
                    index < orderedCorrectionEvents.length;
                    index++
                  )
                    _correctionParagraph(
                      index + 1,
                      orderedCorrectionEvents[index],
                    ),
                ],
      ),
      StructuredReportSection(
        title: 'Record assurance',
        fields: <StructuredReportField>[
          StructuredReportField(
            label: 'Synchronization',
            value:
                ticket.isSynced ? 'Server-synchronized' : 'Pending local write',
          ),
          StructuredReportField(label: 'Version', value: '${ticket.version}'),
          StructuredReportField(
            label: 'Governed record ID',
            value: ticket.firestoreId ?? 'Local ${ticket.id}',
          ),
          StructuredReportField(
            label: 'Last update',
            value: _dateTime(ticket.updatedAt),
          ),
          if (ticket.isDeleted)
            StructuredReportField(
              label: 'Deletion evidence',
              value:
                  '${ticket.deletedAt == null ? 'Time unavailable' : _dateTime(ticket.deletedAt!)} by '
                  '${_value(ticket.deletedByName)}; ${_value(ticket.deleteReason)}',
            ),
        ],
      ),
    ],
  );
}

List<AuditEvent> maintenanceTicketCorrectionEventsInDossierOrder(
  Iterable<AuditEvent> events,
) {
  final ordered = events.toList(growable: false)..sort((left, right) {
    final timestampOrder = left.timestamp.compareTo(right.timestamp);
    if (timestampOrder != 0) return timestampOrder;
    final leftRemoteId = left.remoteDocumentId;
    final rightRemoteId = right.remoteDocumentId;
    if (leftRemoteId != null || rightRemoteId != null) {
      return (leftRemoteId ?? '').compareTo(rightRemoteId ?? '');
    }
    return left.id.compareTo(right.id);
  });
  return List<AuditEvent>.unmodifiable(ordered);
}

List<List<String>> _timelineRows(
  MaintenanceRecord ticket,
  List<ResolutionHistory> history,
) {
  final rows = <({DateTime at, List<String> values})>[
    (
      at: ticket.startDate,
      values: <String>[
        _dateTime(ticket.startDate),
        'Issue started',
        ticket.description,
      ],
    ),
    (
      at: ticket.createdAt,
      values: <String>[
        _dateTime(ticket.createdAt),
        'Record raised',
        _value(ticket.loggedByName ?? ticket.reportedBy),
      ],
    ),
    if (ticket.acknowledgedAt != null)
      (
        at: ticket.acknowledgedAt!,
        values: <String>[
          _dateTime(ticket.acknowledgedAt!),
          'First acknowledgement',
          _value(ticket.acknowledgedByName),
        ],
      ),
    for (var index = 0; index < history.length; index++) ...[
      if (history[index].resolvedAt != null)
        (
          at: history[index].resolvedAt!,
          values: <String>[
            _dateTime(history[index].resolvedAt!),
            'Closure cycle ${index + 1}',
            '${_value(history[index].resolvedByName)}; ${_value(history[index].remarks)}',
          ],
        ),
      if (history[index].reopenedAt != null)
        (
          at: history[index].reopenedAt!,
          values: <String>[
            _dateTime(history[index].reopenedAt!),
            'Reopened after cycle ${index + 1}',
            '${_value(history[index].reopenedByName)}; ${_value(history[index].reopenReason)}',
          ],
        ),
    ],
    if (ticket.endDate != null)
      (
        at: ticket.endDate!,
        values: <String>[
          _dateTime(ticket.endDate!),
          ticket.wasClosedWithoutResolution
              ? 'Administrative closure'
              : 'Technical closure',
          _value(ticket.closedByName),
        ],
      ),
    (
      at: ticket.updatedAt,
      values: <String>[
        _dateTime(ticket.updatedAt),
        'Last record update',
        'Version ${ticket.version}',
      ],
    ),
  ];
  rows.sort((left, right) => left.at.compareTo(right.at));
  return rows.map((row) => row.values).toList(growable: false);
}

List<List<String>> _closureRows(
  MaintenanceRecord ticket,
  List<ResolutionHistory> history,
) => <List<String>>[
  for (var index = 0; index < history.length; index++)
    <String>[
      '${index + 1}',
      history[index].resolvedAt == null
          ? 'Not retained'
          : _dateTime(history[index].resolvedAt!),
      _value(history[index].resolvedByName),
      history[index].reopenedAt == null
          ? 'Not reopened'
          : _dateTime(history[index].reopenedAt!),
      history[index].reopenedAt == null
          ? '-'
          : '${_value(history[index].reopenedByName)} / ${_value(history[index].reopenReason)}',
      '${history[index].downtimeHours?.toStringAsFixed(2) ?? '-'} h / '
          '${history[index].teamsInvolved.isEmpty ? '-' : history[index].teamsInvolved.join(', ')}',
    ],
  if (ticket.isClosed)
    <String>[
      'Current',
      ticket.endDate == null ? 'Not retained' : _dateTime(ticket.endDate!),
      _value(ticket.closedByName),
      'Not reopened',
      '-',
      '${ticket.downtimeHours?.toStringAsFixed(2) ?? '-'} h / '
          '${ticket.teamsInvolved.isEmpty ? '-' : ticket.teamsInvolved.join(', ')}',
    ],
];

List<String> _actionRow(String cycle, ComponentAction action) {
  final target = <String>[
    if (action.hierarchyPath?.isNotEmpty == true)
      action.hierarchyPath!.join(' / '),
    if (_hasText(action.component)) action.component.trim(),
    if (_hasText(action.subComponent)) action.subComponent!.trim(),
    if (_hasText(action.tag)) 'Tag ${action.tag!.trim()}',
    if (action.burnerPosition != null) 'Burner ${action.burnerPosition}',
  ];
  final actionEvidence = <String>[
    _enumLabel(action.actionType.name),
    if (action.replacement != null) _enumLabel(action.replacement!.name),
    if (action.burnerBlockSupplyMode != null)
      _enumLabel(action.burnerBlockSupplyMode!.name),
    if (_hasText(action.burnerBlockSupplierName))
      'Supplier ${action.burnerBlockSupplierName!}',
    if (_hasText(action.burnerBlockPurchaseOrderNumber))
      'PO ${action.burnerBlockPurchaseOrderNumber!}',
  ];
  final outcome = <String>[
    if (_hasText(action.issue)) action.issue!.trim(),
    if (_hasText(action.resolution)) action.resolution!.trim(),
    if (_hasText(action.burnerActionCode))
      'Burner action ${_enumLabel(action.burnerActionCode!)}',
    if (_hasText(action.burnerOutcome))
      'Outcome ${_enumLabel(action.burnerOutcome!)}',
    if (action.burnerMicroampReading != null)
      '${action.burnerMicroampReading} microamp',
    if (_hasText(action.remarks)) action.remarks!.trim(),
  ];
  return <String>[
    cycle,
    '${_dateTime(action.createdAt)}${action.updatedAt == null ? '' : ' / updated ${_dateTime(action.updatedAt!)}'}',
    target.isEmpty ? 'Not specified' : target.join(' / '),
    actionEvidence.join(' / '),
    outcome.isEmpty ? 'Not recorded' : outcome.join(' / '),
    _value(action.performedBy),
  ];
}

String _correctionParagraph(int sequence, AuditEvent event) =>
    'Correction $sequence at ${_dateTime(event.timestamp)} by '
    '${_value(event.performedByName ?? event.performedByUid)}. '
    'Reason: ${_value(event.reasonNotes)}. Summary: ${_value(event.summary)}. '
    'Before: ${event.beforeJson ?? 'Not retained'}. '
    'After: ${event.afterJson ?? 'Not retained'}.';

String _ticketAssetLabel(MaintenanceRecord ticket) {
  final hierarchy = ticket.assetHierarchyReference;
  if (hierarchy != null) {
    return '${hierarchy.assetClassName} ${hierarchy.assetNumber ?? ticket.assetNumber}';
  }
  return switch (ticket.assetType) {
    AssetType.base => 'Base ${ticket.assetNumber}',
    AssetType.furnace => 'Furnace ${ticket.assetNumber}',
    AssetType.forceCooler => 'Forced Cooler ${ticket.assetNumber}',
    AssetType.innerCover => 'Inner Cover ${ticket.assetNumber}',
    AssetType.governedCustom => 'Asset ${ticket.assetNumber}',
  };
}

String _componentPath(MaintenanceRecord ticket) {
  final hierarchy = ticket.assetHierarchyReference;
  final parts = <String>[
    if (hierarchy != null) ...hierarchy.hierarchyPath,
    if (hierarchy == null && _hasText(ticket.subsystem))
      ticket.subsystem!.trim(),
    if (hierarchy == null && _hasText(ticket.component))
      ticket.component!.trim(),
  ];
  return parts.isEmpty ? 'Not specified' : parts.join(' / ');
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}-${two(local.month)}-${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _enumLabel(String value) {
  final words = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return words.isEmpty
      ? value
      : '${words[0].toUpperCase()}${words.substring(1)}';
}

bool _hasText(String? value) => value?.trim().isNotEmpty == true;

String _value(String? value) =>
    _hasText(value) ? value!.trim() : 'Not recorded';
