import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/services/local_recovery_session_guard.dart';
import 'package:crm3_baf_ops/features/admin/services/device_local_recovery_reset_service.dart';
import 'package:crm3_baf_ops/features/admin/services/device_recovery_command_service.dart';
import 'package:crm3_baf_ops/features/admin/services/device_recovery_listener.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _installation = '11111111-1111-4111-8111-111111111111';
const _request = '33333333-3333-4333-8333-333333333333';
const _replacement = '44444444-4444-4444-8444-444444444444';

void main() {
  test('listener blocks sign-out before its startup poll completes', () async {
    final firstPoll = Completer<Map<String, dynamic>>();
    final commands = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'operator-1',
      invoke: (payload) async {
        if (payload['operation'] == deviceRecoveryPollOperation) {
          return firstPoll.future;
        }
        throw StateError('Unexpected request: ${payload['operation']}');
      },
    );
    final scope = _listenerScope(commands: commands, reset: _LocalResetProbe());
    addTearDown(scope.dispose);

    scope.listener.start(_operator());
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      scope.recoverySessionGuard.beginSessionEnd(),
      throwsA(isA<LocalRecoverySignOutBlockedException>()),
    );

    firstPoll.complete(_pollResponse(null));
    await _waitFor(
      () => !scope.recoverySessionGuard.isRecoveryProtectionActive,
    );
    await scope.recoverySessionGuard.beginSessionEnd();
    scope.recoverySessionGuard.endSessionEnd();
  });

  test(
    'missing registration releases startup check only without an active journal',
    () async {
      var pollCalls = 0;
      var installationReads = 0;
      var journalProbes = 0;
      final recoveryChecks = <String>[];
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (_) async {
          pollCalls++;
          return _pollResponse(null);
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        installationIdReader: () async {
          installationReads++;
          return null;
        },
        activeJournalProbe: () async {
          journalProbes++;
          recoveryChecks.add('active-probe');
          return false;
        },
        terminalJournalSynchronizer: () async {
          recoveryChecks.add('terminal-sync');
        },
        registrationRetryDelay: const Duration(milliseconds: 1),
        maxRegistrationRetries: 1,
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await _waitFor(
        () => !scope.recoverySessionGuard.isRecoveryProtectionActive,
      );

      expect(installationReads, 2);
      expect(journalProbes, 1);
      expect(pollCalls, 0);
      expect(recoveryChecks, <String>['terminal-sync', 'active-probe']);
      await scope.recoverySessionGuard.beginSessionEnd();
      scope.recoverySessionGuard.endSessionEnd();
    },
  );

  test(
    'missing registration retains protection for an active journal',
    () async {
      final probed = Completer<void>();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (_) async => _pollResponse(null),
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        installationIdReader: () async => null,
        terminalJournalSynchronizer: () async {},
        activeJournalProbe: () async {
          probed.complete();
          return true;
        },
        maxRegistrationRetries: 0,
        maxRecoveryRetries: 0,
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await probed.future.timeout(const Duration(seconds: 2));

      expect(scope.recoverySessionGuard.isRecoveryProtectionActive, isTrue);
      await expectLater(
        scope.recoverySessionGuard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );
    },
  );

  test(
    'missing registration retains protection when the journal probe fails',
    () async {
      final probed = Completer<void>();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (_) async => _pollResponse(null),
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        installationIdReader: () async => null,
        terminalJournalSynchronizer: () async {},
        activeJournalProbe: () async {
          probed.complete();
          throw const FormatException('unreadable recovery journal');
        },
        maxRegistrationRetries: 0,
        maxRecoveryRetries: 0,
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await probed.future.timeout(const Duration(seconds: 2));

      expect(scope.recoverySessionGuard.isRecoveryProtectionActive, isTrue);
      await expectLater(
        scope.recoverySessionGuard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );
    },
  );

  test(
    'missing registration retains protection when terminal evidence cannot sync',
    () async {
      final syncAttempted = Completer<void>();
      var activeJournalProbes = 0;
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (_) async => _pollResponse(null),
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        installationIdReader: () async => null,
        terminalJournalSynchronizer: () async {
          syncAttempted.complete();
          throw StateError('terminal directory sync failed');
        },
        activeJournalProbe: () async {
          activeJournalProbes++;
          return false;
        },
        maxRegistrationRetries: 0,
        maxRecoveryRetries: 0,
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await syncAttempted.future.timeout(const Duration(seconds: 2));

      expect(activeJournalProbes, 0);
      expect(scope.recoverySessionGuard.isRecoveryProtectionActive, isTrue);
      await expectLater(
        scope.recoverySessionGuard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );
    },
  );

  test(
    'terminal journal is retained before sign-out protection ends',
    () async {
      final markerEntered = Completer<void>();
      final releaseMarker = Completer<void>();
      final markedRequests = <String>[];
      String? preservedRequestId;
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(_request, status: 'in_progress');
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        terminalJournalMarker: (requestId) async {
          markedRequests.add(requestId);
          markerEntered.complete();
          await releaseMarker.future;
        },
        inactiveJournalRetirer: ({
          required targetUid,
          required installationId,
          required activeRequestId,
        }) async {
          expect(targetUid, 'operator-1');
          expect(installationId, _installation);
          preservedRequestId = activeRequestId;
          return 0;
        },
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await markerEntered.future.timeout(const Duration(seconds: 2));

      await expectLater(
        scope.recoverySessionGuard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );
      expect(markedRequests, <String>[_request]);
      expect(preservedRequestId, _request);

      releaseMarker.complete();
      await _waitFor(
        () => !scope.recoverySessionGuard.isRecoveryProtectionActive,
      );
      await scope.recoverySessionGuard.beginSessionEnd();
      scope.recoverySessionGuard.endSessionEnd();
    },
  );

  test(
    'no-request retry retires a journal after server completion won the race',
    () async {
      var pollAttempts = 0;
      var terminalAttempts = 0;
      var journalValidationAttempts = 0;
      final inactiveRetired = Completer<void>();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              pollAttempts++;
              return pollAttempts == 1
                  ? _pollResponse(_request, status: 'in_progress')
                  : _pollResponse(null);
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        recoveryRetryDelay: const Duration(milliseconds: 1),
        terminalJournalMarker: (_) async {
          terminalAttempts++;
          throw StateError('terminal rename interrupted');
        },
        inactiveJournalRetirer: ({
          required targetUid,
          required installationId,
          required activeRequestId,
        }) async {
          expect(targetUid, 'operator-1');
          expect(installationId, _installation);
          journalValidationAttempts++;
          if (activeRequestId == _request) return 0;
          expect(activeRequestId, isNull);
          inactiveRetired.complete();
          return 1;
        },
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await inactiveRetired.future.timeout(const Duration(seconds: 2));
      await _waitFor(
        () => !scope.recoverySessionGuard.isRecoveryProtectionActive,
      );

      expect(pollAttempts, 2);
      expect(terminalAttempts, 1);
      expect(journalValidationAttempts, 2);
      await scope.recoverySessionGuard.beginSessionEnd();
      scope.recoverySessionGuard.endSessionEnd();
    },
  );

  test(
    'journal identity mismatch keeps startup and sign-out protection active',
    () async {
      final retireAttempted = Completer<void>();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          if (payload['operation'] == deviceRecoveryPollOperation) {
            return _pollResponse(null);
          }
          throw StateError('Unexpected request: ${payload['operation']}');
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        maxRecoveryRetries: 0,
        inactiveJournalRetirer: ({
          required targetUid,
          required installationId,
          required activeRequestId,
        }) async {
          expect(targetUid, 'operator-1');
          expect(installationId, _installation);
          expect(activeRequestId, isNull);
          retireAttempted.complete();
          throw const FormatException('cross-identity active journal');
        },
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await retireAttempted.future.timeout(const Duration(seconds: 2));

      expect(scope.recoverySessionGuard.isRecoveryProtectionActive, isTrue);
      await expectLater(
        scope.recoverySessionGuard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );
    },
  );

  test(
    'returned request cannot bypass active journal identity validation',
    () async {
      final validationAttempted = Completer<void>();
      final reset = _LocalResetProbe();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          if (payload['operation'] == deviceRecoveryPollOperation) {
            return _pollResponse(_replacement);
          }
          throw StateError('Unexpected request: ${payload['operation']}');
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: reset,
        maxRecoveryRetries: 0,
        inactiveJournalRetirer: ({
          required targetUid,
          required installationId,
          required activeRequestId,
        }) async {
          expect(targetUid, 'operator-1');
          expect(installationId, _installation);
          expect(activeRequestId, _replacement);
          validationAttempted.complete();
          throw const FormatException('cross-identity active journal');
        },
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await validationAttempted.future.timeout(const Duration(seconds: 2));

      expect(reset.requests, isEmpty);
      expect(scope.recoverySessionGuard.isRecoveryProtectionActive, isTrue);
      await expectLater(
        scope.recoverySessionGuard.beginSessionEnd(),
        throwsA(isA<LocalRecoverySignOutBlockedException>()),
      );
    },
  );

  test(
    'recovery notification received during a poll is checked afterward',
    () async {
      final calls = <Map<String, Object?>>[];
      final firstPoll = Completer<Map<String, dynamic>>();
      final completed = Completer<void>();
      final reset = _LocalResetProbe();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          calls.add(Map<String, Object?>.from(payload));
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              final polls = calls.where(
                (call) => call['operation'] == deviceRecoveryPollOperation,
              );
              if (polls.length == 1) return firstPoll.future;
              return _pollResponse(_request);
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              completed.complete();
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(commands: commands, reset: reset);
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await _waitFor(() => calls.isNotEmpty);
      await scope.listener.checkNow(
        reason: 'admin_push',
        expectedInstallationId: _installation,
      );
      firstPoll.complete(_pollResponse(null));
      await completed.future.timeout(const Duration(seconds: 2));

      expect(calls.map((call) => call['operation']), <String>[
        deviceRecoveryPollOperation,
        deviceRecoveryPollOperation,
        deviceRecoveryClaimOperation,
        deviceRecoveryCompleteOperation,
      ]);
      expect(reset.requests.single.requestId, _request);
    },
  );

  test(
    'safe local failure remains bound to its original claimed request',
    () async {
      final calls = <Map<String, Object?>>[];
      final reported = Completer<void>();
      var replacementAvailable = false;
      final reset = _LocalResetProbe(
        onReset: (request) async {
          replacementAvailable = true;
          throw const DeviceRecoveryLocalResetException(
            'Backup was unavailable.',
            reasonCode: 'device-recovery-backup-failed',
          );
        },
      );
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          calls.add(Map<String, Object?>.from(payload));
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(
                replacementAvailable ? _replacement : _request,
              );
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryFailOperation:
              expect(payload['requestId'], _request);
              reported.complete();
              return _finishResponse(_request, 'failed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(commands: commands, reset: reset);
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await reported.future.timeout(const Duration(seconds: 2));

      expect(calls.map((call) => call['operation']), <String>[
        deviceRecoveryPollOperation,
        deviceRecoveryClaimOperation,
        deviceRecoveryFailOperation,
      ]);
    },
  );

  test(
    'revoked phone resumes only its previously claimed protected reset',
    () async {
      final calls = <Map<String, Object?>>[];
      final completed = Completer<void>();
      final reset = _LocalResetProbe();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          calls.add(Map<String, Object?>.from(payload));
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(_request, status: 'in_progress');
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              completed.complete();
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(commands: commands, reset: reset);
      addTearDown(scope.dispose);

      scope.listener.start(
        _operator(approved: false),
        claimedRecoveryOnly: true,
      );
      await completed.future.timeout(const Duration(seconds: 2));

      expect(calls.map((call) => call['operation']), <String>[
        deviceRecoveryPollOperation,
        deviceRecoveryClaimOperation,
        deviceRecoveryCompleteOperation,
      ]);
      expect(reset.requests.single.status, 'in_progress');
      expect(reset.claimedRecoveryModes, <bool>[true]);
      expect(scope.coordinator.followUpModes, <bool>[false]);
    },
  );

  test(
    'revoked terminal poll retires its journal without ordinary sync',
    () async {
      final retired = Completer<void>();
      final reset = _LocalResetProbe();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          expect(payload['operation'], deviceRecoveryPollOperation);
          return _pollResponse(null);
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: reset,
        inactiveJournalRetirer: ({
          required targetUid,
          required installationId,
          required activeRequestId,
        }) async {
          expect(targetUid, 'operator-1');
          expect(installationId, _installation);
          expect(activeRequestId, isNull);
          retired.complete();
          return 1;
        },
      );
      addTearDown(scope.dispose);

      scope.listener.start(
        _operator(approved: false),
        claimedRecoveryOnly: true,
      );
      await retired.future.timeout(const Duration(seconds: 2));
      await _waitFor(
        () => !scope.recoverySessionGuard.isRecoveryProtectionActive,
      );

      expect(reset.requests, isEmpty);
      expect(scope.coordinator.followUpModes, isEmpty);
      await scope.recoverySessionGuard.beginSessionEnd();
      scope.recoverySessionGuard.endSessionEnd();
    },
  );

  test(
    'claimed reset retries completion after a temporary connection failure',
    () async {
      final calls = <Map<String, Object?>>[];
      final completed = Completer<void>();
      final reset = _LocalResetProbe();
      var completionAttempts = 0;
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          calls.add(Map<String, Object?>.from(payload));
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(
                _request,
                status: completionAttempts == 0 ? 'pending' : 'in_progress',
              );
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              completionAttempts++;
              if (completionAttempts == 1) {
                throw StateError('The connection was temporarily unavailable.');
              }
              completed.complete();
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: reset,
        recoveryRetryDelay: const Duration(milliseconds: 1),
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await completed.future.timeout(const Duration(seconds: 2));

      expect(completionAttempts, 2);
      expect(reset.requests.map((request) => request.requestId), [
        _request,
        _request,
      ]);
      expect(calls.map((call) => call['operation']), <String>[
        deviceRecoveryPollOperation,
        deviceRecoveryClaimOperation,
        deviceRecoveryCompleteOperation,
        deviceRecoveryPollOperation,
        deviceRecoveryClaimOperation,
        deviceRecoveryCompleteOperation,
      ]);
    },
  );

  test(
    'initial recovery lookup retries before the request identity is known',
    () async {
      final calls = <String>[];
      final completed = Completer<void>();
      var pollAttempts = 0;
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          final operation = payload['operation']! as String;
          calls.add(operation);
          switch (operation) {
            case deviceRecoveryPollOperation:
              pollAttempts++;
              if (pollAttempts == 1) {
                throw _RecoveryFunctionsException(code: 'unavailable');
              }
              return _pollResponse(_request);
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              completed.complete();
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: $operation');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        recoveryRetryDelay: const Duration(milliseconds: 1),
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await completed.future.timeout(const Duration(seconds: 2));

      expect(pollAttempts, 2);
      expect(calls, <String>[
        deviceRecoveryPollOperation,
        deviceRecoveryPollOperation,
        deviceRecoveryClaimOperation,
        deviceRecoveryCompleteOperation,
      ]);
    },
  );

  test(
    'revoked phone retries an initial lookup without enabling ordinary sync',
    () async {
      final completed = Completer<void>();
      var pollAttempts = 0;
      final reset = _LocalResetProbe();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              pollAttempts++;
              if (pollAttempts == 1) {
                throw _RecoveryFunctionsException(code: 'deadline-exceeded');
              }
              return _pollResponse(_request, status: 'in_progress');
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              completed.complete();
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: reset,
        recoveryRetryDelay: const Duration(milliseconds: 1),
      );
      addTearDown(scope.dispose);

      scope.listener.start(
        _operator(approved: false),
        claimedRecoveryOnly: true,
      );
      await completed.future.timeout(const Duration(seconds: 2));

      expect(pollAttempts, 2);
      expect(reset.claimedRecoveryModes, <bool>[true]);
      expect(scope.coordinator.followUpModes, <bool>[false]);
    },
  );

  test('permanent recovery authority denial is never retried', () async {
    final denied = Completer<void>();
    var pollAttempts = 0;
    final commands = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'operator-1',
      invoke: (_) async {
        pollAttempts++;
        denied.complete();
        throw _RecoveryFunctionsException(code: 'permission-denied');
      },
    );
    final scope = _listenerScope(
      commands: commands,
      reset: _LocalResetProbe(),
      recoveryRetryDelay: const Duration(milliseconds: 1),
    );
    addTearDown(scope.dispose);

    scope.listener.start(_operator());
    await denied.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(pollAttempts, 1);
  });

  test(
    'revoked phone retries claimed completion without ordinary synchronization',
    () async {
      final completed = Completer<void>();
      final reset = _LocalResetProbe();
      var completionAttempts = 0;
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(_request, status: 'in_progress');
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              completionAttempts++;
              if (completionAttempts == 1) {
                throw StateError('The connection was temporarily unavailable.');
              }
              completed.complete();
              return _finishResponse(_request, 'completed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: reset,
        recoveryRetryDelay: const Duration(milliseconds: 1),
      );
      addTearDown(scope.dispose);

      scope.listener.start(
        _operator(approved: false),
        claimedRecoveryOnly: true,
      );
      await completed.future.timeout(const Duration(seconds: 2));

      expect(completionAttempts, 2);
      expect(reset.claimedRecoveryModes, <bool>[true, true]);
      expect(scope.coordinator.followUpModes, <bool>[false, false]);
    },
  );

  test('claimed recovery retries are bounded', () async {
    final lastAttempt = Completer<void>();
    var completionAttempts = 0;
    final commands = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'operator-1',
      invoke: (payload) async {
        switch (payload['operation']) {
          case deviceRecoveryPollOperation:
            return _pollResponse(_request, status: 'in_progress');
          case deviceRecoveryClaimOperation:
            return _claimResponse(_request);
          case deviceRecoveryCompleteOperation:
            completionAttempts++;
            if (completionAttempts == 3) lastAttempt.complete();
            throw StateError('The connection is still unavailable.');
          default:
            throw StateError('Unexpected request: ${payload['operation']}');
        }
      },
    );
    final scope = _listenerScope(
      commands: commands,
      reset: _LocalResetProbe(),
      recoveryRetryDelay: const Duration(milliseconds: 1),
      maxRecoveryRetries: 2,
    );
    addTearDown(scope.dispose);

    scope.listener.start(_operator());
    await lastAttempt.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(completionAttempts, 3);
  });

  test(
    'stopping the signed-in session cancels pending recovery retries',
    () async {
      final attempted = Completer<void>();
      var completionAttempts = 0;
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(_request, status: 'in_progress');
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryCompleteOperation:
              completionAttempts++;
              attempted.complete();
              throw StateError('The connection was temporarily unavailable.');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
        recoveryRetryDelay: const Duration(milliseconds: 30),
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await attempted.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      scope.listener.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(completionAttempts, 1);
    },
  );

  test(
    'temporary failure-report errors retry the exact claimed request',
    () async {
      final reported = Completer<void>();
      var failureAttempts = 0;
      final reset = _LocalResetProbe(
        onReset: (_) async {
          throw const DeviceRecoveryLocalResetException(
            'Backup was unavailable.',
            reasonCode: 'device-recovery-backup-failed',
          );
        },
      );
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(_request, status: 'in_progress');
            case deviceRecoveryClaimOperation:
              return _claimResponse(_request);
            case deviceRecoveryFailOperation:
              failureAttempts++;
              if (failureAttempts == 1) {
                throw StateError('The connection was temporarily unavailable.');
              }
              reported.complete();
              return _finishResponse(_request, 'failed');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: reset,
        recoveryRetryDelay: const Duration(milliseconds: 1),
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await reported.future.timeout(const Duration(seconds: 2));

      expect(failureAttempts, 2);
      expect(reset.requests.map((request) => request.requestId), [
        _request,
        _request,
      ]);
    },
  );

  test('sign-out stays blocked between claimed completion retries', () async {
    final firstCompletion = Completer<void>();
    final completed = Completer<void>();
    var completionAttempts = 0;
    final commands = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'operator-1',
      invoke: (payload) async {
        switch (payload['operation']) {
          case deviceRecoveryPollOperation:
            return _pollResponse(_request, status: 'in_progress');
          case deviceRecoveryClaimOperation:
            return _claimResponse(_request);
          case deviceRecoveryCompleteOperation:
            completionAttempts++;
            if (completionAttempts == 1) {
              firstCompletion.complete();
              throw StateError('The completion receipt was interrupted.');
            }
            completed.complete();
            return _finishResponse(_request, 'completed');
          default:
            throw StateError('Unexpected request: ${payload['operation']}');
        }
      },
    );
    final scope = _listenerScope(
      commands: commands,
      reset: _LocalResetProbe(),
      recoveryRetryDelay: const Duration(milliseconds: 100),
    );
    addTearDown(scope.dispose);

    scope.listener.start(_operator());
    await firstCompletion.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      scope.recoverySessionGuard.beginSessionEnd(),
      throwsA(isA<LocalRecoverySignOutBlockedException>()),
    );

    await completed.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);
    await scope.recoverySessionGuard.beginSessionEnd();
    scope.recoverySessionGuard.endSessionEnd();
  });

  test('final listener disposal releases a retained claim interlock', () async {
    final firstCompletion = Completer<void>();
    final commands = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'operator-1',
      invoke: (payload) async {
        switch (payload['operation']) {
          case deviceRecoveryPollOperation:
            return _pollResponse(_request, status: 'in_progress');
          case deviceRecoveryClaimOperation:
            return _claimResponse(_request);
          case deviceRecoveryCompleteOperation:
            firstCompletion.complete();
            throw StateError('The completion receipt was interrupted.');
          default:
            throw StateError('Unexpected request: ${payload['operation']}');
        }
      },
    );
    final scope = _listenerScope(
      commands: commands,
      reset: _LocalResetProbe(),
      recoveryRetryDelay: const Duration(seconds: 5),
    );
    addTearDown(scope.dispose);

    scope.listener.start(_operator());
    await firstCompletion.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      scope.recoverySessionGuard.beginSessionEnd(),
      throwsA(isA<LocalRecoverySignOutBlockedException>()),
    );

    scope.listener.dispose();
    await scope.recoverySessionGuard.beginSessionEnd();
    scope.recoverySessionGuard.endSessionEnd();
  });

  test(
    'a definitive claim rejection releases the sign-out interlock',
    () async {
      final rejected = Completer<void>();
      final commands = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          switch (payload['operation']) {
            case deviceRecoveryPollOperation:
              return _pollResponse(_request);
            case deviceRecoveryClaimOperation:
              rejected.complete();
              throw _RecoveryFunctionsException(code: 'permission-denied');
            default:
              throw StateError('Unexpected request: ${payload['operation']}');
          }
        },
      );
      final scope = _listenerScope(
        commands: commands,
        reset: _LocalResetProbe(),
      );
      addTearDown(scope.dispose);

      scope.listener.start(_operator());
      await rejected.future.timeout(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);

      await scope.recoverySessionGuard.beginSessionEnd();
      scope.recoverySessionGuard.endSessionEnd();
    },
  );

  test('revoked phone cannot start an ordinary recovery listener', () async {
    var calls = 0;
    final commands = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'operator-1',
      invoke: (_) async {
        calls++;
        return _pollResponse(_request, status: 'in_progress');
      },
    );
    final scope = _listenerScope(commands: commands, reset: _LocalResetProbe());
    addTearDown(scope.dispose);

    scope.listener.start(_operator(approved: false));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, 0);
  });
}

