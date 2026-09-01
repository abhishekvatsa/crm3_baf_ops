import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'relevance-end evidence survives synchronized and local round trips',
    () {
      final endedAt = DateTime.utc(2026, 9, 1, 9, 15);
      final closure = IssueAdministrativeClosure(
        disposition: IssueAdministrativeClosureDisposition.relevanceEnded,
        reason: 'The unresolved concern was retained after closure.',
        relevanceEndedAt: endedAt,
        relevanceEndedByUid: 'admin-1',
        relevanceEndedByName: 'Admin User',
        relevanceEndReason: 'A valid Inner Cover is now assigned to the Base.',
      );

      final synchronized = IssueAdministrativeClosure.fromSynchronizedFields(
        closure.toSynchronizedFields(),
        source: 'test maintenance record',
      );
      final local = IssueAdministrativeClosure.tryDecodeLocal(
        mergeIssueAdministrativeClosureIntoMaintenanceMetadata(null, closure),
      );

      for (final decoded in <IssueAdministrativeClosure?>[
        synchronized,
        local,
      ]) {
        expect(
          decoded?.disposition,
          IssueAdministrativeClosureDisposition.relevanceEnded,
        );
        expect(decoded?.reason, closure.reason);
        expect(decoded?.relevanceEndedAt, endedAt);
        expect(decoded?.relevanceEndedByUid, 'admin-1');
        expect(decoded?.relevanceEndedByName, 'Admin User');
        expect(decoded?.relevanceEndReason, closure.relevanceEndReason);
      }
    },
  );

  test('partial relevance-end evidence fails closed', () {
    expect(
      () => IssueAdministrativeClosure.fromSynchronizedFields(<String, Object?>{
        'issueClosureSchemaVersion': 1,
        'issueClosureDisposition': 'relevanceEnded',
        'issueClosureReason': 'Original administrative closure.',
        'issueClosureRelevanceEndedAt':
            DateTime.utc(2026, 9, 1, 9, 15).toIso8601String(),
      }, source: 'partial test record'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
