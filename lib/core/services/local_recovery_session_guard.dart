import 'package:flutter_riverpod/flutter_riverpod.dart';

final class LocalRecoverySignOutBlockedException implements Exception {
  const LocalRecoverySignOutBlockedException();

  static const message =
      'Protected local recovery is in progress. Wait for it to finish before signing out.';

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
  int _recoveryDepth = 0;
  bool _sessionEndReserved = false;

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

  void beginSessionEnd() {
    if (_recoveryDepth > 0) {
      throw const LocalRecoverySignOutBlockedException();
    }
    if (_sessionEndReserved) {
      throw StateError('Sign-out is already in progress.');
    }
    _sessionEndReserved = true;
  }

  void endSessionEnd() {
    _sessionEndReserved = false;
  }
}

final localRecoverySessionGuardProvider = Provider<LocalRecoverySessionGuard>(
  (ref) => LocalRecoverySessionGuard(),
);
