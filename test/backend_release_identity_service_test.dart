import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/release/backend_release_identity_service.dart';

void main() {
  test('parses backend release identity returned by callable', () {
    final identity = BackendReleaseIdentity.fromCallableData(<String, dynamic>{
      'releaseId': 'backend-70i-1',
      'firebaseProjectId': 'crm3-baf-ops-b8638',
      'environment': 'production',
      'gitCommit': 'abcdef1',
      'functionsRevision': 'assign-00001',
      'functionsDigest': 'FUNCTIONS_SHA',
      'firestoreRulesReleaseId': 'ruleset-123',
      'firestoreRulesDigest': 'RULES_SHA',
      'firestoreIndexesDigest': 'INDEX_SHA',
      'deployedAt': '2026-06-19T12:00:00Z',
    });

    expect(identity.releaseId, 'backend-70i-1');
    expect(identity.firebaseProjectId, 'crm3-baf-ops-b8638');
    expect(identity.functionsRevision, 'assign-00001');
    expect(identity.deployedAt, DateTime.parse('2026-06-19T12:00:00Z'));
  });

  test('rejects an incomplete backend identity response', () {
    expect(
      () => BackendReleaseIdentity.fromCallableData(const <String, dynamic>{
        'releaseId': 'backend-70i-1',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('accepts an absent optional deployment timestamp', () {
    final identity =
        BackendReleaseIdentity.fromCallableData(const <String, dynamic>{
          'releaseId': 'backend-70i-1',
          'firebaseProjectId': 'crm3-baf-ops-b8638',
          'environment': 'production',
        });

    expect(identity.deployedAt, isNull);
  });

  test('parses a complete serialized callable timestamp', () {
    final identity = BackendReleaseIdentity.fromCallableData(
      const <String, dynamic>{
        'releaseId': 'backend-70i-1',
        'firebaseProjectId': 'crm3-baf-ops-b8638',
        'environment': 'production',
        'deployedAt': <String, Object>{
          '_seconds': 1785911400,
          '_nanoseconds': 123456000,
        },
      },
    );

    expect(identity.deployedAt, DateTime.utc(2026, 8, 5, 6, 30, 0, 123, 456));
  });

  test('malformed present deployment timestamps fail closed', () {
    for (final deployedAt in <Object>[
      'not-a-timestamp',
      const <String, Object>{'_seconds': 1785911400},
      const <String, Object>{'_seconds': 1785911400, '_nanoseconds': -1},
    ]) {
      expect(
        () => BackendReleaseIdentity.fromCallableData(<String, dynamic>{
          'releaseId': 'backend-70i-1',
          'firebaseProjectId': 'crm3-baf-ops-b8638',
          'environment': 'production',
          'deployedAt': deployedAt,
        }),
        throwsA(isA<FormatException>()),
      );
    }
  });
}
