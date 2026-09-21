import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  setUpAll(initializeTestIsarCore);

  test(
    'old false index cannot hide damaged or still-relevant closure evidence',
    () async {
      await _withMaintenanceIsar((isar) async {
        final rows = [
          for (final id in [
            'damaged',
            'retained',
            'ended',
            'contradictory',
            'deleted',
          ])
            _record(
              id: id,
              status: TicketStatus.closedWithoutResolution,
              isSynced: true,
              disposition: id == 'ended'
                  ? IssueAdministrativeClosureDisposition.relevanceEnded
                  : IssueAdministrativeClosureDisposition.stillRelevant,
            ),
        ];
        await isar.writeTxn(() => isar.maintenanceRecords.putAll(rows));
        final exported = await isar.maintenanceRecords.where().exportJsonRaw(
          (bytes) => utf8.decode(bytes),
        );
        final rawRows = (jsonDecode(exported) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        for (final row in rawRows) {
          row['plantConditionContributionActive'] = false;
          if (row['firestoreId'] == 'damaged') {
            row['metadataJson'] = '{"administrativeClosure":';
          }
          if (row['firestoreId'] == 'contradictory' ||
              row['firestoreId'] == 'deleted') {
            row['status'] = TicketStatus.resolved.name;
            row['isDeleted'] = row['firestoreId'] == 'deleted';
          }
        }
        // Import raw native rows, bypassing the repaired Dart projection getter.
        await isar.writeTxn(() => isar.maintenanceRecords.importJson(rawRows));
        expect(
          await isar.maintenanceRecords
              .where()
              .plantConditionContributionActiveEqualTo(true)
              .count(),
          0,
        );
        final streamed = await IsarMaintenanceRepository()
            .watchPlantConditionTickets()
            .first;
        expect(streamed.map((row) => row.firestoreId).toSet(), {
          'damaged',
          'retained',
          'contradictory',
        });
        final damaged = streamed.singleWhere(
          (row) => row.firestoreId == 'damaged',
        );
        expect(damaged.metadataJson, '{"administrativeClosure":');
        expect(
          () => damaged.canStillAffectPlantCondition,
          throwsA(isA<PersistedDataFormatException>()),
        );
        final priorVersion = damaged.version;
        final priorUpdatedAt = damaged.updatedAt;
        final priorSynced = damaged.isSynced;
        await expectLater(
          IsarMaintenanceRepository().saveTicket(damaged),
          throwsStateError,
        );
        final retained = await isar.maintenanceRecords.get(damaged.id);
        expect(retained!.metadataJson, '{"administrativeClosure":');
        expect(retained.version, priorVersion);
        expect(retained.updatedAt, priorUpdatedAt);
        expect(retained.isSynced, priorSynced);
        expect(damaged.version, priorVersion);
        expect(damaged.updatedAt, priorUpdatedAt);
        expect(damaged.isSynced, priorSynced);
        expect(
          streamed
              .singleWhere((row) => row.firestoreId == 'retained')
              .canStillAffectPlantCondition,
          isTrue,
        );
        expect(
          () => streamed
              .singleWhere((row) => row.firestoreId == 'contradictory')
              .canStillAffectPlantCondition,
          throwsA(isA<PersistedDataFormatException>()),
        );
      });
    },
  );

  test(
    'native candidate query qualifies representative historical metadata',
    () async {
      await _withMaintenanceIsar((isar) async {
        final history = [
          for (var i = 0; i < 10000; i++)
            _record(
              id: 'history-$i',
              status: TicketStatus.resolved,
              isSynced: true,
            )..metadataJson = '{"retained":"historical assessment $i"}',
        ];
        await isar.writeTxn(() => isar.maintenanceRecords.putAll(history));
        final elapsed = Stopwatch()..start();
        final rows = await IsarMaintenanceRepository()
            .watchPlantConditionTickets()
            .first;
        elapsed.stop();
        expect(rows, isEmpty);
        // Evidence for this bounded query tradeoff, not a timing-sensitive gate.
        // ignore: avoid_print
        print(
          'Native closure admission: 10000 historical metadata rows, '
          '${elapsed.elapsedMilliseconds} ms, ${rows.length} returned.',
        );
      });
    },
  );

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

        final streamed = await IsarMaintenanceRepository()
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

  test(
    'web stream excludes tombstones and atomically queries retained closures',
    () {
      final source = File(
        'lib/features/maintenance/providers/maintenance_provider.remote.dart',
      ).readAsStringSync();

      expect(source, contains('Filter.or('));
      expect(source, contains('Filter.and('));
      expect(source, contains("Filter('isDeleted', isEqualTo: false)"));
      expect(source, contains('TicketStatus.closedWithoutResolution.name'));
      expect(source, contains("'issueClosureDisposition'"));
      expect(
        source,
        contains('IssueAdministrativeClosureDisposition.stillRelevant.name'),
      );
      expect(source, contains('ticket.canStillAffectPlantCondition'));
    },
  );

  test('native stream includes closures independently of the old index', () {
    final source = File(
      'lib/features/maintenance/providers/maintenance_provider.local.dart',
    ).readAsStringSync();

    expect(source, contains('.plantConditionContributionActiveEqualTo(true)'));
    expect(
      source,
      contains('.statusEqualTo(TicketStatus.closedWithoutResolution)'),
    );
    expect(source, isNot(contains('.metadataJsonContains(')));
    expect(
      MaintenanceRecordSchema.indexes,
      contains('plantConditionContributionActive'),
    );
  });

  test('startup rebuilds the v10 index before committing provenance', () {
    final source = File('lib/main.dart').readAsStringSync();
    final repair = source.indexOf(
      'repairMaintenancePlantConditionIndexForSchemaUpgrade(',
    );
    final commit = source.indexOf('commitAfterSuccessfulOpen()');

    expect(repair, greaterThanOrEqualTo(0));
    expect(commit, greaterThan(repair));
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
  final record = MaintenanceRecord()
    ..firestoreId = id
    ..version = 1
    ..isSynced = isSynced
    ..isDeleted = isDeleted
    ..assetType = AssetType.base
    ..assetNumber = 201
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Plant Condition stream test'
    ..plantConditionEffect = MaintenanceIssuePlantConditionEffect.unavailable
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
