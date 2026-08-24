import 'dart:io';

import 'package:crm3_baf_ops/core/utils/combined_record_stream.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 8, 1);
  final end = DateTime.utc(2026, 9, 1);

  test('report query bounds retain the persisted ISO string type', () {
    expect(
      plannedExecutionReportTimestampBound(start),
      '2026-08-01T00:00:00.000Z',
    );
    expect(
      plannedExecutionReportTimestampBound(end),
      '2026-09-01T00:00:00.000Z',
    );
    final offsetInstant = DateTime.parse('2026-08-01T00:00:00+05:30');
    expect(
      plannedExecutionReportTimestampBound(offsetInstant),
      '2026-07-31T18:30:00.000Z',
    );
  });

  test(
    'maintenance overlap includes carry-in and excludes boundary closure',
    () {
      final carryIn = _ticket(start.subtract(const Duration(days: 10)))
        ..endDate = start.add(const Duration(hours: 1));
      final endedAtStart = _ticket(start.subtract(const Duration(days: 10)))
        ..endDate = start;

      expect(maintenanceRecordOverlapsPeriod(carryIn, start, end), isTrue);
      expect(
        maintenanceRecordOverlapsPeriod(endedAtStart, start, end),
        isFalse,
      );
    },
  );

  test('execution overlap includes completed and cancelled carry-in work', () {
    final completed =
        _execution(start.subtract(const Duration(days: 5)))
          ..isCompleted = true
          ..completedAt = start.add(const Duration(hours: 2));
    final cancelled =
        _execution(start.subtract(const Duration(days: 5)))
          ..isCancelled = true
          ..cancelledAt = start.add(const Duration(hours: 3));
    final endedAtStart =
        _execution(start.subtract(const Duration(days: 5)))
          ..isCancelled = true
          ..cancelledAt = start;

    expect(jobExecutionOverlapsPeriod(completed, start, end), isTrue);
    expect(jobExecutionOverlapsPeriod(cancelled, start, end), isTrue);
    expect(jobExecutionOverlapsPeriod(endedAtStart, start, end), isFalse);
  });

  test(
    'combined report query windows deduplicate the same source record',
    () async {
      final older = _execution(start)..firestoreId = 'execution-1';
      final newer = _execution(start.add(const Duration(days: 1)))
        ..firestoreId = 'execution-2';

      final result =
          await combineLatestUniqueRecordStreams<JobExecution>(
            streams: [
              Stream.value([older, newer]),
              Stream.value([older]),
            ],
            identityOf: (record) => record.firestoreId!,
            compare: (left, right) => right.createdAt.compareTo(left.createdAt),
          ).first;

      expect(result.map((record) => record.firestoreId), [
        'execution-2',
        'execution-1',
      ]);
    },
  );

  test('report authority resolves before any business-data subscription', () {
    final source =
        File(
          'lib/features/reports/providers/operations_report_provider.dart',
        ).readAsStringSync();
    final providerStart = source.indexOf('final operationsReportProvider');
    final actorRead = source.indexOf(
      'ref.watch(currentAppUserProvider)',
      providerStart,
    );
    final authorityRejection = source.indexOf(
      '!authorizedActor.canViewReports',
      actorRead,
    );
    final firstBusinessRead = source.indexOf(
      'ref.watch(operationsReportTicketsProvider(periodScope))',
      authorityRejection,
    );

    expect(providerStart, greaterThanOrEqualTo(0));
    expect(actorRead, greaterThan(providerStart));
    expect(authorityRejection, greaterThan(actorRead));
    expect(firstBusinessRead, greaterThan(authorityRejection));
  });

  test('report graph is actor-scoped and auto-disposed', () {
    final source =
        File(
          'lib/features/reports/providers/operations_report_provider.dart',
        ).readAsStringSync();

    expect(
      source,
      contains('final operationsReportProvider = Provider.autoDispose.family'),
    );
    expect(source, contains('authorizedActor.uid != scope.actorUid'));
    expect(
      source,
      contains('operationalEventsForReportsProvider(scope.actorUid)'),
    );
    expect(
      source.indexOf('ref.watch(_operationsReportAuthorityLifecycleProvider)'),
      lessThan(source.indexOf('ref.watch(currentAppUserProvider)')),
    );
    for (final provider in [
      'operationalEventsForReportsProvider',
      'qualityWarningsProvider',
      'workflowAllComplianceProvider',
      'assetClassesProvider',
      'operationsReportClockProvider',
    ]) {
      expect(source, contains('ref.invalidate($provider)'));
    }
  });
}

MaintenanceRecord _ticket(DateTime started) =>
    MaintenanceRecord()
      ..assetType = AssetType.furnace
      ..assetNumber = 7
      ..maintenanceType = MaintenanceType.breakdown
      ..description = 'Fixture issue'
      ..routedTo = RoutedTo.mechanical
      ..status = TicketStatus.open
      ..isResolved = false
      ..startDate = started
      ..createdAt = started
      ..updatedAt = started
      ..actionsJson = '[]'
      ..resolutionHistoryJson = '[]';

JobExecution _execution(DateTime created) =>
    JobExecution()
      ..templateFirestoreId = 'template-1'
      ..assetType = AssetType.furnace
      ..assetNumber = 7
      ..createdAt = created
      ..updatedAt = created
      ..isCompleted = false
      ..isCancelled = false;
