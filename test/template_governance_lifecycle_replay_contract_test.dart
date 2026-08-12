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
        'final archiveReplayed =',
        '_tryPushDecomposedTemplateVersionArchive(',
        'final publishReplayed =',
        '_tryPushDecomposedTemplateVersion(',
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
        contains(
          'enum _TemplateVersionReplayStep { createDraft, updateDraft, publish, archive }',
        ),
        reason:
            'TemplateVersion replay is explicitly limited to draft create/update, publish, and governed draft archive.',
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

    test('offline draft archive replays draft create before scoped archive', () {
      final source = _read(_syncPath);
      final archivePlan = _blockStartingAt(
        source,
        'List<_TemplateVersionReplayStep> _templateVersionArchiveReplayPlan',
      );
      final archivePayload = _blockStartingAt(
        source,
        'Map<String, dynamic> _templateVersionArchiveReplayStepData',
      );
      final provider = _read(_providerPath);

      expect(
        archivePlan,
        contains('local.status != TemplateVersionStatus.archived'),
      );
      expect(archivePlan, contains('_TemplateVersionReplayStep.createDraft'));
      expect(archivePlan, contains('_TemplateVersionReplayStep.updateDraft'));
      expect(archivePlan, contains('_TemplateVersionReplayStep.archive'));
      expect(
        archivePlan,
        contains('predecessorVersion <= remote.version'),
        reason:
            'an unsynced saved edit may be replayed as draft→draft before archive only when its predecessor version is newer than remote',
      );
      expect(
        source,
        contains('_canReplayTemplateVersionArchiveForCurrentUser'),
      );
      expect(
        source,
        contains('_remoteTemplateVersionArchiveAlreadySatisfied'),
        reason:
            'a committed archive replay must be markable on the next sync without an illegal archived→archived write',
      );

      for (final field in <String>[
        'status',
        'contentHash',
        'closureReviewConfirmed',
        'closureCriticalModuleCount',
        'updatedByUid',
        'updatedAt',
        'version',
      ]) {
        expect(archivePayload, contains("'$field'"));
      }
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
        expect(archivePayload, isNot(contains("'$forbidden'")));
      }

      expect(source, contains('_templateVersionDraftReplayUpdateData'));
      expect(
        provider,
        contains('applyRemoteTemplateVersionDraftUpdateReplayStepForSync'),
      );
      expect(
        provider,
        contains('applyRemoteTemplateVersionArchiveReplayStepForSync'),
      );
      expect(
        source.split('expectedDraftVersion: predecessorVersion').length - 1,
        2,
        reason:
            'both draft-update and archive replay steps must carry their expected remote predecessor version',
      );
      expect(
        provider,
        contains('remote.version != expectedDraftVersion'),
        reason:
            'archive replay must re-read and compare the remote predecessor version before committing the lifecycle transition',
      );
    });

    test('existing remote audit must match immutable local evidence', () {
      final source = _read(_syncPath);
      final matcher = _blockStartingAt(
        source,
        'bool _templatePublishAuditMatchesRemote',
      );
      final auditSync = _blockStartingAt(
        source,
        'Future<void> _syncTemplatePublishAudits()',
      );

      expect(matcher, contains('local.action == remote.action'));
      expect(matcher, contains('local.payloadSnapshotJson'));
      expect(matcher, contains('local.afterHash'));
      expect(auditSync, contains('_templatePublishAuditMatchesRemote'));
      expect(auditSync, contains('audit collision preserved locally'));
    });

    test('restore audit waits for the remote version to return to draft', () {
      final source = _read(_syncPath);
      final dependency = _blockStartingAt(
        source,
        'bool _templatePublishAuditRemoteDependencySatisfied',
      );
      final snapshotMatcher = _blockStartingAt(
        source,
        'bool _templateLifecycleAuditSnapshotMatchesRemote',
      );

      expect(dependency, contains('case TemplatePublishAuditAction.restored:'));
      expect(
        dependency,
        contains('remoteVersion.status == TemplateVersionStatus.draft'),
      );
      expect(
        source,
        contains('_templateLifecycleAuditSnapshotMatchesRemote'),
        reason:
            'archive/restore audits must not sync merely because the remote lifecycle status happens to match',
      );
      expect(snapshotMatcher, contains('readRequiredPersistedDateTime('));
      expect(snapshotMatcher, contains("field: 'updatedAt'"));
      expect(snapshotMatcher, isNot(contains('DateTime.tryParse(')));
      expect(
        snapshotMatcher,
        isNot(contains("decoded['updatedAt']?.toString()")),
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

    test('assignment only exposes remotely confirmed active versions', () {
      final assignment = _read(
        'lib/features/planned_maintenance/presentation/published_template_assignment_screen.dart',
      );
      final readiness = _read(
        'lib/features/planned_maintenance/domain/template_publication_readiness.dart',
      );

      expect(
        assignment,
        contains('activeTemplateVersionForPackage('),
        reason:
            'the assignment catalogue must resolve only the package active version',
      );
      expect(
        assignment,
        contains('templatePublicationReadinessProvider('),
        reason:
            'the visible assignment state must depend on the synchronized publication-readiness triad',
      );
      expect(
        assignment,
        contains('evaluateTemplatePublicationReadiness('),
        reason:
            'submit must re-evaluate readiness from the repository instead of trusting stale widget state',
      );
      expect(
        readiness,
        contains('if (!package.isSynced)'),
        reason: 'the package active pointer must be remotely confirmed',
      );
      expect(
        readiness,
        contains('if (!version.isSynced)'),
        reason: 'the published version must be remotely confirmed',
      );
      expect(
        readiness,
        contains('if (versionId != activeVersionId)'),
        reason: 'historical published versions must not be normally assignable',
      );
      expect(
        readiness,
        contains('if (syncedAudit == null)'),
        reason:
            'a matching synchronized publish audit is required before assignment',
      );
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
