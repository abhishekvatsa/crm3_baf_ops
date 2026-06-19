import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/release/app_build_identity.dart';

void main() {
  test(
    'identified versioned build qualifies as release-candidate identity',
    () {
      const identity = AppBuildIdentity(
        appVersion: '1.0.0',
        buildNumber: '70',
        gitCommit: 'abcdef1',
        releaseTag: 'v1.0.0-rc1',
        releaseChannel: 'candidate',
        ciRunId: '12345',
        buildTimestampUtc: '2026-06-19T12:00:00Z',
        releaseId: 'crm3-baf-ops-1.0.0-70',
        expectedBackendReleaseId: 'backend-70',
        sourceArchiveSha256: 'ABC',
      );

      expect(identity.isVersioned, isTrue);
      expect(identity.isSourceIdentified, isTrue);
      expect(identity.isReleaseCandidateIdentified, isTrue);
      expect(identity.expectsBackendParity, isTrue);
    },
  );
}
