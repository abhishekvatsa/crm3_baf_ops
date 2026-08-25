import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
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
}

_ListenerScope _listenerScope({
  required DeviceRecoveryCommandService commands,
  required _LocalResetProbe reset,
}) {
  final provider = Provider<DeviceRecoveryListener>((ref) {
    final listener = DeviceRecoveryListener(
      commands: commands,
      localReset: reset,
      coordinator: _SyncCoordinatorProbe(),
      ref: ref,
      installationIdReader: () async => _installation,
      foregroundMessages: const Stream<RemoteMessage>.empty(),
    );
    ref.onDispose(listener.stop);
    return listener;
  });
  final container = ProviderContainer();
  return _ListenerScope(container, container.read(provider));
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

Map<String, dynamic> _pollResponse(String? requestId) => <String, dynamic>{
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
            'status': 'pending',
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

AppUser _operator() => AppUser(
  uid: 'operator-1',
  name: 'Operator One',
  email: 'operator@example.invalid',
  roles: const <AppRole>[AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 25),
);

class _ListenerScope {
  _ListenerScope(this.container, this.listener);

  final ProviderContainer container;
  final DeviceRecoveryListener listener;

  void dispose() => container.dispose();
}

class _SyncCoordinatorProbe implements SyncCoordinator {
  @override
  Future<T> runWithSyncPaused<T>({
    required Future<T> Function() operation,
    String reason = 'local_recovery',
  }) => operation();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalResetProbe implements DeviceLocalRecoveryResetService {
  _LocalResetProbe({this.onReset});

  final Future<void> Function(DeviceRecoveryRequest request)? onReset;
  final List<DeviceRecoveryRequest> requests = <DeviceRecoveryRequest>[];

  @override
  Future<DeviceRecoveryLocalResetResult> reset({
    required AppUser? actor,
    required DeviceRecoveryRequest request,
  }) async {
    requests.add(request);
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
