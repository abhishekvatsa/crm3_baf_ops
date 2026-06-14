import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('70A TemplateVersion publish lifecycle replay contract', () {
    test('sync path attempts replay before standard batch push', () {
      final source = _read(_syncPath);
      final syncBlock = _blockStartingAt(
        source,
        'Future<void> _syncTemplateVersions()',
      );

      _expectOrder(syncBlock, const [
        'final remote = remoteMap[record.firestoreId];',
        'final replayed = await _tryPushDecomposedTemplateVersion',
        'skippedButSyncedSnapshots.add(_syncPushSnapshot(record));',
        'recordsToPush.add(record);',
      ]);

      expect(syncBlock, contains('lastSuccessCount++;'));
      expect(
        syncBlock,
        contains('remote may now be a draft'),
        reason:
            'partial draft replay should fall through safely instead of marking synced',
      );
    });

    test('replay scope is only missing/draft remote to published local', () {
      final source = _read(_syncPath);
      final plan = _blockStartingAt(
        source,
        'List<_TemplateVersionReplayStep> _templateVersionLifecycleReplayPlan',
      );

      expect(plan, contains('remote == null'));
      expect(plan, contains('local.status != TemplateVersionStatus.published'));
      expect(plan, contains('remote.status != TemplateVersionStatus.draft'));
      expect(plan, contains('local.version <= 1'));
      expect(plan, contains('local.version <= remote.version'));
      expect(plan, contains('_templateVersionPinnedFieldDiff(local, remote)'));
      expect(plan, contains('_templateVersionDraftPayloadDiff(local, remote)'));
      expect(plan, contains('_TemplateVersionReplayStep.createDraft'));
      expect(plan, contains('_TemplateVersionReplayStep.publish'));
      expect(
        source,
        contains('enum _TemplateVersionReplayStep { createDraft, publish }'),
        reason:
            '70A must stay limited to TemplateVersion create-draft/publish replay.',
      );
    });

    test(
      'same-user guard is explicit for Firestore create and publish rules',
      () {
        final source = _read(_syncPath);
        final guard = _blockStartingAt(
          source,
          'bool _canReplayTemplateVersionPublishForCurrentUser',
        );

        expect(guard, contains('FirebaseAuth.instance.currentUser?.uid'));
        expect(guard, contains('local.createdByUid'));
        expect(guard, contains('local.publishedByUid'));
        expect(guard, contains('createdByUid == currentUid'));
        expect(guard, contains('publishedByUid == currentUid'));
        expect(
          guard,
          contains('Cross-actor reconstruction'),
          reason:
              'cross-actor offline publish replay must not be hidden in a client shortcut',
        );
      },
    );

    test('draft replay creates a draft-shaped predecessor, not published', () {
      final source = _read(_syncPath);
      final payload = _blockStartingAt(
        source,
        'Map<String, dynamic> _templateVersionDraftReplayCreateData',
      );
      final rules = _readFirstExisting(_rulePaths);
      final createRules = _blockStartingAt(
        rules,
        'function validTemplateVersionCreate',
      );

      for (final field in <String>[
        'firestoreId',
        'packageFirestoreId',
        'versionNumber',
        'status',
        'jobTemplateSnapshotJson',
        'moduleSnapshotsJson',
        'fieldDefinitionsJson',
        'checklistJson',
        'createdByUid',
        'updatedByUid',
        'version',
        'schemaVersion',
        'isDeleted',
      ]) {
        expect(
          payload,
          contains("'$field'"),
          reason: 'draft replay should include create-rule field $field',
        );
        expect(createRules, contains("'$field'"));
      }

      expect(payload, contains("'status': TemplateVersionStatus.draft.name"));
      expect(payload, contains("'contentHash': null"));
      expect(payload, contains("'publishedByUid': null"));
      expect(payload, contains("'publishedByName': null"));
      expect(payload, contains("'publishedAt': null"));
      expect(payload, contains("'version': local.version - 1"));
      expect(payload, contains("'isDeleted': false"));
    });

    test('publish replay uses field-scoped publish update payload', () {
      final source = _read(_syncPath);
      final payload = _blockStartingAt(
        source,
        'Map<String, dynamic> _templateVersionPublishReplayStepData',
      );

      for (final field in <String>[
        'status',
        'contentHash',
        'publishedByUid',
        'publishedByName',
        'publishedAt',
        'updatedByUid',
        'updatedByName',
        'updatedAt',
        'version',
      ]) {
        expect(payload, contains("'$field'"));
      }

      expect(
        payload,
        contains("'status': TemplateVersionStatus.published.name"),
      );
      expect(payload, contains("'updatedByUid': full['publishedByUid']"));
      expect(payload, contains("'version': full['version']"));

      for (final forbidden in <String>[
        'jobTemplateSnapshotJson',
        'moduleSnapshotsJson',
        'fieldDefinitionsJson',
        'checklistJson',
        'createdByUid',
        'createdAt',
        'packageFirestoreId',
        'versionNumber',
        'isDeleted',
      ]) {
        expect(
          payload,
          isNot(contains("'$forbidden'")),
          reason:
              'publish replay must not resend frozen identity/payload fields as a broad full-doc write',
        );
      }
    });

    test('remote-only primitives are explicit and unsupported by Isar', () {
      final provider = _read(_providerPath);
      final firestoreBlock = _blockStartingAt(
        provider,
        'class FirestoreTemplateGovernanceRepository',
      );

      expect(
        provider,
        contains('createRemoteTemplateVersionDraftReplayStepForSync'),
      );
      expect(
        provider,
        contains('applyRemoteTemplateVersionPublishReplayStepForSync'),
      );
      expect(
        provider,
        contains('supported by the local Isar template-governance repository'),
      );
      expect(
        firestoreBlock,
        contains('txn.set(ref, draftData);'),
        reason:
            'draft replay should create the missing draft predecessor remotely',
      );
      expect(
        firestoreBlock,
        contains(
          '_versions.doc(id).set(publishData, SetOptions(merge: true));',
        ),
        reason: 'publish replay must remain a field-scoped merge update',
      );
    });

    test('remote draft payload is authoritative for resumed publish replay', () {
      final source = _read(_syncPath);

      expect(
        source,
        contains('_shouldRestoreRemoteDraftPayloadBeforePublishReplay'),
      );
      expect(source, contains('_restoreRemoteDraftPayloadForPublishReplay'));
      expect(
        source,
        contains('..jobTemplateSnapshotJson = remote.jobTemplateSnapshotJson'),
      );
      expect(source, contains('remote.jobTemplateSnapshotJson'));
      expect(source, contains('local.refreshContentHash()'));
      expect(
        source,
        contains('_templateGovernanceRepo.batchUpsertVersions'),
        reason:
            'the repaired published record must be persisted locally before replay is marked synced',
      );
    });

    test('version lifecycle precedes package pointer and audit sync', () {
      final source = _read(_syncPath);
      final governance = _blockStartingAt(
        source,
        'Future<void> _syncTemplateGovernance()',
      );

      _expectOrder(governance, const [
        'await _syncTemplateVersions();',
        'await _syncTemplatePackages();',
        'await _syncTemplatePublishAudits();',
      ]);
      expect(
        source,
        contains('_templatePublishAuditRemoteDependencySatisfied'),
      );
      expect(source, contains('Holding TemplateVersion audit'));
    });

    test('assignment only exposes remotely confirmed published versions', () {
      final assignment = _read(
        'lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart',
      );

      expect(assignment, contains('version.isAssignable && version.isSynced'));
    });

    test('does not weaken rules or touch unrelated high-risk domains', () {
      final source = _read(_syncPath);
      final provider = _read(_providerPath);
      final rules = _readFirstExisting(_rulePaths);

      expect(
        rules,
        contains("request.resource.data.get('status', null) == 'draft'"),
        reason: 'TemplateVersion create must remain draft-only.',
      );
      expect(
        rules,
        contains("resource.data.get('status', null) == 'draft'"),
        reason: 'TemplateVersion publish must remain update-only from draft.',
      );
      expect(rules, isNot(contains('createAsPublished')));
      expect(source, isNot(contains('completePlannedJobExecution')));
      expect(source, isNot(contains('GlobalPullService')));
      expect(provider, isNot(contains('FirebaseFunctions')));
    });
  });
}

