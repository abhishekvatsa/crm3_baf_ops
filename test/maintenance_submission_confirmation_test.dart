import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_submission_confirmation.dart';
import 'package:flutter_test/flutter_test.dart';

MaintenanceRecord _ticket({String id = 'issue-1', bool synced = false}) =>
    MaintenanceRecord()
      ..firestoreId = id
      ..assetType = AssetType.furnace
      ..assetNumber = 3
      ..version = 1
      ..isSynced = synced;

void main() {
  test('observer cleanup failure cannot relabel an accepted issue', () async {
    final updates = StreamController<List<MaintenanceRecord>>(
      onCancel: () => throw StateError('Observer already closed'),
    );
    final completion = waitForMaintenanceIssueAcceptance(
      submitted: _ticket(),
      ticketUpdates: updates.stream,
      readTicket: () async => _ticket(synced: true),
      requestSync: () async => SyncRequestOutcome.queued,
    );
    updates.add([_ticket(synced: true)]);
    expect(await completion, isTrue);
    await updates.close();
  });

  test(
    'acceptance releases form before unrelated full sync finishes',
    () async {
      final updates = StreamController<List<MaintenanceRecord>>();
      final sync = Completer<SyncRequestOutcome>();
      bool? accepted;
      var requests = 0;
      var reads = 0;
      final completion = waitForMaintenanceIssueAcceptance(
        submitted: _ticket(),
        ticketUpdates: updates.stream,
        readTicket: () async {
          reads++;
          return null;
        },
        requestSync: () {
          requests++;
          return sync.future;
        },
      ).then((value) => accepted = value);
      await Future<void>.delayed(Duration.zero);
      expect(accepted, isNull);
      updates.add([_ticket(synced: true)..version = 3]);
      await completion.timeout(const Duration(seconds: 1));
      expect(accepted, isTrue);
      expect(sync.isCompleted, isFalse);
      expect(updates.hasListener, isFalse);
      expect(requests, 1);
      sync.completeError(StateError('An unrelated later sync failed'));
      await Future<void>.delayed(Duration.zero);
      expect(reads, 0);
      await updates.close();
    },
  );

  test(
    'pending timeout does not cancel or duplicate background sync',
    () async {
      final updates = StreamController<List<MaintenanceRecord>>();
      final sync = Completer<SyncRequestOutcome>();
      bool? accepted;
      var requests = 0;
      final completion = waitForMaintenanceIssueAcceptance(
        submitted: _ticket(),
        ticketUpdates: updates.stream,
        waitLimit: const Duration(milliseconds: 50),
        readTicket: () async => throw StateError('Must not read after timeout'),
        requestSync: () {
          requests++;
          return sync.future;
        },
      ).then((value) => accepted = value);
      updates.add([
        _ticket(),
        _ticket(id: 'other', synced: true),
        _ticket(synced: true)..version = 0,
        _ticket(synced: true)..isDeleted = true,
        _ticket(synced: true)..assetNumber = 4,
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(accepted, isNull);
      await completion.timeout(const Duration(seconds: 1));
      expect(accepted, isFalse);
      expect(updates.hasListener, isFalse);
      expect(sync.isCompleted, isFalse);
      expect(requests, 1);
      sync.complete(SyncRequestOutcome.succeeded);
      await Future<void>.delayed(Duration.zero);
      expect(accepted, isFalse);
      await updates.close();
    },
  );

  test(
    'queued sync can still confirm through canonical local adoption',
    () async {
      final updates = StreamController<List<MaintenanceRecord>>();
      bool? accepted;
      final completion = waitForMaintenanceIssueAcceptance(
        submitted: _ticket(),
        ticketUpdates: updates.stream,
        readTicket: () async => throw StateError('Queued work is not finished'),
        requestSync: () async => SyncRequestOutcome.queued,
      ).then((value) => accepted = value);
      await Future<void>.delayed(Duration.zero);
      expect(accepted, isNull);
      updates.add([_ticket(synced: true)]);
      await completion.timeout(const Duration(seconds: 1));
      expect(accepted, isTrue);
      await updates.close();
    },
  );

  for (final outcome in SyncRequestOutcome.values.where(
    (value) => value != SyncRequestOutcome.queued,
  )) {
    for (final synced in [true, false]) {
      test(
        '$outcome uses ticket readback, not global success ($synced)',
        () async {
          final result = waitForMaintenanceIssueAcceptance(
            submitted: _ticket(),
            ticketUpdates: Stream.error(StateError('Observer unavailable')),
            readTicket: () async => _ticket(synced: synced),
            requestSync: () async => outcome,
          );
          expect(await result, synced);
        },
      );
    }
  }

  test('request exception preserves pending status without escaping', () async {
    final result = waitForMaintenanceIssueAcceptance(
      submitted: _ticket(),
      ticketUpdates: const Stream.empty(),
      readTicket: () async => null,
      requestSync: () => throw StateError('Offline'),
    );
    expect(await result, isFalse);
  });
}
