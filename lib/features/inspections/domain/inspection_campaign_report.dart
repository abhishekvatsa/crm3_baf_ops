import '../data/inspection_campaign.dart';
import '../../reports/domain/report_provenance.dart';
import '../../reports/domain/structured_report_document.dart';

bool hasInspectionCampaignReportEvidence({
  required InspectionCampaign campaign,
  required List<InspectionObservation> observations,
}) =>
    observations.isNotEmpty ||
    campaign.targets.any(
      (target) => target.disposition != InspectionTargetDisposition.pending,
    );

StructuredReportDocument buildInspectionCampaignReport({
  required InspectionCampaign campaign,
  required List<InspectionObservation> observations,
  required List<InspectionFinding> findings,
  required DateTime generatedAt,
  required String generatedByName,
  required ReportProvenance provenance,
}) {
  if (!hasInspectionCampaignReportEvidence(
    campaign: campaign,
    observations: observations,
  )) {
    throw StateError(
      'An inspection report requires at least one recorded audit result.',
    );
  }
  if (observations.any((row) => row.campaignId != campaign.id) ||
      findings.any((row) => row.campaignId != campaign.id)) {
    throw StateError(
      'Inspection evidence from another campaign cannot be reported here.',
    );
  }

  final orderedObservations = observations.toList(growable: false)
    ..sort((left, right) {
      final occurrence = left.observedAt.compareTo(right.observedAt);
      return occurrence != 0
          ? occurrence
          : left.recordedAt.compareTo(right.recordedAt);
    });
  final supersededObservationIds = observations
      .map((row) => row.supersedesObservationId)
      .whereType<String>()
      .toSet();
  final currentObservations = _currentObservationsByTarget(
    campaign.targets,
    observations,
  );
  final orderedFindings = findings.toList(growable: false)
    ..sort((left, right) {
      final asset = left.assetNumber.compareTo(right.assetNumber);
      return asset != 0
          ? asset
          : left.latestObservedAt.compareTo(right.latestObservedAt);
    });

  return StructuredReportDocument(
    title: 'Inspection audit dossier',
    subtitle: 'Complete campaign scope, readings, dispositions and findings',
    reportId: createStructuredReportId('AUDIT', generatedAt),
    generatedAt: generatedAt,
    generatedByName: generatedByName,
    scopeLabel:
        '${campaign.definition.code} / ${_assetTypeLabel(campaign.assetTypeKey)} / ${campaign.id}',
    provenance: provenance,
    orientation: StructuredReportOrientation.landscape,
    sections: <StructuredReportSection>[
      StructuredReportSection(
        title: 'Campaign identity and authority',
        metrics: <StructuredReportMetric>[
          StructuredReportMetric(
            label: 'Status',
            value: _enumLabel(campaign.status.name),
            tone: campaign.status == InspectionCampaignStatus.closed
                ? StructuredReportMetricTone.positive
                : StructuredReportMetricTone.warning,
          ),
          StructuredReportMetric(
            label: 'Expected targets',
            value: '${campaign.expectedPopulation}',
            tone: StructuredReportMetricTone.info,
          ),
          StructuredReportMetric(
            label: 'Accounted targets',
            value: '${campaign.accountedTargetCount}',
            detail: '${campaign.remainingPopulation} remaining',
            tone: campaign.remainingPopulation == 0
                ? StructuredReportMetricTone.positive
                : StructuredReportMetricTone.warning,
          ),
          StructuredReportMetric(
            label: 'Immutable readings',
            value: '${observations.length}',
            tone: StructuredReportMetricTone.info,
          ),
          StructuredReportMetric(
            label: 'Findings',
            value: '${findings.length}',
            tone: findings.any((finding) => finding.blocksCampaignClosure)
                ? StructuredReportMetricTone.danger
                : StructuredReportMetricTone.neutral,
          ),
        ],
        fields: <StructuredReportField>[
          StructuredReportField(
            label: 'Definition',
            value:
                '${campaign.definition.code} v${campaign.definition.version} - ${campaign.definition.title}',
          ),
          StructuredReportField(
            label: 'Definition description',
            value: campaign.definition.description,
          ),
          StructuredReportField(label: 'Purpose', value: campaign.purpose),
          StructuredReportField(
            label: 'Population',
            value: _populationLabel(campaign),
          ),
          StructuredReportField(
            label: 'Value contract',
            value: _valueContract(campaign.definition),
          ),
          StructuredReportField(
            label: 'Permitted observer roles',
            value: campaign.observerRoleKeys.isEmpty
                ? 'Any approved inspection observer'
                : campaign.observerRoleKeys.map(_enumLabel).join(', '),
          ),
          StructuredReportField(
            label: 'Preconditions',
            value: campaign.definition.preconditions.isEmpty
                ? 'None recorded'
                : campaign.definition.preconditions.join('; '),
          ),
          StructuredReportField(
            label: 'Campaign created',
            value: _dateTime(campaign.createdAt),
          ),
          StructuredReportField(
            label: 'Latest observation',
            value: _optionalDateTime(campaign.latestObservationAt),
          ),
          StructuredReportField(
            label: 'Baseline campaign',
            value: campaign.baselineCampaignId ?? 'None',
          ),
        ],
      ),
      StructuredReportSection(
        title: 'Target coverage and disposition',
        subtitle:
            'Every frozen campaign target is retained, including targets without a reading.',
        tables: <StructuredReportTable>[
          StructuredReportTable(
            headers: const <String>[
              'Target',
              'Component / position',
              'Disposition',
              'Current result',
              'Accountability',
              'Frozen identity context',
            ],
            rows: campaign.targets
                .map(
                  (target) =>
                      _targetRow(target, currentObservations[target.targetKey]),
                )
                .toList(growable: false),
            columnFlex: const <double>[1.35, 1.45, 1.15, 1.35, 1.75, 2.1],
          ),
        ],
      ),
      if (orderedObservations.isNotEmpty)
        StructuredReportSection(
          title: 'Immutable readings and corrections',
          subtitle:
              'Occurrence time and record time are both shown. Superseded readings remain visible.',
          pageBreakBefore: true,
          tables: <StructuredReportTable>[
            StructuredReportTable(
              headers: const <String>[
                'Observed / recorded',
                'Target / component',
                'Result',
                'Operating context',
                'Observer',
                'Trace and evidence',
              ],
              rows: orderedObservations
                  .map(
                    (row) => _observationRow(
                      row,
                      isSuperseded: supersededObservationIds.contains(row.id),
                    ),
                  )
                  .toList(growable: false),
              columnFlex: const <double>[1.25, 1.8, 1.25, 1.65, 1.2, 2.35],
            ),
          ],
        ),
      if (orderedFindings.isNotEmpty)
        StructuredReportSection(
          title: 'Findings and follow-through',
          subtitle:
              'Finding status, recurrence, linked maintenance and verification evidence.',
          pageBreakBefore: true,
          tables: <StructuredReportTable>[
            StructuredReportTable(
              headers: const <String>[
                'Target',
                'Component / position',
                'Status',
                'First / latest',
                'Recurrence',
                'Corrective and verification evidence',
              ],
              rows: orderedFindings.map(_findingRow).toList(growable: false),
              columnFlex: const <double>[1.4, 1.55, 1.15, 1.45, 0.75, 2.35],
            ),
          ],
        ),
    ],
  );
}

