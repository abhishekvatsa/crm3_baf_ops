import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/reports/domain/base_inner_cover_register.dart';
import 'package:crm3_baf_ops/features/reports/domain/operations_report_document.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_population_policy.dart';
import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/presentation/operations_report_pdf_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:crm3_baf_ops/features/reports/services/operations_report_pdf_service.dart';
import 'operations_report_test.dart' as fixture;

final _day = DateTime.utc(2026, 9, 26);
final _baseClass = fixture.assetClass('base-class', 'Base', 'base');
final _coverClass = fixture.assetClass(
  'cover-class',
  'Inner Cover',
  'innerCover',
);
final _base = fixture.asset('base-1', _baseClass, 1);
final _secondBase = fixture.asset('base-2', _baseClass, 2);
final _installedAt = DateTime.utc(2026, 9, 25, 5);
DecodedSnapshotBatch<T> _batch<T>(
  List<T> rows, {
  bool cache = false,
  bool pending = false,
  bool rejected = false,
}) => DecodedSnapshotBatch(
  records: rows,
  rejectedDocumentIds: rejected ? ['unreadable'] : [],
  isFromCache: cache,
  hasPendingWrites: pending,
);
InnerCoverProfile _cover({String baseId = 'base-1'}) => InnerCoverProfile(
  id: 'cover-1',
  assetClassId: _coverClass.id,
  assetClassCode: _coverClass.code,
  assetClassName: _coverClass.name,
  serialNumber: 'GR-REPORT',
  normalizedSerialNumber: 'GR-REPORT',
  sourceType: InnerCoverSourceType.legacyExisting,
  lifecycleState: InnerCoverLifecycleState.installed,
  traceabilityGrade: InnerCoverTraceabilityGrade.t0,
  currentBaseAssetInstanceId: baseId,
  currentBaseAssetNumber: 1,
  currentBaseAssetName: 'Base 1',
  currentLinkageId: 'link-1',
  version: 2,
  createdAt: _installedAt,
  updatedAt: _installedAt,
  lastMutationId: 'fixture',
);
final _assignment = BaseInnerCoverAssignment(
  baseAssetInstanceId: _base.id,
  baseAssetClassId: _baseClass.id,
  baseAssetNumber: 1,
  baseAssetName: 'Base 1',
  innerCoverId: 'cover-1',
  innerCoverSerialNumber: 'GR-REPORT',
  linkageId: 'link-1',
  linkedAt: _installedAt,
  version: 2,
  updatedAt: _installedAt,
  lastMutationId: 'fixture',
);
final _link = InnerCoverLinkage(
  id: 'link-1',
  baseAssetInstanceId: _base.id,
  baseAssetNumber: 1,
  baseAssetName: 'Base 1',
  innerCoverId: 'cover-1',
  innerCoverSerialNumber: 'GR-REPORT',
  installedAt: _installedAt,
  installedByUid: 'supervisor-demo',
  installedByName: 'Demo Supervisor',
  active: true,
  version: 1,
);

BaseInnerCoverRegister _register({
  bool cache = false,
  bool pending = false,
  bool rejected = false,
  bool absent = false,
  bool orphan = false,
  String? selectedAssetId,
  String? selectedClassId,
}) => buildBaseInnerCoverRegister(
  classes: _batch([_baseClass, _coverClass]),
  assets: _batch([_base, _secondBase]),
  assignments: _batch(
    absent ? [] : [_assignment],
    cache: cache,
    pending: pending,
    rejected: rejected,
  ),
  covers: _batch(absent && !orphan ? [] : [_cover()]),
  linkages: _batch(absent ? [] : [_link]),
  selectedClassId: selectedClassId,
  selectedAssetId: selectedAssetId,
);

OperationsReportFilter _filter({
  MaintenanceReportPeriodBasis maintenance =
      MaintenanceReportPeriodBasis.activeDuring,
  QualityReportPeriodBasis quality = QualityReportPeriodBasis.firstReported,
  QualityReportSource source = QualityReportSource.all,
  QualityReportKind kind = QualityReportKind.all,
  bool raOnly = false,
  bool details = false,
}) => OperationsReportFilter(
  startDate: _day,
  endDate: _day,
  maintenancePeriodBasis: maintenance,
  qualityPeriodBasis: quality,
  qualitySource: source,
  qualityKind: kind,
  raOnly: raOnly,
  includeMaintenanceDetails: details,
);

