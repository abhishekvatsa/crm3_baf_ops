import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('69D.1 job-module offline lifecycle replay contract', () {
    test('sync path attempts lifecycle replay before standard batch push', () {
      final source = _read(_syncPath);
      final syncBlock = _blockStartingAt(
        source,
        'Future<void> _syncJobModules()',
      );

      _expectOrder(syncBlock, const [
        'final remote = remoteMap[record.firestoreId];',
        'final replayed = await _tryPushDecomposedJobModule(record, remote);',
        'skippedButSyncedSnapshots.add(_syncPushSnapshot(record));',
        'recordsToPush.add(record);',
      ]);

      expect(
        syncBlock,
        contains('lastSuccessCount++;'),
        reason: 'successful two-step replay should count as a pushed module',
      );
      expect(
        syncBlock,
        isNot(contains('SyncRejection')),
        reason:
            '69D.1 is a clean-state forward fix and must not grow a held-rejection repair lane.',
      );
      expect(
        syncBlock,
        contains('may now be at `submitted`'),
        reason:
            'partial replay fallthrough should remain intentionally documented',
      );
    });

    test('replay plan is narrowly scoped to open remote -> accepted local', () {
      final source = _read(_syncPath);
      final block = _blockStartingAt(source, '_jobModuleLifecycleReplayPlan');
      final openStatusBlock = _blockStartingAt(
        source,
        'bool _isOpenJobModuleStatus',
      );

      expect(block, contains('_isOpenJobModuleStatus(remote.status)'));
      for (final status in [
        'JobModuleStatus.notStarted',
        'JobModuleStatus.draftSaved',
        'JobModuleStatus.inProgress',
        'JobModuleStatus.reopened',
      ]) {
        expect(openStatusBlock, contains(status));
      }

      expect(block, contains('local.status != JobModuleStatus.accepted'));
      expect(block, contains('local.version <= remote.version + 1'));
      expect(block, contains('_jobModulePinnedFieldDiff(local, remote)'));
      expect(block, contains('_JobModuleReplayStep.submit'));
      expect(block, contains('_JobModuleReplayStep.accept'));
      expect(
        source,
        contains('enum _JobModuleReplayStep { submit, accept }'),
        reason:
            '69D.1 must not expand into reopen/notApplicable/generic lifecycle handling.',
      );
    });

    test('same-user replay guard is explicit and metadata complete', () {
      final source = _read(_syncPath);
      final block = _blockStartingAt(source, '_jobModuleLifecycleReplayPlan');

      expect(block, contains('FirebaseAuth.instance.currentUser?.uid'));
      expect(block, contains('local.submittedByUid'));
      expect(block, contains('local.acceptedByUid'));
      expect(block, contains('submittedByUid != currentUid'));
      expect(block, contains('acceptedByUid != currentUid'));
      expect(block, contains('local.submittedAt == null'));
      expect(block, contains('local.acceptedAt == null'));
      expect(
        block,
        contains('_cleanText'),
        reason:
            'auth and actor ids should be compared after trim/empty normalization',
      );
    });

    test('submit replay payload mirrors Firestore submit whitelist exactly', () {
      final source = _read(_syncPath);
      final rules = _readFirstExisting(_rulePaths);
      final payloadBlock = _blockStartingAt(
        source,
        'Map<String, dynamic> _jobModuleSubmitReplayStepData',
      );
      final rulesBlock = _blockStartingAt(
        rules,
        'function jobModuleSubmitChangedFieldsOnly',
      );

      expect(_quotedStrings(payloadBlock), _quotedStrings(rulesBlock));
      expect(
        payloadBlock,
        contains("'status': JobModuleStatus.submitted.name"),
      );
      expect(
        payloadBlock,
        contains("'isOpenForWork': false"),
        reason:
            'field-scoped submit replay must clear a previously persisted open flag',
      );
      expect(
        payloadBlock,
        contains("'updatedAt': full['submittedAt'] ?? full['updatedAt']"),
        reason:
            'submit replay must use submit-time chronology, not accept-time updatedAt',
      );
      expect(payloadBlock, contains("'updatedByUid': full['submittedByUid']"));
      expect(
        payloadBlock,
        contains("'updatedByName': full['submittedByName']"),
      );
      expect(payloadBlock, contains("'version': version"));

      for (final forbidden in <String>[
        'acceptedByUid',
        'acceptedAt',
        'acceptedByName',
        'acceptanceNote',
        'reopenedByUid',
        'notApplicableByUid',
        'isDeleted',
      ]) {
        expect(payloadBlock, isNot(contains("'$forbidden'")));
      }
    });

    test(
      'accept replay payload mirrors Firestore accept whitelist exactly',
      () {
        final source = _read(_syncPath);
        final rules = _readFirstExisting(_rulePaths);
        final payloadBlock = _blockStartingAt(
          source,
          'Map<String, dynamic> _jobModuleAcceptReplayStepData',
        );
        final rulesBlock = _blockStartingAt(
          rules,
          'function jobModuleAcceptChangedFieldsOnly',
        );

        expect(_quotedStrings(payloadBlock), _quotedStrings(rulesBlock));
        expect(
          payloadBlock,
          contains("'status': JobModuleStatus.accepted.name"),
        );
        expect(
          payloadBlock,
          contains("'isOpenForWork': false"),
          reason:
              'field-scoped accept replay must preserve the closed lifecycle invariant',
        );
        expect(
          payloadBlock,
          contains("'updatedAt': full['acceptedAt'] ?? full['updatedAt']"),
          reason: 'accept replay must use accept-time chronology',
        );
        expect(payloadBlock, contains("'updatedByUid': full['acceptedByUid']"));
        expect(
          payloadBlock,
          contains("'updatedByName': full['acceptedByName']"),
        );
        expect(payloadBlock, contains("'version': full['version']"));

        for (final forbidden in <String>[
          'responsesJson',
          'actionsJson',
          'submittedByUid',
          'submittedAt',
          'submissionNote',
          'reopenedByUid',
          'notApplicableByUid',
          'isDeleted',
        ]) {
          expect(payloadBlock, isNot(contains("'$forbidden'")));
        }
      },
    );

    test(
      'two-step replay uses remote+1 submit then final local accept version',
      () {
        final source = _read(_syncPath);
        final block = _blockStartingAt(
          source,
          'Future<bool> _tryPushDecomposedJobModule',
        );

        _expectOrder(block, const [
          'var stepVersion = remote.version;',
          'stepVersion += 1;',
          '_jobModuleSubmitReplayStepData(local, stepVersion)',
          '_jobModuleAcceptReplayStepData(local)',
          "stepVersion = stepData['version'] as int;",
        ]);

        expect(
          block,
          contains('_firestoreJobModule.applyRemoteLifecycleReplayStepForSync'),
          reason: 'replay must use the remote-only field-scoped primitive',
        );
      },
    );

    test('pinned structural-field guard is complete before replay can mark synced', () {
      final source = _read(_syncPath);
      final pinnedBlock = _blockStartingAt(
        source,
        'String _jobModulePinnedFieldDiff',
      );
      final planBlock = _blockStartingAt(
        source,
        '_jobModuleLifecycleReplayPlan',
      );

      expect(
        planBlock,
        contains(
          "if (_jobModulePinnedFieldDiff(local, remote) != 'none') return const [];",
        ),
        reason:
            'replay must refuse to mark a local accepted module synced when structural fields differ remotely',
      );

      for (final field in <String>[
        'createdByUid',
        'createdAt',
        'moduleSnapshotJson',
        'fieldDefinitionsJson',
        'assetType',
        'assetNumber',
        'discipline',
      ]) {
        expect(
          pinnedBlock,
          contains(field),
          reason:
              'pinned structural field "$field" must be part of the replay safety comparison',
        );
      }

      for (final mutableLifecycleField in <String>[
        'responsesJson',
        'actionsJson',
        'submittedByUid',
        'acceptedByUid',
        'status',
        'version',
      ]) {
        expect(
          pinnedBlock,
          isNot(contains(mutableLifecycleField)),
          reason:
              'pinned comparison should stay limited to structural identity fields, not mutable lifecycle/payload fields',
        );
      }
    });

    test('direct Firestore lifecycle transitions persist the open-state invariant', () {
      final provider = _read(_providerPath);
      final remoteRepository = provider.substring(
        provider.indexOf('class FirestoreJobModuleRepository'),
      );

      final expectedTransitions = <(String, String, String)>[
        (
          'Future<void> submitModule(',
          "'status': JobModuleStatus.submitted.name",
          "'isOpenForWork': false",
        ),
        (
          'Future<void> reopenModule(',
          "'status': JobModuleStatus.reopened.name",
          "'isOpenForWork': true",
        ),
        (
          'Future<void> markModuleNotApplicable(',
          "'status': JobModuleStatus.notApplicable.name",
          "'isOpenForWork': false",
        ),
        (
          'Future<void> acceptModule(',
          "'status': JobModuleStatus.accepted.name",
          "'isOpenForWork': false",
        ),
      ];

      for (final (method, status, openState) in expectedTransitions) {
        final block = _methodBlockStartingAt(remoteRepository, method);
        expect(block, contains(status), reason: 'Missing lifecycle status in $method');
        expect(
          block,
          contains(openState),
          reason:
              '$method must persist the derived open-state field used by Rules and canonical closure',
        );
      }
    });

    test('remote-only repository primitive is explicit and merge-scoped', () {
      final provider = _read(_providerPath);

      expect(
        provider,
        contains('Future<void> applyRemoteLifecycleReplayStepForSync('),
      );
      expect(provider, isNot(contains('Future<void> applyLifecycleStep(')));
      expect(provider, isNot(contains('applyLifecycleReplayStep(')));
      expect(provider, contains('UnsupportedError('));
      expect(provider, contains('remote sync primitive'));
      expect(provider, contains('is not '));
      expect(
        provider,
        contains('supported by the local Isar job-module repository'),
      );
      expect(
        provider,
        contains('_modules.doc(id).set(stepData, SetOptions(merge: true));'),
        reason: 'remote primitive must remain a field-scoped merge write',
      );
    });

    test('does not weaken rules, closure, pull, or coordinator contracts', () {
      final source = _read(_syncPath);
      final provider = _read(_providerPath);
      final rules = _readFirstExisting(_rulePaths);

      expect(rules, isNot(contains('validJobModuleSubmitAccept')));
      expect(rules, isNot(contains('submitAccept')));
      expect(source, isNot(contains('completePlannedJobExecution')));
      expect(source, isNot(contains('pullAndReconcile')));
      expect(provider, isNot(contains('FirebaseFunctions')));
    });

    test(
      'scope stays job-module only and avoids broader lifecycle framework',
      () {
        final source = _read(_syncPath);

        expect(source, isNot(contains('Maintenance')));
        expect(source, isNot(contains('TemplateVersion')));
        expect(source, isNot(contains('ModuleRegistry')));
        expect(source, isNot(contains('Directive')));
        expect(source, isNot(contains('maintenance_records')));
        expect(source, isNot(contains('template_versions')));
        expect(source, isNot(contains('module_registry_revisions')));
      },
    );
  });
}