_ListenerScope _listenerScope({
  required DeviceRecoveryCommandService commands,
  required _LocalResetProbe reset,
  Future<String?> Function()? installationIdReader,
  DeviceRecoveryTerminalJournalMarker? terminalJournalMarker,
  DeviceRecoveryInactiveJournalRetirer? inactiveJournalRetirer,
  DeviceRecoveryTerminalJournalSynchronizer? terminalJournalSynchronizer,
  LocalRecoveryJournalProbe? activeJournalProbe,
  Duration registrationRetryDelay = const Duration(seconds: 2),
  int maxRegistrationRetries = 3,
  Duration recoveryRetryDelay = const Duration(seconds: 1),
  int maxRecoveryRetries = 5,
}) {
  final coordinator = _SyncCoordinatorProbe();
  final recoverySessionGuard = LocalRecoverySessionGuard();
  final provider = Provider<DeviceRecoveryListener>((ref) {
    final listener = DeviceRecoveryListener(
      commands: commands,
      localReset: reset,
      coordinator: coordinator,
      recoverySessionGuard: recoverySessionGuard,
      ref: ref,
      installationIdReader: installationIdReader ?? () async => _installation,
      foregroundMessages: const Stream<RemoteMessage>.empty(),
      terminalJournalMarker: terminalJournalMarker,
      inactiveJournalRetirer: inactiveJournalRetirer,
      terminalJournalSynchronizer: terminalJournalSynchronizer,
      activeJournalProbe: activeJournalProbe,
      registrationRetryDelay: registrationRetryDelay,
      maxRegistrationRetries: maxRegistrationRetries,
      recoveryRetryDelay: recoveryRetryDelay,
      maxRecoveryRetries: maxRecoveryRetries,
    );
    ref.onDispose(listener.dispose);
    return listener;
  });
  final container = ProviderContainer();
  return _ListenerScope(
    container,
    container.read(provider),
    coordinator,
    recoverySessionGuard,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Expected listener activity was not observed.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Map<String, dynamic> _pollResponse(
  String? requestId, {
  String status = 'pending',
}) => <String, dynamic>{
  'ok': true,
  'operation': deviceRecoveryPollOperation,
  'installationId': _installation,
  'request':
      requestId == null
          ? null
          : <String, Object?>{
            'requestId': requestId,
            'targetUid': 'operator-1',
            'installationId': _installation,
            'status': status,
            'requestedByUid': 'admin-1',
            'requestedByName': 'Administrator',
            'reason': 'Recover the selected operator phone safely.',
            'requestedAt': '2026-08-25T12:00:00.000Z',
            'expiresAt': '2026-08-26T12:00:00.000Z',
          },
};

Map<String, dynamic> _claimResponse(String requestId) => <String, dynamic>{
  'ok': true,
  'operation': deviceRecoveryClaimOperation,
  'requestId': requestId,
  'targetUid': 'operator-1',
  'installationId': _installation,
  'status': 'in_progress',
};

Map<String, dynamic> _finishResponse(String requestId, String status) =>
    <String, dynamic>{
      'ok': true,
      'operation':
          status == 'completed'
              ? deviceRecoveryCompleteOperation
              : deviceRecoveryFailOperation,
      'requestId': requestId,
      'installationId': _installation,
      'status': status,
    };

AppUser _operator({bool approved = true}) => AppUser(
  uid: 'operator-1',
  name: 'Operator One',
  email: 'operator@example.invalid',
  roles: const <AppRole>[AppRole.operations],
  isApproved: approved,
  createdAt: DateTime.utc(2026, 8, 25),
);

class _ListenerScope {
  _ListenerScope(
    this.container,
    this.listener,
    this.coordinator,
    this.recoverySessionGuard,
  );

  final ProviderContainer container;
  final DeviceRecoveryListener listener;
  final _SyncCoordinatorProbe coordinator;
  final LocalRecoverySessionGuard recoverySessionGuard;

  void dispose() => container.dispose();
}

class _RecoveryFunctionsException extends FirebaseFunctionsException {
  _RecoveryFunctionsException({required super.code})
    : super(message: 'Simulated callable outcome.');
}

class _SyncCoordinatorProbe implements SyncCoordinator {
  final List<bool> followUpModes = <bool>[];

  @override
  Future<T> runWithSyncPaused<T>({
    required Future<T> Function() operation,
    String reason = 'local_recovery',
    bool resumeSyncAfterRecovery = true,
  }) {
    followUpModes.add(resumeSyncAfterRecovery);
    return operation();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalResetProbe implements DeviceLocalRecoveryResetService {
  _LocalResetProbe({this.onReset});

  final Future<void> Function(DeviceRecoveryRequest request)? onReset;
  final List<DeviceRecoveryRequest> requests = <DeviceRecoveryRequest>[];
  final List<bool> claimedRecoveryModes = <bool>[];

  @override
  Future<DeviceRecoveryLocalResetResult> reset({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
    bool claimedRecoveryOnly = false,
  }) async {
    requests.add(request);
    claimedRecoveryModes.add(claimedRecoveryOnly);
    await onReset?.call(request);
    return const DeviceRecoveryLocalResetResult(
      backupDirectory: 'backup',
      backupFileCount: 1,
      clearedCursorCount: 1,
      backedUpUnsyncedRows: 0,
      replayed: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
