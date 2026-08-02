import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('69D.2 maintenance offline lifecycle replay contract', () {
    test('sync path attempts maintenance replay before standard batch push', () {
      final source = _read(_syncPath);
      final syncBlock = _blockStartingAt(source, 'Future<void> _syncTickets()');

      _expectOrder(syncBlock, const [
        'final remote = remoteMap[record.firestoreId];',
        'final replayed = await _tryPushDecomposedMaintenanceTicket',
        'skippedButSyncedSnapshots.add(_syncPushSnapshot(record));',
        'recordsToPush.add(record);',
      ]);

      expect(syncBlock, contains('lastSuccessCount++;'));
      expect(
        syncBlock,
        isNot(contains('SyncRejection')),
        reason:
            '69D.2 is a clean-state forward fix and must not add a held-rejection repair lane.',
      );
    });

    test(
      'replay scope covers create-close and close-reopen without becoming generic',
      () {
        final source = _read(_syncPath);
        final plan = _blockStartingAt(
          source,
          'List<_MaintenanceReplayStep> _maintenanceLifecycleReplayPlan',
        );

        expect(plan, contains('remote == null'));
        expect(plan, contains('local.isResolved'));
        expect(plan, contains('_hasMaintenanceReopenEvidence(local)'));
        expect(plan, contains('remote.isResolved'));
        expect(plan, contains('local.version > remote.version + 1'));
        expect(plan, contains('_maintenancePinnedFieldDiff(local, remote)'));
        expect(plan, contains('_MaintenanceReplayStep.createOpen'));
        expect(plan, contains('_MaintenanceReplayStep.close'));
        expect(plan, contains('_MaintenanceReplayStep.reopen'));

        expect(
          source,
          contains('enum _MaintenanceReplayStep { createOpen, close, reopen }'),
          reason:
              '69D.2 should stay limited to maintenance create/close/reopen replay.',
        );
        expect(source, isNot(contains('TemplateVersion')));
        expect(source, isNot(contains('ModuleRegistry')));
        expect(source, isNot(contains('Directive')));
      },
    );

    test(
      'same-user guards protect create and close replay under request.auth',
      () {
        final source = _read(_syncPath);
        final plan = _blockStartingAt(
          source,
          'List<_MaintenanceReplayStep> _maintenanceLifecycleReplayPlan',
        );

        expect(plan, contains('FirebaseAuth.instance.currentUser?.uid'));
        expect(plan, contains('_canReplayMaintenanceCreateForCurrentUser'));
        expect(plan, contains('_canReplayMaintenanceCloseForCurrentUser'));

        final createGuard = _blockStartingAt(
          source,
          'bool _canReplayMaintenanceCreateForCurrentUser',
        );
        expect(createGuard, contains('local.loggedByUid'));
        expect(createGuard, contains('currentUid'));

        final closeGuard = _blockStartingAt(
          source,
          'bool _canReplayMaintenanceCloseForCurrentUser',
        );
        expect(closeGuard, contains('closeEvidence.closedByUid'));
        expect(closeGuard, contains('currentUid'));
      },
    );

    test(
      'create-open replay preserves ticket identity and required create shape',
      () {
        final source = _read(_syncPath);
        final payload = _blockStartingAt(
          source,
          'Map<String, dynamic> _maintenanceCreateOpenReplayStepData',
        );
        final rules = _readFirstExisting(_rulePaths);
        final createRules = _blockStartingAt(
          rules,
          'function validMaintenanceCreate',
        );

        for (final field in _quotedStrings(createRules)) {
          if (_ruleMetaStrings.contains(field)) continue;
          expect(
            payload,
            contains("'$field'"),
            reason: 'create replay should include required create field $field',
          );
        }

        expect(payload, contains("'status': TicketStatus.open.name"));
        expect(payload, contains("'isResolved': false"));
        expect(payload, contains("'isDeleted': false"));
        expect(
          payload,
          contains("'updatedAt': local.createdAt.toIso8601String()"),
        );
        expect(payload, contains("'resolutionHistoryJson': '[]'"));
      },
    );

    test(
      'close replay payload matches maintenance close rule field surface',
      () {
        final source = _read(_syncPath);
        final rules = _readFirstExisting(_rulePaths);
        final payload = _blockStartingAt(
          source,
          'Map<String, dynamic> _maintenanceCloseReplayStepData',
        );
        final rulesBlock = _blockStartingAt(
          rules,
          'function maintenanceCloseChangedFieldsOnly',
        );

        final closeReplayFields = _quotedStrings(rulesBlock).difference({
          'closedAt',
          'resolvedByUid',
          'resolvedByName',
          'resolvedAt',
          'resolutionNote',
          'resolutionNotes',
          'resolutionDetails',
        });
        for (final field in closeReplayFields) {
          expect(
            payload,
            contains("'$field'"),
            reason:
                'close replay payload should include current close field $field',
          );
        }
        expect(payload, contains("'isResolved': true"));
        expect(payload, contains("'status': TicketStatus.resolved.name"));
        expect(payload, contains("'endDate': timestamp.toIso8601String()"));
        expect(payload, contains("'closedByUid': evidence.closedByUid"));
        expect(payload, contains("'updatedByUid': evidence.closedByUid"));
        expect(payload, contains('final proposedVersion ='));
        expect(payload, contains('final remoteVersion = remote?.version'));
        expect(payload, contains("'version': version"));
        expect(payload, isNot(contains('remote!')));
      },
    );

    test(
      'reopen replay payload matches maintenance reopen rule field surface',
      () {
        final source = _read(_syncPath);
        final rules = _readFirstExisting(_rulePaths);
        final payload = _blockStartingAt(
          source,
          'Map<String, dynamic> _maintenanceReopenReplayStepData',
        );
        final rulesBlock = _blockStartingAt(
          rules,
          'function maintenanceReopenChangedFieldsOnly',
        );

        final ruleKeys = _quotedStrings(rulesBlock).difference({
          'reopenedByUid',
          'reopenedByName',
          'reopenedAt',
          'reopenReason',
        });
        for (final field in ruleKeys) {
          expect(
            payload,
            contains("'$field'"),
            reason:
                'reopen replay payload should include allowed reopen field $field',
          );
        }
        expect(payload, contains("'isResolved': false"));
        expect(payload, contains("'status': TicketStatus.open.name"));
        expect(
          payload,
          contains("'resolutionHistoryJson': local.resolutionHistoryJson"),
        );
        expect(payload, contains("'version': local.version"));
      },
    );

    test(
      'rules accept mobile close/reopen field surfaces without allowing identity edits',
      () {
        final rules = _readFirstExisting(_rulePaths);
        final closeRules = _blockStartingAt(
          rules,
          'function maintenanceCloseChangedFieldsOnly',
        );
        final reopenRules = _blockStartingAt(
          rules,
          'function maintenanceReopenChangedFieldsOnly',
        );

        for (final field in <String>[
          'endDate',
          'remarks',
          'downtimeHours',
          'teamsInvolved',
          'actionsJson',
        ]) {
          expect(closeRules, contains("'$field'"));
        }

        for (final field in <String>[
          'endDate',
          'closedByUid',
          'closedByName',
          'downtimeHours',
          'teamsInvolved',
          'actionsJson',
          'remarks',
          'resolutionHistoryJson',
        ]) {
          expect(reopenRules, contains("'$field'"));
        }

        for (final protected in <String>[
          'assetType',
          'assetNumber',
          'description',
          'loggedByUid',
          'createdAt',
        ]) {
          expect(closeRules, isNot(contains("'$protected'")));
          expect(reopenRules, isNot(contains("'$protected'")));
        }

        final close = _blockStartingAt(rules, 'function validMaintenanceClose');
        expect(
          close,
          contains("request.resource.data.get('status', null) == 'resolved'"),
        );
        expect(
          close,
          contains(
            "request.resource.data.get('closedByUid', null) == request.auth.uid",
          ),
        );
        expect(
          close,
          contains("request.resource.data.get('endDate', '') is string"),
        );
        expect(
          close,
          contains("request.resource.data.get('teamsInvolved', []) is list"),
        );
        expect(
          close,
          contains("request.resource.data.get('actionsJson', '[]') is string"),
        );

        final reopen = _blockStartingAt(
          rules,
          'function validMaintenanceReopen',
        );
        expect(
          reopen,
          contains("request.resource.data.get('status', null) == 'open'"),
        );
        expect(
          reopen,
          contains('maintenanceMobileCloseFieldsClearedOnReopen()'),
        );
        expect(
          reopen,
          contains('maintenanceLegacyResolutionFieldsFrozenOnReopen(affected)'),
        );
        expect(
          reopen,
          contains('maintenanceReopenChangedFieldsOnly(affected)'),
        );

        final mobileUsage = _blockStartingAt(
          rules,
          'function maintenanceUsesMobileCloseFields',
        );
        expect(mobileUsage, contains("'endDate'"));
        expect(mobileUsage, contains("'resolutionHistoryJson'"));

        final mobileClear = _blockStartingAt(
          rules,
          'function maintenanceMobileCloseFieldsClearedOnReopen',
        );
        expect(mobileClear, contains('maintenanceUsesMobileCloseFields()'));
        expect(
          mobileClear,
          contains("request.resource.data.get('endDate', null) == null"),
        );
        expect(
          mobileClear,
          contains("request.resource.data.get('closedByUid', null) == null"),
        );
        expect(
          mobileClear,
          contains("request.resource.data.get('closedByName', null) == null"),
        );
        expect(
          mobileClear,
          contains("request.resource.data.get('downtimeHours', null) == null"),
        );
        expect(
          mobileClear,
          contains("request.resource.data.get('teamsInvolved', []) is list"),
        );
        expect(
          mobileClear,
          contains(
            "request.resource.data.get('teamsInvolved', []).size() == 0",
          ),
        );
        expect(
          mobileClear,
          contains("request.resource.data.get('actionsJson', '[]') == '[]'"),
        );
        expect(
          mobileClear,
          contains(
            "request.resource.data.get('resolutionHistoryJson', '[]') is string",
          ),
        );

        final legacyFrozen = _blockStartingAt(
          rules,
          'function maintenanceLegacyResolutionFieldsFrozenOnReopen',
        );
        expect(legacyFrozen, contains('!maintenanceUsesMobileCloseFields()'));
        expect(legacyFrozen, contains('affected.hasAny'));
        expect(legacyFrozen, isNot(contains('affectedKeys().hasAny')));
        expect(legacyFrozen, contains("'teamsInvolved'"));
        expect(legacyFrozen, contains("'actionsJson'"));
        expect(legacyFrozen, contains("'resolutionHistoryJson'"));

        final closeUpdate = _blockStartingAt(
          rules,
          'function validMaintenanceCloseUpdate',
        );
        final reopenUpdate = _blockStartingAt(
          rules,
          'function validMaintenanceReopenUpdate',
        );
        final softDeleteUpdate = _blockStartingAt(
          rules,
          'function validMaintenanceSoftDeleteUpdate',
        );
        final adminEditUpdate = _blockStartingAt(
          rules,
          'function validMaintenanceAdminEditUpdate',
        );
        for (final branch in <String>[
          closeUpdate,
          reopenUpdate,
          softDeleteUpdate,
          adminEditUpdate,
        ]) {
          expect(
            branch,
            contains(
              'let affected = request.resource.data.diff(resource.data).affectedKeys()',
            ),
          );
        }
        expect(
          closeUpdate,
          contains('maintenanceCloseChangedFieldsOnly(affected)'),
        );
        expect(closeUpdate, contains('maintenanceIsCloseTransition()'));
        expect(
          reopenUpdate,
          contains('maintenanceReopenChangedFieldsOnly(affected)'),
        );
        expect(reopenUpdate, contains('maintenanceIsReopenTransition()'));
        expect(
          softDeleteUpdate,
          contains('maintenanceSoftDeleteChangedFieldsOnly(affected)'),
        );
        expect(
          adminEditUpdate,
          contains('maintenanceAdminEditShape(affected)'),
        );
        final maintenanceMatch = _blockStartingAt(
          rules,
          'match /maintenance_records/{docId}',
        );
        expect(
          RegExp(r'allow\s+update\s*:')
              .allMatches(maintenanceMatch)
              .length,
          1,
          reason:
              'Maintenance writes must evaluate exactly one routed update rule so denied branches do not consume the Firestore expression budget.',
        );
        expect(
          maintenanceMatch,
          contains('allow update: if globalPullStampValidOnUpdate()'),
        );
        expect(maintenanceMatch, contains('&& validMaintenanceUpdate();'));

        final maintenanceRouter = _blockStartingAt(
          rules,
          'function validMaintenanceUpdate',
        );
        expect(
          maintenanceRouter,
          contains('targetDeleted != sourceDeleted'),
        );
        expect(
          maintenanceRouter,
          contains('targetResolved != sourceResolved'),
        );
        for (final validator in <String>[
          'validMaintenanceSoftDeleteUpdate()',
          'validMaintenanceCloseUpdate()',
          'validMaintenanceReopenUpdate()',
          'validMaintenanceAdminEditUpdate()',
        ]) {
          expect(maintenanceRouter, contains(validator));
        }
        expect(
          maintenanceRouter,
          isNot(contains('||')),
          reason:
              'The router must select one lifecycle validator instead of evaluating parallel alternatives.',
        );

        final adminShape = _blockStartingAt(
          rules,
          'function maintenanceAdminEditShape',
        );
        expect(adminShape, contains('!maintenanceIsCloseTransition()'));
        expect(adminShape, contains('!maintenanceIsReopenTransition()'));
        expect(adminShape, contains('deletedByUid'));
      },
    );

    test(
      'Firestore Jest tests cover maintenance close/reopen negative invariants',
      () {
        final jest = _read('test/firestore.rules.test.js');
        expect(
          jest,
          contains(
            'maintenance close requires resolved status and matching closer identity',
          ),
        );
        expect(
          jest,
          contains(
            'maintenance reopen requires open status and clears active close fields',
          ),
        );
        expect(
          jest,
          contains(
            'maintenance mobile reopen clears active work payload fields',
          ),
        );
        expect(
          jest,
          contains(
            'legacy reopen cannot introduce mobile resolution payload fields',
          ),
        );
        expect(jest, contains('assertFails'));
      },
    );

    test(
      'pinned structural fields must match before maintenance replay can mark synced',
      () {
        final source = _read(_syncPath);
        final diff = _blockStartingAt(
          source,
          'String _maintenancePinnedFieldDiff',
        );

        for (final field in <String>[
          'assetType',
          'assetNumber',
          'maintenanceType',
          'description',
          'routedTo',
          'isCritical',
          'loggedByUid',
          'createdAt',
          'startDate',
          'component',
          'subsystem',
          'tag',
          'hierarchyPath',
          'classification',
          'otherDepartment',
          'reportedBy',
          'acknowledgedByUid',
          'acknowledgedByName',
          'acknowledgedAt',
          'chargeNoAtEvent',
          'metadataJson',
          'performedBy',
        ]) {
          expect(diff, contains("'$field'"), reason: 'Pinned field $field');
        }

        for (final mutableLifecycleField in <String>[
          'isResolved',
          'status',
          'closedByUid',
          'closedByName',
          'remarks',
          'endDate',
          'downtimeHours',
          'teamsInvolved',
          'actionsJson',
          'resolutionHistoryJson',
        ]) {
          expect(
            diff,
            isNot(contains("'$mutableLifecycleField'")),
            reason:
                '$mutableLifecycleField is lifecycle/payload state, not pinned structure.',
          );
        }
      },
    );

    test('remote-only repository primitive is explicit and merge-scoped', () {
      final provider = _read(_providerPath);

      expect(
        provider,
        contains(
          'Future<void> applyRemoteMaintenanceLifecycleReplayStepForSync(',
        ),
      );
      expect(provider, contains('remote sync'));
      expect(provider, contains('primitive'));
      expect(provider, contains('local Isar maintenance repository'));
      expect(
        provider,
        contains('_collection.doc(id).set(stepData, SetOptions(merge: true));'),
      );
    });

    test(
      'does not touch closure, pull, job-module, or governance contracts',
      () {
        final source = _read(_syncPath);
        final provider = _read(_providerPath);
        final rules = _readFirstExisting(_rulePaths);

        expect(source, isNot(contains('completePlannedJobExecution')));
        expect(source, isNot(contains('pullAndReconcile')));
        expect(source, isNot(contains('_tryPushDecomposedJobModule')));
        expect(provider, isNot(contains('FirebaseFunctions')));
        expect(rules, isNot(contains('validMaintenanceCloseReopenCombined')));
        expect(rules, isNot(contains('validMaintenanceCreateClosed')));
      },
    );
  });
}

const _syncPath = 'lib/core/services/sync_service.tickets_templates.dart';
const _providerPath =
    'lib/features/maintenance/providers/maintenance_provider.dart';
const _rulePaths = <String>[
  'firestore.rules',
  'Other root files/firestore.rules',
];

const _ruleMetaStrings = <String>{'maintenanceType', 'string', 'int', 'bool'};

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

String _blockStartingAt(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, isNot(-1), reason: 'Missing marker: $marker');

  final openBrace = source.indexOf('{', markerIndex + marker.length);
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

  fail('Could not find complete block for $marker');
}
