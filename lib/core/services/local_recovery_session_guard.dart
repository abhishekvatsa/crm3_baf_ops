import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'isar_production_recovery.dart';

typedef LocalRecoveryJournalProbe = Future<bool> Function();

final class LocalRecoverySignOutBlockedException implements Exception {
  const LocalRecoverySignOutBlockedException();

  static const message =
      'Protected local recovery is being checked or is in progress. Wait for it to finish before signing out.';

  @override
  String toString() => message;
}

final class LocalRecoverySessionEndingException implements Exception {
  const LocalRecoverySessionEndingException();

  @override
  String toString() =>
      'Local recovery cannot begin while the signed-in session is ending.';
}

final class LocalRecoverySessionGuard {
  LocalRecoverySessionGuard({LocalRecoveryJournalProbe? startupRecoveryProbe})
    : _startupRecoveryProbe = startupRecoveryProbe;

  final LocalRecoveryJournalProbe? _startupRecoveryProbe;
  int _recoveryDepth = 0;
  bool _recoveryCheckRequired = false;
  bool _serverRecoveryCheckCompleted = false;
  bool _startupProbeCompleted = false;
  Future<void>? _startupProbeInFlight;
  bool _sessionEndReserved = false;

  void requireRecoveryCheck() {
    if (_sessionEndReserved) {
      throw const LocalRecoverySessionEndingException();
    }
    _serverRecoveryCheckCompleted = false;
    _recoveryCheckRequired = true;
  }

  void completeRecoveryCheck() {
    _serverRecoveryCheckCompleted = true;
    _recoveryCheckRequired = false;
  }

  bool get isRecoveryProtectionActive =>
      _recoveryCheckRequired || _recoveryDepth > 0;

  void beginRecovery() {
    if (_sessionEndReserved) {
      throw const LocalRecoverySessionEndingException();
    }
    _recoveryDepth++;
  }

  void endRecovery() {
    if (_recoveryDepth == 0) {
      throw StateError('No protected local recovery lease is active.');
    }
    _recoveryDepth--;
  }

  Future<void> beginSessionEnd() async {
    await _ensureStartupRecoveryState();
    if (isRecoveryProtectionActive) {
      throw const LocalRecoverySignOutBlockedException();
    }
    if (_sessionEndReserved) {
      throw StateError('Sign-out is already in progress.');
    }
    _sessionEndReserved = true;
  }

  Future<void> _ensureStartupRecoveryState() {
    if (_startupProbeCompleted || _startupRecoveryProbe == null) {
      return Future<void>.value();
    }
    return _startupProbeInFlight ??= _readStartupRecoveryState();
  }

  Future<void> _readStartupRecoveryState() async {
    final probe = _startupRecoveryProbe;
    if (probe == null) return;
    try {
      final activeJournal = await probe();
      if (!_serverRecoveryCheckCompleted && activeJournal) {
        _recoveryCheckRequired = true;
      }
    } catch (_) {
      if (!_serverRecoveryCheckCompleted) {
        _recoveryCheckRequired = true;
      }
    } finally {
      _startupProbeCompleted = true;
    }
  }

  void endSessionEnd() {
    _sessionEndReserved = false;
  }
}

final localRecoverySessionGuardProvider = Provider<LocalRecoverySessionGuard>(
  (ref) => LocalRecoverySessionGuard(
    startupRecoveryProbe:
        crashDurableIsarRecoveryJournalSupported
            ? hasActiveCrashDurableIsarRecoveryJournal
            : null,
  ),
);
