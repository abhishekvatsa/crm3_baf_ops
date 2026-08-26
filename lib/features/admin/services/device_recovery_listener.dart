import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/isar_production_recovery.dart';
import '../../../core/services/local_recovery_session_guard.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/services/sync_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/services/notification_installation_registry.dart';
import 'device_local_recovery_reset_service.dart';
import 'device_recovery_command_service.dart';

typedef DeviceRecoveryTerminalJournalMarker =
    Future<void> Function(String requestId);
typedef DeviceRecoveryInactiveJournalRetirer =
    Future<int> Function({
      required String targetUid,
      required String installationId,
      required String? activeRequestId,
    });
typedef DeviceRecoveryTerminalJournalSynchronizer = Future<void> Function();

class DeviceRecoveryListener {
  DeviceRecoveryListener({
    required DeviceRecoveryCommandService commands,
    required DeviceLocalRecoveryResetService localReset,
    required SyncCoordinator coordinator,
    required LocalRecoverySessionGuard recoverySessionGuard,
    required Ref ref,
    Future<String?> Function()? installationIdReader,
    Stream<RemoteMessage>? foregroundMessages,
    DeviceRecoveryTerminalJournalMarker? terminalJournalMarker,
    DeviceRecoveryInactiveJournalRetirer? inactiveJournalRetirer,
    DeviceRecoveryTerminalJournalSynchronizer? terminalJournalSynchronizer,
    LocalRecoveryJournalProbe? activeJournalProbe,
    Duration registrationRetryDelay = const Duration(seconds: 2),
    int maxRegistrationRetries = 3,
    Duration recoveryRetryDelay = const Duration(seconds: 1),
    int maxRecoveryRetries = 5,
  }) : _commands = commands,
       _localReset = localReset,
       _coordinator = coordinator,
       _recoverySessionGuard = recoverySessionGuard,
       _ref = ref,
       _installationIdReader =
           installationIdReader ??
           SharedPreferencesNotificationInstallationIdStore().read,
       _foregroundMessages = foregroundMessages,
       _terminalJournalMarker =
           terminalJournalMarker ?? markCrashDurableIsarRecoveryJournalTerminal,
       _inactiveJournalRetirer =
           inactiveJournalRetirer ??
           markInactiveCrashDurableIsarRecoveryJournalsTerminal,
       _terminalJournalSynchronizer =
           terminalJournalSynchronizer ??
           syncRetainedCrashDurableIsarRecoveryJournalEvidence,
       _activeJournalProbe =
           activeJournalProbe ?? hasActiveCrashDurableIsarRecoveryJournal,
       _registrationRetryDelay = registrationRetryDelay,
       _maxRegistrationRetries = maxRegistrationRetries,
       _recoveryRetryDelay = recoveryRetryDelay,
       _maxRecoveryRetries = maxRecoveryRetries;

  final DeviceRecoveryCommandService _commands;
  final DeviceLocalRecoveryResetService _localReset;
  final SyncCoordinator _coordinator;
  final LocalRecoverySessionGuard _recoverySessionGuard;
  final Ref _ref;
  final Future<String?> Function() _installationIdReader;
  final Stream<RemoteMessage>? _foregroundMessages;
  final DeviceRecoveryTerminalJournalMarker _terminalJournalMarker;
  final DeviceRecoveryInactiveJournalRetirer _inactiveJournalRetirer;
  final DeviceRecoveryTerminalJournalSynchronizer _terminalJournalSynchronizer;
  final LocalRecoveryJournalProbe _activeJournalProbe;
  final Duration _registrationRetryDelay;
  final int _maxRegistrationRetries;
  final Duration _recoveryRetryDelay;
  final int _maxRecoveryRetries;

  AppUser? _actor;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  Timer? _registrationRetry;
  Timer? _recoveryRetry;
  int _registrationRetries = 0;
  int _recoveryRetries = 0;
  String? _pendingRecoveryRequestId;
  bool _busy = false;
  bool _followUpRequested = false;
  bool _claimedRecoveryOnly = false;
  bool _claimProtectionHeld = false;
  int _generation = 0;

