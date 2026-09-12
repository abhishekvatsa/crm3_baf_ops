import 'dart:io';

import 'package:crm3_baf_ops/features/admin/services/local_diagnostics_read_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

/// The workflow command journal is not a business collection and carries no
/// `isSynced` flag, so it never appeared in the dirty-row inventory. A queue of
/// unfinished lifecycle commands could therefore sit behind a reassuring
/// "0 unsynced rows".
///
/// The counts are read by matching `stateKey` string literals. If those values
/// drift in the record and not in the adapter, every count silently becomes
/// zero — which reads as "nothing pending" rather than as a broken query. These
/// tests bind the two sides together.
void main() {
  group('workflow command journal diagnostics coverage', () {
    const states = <String>[
      'ready',
      'sending',
      'uncertainOutcome',
      'applied',
      'rejected',
      'manualReview',
    ];

    test('the record still declares exactly the documented state values', () {
      final source =
          File(
            'lib/features/maintenance_workflow/data/workflow_command_record.dart',
          ).readAsStringSync();

      for (final state in states) {
        expect(
          source,
          contains(state),
          reason:
              'WorkflowCommandRecord no longer mentions "$state". If a state '
              'was renamed or removed, update the adapter queries too.',
        );
      }
    });

    test('the adapter counts every declared state', () {
      final source =
          File(
            'lib/features/admin/services/local_diagnostics_read_adapter.dart',
          ).readAsStringSync();

      for (final state in states) {
        expect(
          source,
          contains("'$state'"),
          reason:
              'The diagnostics adapter does not count "$state" commands, so '
              'they would be invisible to support.',
        );
      }
      expect(source, contains('workflowCommandRecords'));
      expect(source, contains('stateKeyEqualTo'));
    });

    test('unfinished counts every non-terminal state', () {
      const snapshot = LocalDiagnosticsCommandJournalSnapshot(
        ready: 1,
        sending: 2,
        uncertainOutcome: 4,
        manualReview: 8,
        applied: 16,
        rejected: 32,
        total: 63,
      );

      // Only applied and rejected are terminal.
      expect(snapshot.unfinished, 1 + 2 + 4 + 8);
      expect(snapshot.unresolvedOutcome, 4 + 8);
    });

    test('an empty journal reports nothing outstanding', () {
      const snapshot = LocalDiagnosticsCommandJournalSnapshot.empty();

      expect(snapshot.unfinished, 0);
      expect(snapshot.unresolvedOutcome, 0);
      expect(snapshot.total, 0);
    });

    test('a fully settled journal reports nothing outstanding', () {
      const snapshot = LocalDiagnosticsCommandJournalSnapshot(
        ready: 0,
        sending: 0,
        uncertainOutcome: 0,
        manualReview: 0,
        applied: 9,
        rejected: 3,
        total: 12,
      );

      expect(snapshot.unfinished, 0);
      expect(snapshot.unresolvedOutcome, 0);
    });

    test('the diagnostics screen surfaces and exports the journal', () {
      final source =
          File(
            'lib/features/admin/presentation/local_diagnostics_screen.dart',
          ).readAsStringSync();

      expect(source, contains('unfinished commands'));
      expect(source, contains('outcome unknown'));
      expect(source, contains("'workflowCommandJournal'"));
      expect(source, contains('workflowCommandsUncertainOutcome'));
    });
  });
}