Map<String, InspectionObservation> _currentObservationsByTarget(
  List<InspectionCampaignTarget> targets,
  List<InspectionObservation> observations,
) {
  final observationsById = <String, InspectionObservation>{
    for (final observation in observations) observation.id: observation,
  };
  final result = <String, InspectionObservation>{};
  final certifiedTargetKeys = <String>{};
  for (final target in targets) {
    final certified = observationsById[target.lastObservationId];
    if (certified != null && certified.targetKey == target.targetKey) {
      result[target.targetKey] = certified;
      certifiedTargetKeys.add(target.targetKey);
    }
  }
  for (final observation in observations) {
    if (certifiedTargetKeys.contains(observation.targetKey)) continue;
    final current = result[observation.targetKey];
    if (current == null || observation.observedAt.isAfter(current.observedAt)) {
      result[observation.targetKey] = observation;
    }
  }
  return result;
}

List<String> _targetRow(
  InspectionCampaignTarget target,
  InspectionObservation? latest,
) => <String>[
  target.rowLabel,
  _componentPosition(
    componentName: latest?.componentName,
    componentNodeId: target.componentNodeId,
    hierarchyPath: latest?.hierarchyPath ?? const <String>[],
    physicalPosition: target.physicalPosition,
  ),
  '${_enumLabel(target.disposition.name)}'
      '${target.dispositionReason == null ? '' : '\n${target.dispositionReason}'}',
  latest == null
      ? 'No reading recorded'
      : '${latest.displayValue}\n${latest.outOfRange ? 'Exception recorded' : 'Within defined condition'}',
  '${_dateTime(target.dispositionAt)}\nby ${target.dispositionByName}',
  'Asset v${target.assetInstanceVersion}'
      '${target.addedLater ? '\nAdded after campaign start' : ''}'
      '${target.subjectSerialNumber == null ? '' : '\nInner Cover ${target.subjectSerialNumber}'}'
      '${target.linkageVersion == null ? '' : '\nLinkage v${target.linkageVersion} at ${_optionalDateTime(target.linkedAt)}'}',
];

