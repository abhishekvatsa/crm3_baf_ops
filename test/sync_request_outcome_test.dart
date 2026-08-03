import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R-03 sync request outcomes', () {
    test('success and failure are completed terminal outcomes', () {
      expect(SyncRequestOutcome.succeeded.isSuccessful, isTrue);
      expect(SyncRequestOutcome.succeeded.isFailure, isFalse);
      expect(SyncRequestOutcome.succeeded.isDeferred, isFalse);

      expect(SyncRequestOutcome.failed.isSuccessful, isFalse);
      expect(SyncRequestOutcome.failed.isFailure, isTrue);
      expect(SyncRequestOutcome.failed.isDeferred, isFalse);
    });

    test('queued and throttled requests are deferred, not failed', () {
      for (final outcome in <SyncRequestOutcome>[
        SyncRequestOutcome.queued,
        SyncRequestOutcome.throttled,
      ]) {
        expect(outcome.isSuccessful, isFalse);
        expect(outcome.isFailure, isFalse);
        expect(outcome.isDeferred, isTrue);
      }
    });

    test('diagnostic labels preserve all four states', () {
      expect(SyncRequestOutcome.succeeded.diagnosticLabel, 'Success');
      expect(SyncRequestOutcome.failed.diagnosticLabel, 'Failed');
      expect(SyncRequestOutcome.queued.diagnosticLabel, 'Queued');
      expect(SyncRequestOutcome.throttled.diagnosticLabel, 'Throttled');
    });

    test(
      'manual feedback names deferred outcomes without calling them failures',
      () {
        expect(
          SyncRequestOutcome.queued.manualSyncMessage,
          'Manual sync queued behind the sync already running.',
        );
        expect(
          SyncRequestOutcome.throttled.manualSyncMessage,
          'Manual sync skipped because another sync completed recently.',
        );
        expect(
          SyncRequestOutcome.queued.manualSyncMessage,
          isNot(contains('fail')),
        );
        expect(
          SyncRequestOutcome.throttled.manualSyncMessage,
          isNot(contains('fail')),
        );
      },
    );
  });
}
