import 'dart:async';
import 'dart:convert';

/// Read-only state of the one original command exercised by the RED journey.
class RequiredRedRetrySnapshot {
  const RequiredRedRetrySnapshot({
    this.hasReceipt = false,
    this.stateKey,
    this.attemptCount,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.lastErrorCode,
  });

  final bool hasReceipt;
  final String? stateKey;
  final int? attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? nextRetryAt;
  final String? lastErrorCode;

  bool isDue(DateTime now) =>
      !hasReceipt &&
      stateKey == 'uncertainOutcome' &&
      nextRetryAt != null &&
      !nextRetryAt!.isAfter(now);

  Map<String, Object?> toJson() => {
    'hasReceipt': hasReceipt,
    'stateKey': stateKey,
    'attemptCount': attemptCount,
    'lastAttemptAt': lastAttemptAt?.toUtc().toIso8601String(),
    'nextRetryAt': nextRetryAt?.toUtc().toIso8601String(),
    'lastErrorCode': lastErrorCode,
  };
}

/// Drives normal UI sync only for a currently due journal entry.
///
/// Startup can already be sending the command when the relay is released. Its
/// failure may move the deadline after an earlier journal read. Re-read after
/// each asynchronous wait, including the UI's final pointer-readiness wait.
/// This helper never changes the journal, production backoff or claim lease.
Future<void> waitForRequiredRedReceipt({
  required Future<RequiredRedRetrySnapshot> Function() readCurrent,
  required DateTime Function() now,
  required Future<void> Function() wait,
  required Future<bool> Function(Future<bool> Function() canTap) syncThroughUi,
  required void Function(Map<String, Object?> observation) onObservation,
  Duration timeout = const Duration(minutes: 3),
  int maxSyncAttempts = 3,
}) async {
  if (timeout <= Duration.zero || maxSyncAttempts < 1) {
    throw ArgumentError(
      'A finite positive wait and UI attempt limit are required.',
    );
  }
  final started = now();
  final deadline = started.add(timeout);
  var syncAttempts = 0;
  var observations = 0;
  String? lastObserved;
  String? lastRequested;
  RequiredRedRetrySnapshot? latest;

  Map<String, Object?> diagnostics(String phase) => {
    'phase': phase,
    'elapsedMilliseconds': now().difference(started).inMilliseconds,
    'syncAttempts': syncAttempts,
    'lastState': latest?.toJson(),
  };

  Future<RequiredRedRetrySnapshot> observe() async {
    final value = await readCurrent();
    latest = value;
    final fingerprint = jsonEncode(value.toJson());
    if (fingerprint != lastObserved && observations < 24) {
      onObservation(diagnostics('journal'));
      observations++;
      lastObserved = fingerprint;
    }
    if (!value.hasReceipt &&
        (value.stateKey != 'sending' && value.stateKey != 'uncertainOutcome')) {
      throw StateError(
        'Original RED command is missing or terminal: '
        '${jsonEncode(diagnostics('not-retryable'))}',
      );
    }
    if (!value.hasReceipt &&
        value.stateKey == 'uncertainOutcome' &&
        value.nextRetryAt == null) {
      throw StateError(
        'Original RED command has no durable retry deadline: '
        '${jsonEncode(diagnostics('missing-deadline'))}',
      );
    }
    return value;
  }

  while (now().isBefore(deadline)) {
    final current = await observe();
    if (current.hasReceipt) return;
    if (current.isDue(now()) && jsonEncode(current.toJson()) != lastRequested) {
      if (syncAttempts >= maxSyncAttempts) {
        throw StateError(
          'RED replay exceeded the bounded UI attempt limit: '
          '${jsonEncode(diagnostics('attempt-limit'))}',
        );
      }
      String? requested;
      final tapped = await syncThroughUi(() async {
        // This callback runs after navigation and pointer-readiness waits.
        final fresh = await observe();
        if (!now().isBefore(deadline) ||
            !fresh.isDue(now()) ||
            jsonEncode(fresh.toJson()) == lastRequested) {
          return false;
        }
        requested = jsonEncode(fresh.toJson());
        return true;
      });
      if (tapped) {
        lastRequested = requested;
        syncAttempts++;
        onObservation(diagnostics('ui-sync'));
      }
    }
    await wait();
  }
  onObservation(diagnostics('timeout'));
  throw TimeoutException(
    'Original RED receipt did not settle within the bounded live-journal wait: '
    '${jsonEncode(diagnostics('timeout'))}',
    timeout,
  );
}