ChargeAbnormality _case(
  String id, {
  int charge = 50001,
  DateTime? loggedAt,
  DateTime? performed,
  ReannealingStatus status = ReannealingStatus.completed,
  String? issue,
  AbnormalityObservationKind kind = AbnormalityObservationKind.resultFinding,
}) => ChargeAbnormality()
  ..firestoreId = id
  ..sourceChargeNo = charge
  ..abnormalityTypeId = 'type'
  ..abnormalityTypeTitle = 'Surface appearance'
  ..abnormalityTypeCode = 'APPEARANCE'
  ..category = AbnormalityCategory.resultQuality
  ..observedReason = 'Dark colour on outer coils'
  ..loggedAt = loggedAt ?? _day
  ..updatedAt = _day
  ..loggedByName = 'Demo Operations'
  ..linkedTicketFirestoreId = issue
  ..reannealingStatus = status
  ..reannealedToChargeNo = status == ReannealingStatus.completed ? 50002 : null
  ..assessment = AbnormalityAssessment(
    observationKind: kind,
    raPerformedAt: performed,
    candidateCauses: const [
      CandidateProcessCause(
        id: 'cause-1',
        description: 'Possible atmosphere deviation',
        assessment: CauseAssessment.suspected,
        evidence: 'Operator observation, not yet confirmed',
        maintenanceTicketId: 'issue-demo',
      ),
    ],
  )
  ..affectedAssets = const [
    AffectedAssetRef(assetType: AssetType.base, assetNumber: 1),
  ];
