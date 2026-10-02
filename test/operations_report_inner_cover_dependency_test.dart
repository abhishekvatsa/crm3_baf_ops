import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/domain/inner_cover_dependencies.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:crm3_baf_ops/features/reports/services/operations_report_pdf_service.dart';
import 'inner_cover_lifecycle_model_test.dart' as lifecycle;
import 'operations_report_test.dart' as fixtures;

final coverClass = fixtures.assetClass(
  'fixture-covers',
  'Inner Cover',
  'innerCover',
);

InnerCoverProfile cover(String serial, int base) => InnerCoverProfile.fromMap({
  ...lifecycle.profileMap(
    state: 'installed',
    baseId: 'fixture-base-$base',
    baseNumber: base,
    baseName: 'Base $base',
    linkageId: 'fixture-link-$serial',
  ),
  'innerCoverId': 'fixture-cover-$serial',
  'assetClassId': coverClass.id,
  'assetClassCode': coverClass.code,
  'serialNumber': serial,
  'normalizedSerialNumber': serial,
}, 'fixture-cover-$serial');

PlantInnerCoverState condition(
  InnerCoverProfile profile, {
  InnerCoverDependencyKind? kind,
  bool complete = true,
}) => PlantInnerCoverState(
  profile: profile,
  // Dependency completeness must stand on its own, without duplicated warnings.
  evidenceWarnings: const [],
  dependency: InnerCoverDependencyState(
    coverId: profile.id,
    serialNumber: profile.serialNumber,
    complete: complete,
    warnings: complete ? const [] : const ['Workflow population incomplete'],
    reasons: [
      if (kind != null)
        InnerCoverDependencyReason(
          key: 'fixture-restriction-${profile.id}',
          sourceId: 'fixture-source',
          kind: kind,
          coverId: profile.id,
          serialNumber: profile.serialNumber,
          eventHostAssetId: profile.currentBaseAssetInstanceId!,
          eventHostClassId: 'fixture-base-class',
          eventHostNumber: profile.currentBaseAssetNumber!,
          eventLinkageId: profile.currentLinkageId!,
          awaitingServerConfirmation: false,
        ),
    ],
  ),
);

OperationsReport reportFor(
  List<PlantInnerCoverState> states, {
  String? selectedId,
}) => buildOperationsReport(
  filter: OperationsReportFilter(
    startDate: DateTime.utc(2026, 8),
    endDate: DateTime.utc(2026, 8, 31),
    assetInstanceId: selectedId,
    subjectKind: OperationsReportSubjectKind.innerCover,
  ),
  asOf: DateTime.utc(2026, 8, 29),
  tickets: const [],
  executions: const [],
  events: const [],
  assetClasses: [coverClass],
  assetInstances: const [],
  // The complete report population comes from qualified states. A selected
  // native serial still requires the existing explicit identity lookup.
  innerCoverProfiles: selectedId == null
      ? const []
      : states.map((state) => state.profile).toList(),
  overview: PlantAssetOverview(
    classes: const [],
    assets: const [],
    innerCovers: states,
    hasQualifiedInnerCoverInventory: true,
    evidenceWarnings: states.expand((s) => s.evidenceWarnings).toList(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final g66 = cover('G66', 119);
  final g99 = cover('G99', 120);

  test(
    'qualified unrestricted serial rows keep inventory and report counts aligned',
    () {
      final states = [condition(g66), condition(g99)];
      final report = reportFor(states);
      final rows = OperationsReportPdfService.assetConditionRowsForTesting(
        report,
      );
      expect(report.assetCount, 2);
      expect(report.availableAssetCount, 2);
      expect(report.classSummaries.single.availableCount, 2);
      expect(report.qualifiedInnerCoverStates, states);
      expect(rows, hasLength(2));
      expect(rows.first[1], 'Installed');
      expect(rows.first[3], contains('Base 119'));
      expect(rows.expand((r) => r).join(' '), isNot(contains('In service')));
    },
  );

  for (final entry in {
    InnerCoverDependencyKind.unavailable: 'Unavailable by Inner Cover issue',
    InnerCoverDependencyKind.unfit: 'Unfit by Inner Cover issue',
    InnerCoverDependencyKind.maintenance: 'Maintenance work remains open',
    InnerCoverDependencyKind.red: 'RED work remains open',
    InnerCoverDependencyKind.preparation: 'Awaiting preparation',
  }.entries) {
    test(
      'report count and PDF row retain ${entry.key.name} serial restriction',
      () {
        final affected = condition(g66, kind: entry.key);
        final report = reportFor([affected, condition(g99)]);
        final rows = OperationsReportPdfService.assetConditionRowsForTesting(
          report,
        );
        expect(report.assetCount, 2);
        expect(report.availableAssetCount, 1);
        expect(report.classSummaries.single.availableCount, 1);
        expect(report.downAssetCount, 0);
        expect(
          report.underMaintenanceAssetCount,
          affected.isUnderMaintenance ? 1 : 0,
        );
        expect(report.unfitAssetCount, affected.isUnfit ? 1 : 0);
        expect(rows, hasLength(2));
        expect(rows.first[0], contains('G66'));
        expect(rows.first[1], contains(entry.value));
        expect(rows.first[4], contains(entry.value));
        expect(rows.first[3], contains('Base 119'));
        expect(rows.last[0], contains('G99'));
        expect(rows.last[1], 'Installed');
        expect(rows.expand((r) => r).join(' '), isNot(contains('In service')));
      },
    );
  }

  test(
    'incomplete serial evidence remains unverified with a null availability rate',
    () {
      final report = reportFor([
        condition(g66, complete: false),
        condition(g99),
      ]);
      final row = OperationsReportPdfService.assetConditionRowsForTesting(
        report,
      ).first;
      expect(report.availableAssetCount, 1);
      expect(report.unknownAssetCount, 1);
      expect(report.unverifiedInnerCoverIds, {g66.id});
      expect(report.assetAvailabilityRate, isNull);
      expect(row[1], contains('evidence unverified'));
      expect(row[4], contains('Workflow population incomplete'));
    },
  );

  test(
    'selected serial scope carries only its own qualified restriction into the PDF',
    () {
      final report = reportFor([
        condition(g66, kind: InnerCoverDependencyKind.red),
        condition(g99),
      ], selectedId: g66.id);
      final rows = OperationsReportPdfService.assetConditionRowsForTesting(
        report,
      );
      expect(report.assetCount, 1);
      expect(report.availableAssetCount, 0);
      expect(report.underMaintenanceAssetCount, 1);
      expect(report.downAssetCount, 0);
      expect(report.qualifiedInnerCoverStates!.single.profile.id, g66.id);
      expect(rows, hasLength(1));
      expect(rows.single[1], contains('RED work remains open'));
      expect(rows.single.join(' '), isNot(contains('G99')));
    },
  );
}
