import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('67B.1 sync status indicator hardening contract', () {
    late String source;

    setUpAll(() {
      source =
          File(
            'lib/core/widgets/sync_status_indicator.dart',
          ).readAsStringSync();
    });

    test(
      'indicator owns health-panel state instead of using a file-global guard',
      () {
        expect(
          source,
          contains('class SyncStatusIndicator extends ConsumerStatefulWidget'),
        );
        expect(
          source,
          contains('ConsumerState<SyncStatusIndicator> createState()'),
        );
        expect(
          source,
          contains(
            'class _SyncStatusIndicatorState extends ConsumerState<SyncStatusIndicator>',
          ),
        );
        expect(source, contains('bool _isHealthPanelOpen = false;'));
        expect(source, contains('if (_isHealthPanelOpen) return;'));
        expect(source, contains('_isHealthPanelOpen = true;'));
        expect(source, contains('finally'));
        expect(source, contains('_isHealthPanelOpen = false;'));
        expect(
          source,
          isNot(contains('bool _isSyncHealthPanelOpen = false;')),
          reason:
              'The duplicate-sheet guard should be instance-scoped, not file-global.',
        );
      },
    );

    test('durable rejection provider uses a named recent-limit constant', () {
      expect(source, contains('const int _recentSyncRejectionLimit = 5;'));
      expect(source, contains('.limit(_recentSyncRejectionLimit)'));
      expect(
        source,
        isNot(contains('.limit(5)')),
        reason:
            'The recent rejection limit should not be magic-numbered inline.',
      );
    });

    test('resolve rejection dialog owns its TextEditingController', () {
      expect(source, contains('class _ResolveSyncRejectionDialog'));
      expect(source, contains('class _ResolveSyncRejectionDialogState'));
      expect(
        source,
        contains('late final TextEditingController _notesController'),
      );
      expect(
        source,
        contains(
          '_notesController = TextEditingController(text: widget.initialNote)',
        ),
      );
      expect(
        source,
        contains('_notesController.addListener(_handleNotesChanged)'),
      );
      expect(
        source,
        contains('_notesController.removeListener(_handleNotesChanged)'),
      );
      expect(source, contains('_notesController.dispose();'));
      expect(source, contains('ConstrainedBox('));
      expect(
        source,
        contains('constraints: const BoxConstraints(maxWidth: 520)'),
      );
      expect(source, contains('SingleChildScrollView('));
      expect(source, contains('textInputAction: TextInputAction.newline'));
      expect(
        source,
        isNot(contains('final notesController = TextEditingController')),
        reason:
            'The sync rejection note controller must be owned by the dialog State, not the caller awaiting showDialog.',
      );
    });

    test('resolve action requires a non-empty note before submitting', () {
      expect(
        source,
        contains('final canSubmit = _notesController.text.trim().isNotEmpty;'),
      );
      expect(
        source,
        matches(RegExp(r'onPressed:\s*canSubmit\s*\?')),
        reason:
            'The Mark resolved action must be disabled until the note is non-empty, regardless of formatter line breaks.',
      );
      expect(
        source,
        contains('Navigator.of(context).pop(_notesController.text.trim())'),
      );
      expect(source, contains("'Resolve retry-held sync rejection?'"));
      expect(source, contains("'Mark sync rejection reviewed?'"));
    });

    test(
      'caller awaits a typed dialog and checks context before resolving',
      () {
        expect(source, contains('await showDialog<String>('));
        expect(source, contains('if (!context.mounted) return;'));
        expect(source, contains('if (resolutionNotes == null) return;'));
        expect(source, contains('await _resolveSyncRejection('));
      },
    );

    test(
      'manual sync captures services before await and orders mounted checks safely',
      () {
        expect(
          source,
          contains('final coordinator = ref.read(syncCoordinatorProvider);'),
        );
        expect(
          source,
          contains(
            'final autoSyncService = ref.read(autoSyncServiceProvider);',
          ),
        );
        expect(source, contains('await coordinator.runFullSyncWithResult('));
        expect(source, contains('if (!mounted) return;'));
        expect(source, contains('autoSyncService.clearPendingTicketSync();'));
        expect(source, contains('ref.invalidate(syncPendingCountsProvider);'));
        expect(source, contains('if (!context.mounted) return;'));
        expect(source, contains('_showSyncSnack('));
        expect(source, contains('outcome.manualSyncMessage'));
        final coordinatorSource =
            File('lib/core/services/sync_coordinator.dart').readAsStringSync();
        expect(
          coordinatorSource,
          contains('Manual sync queued behind the sync already running.'),
        );
      },
    );

    test(
      'health panel and compact indicator expose queued follow-up sync state',
      () {
        expect(source, contains('runHealth.hasPendingFollowUp'));
        expect(source, contains("'Sync queued'"));
        expect(source, contains("'Pending follow-up'"));
        expect(source, contains('runHealth.pendingFollowUpForce'));
        expect(source, contains("'Follow-up reason'"));
        expect(source, contains('runHealth.pendingFollowUpReason'));
      },
    );
  });
}
