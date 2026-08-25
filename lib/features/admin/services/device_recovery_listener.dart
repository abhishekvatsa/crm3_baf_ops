import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/services/sync_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/services/notification_installation_registry.dart';
import 'device_local_recovery_reset_service.dart';
import 'device_recovery_command_service.dart';

class DeviceRecoveryListener {
  DeviceRecoveryListener({
    required DeviceRecoveryCommandService commands,
    required DeviceLocalRecoveryResetService localReset,
    required SyncCoordinator coordinator,
    required Ref ref,
    Future<String?> Function()? installationIdReader,
    Stream<RemoteMessage>? foregroundMessages,
  }) : _commands = commands,
       _localReset = localReset,
       _coordinator = coordinator,
       _ref = ref,
       _installationIdReader =
           installationIdReader ??
           SharedPreferencesNotificationInstallationIdStore().read,
       _foregroundMessages = foregroundMessages;

  final DeviceRecoveryCommandService _commands;
  final DeviceLocalRecoveryResetService _localReset;
  final SyncCoordinator _coordinator;
  final Ref _ref;
  final Future<String?> Function() _installationIdReader;
  final Stream<RemoteMessage>? _foregroundMessages;

  AppUser? _actor;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  Timer? _registrationRetry;
  int _registrationRetries = 0;
  bool _busy = false;
  bool _followUpRequested = false;
  bool _claimedRecoveryOnly = false;
  int _generation = 0;

  void start(AppUser actor, {bool claimedRecoveryOnly = false}) {
    if (kIsWeb ||
        (!actor.isApproved && !claimedRecoveryOnly) ||
        (actor.isApproved && claimedRecoveryOnly)) {
      return;
    }
    if (_actor?.uid != actor.uid ||
        _claimedRecoveryOnly != claimedRecoveryOnly) {
      stop();
      _actor = actor;
      _claimedRecoveryOnly = claimedRecoveryOnly;
      _registrationRetries = 0;
      final stream = _foregroundMessages ?? FirebaseMessaging.onMessage;
      _messageSubscription = stream.listen(
        _onMessage,
        onError: (Object error, StackTrace stackTrace) {
          AppLogger.warning(
            'Foreground device-recovery notification stream failed',
            error: error,
            stackTrace: stackTrace,
            context: const {'app_area': 'device_recovery'},
          );
        },
      );
    } else {
      _actor = actor;
    }
    unawaited(checkNow(reason: 'session_started'));
  }

  void stop() {
    _generation++;
    _registrationRetry?.cancel();
    _registrationRetry = null;
    final subscription = _messageSubscription;
    _messageSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _actor = null;
    _busy = false;
    _followUpRequested = false;
    _claimedRecoveryOnly = false;
  }

  void _onMessage(RemoteMessage message) {
    if (message.data['destinationType'] != 'admin_device_reset') return;
    unawaited(
      checkNow(
        reason: 'admin_push',
        expectedInstallationId: message.data['installationId'],
      ),
    );
  }