QualityWarning _warning(
  String sourceId, {
  QualityWarningSourceType source = QualityWarningSourceType.abnormality,
  bool closed = false,
  int charge = 50001,
}) => QualityWarning(
  warningId: 'warning-$sourceId',
  sourceType: source,
  sourceId: sourceId,
  sourceVersion: 1,
  sourceSeverity: "high",
  sourceChargeNo: charge,
  warningReason: 'Review charge evidence',
  sourceSummary: 'Surface appearance',
  affectedAssets: const [
    QualityAffectedAsset(assetType: 'base', assetNumber: 1),
  ],
  status: closed ? QualityWarningStatus.closed : QualityWarningStatus.open,
  createdAt: _day,
  createdByUid: 'demo',
  updatedAt: _day,
  updatedByUid: 'demo',
  version: 1,
  closedAt: closed ? _day.add(const Duration(hours: 1)) : null,
);
OperationsReport _report({
  OperationsReportFilter? filter,
  List<ChargeAbnormality> cases = const [],
  List<QualityWarning> warnings = const [],
  List<MaintenanceRecord> tickets = const [],
}) => buildOperationsReport(
  filter: filter ?? _filter(),
  tickets: tickets,
  executions: [],
  events: [],
  abnormalities: cases,
  qualityWarnings: warnings,
  assetClasses: [_baseClass, _coverClass],
  assetInstances: [_base, _secondBase],
  overview: const PlantAssetOverview(classes: [], assets: []),
  asOf: _day.add(const Duration(hours: 12)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'every selected Base has a row, including no recorded linkage; installation actor retained',
    () {
      final register = _register();
      expect(register.rows.map((r) => r.state), [
        BaseCoverLinkState.linked,
        BaseCoverLinkState.empty,
      ]);
      final rows = OperationsReportPdfService.baseCoverRegisterRows(register);
      expect(rows.first[1], 'In service');
      expect(rows.first[4], startsWith('25-09-2026 10:30'));
      expect(rows.first[5], contains('updated 25-09-2026 10:30'));
      expect(rows.first.join(' '), contains('Demo Supervisor'));
      expect(rows.first.join(' '), contains('GR-REPORT'));
      expect(
        _register(selectedAssetId: 'base-2').rows.single.state,
        BaseCoverLinkState.empty,
      );
      expect(_register(selectedClassId: 'cover-class').rows, isEmpty);
    },
  );
  for (final flag in ['cache', 'pending', 'rejected']) {
    test('$flag assignment snapshot never establishes vacancy', () {
      final register = _register(
        absent: true,
        cache: flag == 'cache',
        pending: flag == 'pending',
        rejected: flag == 'rejected',
      );
      expect(register.evidenceConfirmed, false);
      expect(
        register.rows.every((r) => r.state == BaseCoverLinkState.unknown),
        true,
      );
    });
  }
  test(
    'missing assignment with retained cover claim is inconsistent, not empty',
    () {
      expect(
        _register(absent: true, orphan: true).rows.first.state,
        BaseCoverLinkState.inconsistent,
      );
    },
  );
  test(
    'same cover claimed by another active linkage cannot be confirmed linked',
    () {
      final conflicting = InnerCoverLinkage(
        id: 'link-other',
        baseAssetInstanceId: _secondBase.id,
        baseAssetNumber: 2,
        baseAssetName: 'Base 2',
        innerCoverId: 'cover-1',
        innerCoverSerialNumber: 'GR-REPORT',
        installedAt: _installedAt,
        installedByUid: 'other',
        installedByName: 'Other',
        active: true,
        version: 1,
      );
      final register = buildBaseInnerCoverRegister(
        classes: _batch([_baseClass]),
        assets: _batch([_base, _secondBase]),
        assignments: _batch([_assignment]),
        covers: _batch([_cover()]),
        linkages: _batch([_link, conflicting]),
      );
      expect(
        register.rows.every(
          (row) => row.state == BaseCoverLinkState.inconsistent,
        ),
        true,
      );
    },
  );
  test(
    'maintenance date bases differ and inclusive completion boundary is preserved',
    () {
      final ticket = fixture.issue(
        type: AssetType.base,
        number: 1,
        started: _day.subtract(const Duration(days: 3)),
      );
      expect(maintenanceTicketMatchesPeriod(ticket, _filter()), true);
      expect(
        maintenanceTicketMatchesPeriod(
          ticket,
          _filter(maintenance: MaintenanceReportPeriodBasis.openedDuring),
        ),
        false,
      );
      ticket
        ..status = TicketStatus.resolved
        ..isResolved = true
        ..endDate = _filter().startInclusive;
      expect(maintenanceTicketMatchesPeriod(ticket, _filter()), false);
      expect(
        maintenanceTicketMatchesPeriod(
          ticket,
          _filter(maintenance: MaintenanceReportPeriodBasis.completedDuring),
        ),
        true,
      );
      ticket.status = TicketStatus.closedWithoutResolution;
      expect(
        maintenanceTicketMatchesPeriod(
          ticket,
          _filter(maintenance: MaintenanceReportPeriodBasis.completedDuring),
        ),
        false,
      );
    },
  );
  test(
    'RA performed date selects older case, unknown historical date stays separate',
    () {
      final old = _day.subtract(const Duration(days: 30));
      final dated = _case(
        'dated',
        loggedAt: old,
        performed: _filter().startInclusive,
      );
      final undated = _case('unknown', loggedAt: old);
      final report = _report(
        filter: _filter(quality: QualityReportPeriodBasis.raPerformed),
        cases: [dated, undated],
        warnings: [_warning('dated'), _warning('unknown')],
      );
      expect(report.abnormalities.map((r) => r.firestoreId), ['dated']);
      expect(report.undatedRaCases.map((r) => r.firestoreId), ['unknown']);
      expect(report.qualityWarnings.map((w) => w.sourceId), ['dated']);
      expect(_report(cases: [dated, undated]).abnormalities, isEmpty);
    },
  );
  test(
    'same-charge direct and issue cases stay distinct; mirrored warnings do not double count',
    () {
      final cases = [_case('direct'), _case('from-issue', issue: 'issue-demo')];
      final warnings = [
        _warning('direct'),
        _warning('issue-demo', source: QualityWarningSourceType.issue),
        _warning('unrelated'),
      ];
      final report = _report(cases: cases, warnings: warnings);
      expect(report.qualityCaseCount, 2);
      expect(report.qualityDistinctChargeCount, 1);
      expect(report.qualityWarnings.length, 2);
      expect(report.unmatchedQualityWarnings.length, 1);
      final issueOnly = _report(
        filter: _filter(source: QualityReportSource.maintenanceIssue),
        cases: cases,
        warnings: warnings,
      );
      expect(issueOnly.abnormalities.single.firestoreId, 'from-issue');
      expect(issueOnly.qualityWarnings.single.sourceId, 'issue-demo');
    },
  );
  test(
    'outstanding ignores date range but RA-only excludes pending and not-required decisions',
    () {
      final cases = [
        _case(
          'pending',
          loggedAt: DateTime.utc(2025),
          status: ReannealingStatus.pendingDecision,
        ),
        _case('required', status: ReannealingStatus.required),
        _case('not-required', status: ReannealingStatus.notRequired),
      ];
      final report = _report(
        filter: _filter(quality: QualityReportPeriodBasis.outstanding),
        cases: cases,
        warnings: [_warning('not-required'), _warning('unreadable-source')],
      );
      expect(report.abnormalities.length, 3);
      expect(
        report.unmatchedQualityWarnings.single.sourceId,
        'unreadable-source',
      );
      final only = _report(
        filter: _filter(
          quality: QualityReportPeriodBasis.outstanding,
          raOnly: true,
        ),
        cases: cases,
      );
      expect(only.abnormalities.single.firestoreId, 'required');
    },
  );
  test(
    'structured cause evidence is exported without upgrading suspected to confirmed',
    () {
      final record = _case('case');
      final text = OperationsReportPdfService.qualityObservationEvidence(
        record,
      );
      expect(text, contains('Suspected'));
      expect(text, contains('not yet confirmed'));
      expect(text, contains('issue-demo'));
      expect(
        qualityCaseMatchesAttributes(
          record,
          _filter(kind: QualityReportKind.processEquipment),
        ),
        false,
      );
      expect(
        qualityCaseMatchesAttributes(
          record,
          _filter(kind: QualityReportKind.resultFinding),
        ),
        true,
      );
      expect(
        OperationsReportPdfService.qualityRaEvidence(record),
        contains('Unknown / historical'),
      );
    },
  );
  test(
    'representative multi-page PDFs preserve detailed trailing evidence',
    () async {
      final longText =
          '${List.filled(80, 'Retained physical work and inspection observations.').join(' ')} FINAL-RETAINED-REPORT-EVIDENCE';
      final tickets = List.generate(
        5,
        (i) => fixture.issue(type: AssetType.base, number: 1, started: _day)
          ..firestoreId = 'demo-issue-$i'
          ..description = longText,
      );
      final report = _report(
        filter: _filter(details: true),
        tickets: tickets,
        cases: [
          _case('demo-direct', performed: _day),
          _case('demo-issue', issue: 'demo-issue-0'),
        ],
        warnings: [
          _warning('demo-direct'),
          _warning('demo-issue-0', source: QualityWarningSourceType.issue),
        ],
      );
      final output = Directory('output/dev-usability-20260926')
        ..createSync(recursive: true);
      for (final preset in [
        OperationsReportDocumentPreset.baseInnerCoverRegister,
        OperationsReportDocumentPreset.maintenance,
        OperationsReportDocumentPreset.quality,
      ]) {
        final request = OperationsReportDocumentRequest.forPreset(
          preset: preset,
          generatedAt: report.asOf,
          generatedByName: 'Local demo validation',
          generatedByEmail: 'demo@example.invalid',
        );
        final bytes = await OperationsReportPdfService.build(
          report: report,
          request: request,
          assetClassLabel: 'Base',
          assetLabel: 'All Bases',
          furnaceAssets: [],
          currentBurnerRounds: {},
          baseInnerCoverRegister: _register(),
        );
        expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
        File(
          '${output.path}/sample-${preset.name}.pdf',
        ).writeAsBytesSync(bytes);
      }
    },
  );
  testWidgets(
    'composer returns explicit options and hides unrelated controls',
    (tester) async {
      OperationsReportDocumentRequest? request;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async =>
                    request = await showOperationsReportComposer(
                      context: context,
                      generatedByName: 'Demo',
                      generatedByEmail: 'demo@example.invalid',
                      hasFurnaceScope: false,
                      initialPreset:
                          OperationsReportDocumentPreset.baseInnerCoverRegister,
                      provenance: const ReportProvenance.applicationSnapshot(),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('report-quality-period-basis')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('report-maintenance-period-basis')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('report-build-preview')));
      await tester.pumpAndSettle();
      expect(request?.sections, {
        OperationsReportSection.baseInnerCoverRegister,
      });
    },
  );
}
