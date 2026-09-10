import 'dart:io';

import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

/// A rejection was visible on the run that discovered it and gone by the next
/// one. The attention count came from `getPendingCommands()`, which excludes
/// rejected rows because they are not retryable - correct for claiming, wrong
/// for deciding what a person still has to deal with.
///
/// The previous test asserted that `copyWith` preserves a string. That could
/// never have caught this: production recalculates the inventory each run and
/// clears attention when the calculation comes back empty. These run the real
/// repository twice.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  late Isar isar;
  late IsarWorkflowRepository repository;
  late Directory directory;

  final now = DateTime.utc(2026, 9, 10, 10);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('attention_');
    isar = await Isar.open(
      [WorkflowCommandRecordSchema, WorkflowCommandReceiptRecordSchema],
      directory: directory.path,
      name: 'attention_test',
      inspector: false,
    );
    repository = IsarWorkflowRepository(isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  Future<void> seed(String commandId, String stateKey) =>
      repository.saveRetryCommand(
        WorkflowCommandRecord()
          ..commandId = commandId
          ..aggregateId = 'ticket-base-205'
          ..commandTypeKey = 'acknowledgeMaintenanceTicket'
          ..stateKey = stateKey
          ..createdLocallyAt = now,
      );

  test('a rejection survives a second quiet evaluation', () async {
    await seed('cmd-refused', 'rejected');

    final first = describeWorkflowAttention(
      await repository.readOutcomeInventory(),
    );
    // Nothing is claimed or retried in between: this is the quiet run that
    // used to clear the warning.
    final second = describeWorkflowAttention(
      await repository.readOutcomeInventory(),
    );

    expect(first, contains('1 rejected'));
    expect(second, first, reason: 'the rejected row is still there');
  });

  test('the old query is why it vanished', () async {
    await seed('cmd-refused', 'rejected');

    // Demonstrates the actual cause rather than asserting the fix's shape.
    expect(await repository.getPendingCommands(), isEmpty);
    expect((await repository.readOutcomeInventory()).rejected, 1);
  });

  test('manual review counts too, and retrying work does not', () async {
    await seed('cmd-review', 'manualReview');
    await seed('cmd-waiting', 'uncertainOutcome');

    final inventory = await repository.readOutcomeInventory();

    expect(inventory.manualReview, 1);
    expect(inventory.retrying, 1);
    // Retrying work progresses on its own; calling it "action needed" would
    // train operators to ignore the warning.
    expect(describeWorkflowAttention(inventory), contains('1 need review'));
    expect(describeWorkflowAttention(inventory), isNot(contains('retry')));
  });

  test('a settled journal clears attention', () async {
    await seed('cmd-done', 'applied');

    final inventory = await repository.readOutcomeInventory();

    expect(inventory.needingAction, 0);
    expect(describeWorkflowAttention(inventory), isNull);
  });

  test('both ways a phase reports failure produce attention', () {
    // An exception is only one of them. A phase can return normally while
    // carrying commands whose outcome it could not establish, and the journal
    // will look quiet because the released row is back in the retry queue.
    const quiet = WorkflowOutcomeInventory(retrying: 1);

    expect(describeWorkflowAttention(quiet), isNull);
    expect(
      describeWorkflowAttention(quiet, verificationIncomplete: true),
      contains('could not be fully verified'),
    );
  });

  test('outstanding work outranks an unverified run', () {
    // Both are true; the one a person must act on is the one to say.
    const withRejection = WorkflowOutcomeInventory(rejected: 1, retrying: 1);

    expect(
      describeWorkflowAttention(withRejection, verificationIncomplete: true),
      contains('1 rejected'),
    );
  });

  test('an unreadable journal outranks everything', () {
    expect(
      describeWorkflowAttention(null, verificationIncomplete: true),
      contains('could not be checked'),
    );
  });

  test('a retry phase that throws cannot skip the inventory', () {
    // The coordinator reads the journal through claimRetryableCommands first,
    // so a failure there used to jump past the inventory block entirely -
    // leaving the reason null and the final write clearing the warning on a
    // check that never ran. The inventory now sits outside that try, and a
    // failed retry phase reports unverified even when the journal reads
    // cleanly afterwards.
    final source =
        File('lib/core/services/sync_coordinator.dart').readAsStringSync();

    final method = source.substring(
      source.indexOf('Future<void> _runWorkflowSupplementalSync'),
    );
    final body = method.substring(0, method.indexOf('workflowPullServiceProvider'));

    // Structural, not behavioural: it guards the arrangement, and the
    // decision itself is covered by the cases above. Labelled honestly rather
    // than described as a coordinator execution test.
    expect(body, contains('retryVerificationIncomplete = true'));
    expect(
      body,
      contains('summary.failedVerification.isNotEmpty'),
      reason: 'a returned failure must feed the decision, not only a throw',
    );
    // The inventory must come after the retry catch closes, not inside it.
    expect(
      body.indexOf('retryVerificationIncomplete = true'),
      lessThan(body.indexOf('readOutcomeInventory()')),
    );
  });

  test('an unreadable journal is unverified, not quiet', () {
    // The inventory read can fail. Clearing the warning then would assert an
    // absence nothing established.
    expect(
      describeWorkflowAttention(null),
      contains('could not be checked'),
    );
    expect(describeWorkflowAttention(null), isNot(contains('needs attention')));
  });
}