const _syncPath = 'lib/core/services/sync_service.template_governance.dart';
const _providerPath =
    'lib/features/planned_maintenance/providers/template_governance_provider.dart';
const _rulePaths = <String>[
  'firestore.rules',
  'Other root files/firestore.rules',
];

String _read(String path) => File(path).readAsStringSync();

String _readFirstExisting(List<String> paths) {
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  fail("None of these files exist: ${paths.join(', ')}");
}

void _expectOrder(String source, List<String> fragments) {
  var cursor = -1;
  for (final fragment in fragments) {
    final index = source.indexOf(fragment, cursor + 1);
    expect(
      index,
      greaterThan(cursor),
      reason: 'Expected after previous fragment: $fragment',
    );
    cursor = index;
  }
}

String _blockStartingAt(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, isNot(-1), reason: 'Missing marker: $marker');

  final openBrace = source.indexOf('{', markerIndex);
  expect(openBrace, isNot(-1), reason: 'Missing opening brace after $marker');

  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;

  for (var i = openBrace; i < source.length; i++) {
    final char = source[i];

    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = true;
      continue;
    }

    if (!inDoubleQuote && char == "'") {
      inSingleQuote = !inSingleQuote;
      continue;
    }
    if (!inSingleQuote && char == '"') {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }
    if (inSingleQuote || inDoubleQuote) continue;

    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(markerIndex, i + 1);
    }
  }

  fail('Could not find closing brace for $marker');
}