  Future<void> checkNow({
    required String reason,
    String? expectedInstallationId,
  }) async {
    final actor = _actor;
    final claimedRecoveryOnly = _claimedRecoveryOnly;
    if (actor == null || kIsWeb) return;
    if (_busy) {
      _followUpRequested = true;
      return;
    }
    _busy = true;
    final generation = _generation;
    DeviceRecoveryRequest? activeRequest;
    try {
      final installationId = await _installationIdReader();
      if (!_isCurrent(actor, generation)) return;
      if (installationId == null) {
        _scheduleRegistrationRetry();
        return;
      }
      if (expectedInstallationId != null &&
          expectedInstallationId != installationId) {
        return;
      }
      _registrationRetry?.cancel();
      _registrationRetry = null;
      final request = await _commands.pollPending(
        actor: actor,
        installationId: installationId,
        claimedRecoveryOnly: claimedRecoveryOnly,
      );
      if (request == null || !_isCurrent(actor, generation)) return;
      activeRequest = request;

      await _coordinator.runWithSyncPaused<void>(
        reason: 'admin_authorized_device_reset',
        resumeSyncAfterRecovery: !claimedRecoveryOnly,
        operation: () async {
          if (!_isCurrent(actor, generation)) {
            throw const DeviceRecoveryLocalResetException(
              'The signed-in session changed before device recovery.',
              reasonCode: 'device-recovery-session-changed',
            );
          }
          await _commands.claimReset(
            actor: actor,
            request: request,
            claimedRecoveryOnly: claimedRecoveryOnly,
          );
          if (!_isCurrent(actor, generation)) {
            throw const DeviceRecoveryLocalResetException(
              'The signed-in session changed after its recovery claim.',
              reasonCode: 'device-recovery-session-changed',
            );
          }
          final result = await _localReset.reset(
            actor: actor,
            request: request,
            claimedRecoveryOnly: claimedRecoveryOnly,
          );
          await _commands.completeReset(
            actor: actor,
            request: request,
            backupFileCount: result.backupFileCount,
            clearedCursorCount: result.clearedCursorCount,
            backedUpUnsyncedRows: result.backedUpUnsyncedRows,
            claimedRecoveryOnly: claimedRecoveryOnly,
          );
          _ref.invalidate(syncPendingCountsProvider);
          AppLogger.breadcrumb(
            'Administrator-authorized device recovery completed',
            context: {
              'app_area': 'device_recovery',
              'recovery_replayed': result.replayed,
              'recovery_reason': reason,
            },
          );
        },
      );
    } on DeviceRecoveryLocalResetException catch (error, stackTrace) {
      AppLogger.warning(
        'Administrator-authorized device recovery was refused',
        error: error,
        stackTrace: stackTrace,
        context: {
          'app_area': 'device_recovery',
          'recovery_stage': error.reasonCode,
        },
      );
      if (!error.dataMayHaveBeenCleared &&
          activeRequest != null &&
          _isCurrent(actor, generation)) {
        await _reportSafeFailure(
          actor,
          activeRequest,
          error,
          claimedRecoveryOnly: claimedRecoveryOnly,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Administrator-authorized device recovery remains pending',
        error: error,
        stackTrace: stackTrace,
        context: const {'app_area': 'device_recovery'},
      );
    } finally {
      if (generation == _generation) {
        _busy = false;
        if (_followUpRequested) {
          _followUpRequested = false;
          unawaited(checkNow(reason: 'queued_recovery_check'));
        }
      }
    }
  }

  Future<void> _reportSafeFailure(
    AppUser actor,
    DeviceRecoveryRequest request,
    DeviceRecoveryLocalResetException error, {
    required bool claimedRecoveryOnly,
  }) async {
    try {
      final installationId = await _installationIdReader();
      if (installationId != request.installationId) return;
      await _commands.failReset(
        actor: actor,
        request: request,
        failureCode: error.reasonCode,
        claimedRecoveryOnly: claimedRecoveryOnly,
      );
    } catch (reportError, stackTrace) {
      AppLogger.warning(
        'Device recovery failure receipt could not be recorded',
        error: reportError,
        stackTrace: stackTrace,
        context: const {'app_area': 'device_recovery'},
      );
    }
  }

  bool _isCurrent(AppUser actor, int generation) =>
      _generation == generation && _actor?.uid == actor.uid;

  void _scheduleRegistrationRetry() {
    if (_registrationRetries >= 3 || _registrationRetry != null) return;
    _registrationRetries++;
    _registrationRetry = Timer(const Duration(seconds: 2), () {
      _registrationRetry = null;
      unawaited(checkNow(reason: 'device_registration_ready'));
    });
  }
}

final deviceRecoveryListenerProvider = Provider<DeviceRecoveryListener>((ref) {
  final listener = DeviceRecoveryListener(
    commands: ref.watch(deviceRecoveryCommandServiceProvider),
    localReset: ref.watch(deviceLocalRecoveryResetServiceProvider),
    coordinator: ref.watch(syncCoordinatorProvider),
    ref: ref,
  );
  ref.onDispose(listener.stop);
  return listener;
});
