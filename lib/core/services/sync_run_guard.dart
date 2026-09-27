import 'package:firebase_core/firebase_core.dart';
import 'package:isar_community/isar.dart';

import '../../features/abnormalities/services/charge_abnormality_command_service.dart';
import '../../features/maintenance_workflow/domain/workflow_error.dart';
import '../../features/planned_maintenance/services/runtime_job_module_population_service.dart';

/// A whole-run safety boundary, not a rejected business record.
class SyncRunAborted implements Exception {
  final String reason;

  const SyncRunAborted(this.reason);

  @override
  String toString() => switch (reason) {
    'account-authority-unconfirmed' =>
      'Sync paused until your current account access is verified.',
    'account-or-authority-changed' =>
      'Sync stopped because your account or permissions changed.',
    'run-owner-ended' => 'Sync stopped because this session ended.',
    'local-storage-unavailable' =>
      'Sync stopped because local storage is unavailable. Saved work has not been cleared.',
    'unauthenticated' => 'Sign in again to resume synchronization.',
    'data-loss' => 'Sync stopped because data integrity could not be verified.',
    _ => 'Sync stopped: $reason',
  };
}

/// Once invalidated, a run cannot resume even if the same account signs back in.
class SyncRunGuard {
  final void Function() _checkCurrent;
  SyncRunAborted? _aborted;

  SyncRunGuard(this._checkCurrent);

  void checkCurrent() {
    final aborted = _aborted;
    if (aborted != null) throw aborted;
    try {
      _checkCurrent();
    } on SyncRunAborted catch (error) {
      _aborted = error;
      rethrow;
    }
  }
}

/// Domain isolation must never turn unusable storage or a lost session into a
/// recoverable row failure. Ordinary permission denials remain domain failures:
/// they can reject one operation without invalidating the signed-in account.
void rethrowIfSyncRunMustAbort(Object error) {
  if (error is SyncRunAborted || error is IsarError) throw error;
  final code = switch (error) {
    FirebaseException e => e.code,
    ChargeAbnormalityMutationException e => e.code,
    RuntimeJobModulePopulationException e => e.code,
    WorkflowException e when e.code == WorkflowErrorCode.unauthenticated =>
      'unauthenticated',
    _ => null,
  };
  if (code == 'unauthenticated' || code == 'data-loss') {
    throw SyncRunAborted(code!);
  }
}
