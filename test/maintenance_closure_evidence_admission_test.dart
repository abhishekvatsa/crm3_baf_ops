import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/domain/furnace_audit_draft.dart';
import 'package:crm3_baf_ops/features/assets/domain/qualified_plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plant_asset_overview_test.dart' as fixtures;

MaintenanceRecord _closed(String? raw) => MaintenanceRecord()
  ..firestoreId = 'damaged-closure'
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..maintenanceType = MaintenanceType.breakdown
  ..routedTo = RoutedTo.mechanical
  ..description = 'Retained concern'
  ..status = TicketStatus.closedWithoutResolution
  ..isResolved = true
  ..isSynced = true
  ..startDate = DateTime.utc(2026, 9, 1)
  ..endDate = DateTime.utc(2026, 9, 2)
  ..closedByUid = 'admin'
  ..closedByName = 'Admin'
  ..createdAt = DateTime.utc(2026, 9, 1)
  ..updatedAt = DateTime.utc(2026, 9, 2)
  ..metadataJson = raw;

void main() {
  final malformed = <String?>[
    null,
    '',
    'legacy opaque text',
    '[1]',
    '{}',
    '{"administrativeClosure":null}',
    '{"administrativeClosure":',
  ];
  for (var i = 0; i < malformed.length; i++) {
    test('closed issue requires disposition evidence case $i', () {
      final row = _closed(malformed[i]);
      expect(
        () => row.administrativeClosure,
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => row.canStillAffectPlantCondition,
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(row.administrativeClosureReadResult.isValid, isFalse);
      expect(row.administrativeClosureReadResult.value, isNull);
      expect(
        row.administrativeClosureReadResult.error,
        isA<PersistedDataFormatException>(),
      );
      // This persisted flag admits a review candidate, not a condition fact.
      expect(row.plantConditionContributionActive, isTrue);
      expect(row.metadataJson, malformed[i]);
    });
    for (final status in [TicketStatus.open, TicketStatus.resolved]) {
      test('ordinary ${status.name} preserves legacy metadata case $i', () {
        final row = _closed(malformed[i])
          ..status = status
          ..isResolved = status.isTerminal;
        expect(row.administrativeClosure, isNull);
        expect(row.administrativeClosureReadResult.isValid, isTrue);
        expect(row.canStillAffectPlantCondition, status == TicketStatus.open);
        expect(row.metadataJson, malformed[i]);
      });
    }
  }

  test('closure envelope on an ordinary issue is inconsistent evidence', () {
    final row = _closed(null)
      ..administrativeClosure = const IssueAdministrativeClosure(
        disposition: IssueAdministrativeClosureDisposition.stillRelevant,
        reason: 'Retain the unresolved concern.',
      )
      ..status = TicketStatus.open
      ..isResolved = false;
    expect(
      () => row.administrativeClosure,
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('damaged closure qualifies plant overview and refuses audit/report', () {
    final row = _closed('{"administrativeClosure":');
    final cls = fixtures.assetClass(
      id: 'furnace',
      code: 'FURNACE',
      name: 'Furnace',
      legacyKey: 'furnace',
    );
    final asset = fixtures.asset(id: 'furnace-7', assetClass: cls, number: 7);
    final overview = qualifiedPlantAssetOverview(
      classes: [cls],
      assets: [asset],
      conditions: [],
      workflow: [fixtures.workflow(key: 'furnace', number: 7)],
      availability: [],
      tickets: [row],
      populationWarnings: [],
      manualSourcesCurrent: true,
    );
    expect(overview.evidenceWarnings, isNotEmpty);
    expect(overview.available, 0);
    expect(overview.assets.single.isAvailable, isFalse);
    expect(
      () => FurnaceAuditIssueEvidence.fromTickets(
        tickets: [row],
        furnace: asset,
        assetClasses: [cls],
        assets: [asset],
        round: null,
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => buildOperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 9, 1),
          endDate: DateTime.utc(2026, 9, 30),
        ),
        tickets: [row],
        executions: [],
        events: [],
        assetClasses: [cls],
        assetInstances: [asset],
        overview: overview,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(row.metadataJson, '{"administrativeClosure":');
  });
}