const _syncPath = 'lib/core/services/sync_service.job_modules.dart';
const _providerPath =
    'lib/features/planned_maintenance/providers/job_module_provider.dart';
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

Set<String> _quotedStrings(String source) {
  return RegExp(r"'([^']+)'")
      .allMatches(source)
      .map((match) => match.group(1)!)
      .where((value) => !value.contains('['))
      .toSet();
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

String _methodBlockStartingAt(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, isNot(-1), reason: 'Missing marker: $marker');

  final openParen = source.indexOf('(', markerIndex);
  expect(openParen, isNot(-1), reason: 'Missing parameter list after $marker');

  var parenDepth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaped = false;
  var closeParen = -1;

  for (var i = openParen; i < source.length; i++) {
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

    if (char == '(') parenDepth++;
    if (char == ')') {
      parenDepth--;
      if (parenDepth == 0) {
        closeParen = i;
        break;
      }
    }
  }

  expect(closeParen, isNot(-1), reason: 'Missing closing parenthesis for $marker');
  final openBrace = source.indexOf('{', closeParen + 1);
  expect(openBrace, isNot(-1), reason: 'Missing method body after $marker');

  var braceDepth = 0;
  inSingleQuote = false;
  inDoubleQuote = false;
  escaped = false;

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

    if (char == '{') braceDepth++;
    if (char == '}') {
      braceDepth--;
      if (braceDepth == 0) return source.substring(markerIndex, i + 1);
    }
  }

  fail('Could not find method body closing brace for $marker');
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
