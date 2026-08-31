import 'dart:io';

import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('69D.2 maintenance offline lifecycle replay contract', () {
    test('sync path attempts maintenance replay before standard batch push', () {
      final source = _read(_syncPath);
      final syncBlock = _blockStartingAt(source, 'Future<void> _syncTickets()');

      _expectOrder(syncBlock, const [
        'final remote = remoteMap[record.firestoreId];',
        'if (remote == null)',
        'await _pushMissingMaintenanceTicket(record);',
        'continue;',
        'final expectedLocal = _syncPushSnapshot(record);',
        'await _tryRecoverAcceptedMaintenanceCreation(',
        '.applyGovernedCreationServerStateForSync(',
        'continue;',
        'final replayReceipt = await _tryPushDecomposedMaintenanceTicket',
        '.applyMaintenanceLifecycleReplayReceiptForSync(',
        'remote: replayReceipt.serverRecord,',
        'expectedLocal: expectedLocal,',
        'if (_isRemoteNewer(record, remote))',
        'recordsToPush.add(record);',
      ]);

      final replaySuccess = _blockStartingAt(
        syncBlock,
        'if (replayReceipt != null)',
      );
      expect(
        replaySuccess,
        isNot(contains('skippedButSyncedSnapshots.add')),
        reason:
            'A rebased replay must adopt its exact server receipt instead of '
            'marking the stale local snapshot clean.',
      );

      expect(syncBlock, contains('lastSuccessCount++;'));
      expect(
        syncBlock,
        isNot(contains('SyncRejection')),
        reason:
            '69D.2 is a clean-state forward fix and must not add a held-rejection repair lane.',
      );
    });

    test(
      'stale local closure rebases over server acknowledgement without hiding business edits',
      () {
        final remote =
            _maintenanceTicket(version: 6)
              ..status = TicketStatus.acknowledged
              ..acknowledgedByUid = 'maintenance-supervisor'
              ..acknowledgedByName = 'Maintenance Supervisor'
              ..acknowledgedAt = DateTime.utc(2026, 8, 22, 8, 5)
              ..workflowQueueState = 'released'
              ..workflowReleasedAt = DateTime.utc(2026, 8, 22, 8, 6)
              ..workflowReleasedByUid = 'operations-supervisor'
              ..workflowReleasedByName = 'Operations Supervisor'
              ..workflowUpdatedAt = DateTime.utc(2026, 8, 22, 8, 6)
              ..updatedAt = DateTime.utc(2026, 8, 22, 8, 6);
        final local =
            _maintenanceTicket(version: 6)
              ..isResolved = true
              ..status = TicketStatus.resolved
              ..closedByUid = 'maintenance-supervisor'
              ..closedByName = 'Maintenance Supervisor'
              ..endDate = DateTime.utc(2026, 8, 22, 8, 10)
              ..updatedAt = DateTime.utc(2026, 8, 22, 8, 10);

        expect(
          maintenanceResolvedReplayCanRebase(
            local: local,
            remote: remote,
            currentUid: 'maintenance-supervisor',
          ),
          isTrue,
          reason:
              'Server-owned acknowledgement and workflow projection advances '
              'must not strand a valid field-scoped closure.',
        );
        expect(
          maintenanceCloseReplayVersion(
            localIsResolved: true,
            localVersion: local.version,
            priorVersion: remote.version,
            remoteVersion: remote.version,
          ),
          7,
        );

        remote.description = 'A different remote business description';
        expect(
          maintenanceResolvedReplayCanRebase(
            local: local,
            remote: remote,
            currentUid: 'maintenance-supervisor',
          ),
          isFalse,
          reason: 'A genuine concurrent business edit must remain a conflict.',
        );

        remote
          ..description = local.description
          ..resolutionHistoryJson =
              '[{"resolvedByUid":"other-user","resolvedAt":"2026-08-22T08:07:00.000Z"}]';
        expect(
          maintenanceResolvedReplayCanRebase(
            local: local,
            remote: remote,
            currentUid: 'maintenance-supervisor',
          ),
          isFalse,
          reason:
              'A newer remote close-and-reopen cycle must not be reversed by '
              'an older local closure.',
        );
      },
    );

    test('stale closure cannot rebase while workflow is deferred', () {
      final remote =
          _maintenanceTicket(version: 9)
            ..workflowDeferred = true
            ..workflowQueueState = 'deferred';
      final local =
          _maintenanceTicket(version: 6)
            ..isResolved = true
            ..status = TicketStatus.resolved
            ..closedByUid = 'maintenance-supervisor';

      expect(
        maintenanceResolvedReplayCanRebase(
          local: local,
          remote: remote,
          currentUid: 'maintenance-supervisor',
        ),
        isFalse,
      );
      expect(
        maintenanceCloseReplayVersion(
          localIsResolved: true,
          localVersion: local.version,
          priorVersion: remote.version,
          remoteVersion: remote.version,
        ),
        10,
        reason:
            'The version helper follows the remote head, although policy blocks '
            'the deferred closure before any write.',
      );
    });

    test('administrative closure cannot enter technical-resolution replay', () {
      final remote = _maintenanceTicket(version: 6);
      final local =
          _maintenanceTicket(version: 7)
            ..isResolved = true
            ..status = TicketStatus.closedWithoutResolution
            ..closedByUid = 'admin-1'
            ..closedByName = 'Admin One';

      expect(
        maintenanceResolvedReplayCanRebase(
          local: local,
          remote: remote,
          currentUid: 'admin-1',
        ),
        isFalse,
        reason:
            'A terminal administrative decision must never be rewritten as a '
            'technical resolution by the offline replay path.',
      );
    });

    test(
      'resolve UI accepts only governed server closure before local convergence',
      () {
        final source = _read(
          'lib/features/maintenance/presentation/resolve_form.dart',
        );
        final submit = _blockStartingAt(source, 'Future<void> _submit()');

        _expectOrder(submit, const <String>[
          'buildMaintenanceIssueResolutionCommand(',
          '.execute(command);',
          'validateMaintenanceIssueResolutionReceipt(',
          '.adoptServerMutation(',
          'await syncCoordinator.runFullSync(',
        ]);
        expect(
          submit,
          contains('Issue resolved and verified against the plant system'),
        );
        expect(
          submit,
          contains(
            'Issue resolution accepted. Exact device refresh is pending',
          ),
        );
        expect(submit, isNot(contains('repository.resolveTicket(')));
        expect(submit, isNot(contains('runFullSyncWithResult(')));
        expect(
          submit,
          isNot(contains("unawaited(\n        syncCoordinator.runFullSync")),
        );
      },
    );

    test(
      'create UI requires approved identity and distinguishes local save from cloud acceptance',
      () {
        final source = _read(
          'lib/features/maintenance/presentation/maintenance_form.dart',
        );
        final submit = _blockStartingAt(source, 'Future<void> _submit()');

        _expectOrder(submit, const <String>[
          'final appUser = ref.read(currentAppUserProvider).value;',
          '!appUser.isApproved',
          'final createCommand = buildMaintenanceIssueCreateCommand(',
          'await repository.saveTicket(record);',
          'await syncCoordinator.runFullSyncWithResult(',
        ]);
        expect(submit, contains('firebaseUser.uid != appUser.uid'));
        expect(submit, contains('SyncRequestOutcome.succeeded'));
        expect(submit, contains('SyncRequestOutcome.failed'));
        expect(
          submit,
          contains(
            'final synchronizedTicket = await repository.getByFirestoreId(',
          ),
        );
        expect(
          submit,
          contains(
            'final issueAccepted = synchronizedTicket?.isSynced == true;',
          ),
        );
        expect(submit, contains('synchronization is queued'));
        expect(
          submit,
          contains(
            'Issue accepted by the plant system. Another saved item still needs sync attention.',
          ),
        );
        expect(
          submit,
          contains('Do not raise it again; retry the SYNC PENDING issue.'),
        );
        expect(submit, isNot(contains('Issue raised successfully')));
        expect(
          submit,
          isNot(contains('appUser?.uid ?? firebaseUser?.uid')),
          reason:
              'a Firebase-only session must not create locally optimistic maintenance authority',
        );
      },
    );

    test('governed create and lifecycle replay stay deliberately separate', () {
      final source = _read(_syncPath);
      final create = _blockStartingAt(
        source,
        'Future<_MaintenanceCreationReplayResult> _pushMissingMaintenanceTicket',
      );
      final plan = _blockStartingAt(
        source,
        'List<_MaintenanceReplayStep> _maintenanceLifecycleReplayPlan',
      );

      expect(create, contains('buildMaintenanceIssueCreateCommand'));
      expect(create, contains('_maintenanceCommands.execute(command)'));
      expect(create, contains('_maintenanceCloseReplayStepData'));
      expect(create, contains('_maintenanceReopenReplayStepData'));
      expect(
        create,
        contains('readMaintenanceIssueCommandServerState'),
        reason: 'Creation must adopt an exact server record before sync.',
      );
      expect(plan, contains('local.wasTechnicallyResolved'));
      expect(plan, contains('_hasMaintenanceReopenEvidence(local)'));
      expect(plan, contains('remote.wasTechnicallyResolved'));
      expect(plan, contains('remote.isClosed'));
      expect(plan, contains('local.version > remote.version + 1'));
      expect(plan, contains('_maintenancePinnedFieldDiff(local, remote)'));
      expect(plan, contains('_MaintenanceReplayStep.close'));
      expect(plan, contains('_MaintenanceReplayStep.reopen'));

      expect(
        source,
        contains('enum _MaintenanceReplayStep { close, reopen }'),
        reason: 'Post-create replay should stay limited to close/reopen.',
      );
      expect(source, isNot(contains('TemplateVersion')));
      expect(source, isNot(contains('ModuleRegistry')));
      expect(source, isNot(contains('Directive')));
    });

    test('an interrupted creation is replayed before generic update logic', () {
      final source = _read(_syncPath);
      final syncBlock = _blockStartingAt(source, 'Future<void> _syncTickets()');
      final recovery = _blockStartingAt(
        source,
        'Future<MaintenanceRecord?> _tryRecoverAcceptedMaintenanceCreation',
      );

      _expectOrder(syncBlock, const <String>[
        'final recoveredCreation =',
        'await _tryRecoverAcceptedMaintenanceCreation(',
        '.applyGovernedCreationServerStateForSync(',
        'if (_isRemoteNewer(record, remote))',
        'recordsToPush.add(record);',
      ]);
      expect(recovery, contains('_maintenanceCommands.execute(command)'));
      expect(recovery, contains('validateMaintenanceIssueCreateReceipt('));
      expect(recovery, contains('readMaintenanceIssueCommandServerState'));
      expect(recovery, contains('_maintenanceLifecycleReplayPlan('));
      expect(recovery, contains('_validateGovernedCreationServerRecord('));
    });

    test(
      'same-user guards protect create, close and reopen replay under request.auth',
      () {
        final source = _read(_syncPath);
        final create = _blockStartingAt(
          source,
          'Future<_MaintenanceCreationReplayResult> _pushMissingMaintenanceTicket',
        );
        final plan = _blockStartingAt(
          source,
          'List<_MaintenanceReplayStep> _maintenanceLifecycleReplayPlan',
        );

        expect(create, contains('FirebaseAuth.instance.currentUser?.uid'));
        expect(create, contains('_canReplayMaintenanceCreateForCurrentUser'));
        expect(create, contains('maintenanceReopenReplayHasCurrentActor'));
        expect(plan, contains('_canReplayMaintenanceCloseForCurrentUser'));
        expect(plan, contains('maintenanceReopenReplayHasCurrentActor'));

        _expectOrder(create, const <String>[
          'final hasReopenEvidence = _hasMaintenanceReopenEvidence(local);',
          'maintenanceReopenReplayHasCurrentActor(',
          'final createVersion = maintenanceCreateReplayVersion(local);',
          'buildMaintenanceIssueCreateCommand(',
        ]);

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

        expect(
          source,
          contains('final reopenedByUid = local.reopenedByUid?.trim();'),
        );
        expect(source, contains('reopenedByUid == actorUid'));
        expect(source, contains('maintenanceHasLegacyPendingReopenEvidence'));
        expect(source, contains('Legacy reopen synchronized by '));
      },
    );

    test('reopen replay is available only to the recorded reopener', () {
      final local = _maintenanceTicket(version: 8)
        ..reopenedByUid = 'operations-1';

      expect(
        maintenanceReopenReplayHasCurrentActor(
          local: local,
          currentUid: 'operations-1',
        ),
        isTrue,
      );
      expect(
        maintenanceReopenReplayHasCurrentActor(
          local: local,
          currentUid: 'operations-2',
        ),
        isFalse,
      );
      expect(
        maintenanceReopenReplayHasCurrentActor(local: local, currentUid: '   '),
        isFalse,
      );
    });

    test('pending v6 reopen is retained through explicit legacy attribution', () {
      final reopenedAt = DateTime.utc(2026, 8, 23, 18, 45);
      final local =
          _maintenanceTicket(version: 8)
            ..isSynced = false
            ..updatedAt = reopenedAt
            ..remarks = 'Returned for burner correction'
            ..resolutionHistory = <ResolutionHistory>[
              ResolutionHistory(
                resolvedByUid: 'supervisor-1',
                resolvedByName: 'Shift Supervisor',
                resolvedAt: DateTime.utc(2026, 8, 23, 18),
              ),
            ];

      expect(maintenanceHasLegacyPendingReopenEvidence(local), isTrue);
      expect(
        maintenanceReopenReplayHasCurrentActor(
          local: local,
          currentUid: 'si-1',
        ),
        isTrue,
        reason:
            'v6 did not persist the reopener, so its authenticated synchronizer '
            'must remain the explicit replay authority.',
      );

      final evidence = maintenanceReopenReplayEvidenceForActor(
        local: local,
        currentUid: 'si-1',
        currentActorName: 'Senior Instrumentation',
      );
      expect(evidence.reopenedByUid, 'si-1');
      expect(
        evidence.reopenedByName,
        'Legacy reopen synchronized by Senior Instrumentation',
      );
      expect(evidence.reopenedAt, reopenedAt);
      expect(evidence.reopenReason, 'Returned for burner correction');
      expect(evidence.isLegacyAttribution, isTrue);

      local.isSynced = true;
      expect(maintenanceHasLegacyPendingReopenEvidence(local), isFalse);
    });

    test('partial v7 reopen evidence is never treated as legacy', () {
      final local =
          _maintenanceTicket(version: 8)
            ..isSynced = false
            ..reopenedByUid = 'operations-1'
            ..resolutionHistory = <ResolutionHistory>[
              ResolutionHistory(
                resolvedByUid: 'supervisor-1',
                resolvedAt: DateTime.utc(2026, 8, 23, 18),
              ),
            ];

      expect(maintenanceHasLegacyPendingReopenEvidence(local), isFalse);
      expect(
        () => maintenanceReopenReplayEvidenceForActor(
          local: local,
          currentUid: 'operations-1',
          currentActorName: 'Operations User',
        ),
        throwsStateError,
      );
    });

    test(
      'governed create command carries business input without authority fields',
      () {
        final payload = _read(_createCommandPath);
        final rules = _readFirstExisting(_rulePaths);
        final maintenanceRules = _blockStartingAt(
          rules,
          'match /maintenance_records/{docId}',
        );

        expect(
          payload,
          contains('WorkflowCommandType.createMaintenanceTicket'),
        );
        expect(payload, contains(r"'createMaintenanceTicket_$ticketId'"));
        expect(payload, contains('expectedVersion: 0'));
        expect(payload, contains("'assetHierarchyRefJson'"));
        expect(payload, contains('qualityIntent.toSynchronizedFields()'));
        expect(
          payload,
          contains('burnerLockout.clearResolution().toSynchronizedFields()'),
        );
        expect(payload, isNot(contains("'loggedByUid'")));
        expect(payload, isNot(contains("'loggedByName'")));
        expect(payload, isNot(contains("'createdAt'")));
        expect(payload, isNot(contains("'updatedAt'")));
        expect(maintenanceRules, contains('allow create: if false;'));
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
          // Per-lane authority/time is backend-owned. Direct replay preserves
          // the remote field by omitting it from the update payload.
          'issueLaneCompletionEvidence',
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
        expect(
          payload,
          contains("'endDate': eventTimestamp.toIso8601String()"),
        );
        expect(
          payload,
          contains("'updatedAt': mutationTimestamp.toUtc().toIso8601String()"),
        );
        expect(payload, contains('serverMutationFloor'));
        expect(payload, contains("'closedByUid': evidence.closedByUid"));
        expect(payload, contains("'updatedByUid': evidence.closedByUid"));
        expect(payload, contains('maintenanceCloseReplayVersion('));
        expect(payload, contains('remoteVersion: remote?.version'));
        expect(source, contains('final proposedVersion ='));
        expect(source, contains('remoteVersion + 1'));
        expect(payload, contains("'version': version"));
        expect(payload, contains('withResolutionFromActions'));
        expect(payload, contains('evidence.actionsJson'));
        expect(payload, contains("'burnerResolutionEvidence'"));
        expect(payload, isNot(contains("'issueLaneCompletionEvidence'")));
        final finalClosureRules = _blockStartingAt(
          rules,
          'function validMaintenanceIssueLaneFinalClosure',
        );
        expect(
          finalClosureRules,
          contains(
            "request.resource.data.get('issueLaneCompletionEvidence', null)",
          ),
        );
        expect(
          finalClosureRules,
          contains("resource.data.get('issueLaneCompletionEvidence', null)"),
        );
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

        final ruleKeys = _quotedStrings(rulesBlock);
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
        expect(
          payload,
          contains("'updatedAt': mutationTimestamp.toUtc().toIso8601String()"),
        );
        expect(payload, contains('serverMutationFloor'));
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
        for (final branch in <String>[
          closeUpdate,
          reopenUpdate,
          softDeleteUpdate,
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
        expect(rules, isNot(contains('validMaintenanceAdminEditUpdate')));
        expect(rules, isNot(contains('maintenanceAdminEditShape')));
        final maintenanceMatch = _blockStartingAt(
          rules,
          'match /maintenance_records/{docId}',
        );
        expect(
          RegExp(r'allow\s+update\s*:').allMatches(maintenanceMatch).length,
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
        expect(maintenanceRouter, contains('targetDeleted != sourceDeleted'));
        expect(maintenanceRouter, contains('targetResolved != sourceResolved'));
        for (final validator in <String>[
          'validMaintenanceSoftDeleteUpdate()',
          'validMaintenanceCloseUpdate()',
          'validMaintenanceReopenUpdate()',
        ]) {
          expect(maintenanceRouter, contains(validator));
        }
        expect(
          maintenanceRouter,
          isNot(contains('||')),
          reason:
              'The router must select one lifecycle validator instead of evaluating parallel alternatives.',
        );

        expect(rules, isNot(contains('validMaintenanceAdminEditUpdate')));
        expect(rules, isNot(contains('maintenanceAdminEditShape')));
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
          'String maintenanceLifecycleReplayPinnedFieldDiff',
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
          'assetHierarchyRefJson',
          'classification',
          'otherDepartment',
          'reportedBy',
          'chargeNoAtEvent',
          'metadataJson',
          'performedBy',
        ]) {
          expect(diff, contains("'$field'"), reason: 'Pinned field $field');
        }
        expect(
          diff,
          contains('persistedJsonEquivalent('),
          reason:
              'Metadata envelopes must compare decoded JSON values rather than map insertion order.',
        );

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
        for (final serverProjectionField in <String>[
          'acknowledgedByUid',
          'acknowledgedByName',
          'acknowledgedAt',
          'workflowDeferred',
          'workflowQueueState',
        ]) {
          expect(
            diff,
            isNot(contains("'$serverProjectionField'")),
            reason:
                '$serverProjectionField is preserved from the current server projection during field-scoped replay.',
          );
        }
      },
    );

    test('remote-only repository primitive is explicit and merge-scoped', () {
      final provider = _readMaintenanceProviderLibrary();

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

    test('ordinary batch upload atomically pairs every red-hot directive', () {
      final sync = _read(_syncPath);
      final provider = _read(
        'lib/features/maintenance/providers/maintenance_provider.remote.dart',
      );
      final batch = _blockStartingAt(
        provider,
        'Future<void> batchUpsertTickets(List<MaintenanceRecord> records)',
      );

      expect(batch, contains('burnerRedHotDirectiveProjection(record)'));
      expect(batch, contains('_existingDirectiveIds(directives.keys)'));
      expect(
        batch,
        contains('batch.set(_directives.doc(entry.key), entry.value)'),
      );
      expect(batch, contains('maintenancePairedBatchMaximum'));
      expect(batch, isNot(contains('for (\n      var offset = 0;')));
      final syncBlock = _blockStartingAt(sync, 'Future<void> _syncTickets()');
      _expectOrder(syncBlock, const <String>[
        'final chunk = recordsToPush.sublist(',
        'await _firestoreMaintenance.batchUpsertTickets(chunk);',
        '_maintenanceRepo.markTicketsSyncedIfUnchanged(',
        'lastSuccessCount += chunk.length;',
      ]);
    });

    test('uncertain lifecycle outcomes require exact readback evidence', () {
      final closeAt = DateTime.utc(2026, 8, 21, 10);
      final updatedAt = DateTime.utc(2026, 8, 21, 10, 1);
      final step = <String, dynamic>{
        'version': 2,
        'isResolved': true,
        'status': 'resolved',
        'endDate': closeAt.toIso8601String(),
        'closedByUid': 'si-1',
        'closedByName': 'Senior Mechanical',
        'remarks': 'Inspection complete',
        'downtimeHours': 1.5,
        'teamsInvolved': <String>['mechanical', 'operations'],
        'actionsJson': '[{"action":"inspection"}]',
        'burnerAttendedPositions': <int>[2, 5],
        'burnerResolutionEvidence': <String, dynamic>{
          '2': <String, dynamic>{
            'outcome': 'returnedToService',
            'actionCodes': <String>['uvDetectorCleaning'],
            'microampReading': 3.75,
          },
        },
        'updatedAt': updatedAt.toIso8601String(),
        'updatedByUid': 'si-1',
        'updatedByName': 'Senior Mechanical',
      };
      final remote = <String, dynamic>{...step, 'unrelatedServerField': true};

      expect(maintenanceLifecycleReplayOutcomeMatches(remote, step), isTrue);
      for (final field in step.keys) {
        expect(
          maintenanceLifecycleReplayOutcomeMatches(<String, dynamic>{
            ...remote,
            field: _differentReplayValue(step[field]),
          }, step),
          isFalse,
          reason: 'A mismatch in replayed field $field must fail readback.',
        );
      }
      expect(
        maintenanceLifecycleReplayOutcomeMatches(<String, dynamic>{
          ...remote,
          'burnerResolutionEvidence': <String, dynamic>{
            '2': <String, dynamic>{
              'outcome': 'returnedToService',
              'actionCodes': <String>['uvDetectorCleaning'],
              'microampReading': 1.0,
            },
          },
        }, step),
        isFalse,
      );
    });

    test(
      'successful lifecycle replay also requires exact receipt readback',
      () {
        final source = _read(_syncPath);
        final applyStep = _blockStartingAt(
          source,
          'Future<_MaintenanceLifecycleReplayReceipt>\n'
          '  _applyMaintenanceLifecycleReplayStep(',
        );

        expect(
          applyStep,
          contains(
            'observed ??= await _firestoreMaintenance\n'
            '        .readRemoteMaintenanceLifecycleReplayFieldsForSync',
          ),
          reason:
              'A successful write must be read back; error-only readback can '
              'leave the local row at its stale pre-rebase version.',
        );
        expect(applyStep, contains('readRequiredPersistedInt('));
        expect(applyStep, contains("data['version']"));
        expect(applyStep, contains('readRequiredPersistedDateTime('));
        expect(applyStep, contains("data['updatedAt']"));

        final provider = _readMaintenanceProviderLibrary();
        expect(
          provider,
          contains('applyMaintenanceLifecycleReplayReceiptForSync('),
        );
        expect(provider, contains('_overwriteLocalMaintenanceRecord('));
        expect(provider, contains('required MaintenanceRecord remote'));
        expect(provider, contains('const GetOptions(source: Source.server)'));
        expect(applyStep, contains('readRemoteMaintenanceRecord('));
        expect(applyStep, contains('serverRecord: serverRecord'));
      },
    );

    test('uncertain reopen outcome preserves exact resolution history', () {
      final updatedAt = DateTime.utc(2026, 8, 21, 10, 5);
      final step = <String, dynamic>{
        'version': 3,
        'isResolved': false,
        'status': 'open',
        'actionsJson': '[]',
        'resolutionHistoryJson': '[{"version":2}]',
        'updatedAt': updatedAt.toIso8601String(),
      };
      final remote = <String, dynamic>{...step};

      expect(maintenanceLifecycleReplayOutcomeMatches(remote, step), isTrue);
      expect(
        maintenanceLifecycleReplayOutcomeMatches(remote, <String, dynamic>{
          ...step,
          'resolutionHistoryJson': '[]',
        }),
        isFalse,
      );
    });

    test('burner intake validates its fixed component after asset changes', () {
      final form = _read(
        'lib/features/maintenance/presentation/maintenance_form.dart',
      );

      expect(form, contains("burnerLockout != null"));
      expect(form, contains("? 'Burner system'"));
      expect(form, contains("? 'Furnace / Inner Cover interface'"));
    });

    test('never-created local tombstones do not attempt remote creation', () {
      final source = _read(_syncPath);
      final syncBlock = _blockStartingAt(source, 'Future<void> _syncTickets()');

      _expectOrder(syncBlock, const [
        'if (record.isDeleted)',
        'if (remote == null)',
        'skippedButSyncedSnapshots.add(_syncPushSnapshot(record));',
        'continue;',
        'if (remote == null)',
        'await _pushMissingMaintenanceTicket(record)',
      ]);
      expect(
        syncBlock,
        contains('The issue never crossed the governed creation boundary'),
      );
    });

    test(
      'a never-created local issue always starts the server aggregate at v1',
      () {
        final open = _maintenanceTicket(version: 2);
        final locallyClosed =
            _maintenanceTicket(version: 7)
              ..isResolved = true
              ..status = TicketStatus.resolved;

        expect(maintenanceCreateReplayVersion(open), 1);
        expect(maintenanceCreateReplayVersion(locallyClosed), 1);

        final source = _read(_syncPath);
        expect(source, contains('maintenanceCreateReplayVersion(local)'));
        expect(
          source,
          contains('any collapsed close/reopen'),
          reason:
              'Later local lifecycle transitions must remain separate steps.',
        );
      },
    );

    test(
      'does not touch closure, pull, job-module, or governance contracts',
      () {
        final source = _read(_syncPath);
        final provider = _readMaintenanceProviderLibrary();
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

MaintenanceRecord _maintenanceTicket({required int version}) {
  final createdAt = DateTime.utc(2026, 8, 22, 8);
  return MaintenanceRecord()
    ..firestoreId = 'maintenance-stale-version'
    ..version = version
    ..assetType = AssetType.base
    ..assetNumber = 201
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Cold leak test failed'
    ..routedTo = RoutedTo.mechanical
    ..loggedByUid = 'operations-user'
    ..createdAt = createdAt
    ..startDate = createdAt
    ..updatedAt = createdAt;
}

Object? _differentReplayValue(Object? value) {
  return switch (value) {
    null => 'unexpected',
    bool current => !current,
    int current => current + 1,
    double current => current + 1,
    String current => '$current changed',
    List current => <Object?>[...current, 'unexpected'],
    Map current => <Object?, Object?>{...current, 'unexpected': true},
    _ => 'unexpected',
  };
}

const _syncPath = 'lib/core/services/sync_service.tickets_templates.dart';
const _createCommandPath =
    'lib/features/maintenance/services/maintenance_issue_create_command.dart';
const _providerPaths = <String>[
  'lib/features/maintenance/providers/maintenance_provider.dart',
  'lib/features/maintenance/providers/maintenance_provider.local.dart',
  'lib/features/maintenance/providers/maintenance_provider.remote.dart',
];
const _rulePaths = <String>[
  'firestore.rules',
  'Other root files/firestore.rules',
];

String _read(String path) => File(path).readAsStringSync();

String _readMaintenanceProviderLibrary() =>
    _providerPaths.map(_read).join('\n');

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
