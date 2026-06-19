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
}
