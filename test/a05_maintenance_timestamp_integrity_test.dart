import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_timestamps.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart'
    show PaginatedMaintenanceResult;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('A-05 remote maintenance timestamp integrity', () {
    test('accepts only the governed timestamp representations', () {
      final start = DateTime.utc(2026, 8, 6, 1);
      final created = start.subtract(const Duration(hours: 1));
      final updated = start.add(const Duration(minutes: 20));
      final deferred = start.add(const Duration(minutes: 5));

      final timestamps = readRemoteMaintenanceTimestamps(<String, dynamic>{
        'startDate': Timestamp.fromDate(start),
        'createdAt': created,
        'updatedAt': updated.toIso8601String(),
        'workflowDeferredAt': deferred.toIso8601String(),
      }, source: 'maintenance/ticket-1');

      expect(timestamps.startDate.isAtSameMomentAs(start), isTrue);
      expect(timestamps.createdAt, created);
      expect(timestamps.updatedAt, updated);
      expect(timestamps.workflowDeferredAt, deferred);
      expect(timestamps.workflowReactivatedAt, isNull);
      expect(timestamps.workflowReleasedAt, isNull);
      expect(timestamps.workflowUpdatedAt, isNull);
      expect(timestamps.acknowledgedAt, isNull);
      expect(timestamps.endDate, isNull);
      expect(timestamps.deletedAt, isNull);
    });

    test('missing or malformed required timestamps fail closed', () {
      final valid = <String, dynamic>{
        'startDate': '2026-08-06T01:00:00Z',
        'createdAt': '2026-08-06T00:00:00Z',
        'updatedAt': '2026-08-06T01:20:00Z',
      };

      for (final field in <String>['startDate', 'createdAt', 'updatedAt']) {
        final missing = Map<String, dynamic>.from(valid)..remove(field);
        expect(
          () => readRemoteMaintenanceTimestamps(
            missing,
            source: 'maintenance/missing-$field',
          ),
          throwsA(
            isA<PersistedDataFormatException>().having(
              (error) => error.fieldName,
              'fieldName',
              field,
            ),
          ),
        );

        final malformed = Map<String, dynamic>.from(valid)
          ..[field] = 'not-a-timestamp';
        expect(
          () => readRemoteMaintenanceTimestamps(
            malformed,
            source: 'maintenance/malformed-$field',
          ),
          throwsA(
            isA<PersistedDataFormatException>().having(
              (error) => error.fieldName,
              'fieldName',
              field,
            ),
          ),
        );
      }
    });

    test('malformed present optional timestamps fail closed', () {
      final valid = <String, dynamic>{
        'startDate': '2026-08-06T01:00:00Z',
        'createdAt': '2026-08-06T00:00:00Z',
        'updatedAt': '2026-08-06T01:20:00Z',
      };
      const optionalFields = <String>[
        'workflowDeferredAt',
        'workflowReactivatedAt',
        'workflowReleasedAt',
        'workflowUpdatedAt',
        'acknowledgedAt',
        'endDate',
        'deletedAt',
      ];

      for (final field in optionalFields) {
        final malformed = Map<String, dynamic>.from(valid)
          ..[field] = _TimestampLike();
        expect(
          () => readRemoteMaintenanceTimestamps(
            malformed,
            source: 'maintenance/malformed-$field',
          ),
          throwsA(
            isA<PersistedDataFormatException>().having(
              (error) => error.fieldName,
              'fieldName',
              field,
            ),
          ),
        );
      }
    });

    test('page accounting rejects inconsistent counts and cursors', () {
      final empty = PaginatedMaintenanceResult(records: []);
      expect(empty.sourceDocumentCount, 0);
      expect(empty.decodeErrorCount, 0);

      expect(
        () => PaginatedMaintenanceResult(records: [], sourceDocumentCount: 1),
        throwsArgumentError,
      );
      expect(
        () => PaginatedMaintenanceResult(
          records: [],
          sourceDocumentCount: 1,
          decodeErrorCount: 1,
        ),
        throwsArgumentError,
      );
    });

    test('source paths share strict decoding and contain bad pull pages', () {
      final timestampReader =
          File(
            'lib/features/maintenance/data/remote_maintenance_timestamps.dart',
          ).readAsStringSync();
      final maintenanceProvider =
          File(
            'lib/features/maintenance/providers/maintenance_provider.dart',
          ).readAsStringSync();
      final liveRemoteSync =
          File(
            'lib/core/services/live_remote_sync_service.dart',
          ).readAsStringSync();
      final maintenancePull =
          File(
            'lib/core/services/global_pull_service.maintenance.dart',
          ).readAsStringSync();
      final globalPull =
          File('lib/core/services/global_pull_service.dart').readAsStringSync();
      final syncStatusIndicator =
          File(
            'lib/core/widgets/sync_status_indicator.dart',
          ).readAsStringSync();

      expect(timestampReader, contains('readRequiredPersistedDateTime('));
      expect(timestampReader, contains('readOptionalPersistedDateTime('));
      for (final source in <String>[maintenanceProvider, liveRemoteSync]) {
        expect(source, contains('readRemoteMaintenanceTimestamps('));
        expect(source, isNot(contains('DateTime? _parseTimestamp(')));
        expect(
          source,
          isNot(contains("_parseTimestamp(d['startDate']) ?? DateTime.now()")),
        );
        expect(
          source,
          isNot(contains("_parseTimestamp(d['createdAt']) ?? DateTime.now()")),
        );
      }

      expect(
        maintenanceProvider,
        contains('final records = <MaintenanceRecord>[];'),
      );
      expect(maintenanceProvider, contains('decodeErrorCount++;'));
      expect(
        maintenanceProvider,
        contains('sourceDocumentCount: snap.docs.length,'),
      );
      expect(
        maintenanceProvider,
        contains('decodeErrorCount: decodeErrorCount,'),
      );
      final rejectedCount = maintenancePull.indexOf(
        'if (result.decodeErrorCount > 0)',
      );
      final emptyPage = maintenancePull.indexOf(
        'if (result.sourceDocumentCount == 0) break;',
      );
      expect(rejectedCount, greaterThanOrEqualTo(0));
      expect(emptyPage, greaterThan(rejectedCount));
      expect(
        maintenancePull,
        contains('lastSkipped += result.decodeErrorCount;'),
      );
      expect(maintenancePull, contains('_hadRecordProcessingError = true;'));
      expect(
        maintenancePull,
        contains(
          'if (result.sourceDocumentCount < GlobalPullService._pageSize) break;',
        ),
      );
      expect(
        globalPull,
        contains("reasonCode: 'domain-record-processing-failed'"),
      );
      expect(
        globalPull.indexOf('if (_hadRecordProcessingError)'),
        lessThan(globalPull.indexOf('return cursorStore.completeDomain(')),
      );
      expect(syncStatusIndicator, contains("'Last live error',"));
      expect(syncStatusIndicator, contains('liveHealth.lastError!'));
      expect(
        syncStatusIndicator,
        contains('case LiveRemoteSyncConnectionState.error:'),
      );
    });
  });
}

class _TimestampLike {
  DateTime toDate() => DateTime.utc(2026, 8, 6);
}
