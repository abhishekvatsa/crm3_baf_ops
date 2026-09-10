import 'dart:io';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A run could finish with SyncStatus.success and lastSucceeded true while a
/// submitted command sat rejected or awaiting review. The retry summary was
/// logged, but it never reached the decision the operator actually sees.
///
/// These cover the carrier only - that the field survives a copyWith and that
/// the indicator ranks it correctly. Whether attention is still *calculated*
/// on a later run is a different question, and asserting copyWith could never
/// have answered it: see workflow_attention_persistence_test.dart, which runs
/// the real journal twice.
///
/// The two facts are deliberately separate: a data refresh completing is not
/// the same as submitted work having landed, and collapsing them would either
/// hide the work or call the whole sync a failure.
void main() {
  group('workflow attention is carried, not collapsed', () {
    test('it is preserved unless explicitly cleared', () {
      const health = SyncRunHealth(
        workflowAttentionReason: 'Submitted workflow work needs attention: 1 rejected',
      );

      // A later quiet run must not silently drop outstanding work from view.
      final afterQuietRun = health.copyWith(lastSucceeded: true);
      expect(afterQuietRun.needsWorkflowAttention, isTrue);
      expect(afterQuietRun.workflowAttentionReason, health.workflowAttentionReason);

      final afterResolution = health.copyWith(clearWorkflowAttention: true);
      expect(afterResolution.needsWorkflowAttention, isFalse);
    });

    test('a successful data plane can still carry attention', () {
      const health = SyncRunHealth(
        lastSucceeded: true,
        workflowAttentionReason: 'Submitted workflow work needs attention: 1 awaiting resolution',
      );

      expect(health.lastSucceeded, isTrue);
      expect(health.needsWorkflowAttention, isTrue);
    });

    test('no attention means no attention', () {
      const health = SyncRunHealth(lastSucceeded: true);
      expect(health.needsWorkflowAttention, isFalse);
    });
  });

  group('the coordinator and indicator honour it', () {
    test('attention is taken from the journal, not just this run', () {
      // getPendingCommands excludes rejected rows, so it cannot be the source
      // of attention - that exclusion is what made a rejection vanish.
      final source =
          File('lib/core/services/sync_coordinator.dart').readAsStringSync();

      expect(source, contains('readOutcomeInventory()'));
      expect(source, isNot(contains('getPendingCommands()')));
      expect(source, contains('describeWorkflowAttention'));
      expect(source, contains('workflowAttentionReason: _workflowAttentionReason'));
      expect(source, contains('clearWorkflowAttention:'));
    });

    test('the indicator shows it without calling the sync a failure', () {
      final source =
          File('lib/core/widgets/sync_status_indicator.dart').readAsStringSync();

      expect(source, contains("label: 'Action needed'"));
      expect(source, contains('runHealth.needsWorkflowAttention'));
      // Conflicts and a real failure still outrank it.
      expect(
        source.indexOf("label: 'Sync issue'"),
        lessThan(source.indexOf('runHealth.needsWorkflowAttention')),
      );
    });
  });
}
