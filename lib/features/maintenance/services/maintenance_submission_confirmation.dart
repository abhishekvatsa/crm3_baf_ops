import 'dart:async';

import '../../../core/services/sync_coordinator.dart';
import '../data/maintenance_model.dart';

/// Observes canonical local adoption without bypassing the shared sync lock.
/// The wait limit bounds the form, not the background sync or its retries.
Future<bool> waitForMaintenanceIssueAcceptance({
  required MaintenanceRecord submitted,
  required Stream<List<MaintenanceRecord>> ticketUpdates,
  required Future<MaintenanceRecord?> Function() readTicket,
  required Future<SyncRequestOutcome> Function() requestSync,
  Duration waitLimit = const Duration(seconds: 8),
}) async {
  final ticketId = submitted.firestoreId;
  if (ticketId == null || ticketId.isEmpty) {
    throw ArgumentError('A durably saved ticket identity is required.');
  }
  final submittedVersion = submitted.version;
  final result = Completer<bool>();
  void finish(bool accepted) {
    if (!result.isCompleted) result.complete(accepted);
  }

  bool isAccepted(MaintenanceRecord? row) =>
      row != null &&
      row.firestoreId == ticketId &&
      row.assetType == submitted.assetType &&
      row.assetNumber == submitted.assetNumber &&
      row.isSynced &&
      !row.isDeleted &&
      row.version >= submittedVersion;

  final timer = Timer(waitLimit, () => finish(false));
  StreamSubscription<List<MaintenanceRecord>>? subscription;
  try {
    try {
      subscription = ticketUpdates.listen(
        (rows) {
          if (rows.any(isAccepted)) finish(true);
        },
        // A broken observer is not evidence of server rejection. Readback
        // after the sync, or the bounded pending result, remains available.
        onError: (Object _, StackTrace __) {},
      );
    } catch (_) {
      // Still request the centrally serialized sync if observation fails.
    }
    unawaited(() async {
      try {
        final outcome = await requestSync();
        if (result.isCompleted || outcome == SyncRequestOutcome.queued) return;
        finish(isAccepted(await readTicket()));
      } catch (_) {
        finish(false);
      }
    }());
    return await result.future;
  } finally {
    timer.cancel();
    try {
      await subscription?.cancel();
    } catch (_) {
      // Observer cleanup cannot turn an accepted save into a failed submission.
    }
  }
}
