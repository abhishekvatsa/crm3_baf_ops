import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('66F sync coordinator queue contract', () {
    test(
      'running sync requests queue one follow-up instead of being dropped',
      () {
        final source =
            File('lib/core/services/sync_coordinator.dart').readAsStringSync();

        expect(source, contains('bool _followUpRequested = false'));
        expect(source, contains('String? _followUpReason'));
        expect(source, contains('bool _followUpForce = false'));
        expect(
          source,
          contains('bool _followUpRecheckPermanentRejections = false'),
        );
        expect(
          source,
          contains('recheckPermanentRejections: recheckPermanentRejections'),
        );
        expect(source, contains('return SyncRequestOutcome.queued'));
        expect(
          source,
          contains("lastSkippedReason: '\$reason (queued while running)'"),
        );
        expect(source, contains("'sync_followup_pending': true"));
        expect(source, contains("_runFullSync("));
        expect(source, contains("queuedFollowUp: true"));
      },
    );

    test('queued rejection recheck preserves typed intent', () {
      final source =
          File('lib/core/services/sync_coordinator.dart').readAsStringSync();

      expect(
        source,
        contains(
          "recheckPermanentRejections: reason == 'manual_rejection_recheck'",
        ),
      );
      expect(
        source,
        contains(
          '_followUpRecheckPermanentRejections || recheckPermanentRejections',
        ),
      );
      expect(
        source,
        contains(
          'recheckPermanentRejections: _followUpRecheckPermanentRejections',
        ),
      );
      expect(source, contains('followUp.recheckPermanentRejections'));
      expect(
        source,
        isNot(
          contains(
            "recheckPermanentRejections: reason == 'manual_rejection_recheck (queued follow-up)'",
          ),
        ),
      );
    });

    test(
      'queued follow-up bypasses throttle but keeps normal throttle intact',
      () {
        final source =
            File('lib/core/services/sync_coordinator.dart').readAsStringSync();

        expect(
          source,
          contains(
            'if (!force && !queuedFollowUp && now.difference(_lastRun) < minGap)',
          ),
        );
        expect(source, contains('return SyncRequestOutcome.throttled'));
        expect(
          source,
          contains("reason: '\${followUp.reason} (queued follow-up)'"),
        );
        expect(source, contains('force: followUp.force'));
      },
    );

    test('sync health exposes pending follow-up diagnostics', () {
      final coordinatorSource =
          File('lib/core/services/sync_coordinator.dart').readAsStringSync();
      final diagnosticsSource =
          File(
            'lib/features/admin/presentation/local_diagnostics_screen.dart',
          ).readAsStringSync();

      expect(coordinatorSource, contains('final bool hasPendingFollowUp'));
      expect(
        coordinatorSource,
        contains('final String? pendingFollowUpReason'),
      );
      expect(coordinatorSource, contains('final bool pendingFollowUpForce'));
      expect(coordinatorSource, contains('clearPendingFollowUp'));
      expect(diagnosticsSource, contains('syncHasPendingFollowUp'));
      expect(diagnosticsSource, contains('syncPendingFollowUpReason'));
      expect(diagnosticsSource, contains('syncPendingFollowUpSummary'));
      expect(diagnosticsSource, contains("label: 'Pending follow-up sync'"));
    });

    test(
      'restricted revoked-account recovery never schedules business sync',
      () {
        final coordinator =
            File('lib/core/services/sync_coordinator.dart').readAsStringSync();
        final listener =
            File(
              'lib/features/admin/services/device_recovery_listener.dart',
            ).readAsStringSync();

      expect(coordinator, contains('bool resumeSyncAfterRecovery = true'));
      expect(coordinator, contains('if (resumeSyncAfterRecovery)'));
      expect(
        listener,
        contains('resumeSyncAfterRecovery: !claimedRecoveryOnly'),
      );
      },
    );
  });
}
