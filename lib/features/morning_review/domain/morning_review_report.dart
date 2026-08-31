import 'package:intl/intl.dart';

import '../../reports/domain/report_provenance.dart';
import '../../reports/domain/structured_report_document.dart';
import 'morning_review_models.dart';

StructuredReportDocument buildMorningReviewReport({
  required MorningReviewDocument document,
  List<MorningReviewEntry> addenda = const [],
}) {
  final dateTime = DateFormat('dd MMM yyyy, HH:mm');
  final sections = <StructuredReportSection>[
    StructuredReportSection(
      title: 'Meeting record',
      metrics: [
        StructuredReportMetric(
          label: 'Source facts',
          value: '${document.sourceFacts.length}',
          tone: StructuredReportMetricTone.info,
        ),
        StructuredReportMetric(
          label: 'Contributions',
          value: '${document.entries.length}',
          tone: StructuredReportMetricTone.info,
        ),
        StructuredReportMetric(
          label: 'Actions',
          value: '${document.actions.length}',
          tone:
              document.actions.any(
                    (action) =>
                        action.status != MorningReviewActionStatus.completed,
                  )
                  ? StructuredReportMetricTone.warning
                  : StructuredReportMetricTone.positive,
        ),
        StructuredReportMetric(
          label: 'Standing concerns',
          value: '${document.standingConcerns.length}',
          tone:
              document.standingConcerns.any(
                    (concern) =>
                        concern.status == MorningReviewConcernStatus.active,
                  )
                  ? StructuredReportMetricTone.warning
                  : StructuredReportMetricTone.positive,
        ),
        StructuredReportMetric(
          label: 'Participants',
          value: '${document.participants.length}',
          tone: StructuredReportMetricTone.neutral,
        ),
      ],
      fields: [
        StructuredReportField(label: 'Plant day', value: document.plantDay),
        StructuredReportField(
          label: 'Facilitator',
          value: document.facilitatorName ?? 'Not held',
        ),
        StructuredReportField(
          label: 'Finalized by',
          value: document.finalizedByName,
        ),
        StructuredReportField(
          label: 'Finalized at',
          value: '${dateTime.format(_indiaTime(document.finalizedAt))} IST',
        ),
        StructuredReportField(
          label: 'Source capture',
          value: _sourceCaptureLabel(document),
        ),
        if (document.documentDigest != null)
          StructuredReportField(
            label: 'Document digest',
            value: document.documentDigest!,
          ),
      ],
      paragraphs: [document.finalSummary],
    ),
    for (final section in MorningReviewSection.values)
      if (_hasSectionContent(document, section))
        _agendaSection(document, section, dateTime),
    StructuredReportSection(
      title: 'Actions and ownership',
      subtitle:
          'Open actions persist beyond the 14-day meeting artifact until completed.',
      tables: [
        StructuredReportTable(
          headers: const [
            'Area',
            'Action',
            'Owner',
            'Status',
            'Due / completed',
            'Completion evidence',
          ],
          rows: document.actions
              .map(
                (action) => [
                  _assetLabel(
                    action.section,
                    action.assetClassName,
                    action.assetNumber,
                  ),
                  action.text,
                  action.assigneeRole ??
                      action.assigneeName ??
                      action.assigneeUid ??
                      'Unassigned',
                  action.status.name,
                  action.completedAt != null
                      ? dateTime.format(_indiaTime(action.completedAt!))
                      : action.dueAt == null
                      ? 'No due time'
                      : dateTime.format(_indiaTime(action.dueAt!)),
                  action.completionNote ?? 'Pending',
                ],
              )
              .toList(growable: false),
          columnFlex: const [1.2, 2.8, 1.3, 1, 1.5, 2.2],
        ),
      ],
    ),
    StructuredReportSection(
      title: 'Attendance',
      subtitle: 'Attendance records only users who explicitly joined.',
      tables: [
        StructuredReportTable(
          headers: const ['Participant', 'Roles', 'Joined'],
          rows: document.participants
              .map(
                (participant) => [
                  participant.userName,
                  participant.roleKeys.join(', '),
                  dateTime.format(_indiaTime(participant.joinedAt)),
                ],
              )
              .toList(growable: false),
          columnFlex: const [2, 3, 1.8],
        ),
      ],
    ),
    if (document.facilitatorHistory.isNotEmpty)
      StructuredReportSection(
        title: 'Facilitation handover',
        subtitle:
            'Controlled facilitator changes retained in the frozen record.',
        tables: [
          StructuredReportTable(
            headers: const [
              'Previous facilitator',
              'Taken over by',
              'Time',
              'Reason',
            ],
            rows: document.facilitatorHistory
                .map(
                  (transition) => [
                    transition.previousFacilitatorName,
                    transition.takenOverByName,
                    '${dateTime.format(_indiaTime(transition.takenOverAt))} IST',
                    transition.reason,
                  ],
                )
                .toList(growable: false),
            columnFlex: const [1.6, 1.6, 1.5, 3.3],
          ),
        ],
      ),
    if (addenda.isNotEmpty)
      StructuredReportSection(
        title: 'Post-finalization addenda',
        subtitle:
            'Addenda do not alter the frozen meeting record and retain their own attributed reason.',
        tables: [
          StructuredReportTable(
            headers: const ['Area', 'Addendum', 'Author', 'Time', 'Reason'],
            rows: addenda
                .where((entry) => entry.kind == MorningReviewEntryKind.addendum)
                .map(
                  (entry) => [
                    _assetLabel(
                      entry.section,
                      entry.assetClassName,
                      entry.assetNumber,
                    ),
                    entry.text,
                    entry.authorName,
                    dateTime.format(_indiaTime(entry.createdAt)),
                    entry.addendumReason ?? '',
                  ],
                )
                .toList(growable: false),
            columnFlex: const [1.2, 3, 1.4, 1.5, 2],
          ),
        ],
      ),
  ];
  final dayStart = DateTime.parse('${document.plantDay}T00:00:00+05:30');
  return StructuredReportDocument(
    title: 'BAF Morning Review',
    subtitle: 'Daily asset condition, decisions, commitments and assurance',
    reportId: 'MR-${document.plantDay}',
    generatedAt: document.finalizedAt,
    generatedByName: document.finalizedByName,
    scopeLabel: 'CRM-III BAF plant morning coordination',
    periodStart: dayStart,
    periodEnd: dayStart
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1)),
    provenance: ReportProvenance(
      sourceMode: ReportSourceMode.cloudApplicationSnapshot,
      completenessNotes: [
        'The meeting document was frozen by the governed Morning Review command.',
        if (document.sourceCaptureState ==
            MorningReviewSourceCaptureState.bounded)
          'The source snapshot reached its governed bound for: '
              '${document.sourceCollectionsAtLimit.join(', ')}.',
        'Open actions and active standing concerns continue in their own records after this artifact expires.',
      ],
    ),
    sections: sections,
    orientation: StructuredReportOrientation.landscape,
  );
}