  void start(AppUser actor, {bool claimedRecoveryOnly = false}) {
    if (kIsWeb ||
        (!actor.isApproved && !claimedRecoveryOnly) ||
        (actor.isApproved && claimedRecoveryOnly)) {
      return;
    }
    try {
      _recoverySessionGuard.requireRecoveryCheck();
    } on LocalRecoverySessionEndingException {
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
    _clearRecoveryRetry();
    final subscription = _messageSubscription;
    _messageSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _actor = null;
    _busy = false;
    _followUpRequested = false;
    _claimedRecoveryOnly = false;
  }

  void dispose() {
    stop();
    _releaseClaimProtection();
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
    var claimAcknowledged = false;
    try {
      final installationId = await _installationIdReader();
      if (!_isCurrent(actor, generation)) return;
      if (installationId == null) {
        if (_scheduleRegistrationRetry()) return;
        await _terminalJournalSynchronizer();
        if (!_isCurrent(actor, generation)) return;
        final activeJournal = await _activeJournalProbe();
        if (!_isCurrent(actor, generation)) return;
        if (!activeJournal) {
          _recoverySessionGuard.completeRecoveryCheck();
          AppLogger.breadcrumb(
            'Device recovery startup check completed without registration',
            context: const {
              'app_area': 'device_recovery',
              'recovery_reason': 'no_registration_no_active_journal',
            },
          );
        }
        return;
      }
      if (expectedInstallationId != null &&
          expectedInstallationId != installationId) {
        return;
      }
      _registrationRetry?.cancel();
      _registrationRetry = null;
      _registrationRetries = 0;
      final request = await _commands.pollPending(
        actor: actor,
        installationId: installationId,
        claimedRecoveryOnly: claimedRecoveryOnly,
      );
      if (!_isCurrent(actor, generation)) return;
      await _inactiveJournalRetirer(
        targetUid: actor.uid,
        installationId: installationId,
        activeRequestId: request?.requestId,
      );
      if (!_isCurrent(actor, generation)) return;
      if (request == null) {
        _releaseClaimProtection();
        _clearRecoveryRetry();
        _recoverySessionGuard.completeRecoveryCheck();
        return;
      }
      activeRequest = request;
      claimAcknowledged = request.status == 'in_progress';
      _trackRecoveryRequest(request.requestId);
      _holdClaimProtection();
      _recoverySessionGuard.completeRecoveryCheck();

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
          claimAcknowledged = true;
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
          await _terminalJournalMarker(request.requestId);
          _releaseClaimProtection();
          _clearRecoveryRetry();
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
      if (activeRequest != null && _isCurrent(actor, generation)) {
        final failureReported =
            !error.dataMayHaveBeenCleared &&
            await _reportSafeFailure(
              actor,
              activeRequest,
              error,
              claimedRecoveryOnly: claimedRecoveryOnly,
            );
        if (failureReported) {
          _releaseClaimProtection();
          _clearRecoveryRetry();
        } else {
          _scheduleRecoveryRetry(actor, generation);
        }
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Administrator-authorized device recovery remains pending',
        error: error,
        stackTrace: stackTrace,
        context: const {'app_area': 'device_recovery'},
      );
      if (_claimProtectionHeld &&
          !claimAcknowledged &&
          _isDefinitiveClaimRejection(error)) {
        _releaseClaimProtection();
        _clearRecoveryRetry();
      } else if (_claimProtectionHeld || _isRetryableRecoveryError(error)) {
        _scheduleRecoveryRetry(actor, generation);
      }
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

  Future<bool> _reportSafeFailure(
    AppUser actor,
    DeviceRecoveryRequest request,
    DeviceRecoveryLocalResetException error, {
    required bool claimedRecoveryOnly,
  }) async {
    try {
      final installationId = await _installationIdReader();
      if (installationId != request.installationId) return false;
      await _commands.failReset(
        actor: actor,
        request: request,
        failureCode: error.reasonCode,
        claimedRecoveryOnly: claimedRecoveryOnly,
      );
      await _terminalJournalMarker(request.requestId);
      return true;
    } catch (reportError, stackTrace) {
      AppLogger.warning(
        'Device recovery failure receipt could not be recorded',
        error: reportError,
        stackTrace: stackTrace,
        context: const {'app_area': 'device_recovery'},
      );
      return false;
    }
  }

  bool _isCurrent(AppUser actor, int generation) =>
      _generation == generation && _actor?.uid == actor.uid;

  void _trackRecoveryRequest(String requestId) {
    if (_pendingRecoveryRequestId == requestId) return;
    _releaseClaimProtection();
    _clearRecoveryRetry();
    _pendingRecoveryRequestId = requestId;
  }

  void _holdClaimProtection() {
    if (_claimProtectionHeld) return;
    _recoverySessionGuard.beginRecovery();
    _claimProtectionHeld = true;
  }

  void _releaseClaimProtection() {
    if (!_claimProtectionHeld) return;
    _claimProtectionHeld = false;
    _recoverySessionGuard.endRecovery();
  }

  void _scheduleRecoveryRetry(AppUser actor, int generation) {
    final requestId = _pendingRecoveryRequestId;
    if (_recoveryRetry != null ||
        _recoveryRetries >= _maxRecoveryRetries ||
        !_isCurrent(actor, generation)) {
      return;
    }
    final delay = _recoveryRetryDelay * (1 << _recoveryRetries);
    _recoveryRetries++;
    _recoveryRetry = Timer(delay, () {
      _recoveryRetry = null;
      if (!_isCurrent(actor, generation) ||
          _pendingRecoveryRequestId != requestId) {
        return;
      }
      unawaited(checkNow(reason: 'claimed_recovery_retry'));
    });
  }

  bool _isRetryableRecoveryError(Object error) {
    if (error is DeviceRecoveryException) return false;
    if (error is FirebaseFunctionsException) {
      return const {
        'aborted',
        'cancelled',
        'deadline-exceeded',
        'internal',
        'unavailable',
        'unknown',
      }.contains(error.code);
    }
    return true;
  }

  bool _isDefinitiveClaimRejection(Object error) =>
      error is FirebaseFunctionsException && !_isRetryableRecoveryError(error);

  void _clearRecoveryRetry() {
    _recoveryRetry?.cancel();
    _recoveryRetry = null;
    _recoveryRetries = 0;
    _pendingRecoveryRequestId = null;
  }

  bool _scheduleRegistrationRetry() {
    if (_registrationRetry != null) return true;
    if (_registrationRetries >= _maxRegistrationRetries) return false;
    _registrationRetries++;
    _registrationRetry = Timer(_registrationRetryDelay, () {
      _registrationRetry = null;
      unawaited(checkNow(reason: 'device_registration_ready'));
    });
    return true;
  }
}

final deviceRecoveryListenerProvider = Provider<DeviceRecoveryListener>((ref) {
  final listener = DeviceRecoveryListener(
    commands: ref.watch(deviceRecoveryCommandServiceProvider),
    localReset: ref.watch(deviceLocalRecoveryResetServiceProvider),
    coordinator: ref.watch(syncCoordinatorProvider),
    recoverySessionGuard: ref.watch(localRecoverySessionGuardProvider),
    ref: ref,
  );
  ref.onDispose(listener.dispose);
  return listener;
});
