import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'Plant Condition stream retains open, unsynced, and still-relevant closures',
    () async {
      await _withMaintenanceIsar((isar) async {
        final records = <MaintenanceRecord>[
          _record(id: 'open', status: TicketStatus.open, isSynced: true),
          _record(
            id: 'pending-resolution',
            status: TicketStatus.resolved,
            isSynced: false,
          ),
          _record(
            id: 'pending-deletion',
            status: TicketStatus.resolved,
            isSynced: false,
            isDeleted: true,
          ),
          _record(
            id: 'still-relevant',
            status: TicketStatus.closedWithoutResolution,
            isSynced: true,
            disposition: IssueAdministrativeClosureDisposition.stillRelevant,
          ),
          _record(
            id: 'relevance-ended',
            status: TicketStatus.closedWithoutResolution,
            isSynced: true,
            disposition: IssueAdministrativeClosureDisposition.relevanceEnded,
          ),
          _record(
            id: 'resolved',
            status: TicketStatus.resolved,
            isSynced: true,
          ),
        ];
        await isar.writeTxn(() => isar.maintenanceRecords.putAll(records));

        final streamed =
            await IsarMaintenanceRepository()
                .watchPlantConditionTickets()
                .first;

        expect(streamed.map((ticket) => ticket.firestoreId).toSet(), <String?>{
          'open',
          'pending-resolution',
          'pending-deletion',
          'still-relevant',
        });
      });
    },
  );

  test('web stream atomically queries only retained administrative closures', () {
    final source =
        File(
          'lib/features/maintenance/providers/maintenance_provider.remote.dart',
        ).readAsStringSync();

    expect(source, contains('Filter.or('));
    expect(source, contains('Filter.and('));
    expect(source, contains('TicketStatus.closedWithoutResolution.name'));
    expect(source, contains("'issueClosureDisposition'"));
    expect(
      source,
      contains('IssueAdministrativeClosureDisposition.stillRelevant.name'),
    );
    expect(source, contains('ticket.canStillAffectPlantCondition'));
  });
}

MaintenanceRecord _record({
  required String id,
  required TicketStatus status,
  required bool isSynced,
  bool isDeleted = false,
  IssueAdministrativeClosureDisposition? disposition,
}) {
  final time = DateTime.utc(2026, 9, 1, 8).add(Duration(minutes: id.length));
  final record =
      MaintenanceRecord()
        ..firestoreId = id
        ..version = 1
        ..isSynced = isSynced
        ..isDeleted = isDeleted
        ..assetType = AssetType.base
        ..assetNumber = 201
        ..maintenanceType = MaintenanceType.breakdown
        ..description = 'Plant Condition stream test'
        ..plantConditionEffect =
            MaintenanceIssuePlantConditionEffect.unavailable
        ..routedTo = RoutedTo.mechanical
        ..status = status
        ..isResolved = status.isTerminal
        ..startDate = time
        ..createdAt = time
        ..updatedAt = time;
  if (disposition != null) {
    record.administrativeClosure = IssueAdministrativeClosure(
      disposition: disposition,
      reason: 'Administrative disposition for stream coverage.',
    );
  }
  return record;
}

Future<void> _withMaintenanceIsar(Future<void> Function(Isar isar) body) async {
  final directory = await Directory.systemTemp.createTemp(
    'maintenance_plant_condition_stream_',
  );
  final isar = await Isar.open([
    MaintenanceRecordSchema,
  ], directory: directory.path);
  app.isar = isar;
  try {
    await body(isar);
  } finally {
    await isar.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
