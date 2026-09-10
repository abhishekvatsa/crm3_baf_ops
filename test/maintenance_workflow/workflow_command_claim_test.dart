import 'dart:io';

import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../tool/test_support/test_isar_core.dart';

/// A retained command may already have reached the server, so replaying it is
/// how the app finds out. Replaying it *twice* is how one physical action
/// becomes two records: two tickets for one fault, two people assigned, two
/// replacements counted against a component that was fitted once.
///
/// `getRetryableCommands` answers "what is due" and hands the same rows to
/// every caller. That was safe while one engine ran in one process. These
/// tests cover the claim that keeps it safe once a second execution context
/// exists.
void main() {
  late Isar isar;
  late IsarWorkflowRepository repository;
  late Directory directory;

  setUpAll(initializeTestIsarCore);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('workflow_claim_test_');
    isar = await Isar.open(
      [WorkflowCommandRecordSchema],
      directory: directory.path,
      name: 'workflow_claim_test',
      inspector: false,
    );
    repository = IsarWorkflowRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  final now = DateTime.utc(2026, 9, 10, 7, 12);
  const lease = Duration(minutes: 5);

  Future<void> seed({
    required String commandId,
    required String stateKey,
    DateTime? nextRetryAt,
    DateTime? lastAttemptAt,
    DateTime? createdAt,
  }) async {
    await repository.saveRetryCommand(
      WorkflowCommandRecord()
        ..commandId = commandId
        ..aggregateId = 'furnace-6-burner-5'
        ..commandTypeKey = 'raiseCriticalAlarm'
        ..stateKey = stateKey
        ..nextRetryAt = nextRetryAt
        ..lastAttemptAt = lastAttemptAt
        ..createdLocallyAt = createdAt ?? now.subtract(const Duration(hours: 1)),
    );
  }

  Future<String?> stateOf(String commandId) async =>
      (await repository.getRetryCommand(commandId))?.stateKey;

  group('claiming a due command', () {
    test('a due command is claimed and marked as being sent', () async {
      await seed(
        commandId: 'cmd-1',
        stateKey: 'uncertainOutcome',
        nextRetryAt: now.subtract(const Duration(minutes: 1)),
      );

      final claimed = await repository.claimRetryableCommands(
        now: now,
        lease: lease,
      );

      expect(claimed.map((r) => r.commandId), <String>['cmd-1']);
      expect(await stateOf('cmd-1'), 'sending');
    });

    test('a second caller gets nothing for the same command', () async {
      await seed(
        commandId: 'cmd-1',
        stateKey: 'uncertainOutcome',
        nextRetryAt: now.subtract(const Duration(minutes: 1)),
      );

      final first = await repository.claimRetryableCommands(
        now: now,
        lease: lease,
      );
      final second = await repository.claimRetryableCommands(
        now: now,
        lease: lease,
      );

      // This is the whole point: one physical action, one submission.
      expect(first, hasLength(1));
      expect(second, isEmpty);
    });

    test('concurrent callers between them claim each command once', () async {
      for (var index = 0; index < 5; index++) {
        await seed(
          commandId: 'cmd-$index',
          stateKey: 'uncertainOutcome',
          nextRetryAt: now.subtract(const Duration(minutes: 1)),
          createdAt: now.subtract(Duration(hours: 2, minutes: index)),
        );
      }

      final results = await Future.wait(<Future<List<WorkflowCommandRecord>>>[
        repository.claimRetryableCommands(now: now, lease: lease),
        repository.claimRetryableCommands(now: now, lease: lease),
        repository.claimRetryableCommands(now: now, lease: lease),
      ]);

      final ids = <String>[
        for (final batch in results) ...batch.map((r) => r.commandId),
      ];

      expect(ids, hasLength(5));
      expect(ids.toSet(), hasLength(5));
    });

    test('a command not yet due is left alone', () async {
      await seed(
        commandId: 'cmd-later',
        stateKey: 'uncertainOutcome',
        nextRetryAt: now.add(const Duration(minutes: 4)),
      );

      expect(
        await repository.claimRetryableCommands(now: now, lease: lease),
        isEmpty,
      );
      expect(await stateOf('cmd-later'), 'uncertainOutcome');
    });

    test('terminal commands are never re-claimed', () async {
      // A rejected or manually-flagged command has an answer. Replaying it
      // would either duplicate accepted work or re-run a decision a person
      // was asked to make.
      for (final state in <String>['rejected', 'manualReview', 'applied']) {
        await seed(
          commandId: 'cmd-$state',
          stateKey: state,
          nextRetryAt: now.subtract(const Duration(minutes: 1)),
        );
      }

      expect(
        await repository.claimRetryableCommands(now: now, lease: lease),
        isEmpty,
      );
    });
  });

  group('a caller that dies mid-send', () {
    test('an expired claim is offered again', () async {
      await seed(
        commandId: 'cmd-stranded',
        stateKey: 'sending',
        lastAttemptAt: now.subtract(const Duration(minutes: 30)),
      );

      final claimed = await repository.claimRetryableCommands(
        now: now,
        lease: lease,
      );

      expect(claimed.map((r) => r.commandId), <String>['cmd-stranded']);
    });

    test('a claim still within its lease is not stolen', () async {
      // The other caller may still be waiting on the callable. Taking it now
      // is exactly how the duplicate happens.
      await seed(
        commandId: 'cmd-inflight',
        stateKey: 'sending',
        lastAttemptAt: now.subtract(const Duration(minutes: 1)),
      );

      expect(
        await repository.claimRetryableCommands(now: now, lease: lease),
        isEmpty,
      );
    });

    test('claiming does not consume the retry budget', () async {
      await seed(
        commandId: 'cmd-1',
        stateKey: 'uncertainOutcome',
        nextRetryAt: now.subtract(const Duration(minutes: 1)),
      );

      final claimed = await repository.claimRetryableCommands(
        now: now,
        lease: lease,
      );

      // Only a recorded outcome is an attempt. If taking the row counted as
      // one, a few interrupted pickups would exhaust the eight-attempt budget
      // and push the command to manual review without it ever being sent.
      expect(claimed.single.attemptCount, 0);
    });
  });

  group('releasing a claim', () {
    test('a released command becomes claimable again', () async {
      await seed(
        commandId: 'cmd-1',
        stateKey: 'uncertainOutcome',
        nextRetryAt: now.subtract(const Duration(minutes: 1)),
      );
      await repository.claimRetryableCommands(now: now, lease: lease);

      await repository.releaseClaim('cmd-1');

      expect(await stateOf('cmd-1'), 'uncertainOutcome');
      expect(
        await repository.claimRetryableCommands(now: now, lease: lease),
        hasLength(1),
      );
    });

    test('releasing never reopens a settled command', () async {
      // The executor records the outcome itself. A late release from the
      // retry loop must not undo a rejection or a manual-review decision.
      await seed(commandId: 'cmd-rejected', stateKey: 'rejected');

      await repository.releaseClaim('cmd-rejected');

      expect(await stateOf('cmd-rejected'), 'rejected');
    });

    test('releasing an unknown command is harmless', () async {
      await repository.releaseClaim('cmd-never-existed');

      expect(await repository.getRetryCommand('cmd-never-existed'), isNull);
    });
  });
}
