import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('70A TemplateVersion publish replay contract', () {
    test(
      'sync path replays remote-missing published versions before batch push',
      () {
        final source = _read(_syncPath);
        final syncBlock = _blockStartingAt(
          source,
          'Future<void> _syncTemplateVersions()',
        );

        _expectOrder(syncBlock, const [
          'final remote = remoteMap[record.firestoreId];',
          'remote == null && !record.isDeleted && !record.isDraft',
          'final replayed = await _tryPushDecomposedTemplateVersion(record);',
          'skippedButSyncedSnapshots.add(_syncPushSnapshot(record));',
          'recordsToPush.add(record);',
        ]);

        expect(
          syncBlock,
          contains(r'direct create-as-${record.status.name}'),
          reason:
              'remote-missing non-draft versions must not fall through to create-as-published',
        );
        expect(syncBlock, contains('lastSuccessCount++;'));
        expect(syncBlock, contains('lastFailureCount++;'));
        expect(
          syncBlock,
          isNot(contains('validTemplateVersionCreate')),
          reason: 'sync must not encode rule relaxation as a client workaround',
        );
      },
    );

    test(
      'replay is limited to published TemplateVersions with same-user metadata',
      () {
        final source = _read(_syncPath);
        final block = _blockStartingAt(
          source,
          'Future<bool> _tryPushDecomposedTemplateVersion',
        );

        expect(block, contains('!local.isPublished'));
        expect(block, contains('local.version <= 1'));
        expect(block, contains('FirebaseAuth.instance.currentUser?.uid'));
        expect(block, contains('local.createdByUid'));
        expect(block, contains('local.publishedByUid'));
        expect(block, contains('local.updatedByUid'));
        expect(block, contains('createdByUid != currentUid'));
        expect(block, contains('publishedByUid != currentUid'));
        expect(block, contains('updatedByUid != currentUid'));
        expect(block, contains('local.publishedAt == null'));
        expect(block, contains('_cleanText(local.contentHash) == null'));
      },
    );

    test('replay creates draft first and only then applies publish update', () {
      final source = _read(_syncPath);
      final block = _blockStartingAt(
        source,
        'Future<bool> _tryPushDecomposedTemplateVersion',
      );

      _expectOrder(block, const [
        '.createRemoteVersionDraftReplayForSync(',
        '_templateVersionDraftReplayCreateData(local)',
        '.applyRemoteVersionPublishReplayStepForSync(',
        '_templateVersionPublishReplayStepData(local)',
      ]);

      expect(
        block,
        contains('return true;'),
        reason:
            'local may be marked synced only after both replay steps finish',
      );
      expect(
        block,
        contains('return false;'),
        reason: 'partial replay failure must surface through diagnostics',
      );
    });

    test('draft replay payload strips publish-only lifecycle fields', () {
      final source = _read(_syncPath);
      final block = _blockStartingAt(
        source,
        'Map<String, dynamic> _templateVersionDraftReplayCreateData',
      );

      expect(block, contains("['status'] = TemplateVersionStatus.draft.name"));
      expect(block, contains("['contentHash'] = null"));
      expect(block, contains("['publishedByUid'] = null"));
      expect(block, contains("['publishedByName'] = null"));
      expect(block, contains("['publishedAt'] = null"));
      expect(block, contains("['retiredByUid'] = null"));
      expect(block, contains("['retiredByName'] = null"));
      expect(block, contains("['retiredAt'] = null"));
      expect(block, contains("['retireReason'] = null"));
      expect(block, contains("['version'] = local.version - 1"));
      expect(block, contains("['updatedAt'] = createdAt"));
      expect(block, isNot(contains('TemplateVersionStatus.published.name')));
    });

    test('publish replay payload is field-scoped to draft -> published', () {
      final source = _read(_syncPath);
      final block = _blockStartingAt(
        source,
        'Map<String, dynamic> _templateVersionPublishReplayStepData',
      );

      for (final field in <String>{
        'status',
        'contentHash',
        'closureReviewConfirmed',
        'closureCriticalModuleCount',
        'closureReviewConfirmedByUid',
        'closureReviewConfirmedByName',
        'closureReviewConfirmedAt',
        'publishedByUid',
        'publishedByName',
        'publishedAt',
        'updatedAt',
        'updatedByUid',
        'updatedByName',
        'version',
      }) {
        expect(block, contains("'$field'"));
      }

      for (final forbidden in <String>{
        'jobTemplateSnapshotJson',
        'moduleSnapshotsJson',
        'fieldDefinitionsJson',
        'checklistJson',
        'targetRefs',
        'deviceTagRefs',
        'procedureRefs',
        'operationalStatePreconditions',
      }) {
        expect(
          block,
          isNot(contains("'$forbidden'")),
          reason:
              'publish replay must not mutate frozen payload field $forbidden',
        );
      }
    });

    test(
      'remote-only repository primitives are explicit and Isar rejects them',
      () {
        final provider = _read(_providerPath);
        final interfaceBlock = _blockStartingAt(
          provider,
          'abstract class TemplateGovernanceRepository',
        );
        expect(
          interfaceBlock,
          contains('createRemoteVersionDraftReplayForSync'),
        );
        expect(
          interfaceBlock,
          contains('applyRemoteVersionPublishReplayStepForSync'),
        );

        final isarStart = provider.indexOf(
          'class IsarTemplateGovernanceRepository',
        );
        final firestoreStart = provider.indexOf(
          'class FirestoreTemplateGovernanceRepository',
        );
        expect(isarStart, greaterThan(0));
        expect(firestoreStart, greaterThan(isarStart));

        final isarSection = provider.substring(isarStart, firestoreStart);
        expect(isarSection, contains('createRemoteVersionDraftReplayForSync'));
        expect(
          isarSection,
          contains('applyRemoteVersionPublishReplayStepForSync'),
        );
        expect(isarSection, contains('UnsupportedError'));
        expect(isarSection, contains('remote sync primitive'));

        final firestoreSlice = provider.substring(firestoreStart);
        expect(firestoreSlice, contains('runTransaction'));
        expect(firestoreSlice, contains('transaction.set(ref, draftData)'));
        expect(firestoreSlice, contains('existing.exists'));
        expect(
          firestoreSlice,
          contains('SetOptions(merge: true)'),
          reason: 'publish replay step should be a field-scoped merge',
        );
      },
    );

    test('rules remain strict: create draft only, publish is update only', () {
      final rules = _readFirstExisting(_rulePaths);
      final create = _blockStartingAt(
        rules,
        'function validTemplateVersionCreate',
      );
      final publish = _blockStartingAt(
        rules,
        'function validTemplateVersionPublishDelta',
      );

      expect(
        create,
        contains("request.resource.data.get('status', null) == 'draft'"),
      );
      expect(publish, contains("resource.data.get('status', null) == 'draft'"));
      expect(
        publish,
        contains("request.resource.data.get('status', null) == 'published'"),
      );

      expect(
        create,
        isNot(
          contains("request.resource.data.get('status', null) == 'published'"),
        ),
        reason: 'direct create-as-published must remain impossible',
      );
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