StructuredReportSection _agendaSection(
  MorningReviewDocument document,
  MorningReviewSection section,
  DateFormat dateTime,
) {
  final facts = document.sourceFacts.where((fact) => fact.section == section);
  final entries = document.entries.where((entry) => entry.section == section);
  final rows = <List<String>>[
    ...facts.map(
      (fact) => [
        _assetLabel(section, fact.assetClassName, fact.assetNumber),
        'Source · ${fact.sourceType}',
        fact.title,
        fact.summary,
        fact.observedAt == null
            ? fact.status
            : dateTime.format(_indiaTime(fact.observedAt!)),
      ],
    ),
    ...entries.map(
      (entry) => [
        _assetLabel(section, entry.assetClassName, entry.assetNumber),
        entry.kind.name,
        entry.text,
        entry.authorName,
        dateTime.format(_indiaTime(entry.createdAt)),
      ],
    ),
  ];
  if (section == MorningReviewSection.safety) {
    rows.addAll(
      document.standingConcerns.map(
        (concern) => [
          'Standing concern',
          '${concern.criticality.name} · ${concern.status.name}',
          concern.title,
          concern.status == MorningReviewConcernStatus.resolved
              ? '${concern.detail} · Resolved by ${concern.resolvedByName}: ${concern.resolutionReason}'
              : '${concern.detail} · Raised by ${concern.createdByName}',
          dateTime.format(_indiaTime(concern.resolvedAt ?? concern.createdAt)),
        ],
      ),
    );
    rows.addAll(
      document.standingConcernChecks.map(
        (check) => [
          'Standing concern',
          check.state.name,
          check.concernTitle,
          '${check.note} · ${check.checkedByName}',
          dateTime.format(_indiaTime(check.checkedAt)),
        ],
      ),
    );
  }
  return StructuredReportSection(
    title: _sectionLabel(section),
    tables: [
      StructuredReportTable(
        headers: const [
          'Asset / scope',
          'Record',
          'Subject',
          'Detail / owner',
          'Time',
        ],
        rows: rows,
        columnFlex: const [1.4, 1.3, 2.2, 3.5, 1.6],
      ),
    ],
  );
}

bool _hasSectionContent(
  MorningReviewDocument document,
  MorningReviewSection section,
) =>
    document.sourceFacts.any((fact) => fact.section == section) ||
    document.entries.any((entry) => entry.section == section) ||
    (section == MorningReviewSection.safety &&
        (document.standingConcerns.isNotEmpty ||
            document.standingConcernChecks.isNotEmpty));

String _sourceCaptureLabel(MorningReviewDocument document) {
  if (document.sourceCaptureState == MorningReviewSourceCaptureState.bounded) {
    return 'Bounded · ${document.sourceCollectionsAtLimit.join(', ')}';
  }
  return document.sourceCaptureState.name;
}

DateTime _indiaTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 5, minutes: 30));

String _assetLabel(
  MorningReviewSection section,
  String? assetClassName,
  String? assetNumber,
) {
  if (assetClassName != null && assetNumber != null) {
    return '$assetClassName $assetNumber';
  }
  return _sectionLabel(section);
}

String _sectionLabel(MorningReviewSection section) => switch (section) {
  MorningReviewSection.safety => 'Safety and standing concerns',
  MorningReviewSection.furnace => 'Furnaces',
  MorningReviewSection.base => 'Bases and Inner Covers',
  MorningReviewSection.forcedCooler => 'Forced Coolers',
  MorningReviewSection.otherAsset => 'Other assets',
  MorningReviewSection.plantWide => 'Plant-wide and general',
};
