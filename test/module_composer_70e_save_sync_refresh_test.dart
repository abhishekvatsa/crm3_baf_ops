import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
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
          return true;
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
      'accepts concurrent confirmation even if requested sync returns false',
      () async {
        final source = _draft(firestoreId: 'version-70e', isSynced: false);

        final refreshed = await saveAndRefreshComposerTemplateVersionDraft(
          version: source,
          persistLocal: () async {},
          runSync: () async => false,
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
            runSync: () async => false,
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
            return true;
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
          runSync: () async => true,
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
          runSync: () async => true,
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
          runSync: () async => true,
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
