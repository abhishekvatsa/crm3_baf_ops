import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_publication_readiness.dart';

void main() {
  group('publication audit package dependency', () {
    for (final pending in [
      'missing',
      'older',
      'wrong package',
      'deleted',
      'archived',
    ]) {
      test('holds audit while package is $pending', () {
        final fixture = _Fixture.ready();
        final package = fixture.package;
        if (pending == 'older') package.latestVersionNumber = 0;
        if (pending == 'wrong package') package.firestoreId = 'other';
        if (pending == 'deleted') package.isDeleted = true;
        if (pending == 'archived') {
          package.lifecycleStatus = TemplatePackageLifecycleStatus.archived;
        }
        expect(
          remotePackageSupportsPublicationAudit(
            package: pending == 'missing' ? null : package,
            version: fixture.version,
          ),
          isFalse,
        );
      });
    }
    for (final historical in [false, true]) {
      test('allows converged package and historical=$historical audit', () {
        final fixture = _Fixture.ready();
        if (historical) {
          fixture.package
            ..latestVersionNumber = 5
            ..activeVersionFirestoreId = 'version-5'
            ..lifecycleStatus = TemplatePackageLifecycleStatus.retired;
        }
        expect(
          remotePackageSupportsPublicationAudit(
            package: fixture.package,
            version: fixture.version,
          ),
          isTrue,
        );
      });
    }
  });
  group('TemplatePublicationReadiness', () {
    test('accepts synchronized active package/version/audit triad', () {
      final fixture = _Fixture.ready();

      final decision = evaluateTemplatePublicationReadiness(
        package: fixture.package,
        version: fixture.version,
        audits: [fixture.audit],
      );

      expect(decision.isReady, isTrue);
      expect(decision.code, TemplatePublicationReadinessCode.ready);
      expect(decision.matchingAudit?.firestoreId, 'audit-1');
    });

    test('rejects a historical published version', () {
      final fixture = _Fixture.ready();
      fixture.package.activeVersionFirestoreId = 'version-2';

      final decision = evaluateTemplatePublicationReadiness(
        package: fixture.package,
        version: fixture.version,
        audits: [fixture.audit],
      );

      expect(decision.code, TemplatePublicationReadinessCode.versionNotActive);
    });

    test('rejects an unsynchronized publish audit', () {
      final fixture = _Fixture.ready();
      fixture.audit.isSynced = false;

      final decision = evaluateTemplatePublicationReadiness(
        package: fixture.package,
        version: fixture.version,
        audits: [fixture.audit],
      );

      expect(
        decision.code,
        TemplatePublicationReadinessCode.publishAuditNotSynced,
      );
    });

    test('rejects a changed frozen payload whose stored hash is stale', () {
      final fixture = _Fixture.ready();
      fixture.version.jobTemplateSnapshotJson = '{"title":"changed"}';

      final decision = evaluateTemplatePublicationReadiness(
        package: fixture.package,
        version: fixture.version,
        audits: [fixture.audit],
      );

      expect(
        decision.code,
        TemplatePublicationReadinessCode.versionHashMismatch,
      );
    });
  });
}

class _Fixture {
  final TemplatePackage package;
  final TemplateVersion version;
  final TemplatePublishAudit audit;

  _Fixture({required this.package, required this.version, required this.audit});

  factory _Fixture.ready() {
    final now = DateTime.utc(2026, 6, 19, 12);
    final package = TemplatePackage()
      ..firestoreId = 'package-1'
      ..isSynced = true
      ..packageCode = 'BAF-TEST'
      ..title = 'BAF test package'
      ..lifecycleStatus = TemplatePackageLifecycleStatus.active
      ..activeVersionFirestoreId = 'version-1'
      ..latestVersionNumber = 1
      ..createdAt = now
      ..updatedAt = now;

    final version = TemplateVersion()
      ..firestoreId = 'version-1'
      ..packageFirestoreId = 'package-1'
      ..isSynced = true
      ..versionNumber = 1
      ..versionLabel = 'v1'
      ..status = TemplateVersionStatus.published
      ..jobTemplateSnapshotJson = '{"title":"BAF test"}'
      ..moduleSnapshotsJson = '[]'
      ..fieldDefinitionsJson = '[]'
      ..checklistJson = '[]'
      ..createdAt = now
      ..updatedAt = now
      ..publishedAt = now;
    version.refreshContentHash();

    final audit = TemplatePublishAudit()
      ..firestoreId = 'audit-1'
      ..packageFirestoreId = 'package-1'
      ..versionFirestoreId = 'version-1'
      ..isSynced = true
      ..action = TemplatePublishAuditAction.published
      ..performedAt = now
      ..updatedAt = now
      ..afterHash = version.contentHash;

    return _Fixture(package: package, version: version, audit: audit);
  }
}
