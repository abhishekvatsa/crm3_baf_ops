import 'package:crm3_baf_ops/core/serialization/tolerant_snapshot_decode.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';


void main() {
  group('a due-state population that could not be read completely', () {
    test('a decoded batch says how much of the snapshot it holds', () {
      const complete = DecodedSnapshotBatch<int>(
        records: <int>[1, 2],
        rejectedDocumentIds: <String>[],
      );
      const short = DecodedSnapshotBatch<int>(
        records: <int>[1],
        rejectedDocumentIds: <String>['due-77'],
      );

      expect(complete.isComplete, isTrue);
      expect(complete.rawCount, 2);
      expect(short.isComplete, isFalse);
      expect(short.rawCount, 2);
      // The identity travels with the batch so support can go and look.
      expect(short.rejectedDocumentIds, <String>['due-77']);
    });

    test('the report says the population is short, even with nothing overdue',
        () {
      final report = buildOperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 9, 1),
          endDate: DateTime.utc(2026, 9, 30),
        ),
        tickets: const [],
        executions: const [],
        events: const [],
        dueStates: const [],
        unreadableDueStateCount: 1,
        assetClasses: const [],
        assetInstances: const [],
        overview: const PlantAssetOverview(classes: [], assets: []),
      );

      expect(report.unreadableDueStateCount, 1);
      final signal = report.managementSignals.where(
        (entry) =>
            entry.type ==
            OperationsManagementSignalType.incompleteDueStateEvidence,
      );
      // Nothing is overdue among the records that could be read. That is not
      // an all-clear while a record in the population is unreadable.
      expect(report.overdueMaintenanceCount, 0);
      expect(
        signal,
        isNotEmpty,
        reason:
            'zero overdue must not be presented as a complete-population claim',
      );
      expect(signal.first.count, 1);
    });

    test('a complete population raises no incompleteness signal', () {
      final report = buildOperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime.utc(2026, 9, 1),
          endDate: DateTime.utc(2026, 9, 30),
        ),
        tickets: const [],
        executions: const [],
        events: const [],
        dueStates: const [],
        assetClasses: const [],
        assetInstances: const [],
        overview: const PlantAssetOverview(classes: [], assets: []),
      );

      expect(report.unreadableDueStateCount, 0);
      expect(
        report.managementSignals.where(
          (entry) =>
              entry.type ==
              OperationsManagementSignalType.incompleteDueStateEvidence,
        ),
        isEmpty,
      );
    });
  });
}
