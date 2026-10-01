import 'package:crm3_baf_ops/core/release/app_build_identity.dart';
import 'package:crm3_baf_ops/core/release/backend_release_identity_service.dart';
import 'package:crm3_baf_ops/features/admin/presentation/local_diagnostics_screen.dart';
import 'package:flutter_test/flutter_test.dart';

const _build = AppBuildIdentity(
  appVersion: '1.0.0',
  buildNumber: '31',
  gitCommit: 'client-source-sentinel',
  releaseTag: 'candidate',
  releaseChannel: 'test',
  ciRunId: 'test-run',
  buildTimestampUtc: '2026-10-01T00:00:00Z',
  releaseId: 'client-release-sentinel',
  expectedBackendReleaseId: 'backend-release-sentinel',
  sourceArchiveSha256: 'client-archive-sentinel',
);

Map<String, Object?> _observed() => {
  'releaseId': 'backend-release-sentinel',
  'firebaseProjectId': 'backend-project-sentinel',
  'environment': 'production',
  'gitCommit': 'different-backend-source-sentinel',
  'functionsRevision': 'function-revision-sentinel',
  'functionsDigest': 'functions-digest-sentinel',
  'firestoreRulesReleaseId': 'rules-release-sentinel',
  'firestoreRulesDigest': 'rules-digest-sentinel',
  'firestoreIndexesDigest': 'indexes-digest-sentinel',
};

LocalReleaseDiagnosticsSnapshot _snapshot(Map<String, Object?> observed) =>
    LocalReleaseDiagnosticsSnapshot(
      build: _build,
      backend: BackendReleaseIdentity.fromCallableData(observed),
    );

void _expectIdentifierOnly(LocalReleaseDiagnosticsSnapshot snapshot) {
  expect(snapshot.backendReleaseIdMatches, isTrue);
  expect(snapshot.backendReleaseIdComparisonLabel, 'identifier matches');
  final exported = snapshot.toMap();
  expect(exported['backendReleaseIdMatches'], isTrue);
  expect(exported['backendReleaseIdComparison'], 'identifier matches');
  expect(exported['backendDeploymentIdentity'], 'unverified');
  // Older support readers must never interpret ID equality as full parity.
  expect(exported['backendParityConfirmed'], isFalse);
  expect(exported['backendParity'], 'unverified');
  expect(snapshot.backendParityConfirmed, isFalse);
  expect(snapshot.toDiagnosticsText(), contains('backendParity: unverified'));
  expect(
    snapshot.toDiagnosticsText(),
    contains('backendDeploymentIdentity: unverified'),
  );
}

void main() {
  test('matching release IDs allow distinct client and backend sources', () {
    final snapshot = _snapshot(_observed());
    expect(snapshot.backend!.gitCommit, isNot(snapshot.build.gitCommit));
    _expectIdentifierOnly(snapshot);
    expect(snapshot.toMap()['backend'], snapshot.backend!.toMap());
  });

  for (final field in [
    'gitCommit',
    'functionsRevision',
    'functionsDigest',
    'firestoreRulesReleaseId',
    'firestoreRulesDigest',
    'firestoreIndexesDigest',
  ]) {
    for (final value in [null, 'wrong-$field-sentinel']) {
      test('same release ID with $field=$value never confirms parity', () {
        final observed = _observed()..[field] = value;
        final snapshot = _snapshot(observed);
        _expectIdentifierOnly(snapshot);
        expect(snapshot.backend!.toMap()[field], value);
      });
    }
  }

  for (final field in ['firebaseProjectId', 'environment']) {
    test('same release ID does not verify the observed $field', () {
      final observed = _observed()..[field] = 'different-$field-sentinel';
      _expectIdentifierOnly(_snapshot(observed));
    });
  }

  test('schema-v2 fields are not silently promoted to client parity proof', () {
    final observed = _observed()
      ..remove('gitCommit')
      ..remove('functionsDigest')
      ..addAll({
        'schemaVersion': 2,
        'backendGitCommit': 'identity-function-only-source-sentinel',
        'functionsDeployedDigest': 'mixed-fleet-digest-sentinel',
        'functionsDigestSemantics': 'MIXED_FUNCTION_FLEET_DIGEST',
        'releaseModel': {
          'type': 'COMPOSITE_LIVE_STATE',
          'singleHomogeneousDeployment': false,
        },
      });
    _expectIdentifierOnly(_snapshot(observed));
  });

  test('different release ID is reported as an identifier difference', () {
    final snapshot = _snapshot(
      _observed()..['releaseId'] = 'other-release-sentinel',
    );
    expect(snapshot.backendReleaseIdMatches, isFalse);
    expect(snapshot.backendReleaseIdComparisonLabel, 'identifier differs');
    expect(snapshot.toMap()['backendParityConfirmed'], isFalse);
  });

  test('checking, unavailable and undeclared comparisons remain distinct', () {
    const checking = LocalReleaseDiagnosticsSnapshot(
      build: _build,
      backendLoading: true,
    );
    const unavailable = LocalReleaseDiagnosticsSnapshot(
      build: _build,
      backendError: 'Backend identity unavailable',
    );
    const undeclared = LocalReleaseDiagnosticsSnapshot(
      build: AppBuildIdentity(
        appVersion: '1.0.0',
        buildNumber: '31',
        gitCommit: 'client-source-sentinel',
        releaseTag: 'candidate',
        releaseChannel: 'test',
        ciRunId: 'test-run',
        buildTimestampUtc: '2026-10-01T00:00:00Z',
        releaseId: 'client-release-sentinel',
        expectedBackendReleaseId: 'unidentified',
        sourceArchiveSha256: 'client-archive-sentinel',
      ),
    );
    expect(checking.backendReleaseIdComparisonLabel, 'checking');
    expect(checking.toMap()['backendIdentityStatus'], 'checking');
    expect(unavailable.backendReleaseIdComparisonLabel, 'unavailable');
    expect(unavailable.toMap()['backendIdentityStatus'], 'unavailable');
    expect(undeclared.backendReleaseIdComparisonLabel, 'not declared by build');
    for (final snapshot in [checking, unavailable, undeclared]) {
      expect(snapshot.backendReleaseIdMatches, isFalse);
      expect(snapshot.toMap()['backendDeploymentIdentity'], 'unverified');
      expect(snapshot.toMap()['backendParityConfirmed'], isFalse);
    }
  });
}
