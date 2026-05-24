// FILE: test/sync_remote_freshness_policy_test.dart

import 'dart:io';

import 'package:crm3_baf_ops/core/services/sync_remote_freshness_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncRemoteFreshnessPolicy', () {
    final base = DateTime.utc(2026, 5, 15, 10);

    test('remote higher version is newer even with older timestamp', () {
      expect(
        SyncRemoteFreshnessPolicy.isRemoteNewer(
          localVersion: 3,
          localUpdatedAt: base,
          remoteVersion: 4,
          remoteUpdatedAt: base.subtract(const Duration(hours: 1)),
        ),
        isTrue,
      );
    });

    test('remote lower version is not newer even with newer timestamp', () {
      expect(
        SyncRemoteFreshnessPolicy.isRemoteNewer(
          localVersion: 4,
          localUpdatedAt: base,
          remoteVersion: 3,
          remoteUpdatedAt: base.add(const Duration(hours: 1)),
        ),
        isFalse,
      );
    });

    test('same version with newer remote updatedAt is newer', () {
      expect(
        SyncRemoteFreshnessPolicy.isRemoteNewer(
          localVersion: 3,
          localUpdatedAt: base,
          remoteVersion: 3,
          remoteUpdatedAt: base.add(const Duration(milliseconds: 1)),
        ),
        isTrue,
      );
    });

    test('same version with equal updatedAt is not newer', () {
      expect(
        SyncRemoteFreshnessPolicy.isRemoteNewer(
          localVersion: 3,
          localUpdatedAt: base,
          remoteVersion: 3,
          remoteUpdatedAt: base,
        ),
        isFalse,
      );
    });

    test('same version with older remote updatedAt is not newer', () {
      expect(
        SyncRemoteFreshnessPolicy.isRemoteNewer(
          localVersion: 3,
          localUpdatedAt: base,
          remoteVersion: 3,
          remoteUpdatedAt: base.subtract(const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
    });

    test(
      'same-version newer remote time remains conservative for closure sync',
      () {
        expect(
          SyncRemoteFreshnessPolicy.isRemoteNewer(
            localVersion: 3,
            localUpdatedAt: base,
            remoteVersion: 3,
            remoteUpdatedAt: base.add(const Duration(minutes: 5)),
          ),
          isTrue,
        );
      },
    );

    test('remote update ingestion delegates winner checks to policy', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      final handRolled = <String>[];
      var policyUsageCount = 0;
      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        if (source.contains('SyncRemoteFreshnessPolicy.isRemoteNewer')) {
          policyUsageCount += 1;
        }
        if (source.contains('remote.version > local.version ||')) {
          handRolled.add(file.path);
        }
      }

      expect(policyUsageCount, greaterThanOrEqualTo(3));
      expect(
        handRolled,
        isEmpty,
        reason:
            'Remote-update winner checks must not hand-roll the version/timestamp rule.',
      );
    });
  });
}