List<String> _observationRow(
  InspectionObservation observation, {
  required bool isSuperseded,
}) => <String>[
  '${_dateTime(observation.observedAt)}\nRecorded ${_dateTime(observation.recordedAt)}',
  '${observation.rowLabel}\n${_componentPosition(componentName: observation.componentName, componentNodeId: observation.componentNodeId, hierarchyPath: observation.hierarchyPath, physicalPosition: observation.physicalPosition)}',
  '${observation.displayValue}\n${observation.outOfRange ? 'Exception recorded' : 'Within defined condition'}\n${isSuperseded ? 'Superseded' : 'Current'}',
  _operatingContext(observation),
  '${observation.observerName}\n${observation.observerUid}',
  'Observation ${observation.id}'
      '${observation.supersedesObservationId == null ? '' : '\nCorrects ${observation.supersedesObservationId}'}'
      '${observation.baselineObservationId == null ? '' : '\nBaseline ${observation.baselineObservationId}'}'
      '${observation.comparisonOutcome == null ? '' : '\n${_enumLabel(observation.comparisonOutcome!.name)}'}'
      '${observation.note == null ? '' : '\nNote: ${observation.note}'}'
      '${observation.evidenceUrls.isEmpty ? '' : '\nEvidence: ${observation.evidenceUrls.join(', ')}'}',
];

List<String> _findingRow(InspectionFinding finding) => <String>[
  '${finding.rowLabel}\n${finding.targetKey}',
  _componentPosition(
    componentName: finding.componentName,
    componentNodeId: finding.componentNodeId,
    hierarchyPath: const <String>[],
    physicalPosition: finding.physicalPosition,
  ),
  _enumLabel(finding.status.name),
  '${_dateTime(finding.firstObservedAt)}\n${_dateTime(finding.latestObservedAt)}',
  '${finding.recurrenceCount}',
  '${finding.linkedTicketId == null ? 'No linked maintenance issue' : 'Issue ${finding.linkedTicketId}'}'
      '\n${finding.verificationCount} verification(s)'
      '${finding.lastVerificationOutcome == null ? '' : '\nLast: ${_enumLabel(finding.lastVerificationOutcome!.name)}'}'
      '\nUpdated ${_dateTime(finding.updatedAt)}',
];

String _populationLabel(InspectionCampaign campaign) =>
    campaign.populationMode ==
        InspectionCampaignPopulationMode.installedInnerCoversByBase
    ? 'Installed Inner Covers presented by governed Base linkage'
    : '${_assetTypeLabel(campaign.assetTypeKey)} governed asset instances';

String _valueContract(
  FrozenInspectionDefinition definition,
) => switch (definition.valueType) {
  InspectionValueType.number =>
    'Number in ${definition.unit}'
        '${definition.minimumValue == null ? '' : '; minimum ${definition.minimumValue}'}'
        '${definition.maximumValue == null ? '' : '; maximum ${definition.maximumValue}'}',
  InspectionValueType.boolean => 'Yes / No',
  InspectionValueType.text => 'Recorded text',
  InspectionValueType.choice =>
    'Governed choice: ${definition.choiceValues.join(', ')}',
};

String _operatingContext(InspectionObservation observation) {
  final conditions = observation.operatingConditions.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  final values = <String>[
    if (observation.chargeNo != null) 'Charge ${observation.chargeNo}',
    ...conditions.map((entry) => '${_enumLabel(entry.key)}: ${entry.value}'),
    if (observation.subjectSerialNumber != null)
      'Inner Cover ${observation.subjectSerialNumber}',
    if (observation.linkageVersion != null)
      'Frozen linkage v${observation.linkageVersion}',
  ];
  return values.isEmpty ? 'None recorded' : values.join('\n');
}

String _componentPosition({
  required String? componentName,
  required String? componentNodeId,
  required List<String> hierarchyPath,
  required String? physicalPosition,
}) {
  final component = hierarchyPath.isNotEmpty
      ? hierarchyPath.join(' / ')
      : componentName ?? componentNodeId ?? 'Whole asset';
  return physicalPosition == null ? component : '$component\n$physicalPosition';
}

String _assetTypeLabel(String key) => switch (key) {
  'base' => 'Base',
  'furnace' => 'Furnace',
  'forceCooler' => 'Forced Cooler',
  'innerCover' => 'Inner Cover',
  _ => _enumLabel(key),
};

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}-${two(local.month)}-${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _optionalDateTime(DateTime? value) =>
    value == null ? 'Not recorded' : _dateTime(value);

String _enumLabel(String value) {
  final words = value.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return words.isEmpty
      ? value
      : '${words[0].toUpperCase()}${words.substring(1)}';
}
