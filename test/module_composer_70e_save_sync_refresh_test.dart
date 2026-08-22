import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('70E Composer save-sync refresh', () {
    test('returns the same remotely confirmed draft identity', () async {
      final source = _draft(firestoreId: null, isSynced: false);
      final calls = <String>[];

      final refreshed = await saveAndRefreshComposerTemplateVersionDraft(
        version: source,
        persistLocal: () async {
          calls.add('save');
          source.firestoreId = 'version-70e';
        },
        runSync: () async {
          calls.add('sync');
          return SyncRequestOutcome.succeeded;
        },
        reloadLocal: (firestoreId) async {
          calls.add('reload:$firestoreId');
          return _draft(firestoreId: firestoreId, isSynced: true);
        },
      );

      expect(calls, <String>['save', 'sync', 'reload:version-70e']);
      expect(refreshed.firestoreId, 'version-70e');
      expect(refreshed.id, source.id);
      expect(refreshed.packageFirestoreId, source.packageFirestoreId);
      expect(refreshed.versionNumber, source.versionNumber);
      expect(refreshed.createdAt, source.createdAt);
      expect(refreshed.isDraft, isTrue);
      expect(refreshed.isSynced, isTrue);
      expect(refreshed.contentHash, source.contentHash);
    });

    test(
      'accepts concurrent confirmation when requested sync was queued',
      () async {
        final source = _draft(firestoreId: 'version-70e', isSynced: false);

        final refreshed = await saveAndRefreshComposerTemplateVersionDraft(
          version: source,
          persistLocal: () async {},
          runSync: () async => SyncRequestOutcome.queued,
          reloadLocal: (firestoreId) async {
            return _draft(firestoreId: firestoreId, isSynced: true);
          },
        );

        expect(refreshed.isSynced, isTrue);
      },
    );

    test(
      'preserves local draft but refuses publish eligibility without ack',
      () async {
        final source = _draft(firestoreId: 'version-70e', isSynced: false);

        await expectLater(
          saveAndRefreshComposerTemplateVersionDraft(
            version: source,
            persistLocal: () async {},
            runSync: () async => SyncRequestOutcome.failed,
            reloadLocal: (firestoreId) async => source,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              contains('saved locally and remains retryable'),
            ),
          ),
        );
        expect(source.firestoreId, 'version-70e');
        expect(source.isSynced, isFalse);
      },
    );

    test('captures the saved payload fingerprint before sync begins', () async {
      final source = _draft(firestoreId: 'version-70e', isSynced: false);
      final changed = _draft(firestoreId: 'version-70e', isSynced: true)
        ..contentHash = 'mutated-during-sync';

      await expectLater(
        saveAndRefreshComposerTemplateVersionDraft(
          version: source,
          persistLocal: () async {},
          runSync: () async {
            source.contentHash = changed.contentHash;
            return SyncRequestOutcome.succeeded;
          },
          reloadLocal: (firestoreId) async => changed,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('payload changed'),
          ),
        ),
      );
    });

    test('blocks a payload mismatch during refresh', () async {
      final source = _draft(firestoreId: 'version-70e', isSynced: false);
      final changed = _draft(firestoreId: 'version-70e', isSynced: true)
        ..contentHash = 'different-hash';

      await expectLater(
        saveAndRefreshComposerTemplateVersionDraft(
          version: source,
          persistLocal: () async {},
          runSync: () async => SyncRequestOutcome.succeeded,
          reloadLocal: (firestoreId) async => changed,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('payload changed'),
          ),
        ),
      );
    });

    test('blocks stale authoring metadata during refresh', () async {
      final source =
          _draft(firestoreId: 'version-70e', isSynced: false)
            ..versionLabel = 'Operator-ready v7'
            ..releaseNotes = 'Adds structured gas evidence guidance.';
      final stale =
          _draft(firestoreId: 'version-70e', isSynced: true)
            ..versionLabel = 'Old label'
            ..releaseNotes = 'Old release notes';

      await expectLater(
        saveAndRefreshComposerTemplateVersionDraft(
          version: source,
          persistLocal: () async {},
          runSync: () async => SyncRequestOutcome.succeeded,
          reloadLocal: (firestoreId) async => stale,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('authoring metadata changed'),
          ),
        ),
      );
    });

    test('blocks an identity fork during refresh', () async {
      final source = _draft(firestoreId: 'version-70e', isSynced: false);
      final fork =
          _draft(firestoreId: 'version-70e', isSynced: true)
            ..id = 701
            ..versionNumber = 8;

      await expectLater(
        saveAndRefreshComposerTemplateVersionDraft(
          version: source,
          persistLocal: () async {},
          runSync: () async => SyncRequestOutcome.succeeded,
          reloadLocal: (firestoreId) async => fork,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('local identity changed'),
          ),
        ),
      );
    });
  });

  group('Composer publish-sync refresh', () {
    test('returns only a synchronized published record', () async {
      final source = _published(isSynced: false);
      final calls = <String>[];

      final refreshed = await publishAndRefreshComposerTemplateVersion(
        version: source,
        persistLocal: () async => calls.add('publish'),
        runSync: () async {
          calls.add('sync');
          return SyncRequestOutcome.succeeded;
        },
        reloadLocal: (firestoreId) async {
          calls.add('reload:$firestoreId');
          return _published(isSynced: true);
        },
      );

      expect(calls, <String>['publish', 'sync', 'reload:version-70e']);
      expect(refreshed.isPublished, isTrue);
      expect(refreshed.isSynced, isTrue);
    });

    test(
      'preserves a queued publication without claiming confirmation',
      () async {
        final source = _published(isSynced: false);

        await expectLater(
          publishAndRefreshComposerTemplateVersion(
            version: source,
            persistLocal: () async {},
            runSync: () async => SyncRequestOutcome.queued,
            reloadLocal: (firestoreId) async => source,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('safely saved on this device'),
                contains('queued'),
              ),
            ),
          ),
        );
        expect(source.isPublished, isTrue);
        expect(source.isSynced, isFalse);
      },
    );

    test('rejects a mismatched publication readback', () async {
      final source = _published(isSynced: false);
      final changed = _published(isSynced: true)..contentHash = 'other-hash';

      await expectLater(
        publishAndRefreshComposerTemplateVersion(
          version: source,
          persistLocal: () async {},
          runSync: () async => SyncRequestOutcome.succeeded,
          reloadLocal: (firestoreId) async => changed,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('identity or content changed'),
          ),
        ),
      );
    });
  });
}

TemplateVersion _draft({required String? firestoreId, required bool isSynced}) {
  return TemplateVersion()
    ..id = 700
    ..firestoreId = firestoreId
    ..packageFirestoreId = 'package-70e'
    ..versionNumber = 7
    ..status = TemplateVersionStatus.draft
    ..contentHash = 'stable-content-hash'
    ..jobTemplateSnapshotJson = '{}'
    ..moduleSnapshotsJson = '[]'
    ..fieldDefinitionsJson = '[]'
    ..checklistJson = '[]'
    ..createdAt = DateTime(2026, 6, 14)
    ..updatedAt = DateTime(2026, 6, 14)
    ..isSynced = isSynced;
}

TemplateVersion _published({required bool isSynced}) {
  return _draft(firestoreId: 'version-70e', isSynced: isSynced)
    ..version = 2
    ..status = TemplateVersionStatus.published
    ..publishedByUid = 'governor-70e'
    ..publishedByName = 'Governor'
    ..publishedAt = DateTime(2026, 6, 15);
}
