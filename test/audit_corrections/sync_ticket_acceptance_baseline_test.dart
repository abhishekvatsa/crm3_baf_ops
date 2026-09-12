import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../tool/test_support/test_isar_core.dart';

/// B0 — what the ticket creation path does today, before any quota or durable
/// dispatch mechanism is added.
///
/// The harness suite proves dispatch reachability and actor refusal. It stops
/// short of acceptance: its gateway never returns a receipt, so nothing there
/// exercises the receipt validator, the exact server readback or local
/// adoption. These do, against the **real** `IsarMaintenanceRepository` and
/// real storage, because the claim being made is about persistence.
///
/// Establishing this before changing dispatch means a later failure can be
/// attributed rather than absorbed into a moving target.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  late Directory directory;
  late Isar database;
  late IsarMaintenanceRepository local;
  late _Gateway gateway;
  late _Remote remote;

  const ticketId = 'ticket-b0';
  const commandId = 'createMaintenanceTicket_$ticketId';
  const reporter = 'operator-1';
  final appliedAt = DateTime.utc(2026, 9, 11, 8);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sync_b0_');
    database = await Isar.open(
      <CollectionSchema<dynamic>>[MaintenanceRecordSchema, SyncRejectionSchema],
      directory: directory.path,
      inspector: false,
    );
    app.isar = database;
    local = IsarMaintenanceRepository(auditRepository: _SilentAudit());
    gateway = _Gateway();
    remote = _Remote();
  });

  tearDown(() async {
    await database.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  MaintenanceRecord pending() {
    final at = DateTime.utc(2026, 9, 11, 7);
    return MaintenanceRecord()
      ..firestoreId = ticketId
      ..loggedByUid = reporter
      ..isSynced = false
      ..version = 1
      ..assetType = AssetType.furnace
      ..assetNumber = 7
      ..maintenanceType = MaintenanceType.breakdown
      ..description = 'Baseline fixture'
      ..routedTo = RoutedTo.mechanical
      ..assetHierarchyRefJson = const AssetHierarchyReference(
        scope: AssetHierarchyReferenceScope.installedComponent,
        assetClassId: 'class-furnace',
        assetClassCode: 'FURNACE',
        assetClassName: 'Furnace',
        nodeId: 'definition-burner-block',
        nodeVersion: 4,
        nodeName: 'Burner block',
        assetInstanceId: 'furnace-7',
        assetInstanceVersion: 3,
        assetNumber: 7,
        assetInstanceName: 'Furnace 7',
        componentInstanceId: 'furnace-7-burner-block',
        componentInstanceVersion: 2,
        componentTag: 'BB-701',
        hierarchyPath: <String>['Refractory system', 'Burner block'],
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Mechanical',
        accountableRoleKeys: <String>['seniorMechanical'],
      ).encode()
      ..qualityIntent = const IssueQualityIntent(
        assessment: IssueQualityAssessment.notSuspected,
      )
      ..startDate = at
      ..createdAt = at
      ..updatedAt = at;
  }

  /// The receipt an accepting server returns for this exact command.
  WorkflowCommandReceipt acceptedReceipt() => WorkflowCommandReceipt(
    commandId: commandId,
    resultKey: 'maintenance-ticket-created',
    aggregateVersion: 1,
    result: <String, Object?>{
      'ticketId': ticketId,
      'auditId': 'server_maintenance_ticket_$commandId',
    },
    appliedAt: appliedAt,
  );

  /// The exact server state that receipt implies.
  MaintenanceRecord serverState({
    String loggedBy = reporter,
    DateTime? createdAt,
  }) {
    final seed = pending()
      ..version = 1
      ..isSynced = true
      ..loggedByUid = loggedBy
      ..createdAt = createdAt ?? appliedAt
      ..updatedAt = createdAt ?? appliedAt;
    return seed;
  }

  SyncService service({String? actor = reporter}) => SyncService(
    maintenanceRepo: local,
    firestoreMaintenance: remote,
    plannedRepo: _u.planned,
    firestorePlanned: _u.planned,
    serverCompletion: _u.serverCompletion,
    jobDiaryRepo: _u.jobDiary,
    firestoreJobDiary: _u.jobDiary,
    jobModuleRepo: _u.jobModule,
    firestoreJobModule: _u.jobModule,
    templateGovernanceRepo: _u.templateGovernance,
    firestoreTemplateGovernance: _u.templateGovernance,
    directiveRepo: _u.directive,
    firestoreDirective: _u.directive,
    abnormalityRepo: _u.abnormality,
    firestoreAbnormality: _u.abnormality,
    knowledgeRepo: _u.knowledge,
    auditRepository: _SilentAudit(),
    maintenanceCommandGateway: gateway,
    auth: _Auth(actor),
    rejectionOwnerUidLookup: () => reporter,
    now: () => appliedAt,
  );

  Future<MaintenanceRecord?> storedTicket() async => database.maintenanceRecords
      .filter()
      .firestoreIdEqualTo(ticketId)
      .findFirst();

  test(
    'an accepted creation is validated and adopted into local storage',
    () async {
      await local.saveTicket(pending());
      gateway.receipt = acceptedReceipt();
      remote.serverState = serverState();

      await service().syncTicketsForTest();

      expect(gateway.commands, hasLength(1));
      expect(gateway.commands.single.commandId, commandId);

      final stored = await storedTicket();
      expect(stored, isNotNull);
      expect(
        stored!.isSynced,
        isTrue,
        reason: 'the real repository adopted the validated server state',
      );
      expect(stored.version, 1);
    },
  );

  test('a receipt that does not match the command is refused', () async {
    await local.saveTicket(pending());
    // Right shape, wrong target: the server says a different ticket.
    gateway.receipt = WorkflowCommandReceipt(
      commandId: commandId,
      resultKey: 'maintenance-ticket-created',
      aggregateVersion: 1,
      result: const <String, Object?>{
        'ticketId': 'a-different-ticket',
        'auditId': 'server_maintenance_ticket_$commandId',
      },
      appliedAt: appliedAt,
    );
    remote.serverState = serverState();

    await service().syncTicketsForTest();

    final stored = await storedTicket();
    expect(
      stored!.isSynced,
      isFalse,
      reason: 'a mismatched receipt must not produce local adoption',
    );
  });

  test('server state that contradicts the receipt is refused', () async {
    await local.saveTicket(pending());
    gateway.receipt = acceptedReceipt();
    // Readback attributes the issue to someone else.
    remote.serverState = serverState(loggedBy: 'operator-2');

    await service().syncTicketsForTest();

    final stored = await storedTicket();
    expect(
      stored!.isSynced,
      isFalse,
      reason: 'exact server state must agree with the receipt',
    );
  });

  test('a missing server record does not complete the creation', () async {
    await local.saveTicket(pending());
    gateway.receipt = acceptedReceipt();
    remote.serverState = null;

    await service().syncTicketsForTest();

    final stored = await storedTicket();
    expect(stored!.isSynced, isFalse);
  });

  test(
    'an already-accepted creation is recovered under its original identity',
    () async {
      // The submission was accepted before the response was lost, so the ticket
      // exists remotely while the local row is still pending. This is the
      // recovery branch, and it is reached only because the first lookup finds
      // the counterpart — every other case here enters missing-ticket creation.
      await local.saveTicket(pending());
      remote.existing = <MaintenanceRecord>[serverState()];
      gateway.receipt = acceptedReceipt();
      remote.serverState = serverState();

      await service().syncTicketsForTest();

      // Replayed under the identity the ticket already determines, not a new one.
      expect(gateway.commands, hasLength(1));
      expect(gateway.commands.single.commandId, commandId);
      expect(gateway.commands.single.aggregateId, ticketId);

      // The exact readback was consulted rather than trusting the receipt alone.
      expect(remote.calls, contains('readMaintenanceIssueCommandServerState'));
      expect(
        remote.unexpected,
        isEmpty,
        reason: 'recovery completed without any fall-through path',
      );

      final stored = await storedTicket();
      expect(
        stored!.isSynced,
        isTrue,
        reason: 'the real repository adopted the recovered server state',
      );
      expect(stored.version, 1);
    },
  );

  test(
    'contradictory recovery cannot escape through a succeeding batch',
    () async {
      await local.saveTicket(pending());
      remote.existing = <MaintenanceRecord>[serverState()];
      gateway.receipt = acceptedReceipt();
      remote.serverState = serverState(loggedBy: 'operator-2');

      final sync = service();
      await sync.syncTicketsForTest();

      // The refusal must come from recovery having run and rejected this
      // evidence — not from some later path failing for its own reasons and
      // leaving the record untouched. Assert the sequence, then the outcome.
      expect(
        gateway.commands,
        hasLength(1),
        reason: 'recovery replayed the original creation command',
      );
      expect(gateway.commands.single.commandId, commandId);
      expect(
        remote.calls,
        contains('readMaintenanceIssueCommandServerState'),
        reason: 'the exact readback was consulted before any decision',
      );
      // This batch implementation can succeed. No failed double may conceal a
      // fallback write or be the reason the ticket remains pending.
      expect(remote.batches, isEmpty);
      expect(remote.unexpected, isEmpty);
      expect(sync.lastFailureCount, 1);
      expect(sync.lastFailureDetails.single.isLikelyPermanent, isTrue);
      expect(
        sync.lastFailureDetails.single.message,
        contains('reconciliation'),
      );

      final stored = await storedTicket();
      expect(
        stored!.isSynced,
        isFalse,
        reason: 'a contradictory readback cannot complete a recovery either',
      );
      expect(stored.description, 'Baseline fixture');
      expect(stored.loggedByUid, reporter);
    },
  );

  test('a contradictory recovery hold survives reopening the local store', () async {
    await local.saveTicket(pending());
    remote.existing = <MaintenanceRecord>[serverState()];
    gateway.receipt = acceptedReceipt();
    remote.serverState = serverState(loggedBy: 'operator-2');
    await service().syncTicketsForTest();
    expect(await database.syncRejections.count(), 1);
    expect(remote.batches, isEmpty);
    await database.close();
    database = await Isar.open(
      <CollectionSchema<dynamic>>[MaintenanceRecordSchema, SyncRejectionSchema],
      directory: directory.path, inspector: false,
    );
    app.isar = database;
    remote.serverState = serverState();
    gateway.commands.clear();
    remote.calls.clear();
    final nextPass = service();
    await nextPass.syncTicketsForTest();
    expect(gateway.commands, isEmpty);
    expect(remote.calls, isEmpty);
    expect(remote.batches, isEmpty);
    expect((await storedTicket())!.isSynced, isFalse);
    expect((await storedTicket())!.description, 'Baseline fixture');
    expect(nextPass.lastFailureDetails.single.message, contains('retry held'));
    expect((await database.syncRejections.where().findFirst())!.isResolved, isFalse);
  });

  test('an unreadable hold collection cannot authorize automatic sending', () async {
    await local.saveTicket(pending());
    await database.close();
    // This fixture opens the business collection without its hold collection,
    // producing a real storage lookup error rather than an empty hold result.
    database = await Isar.open(
      <CollectionSchema<dynamic>>[MaintenanceRecordSchema],
      directory: directory.path, inspector: false,
    );
    app.isar = database;
    gateway.receipt = acceptedReceipt();
    remote.serverState = serverState();
    final sync = service();
    await sync.syncTicketsForTest();
    expect(gateway.commands, isEmpty);
    expect(remote.calls, isEmpty);
    expect(remote.batches, isEmpty);
    expect((await storedTicket())!.isSynced, isFalse);
    expect((await storedTicket())!.description, 'Baseline fixture');
    expect(sync.lastFailureCount, 1);
    expect(sync.lastFailureDetails.single.isLikelyPermanent, isFalse);
    expect(sync.lastFailureDetails.single.message, contains('holds could not be verified'));
  });

  test('an ordinary changed payload keeps its existing update route', () async {
    final edit = serverState()
      ..version = 2
      ..updatedAt = appliedAt.add(const Duration(minutes: 1))
      ..description = 'A later legitimate local edit'
      ..isSynced = false;
    await local.saveTicket(edit);
    remote.existing = <MaintenanceRecord>[serverState()];
    remote.serverState = serverState();

    await service().syncTicketsForTest();

    expect(
      gateway.commands,
      isEmpty,
      reason: 'do not replay creation from an already adopted, edited payload',
    );
    expect(remote.calls, <String>[
      'getTicketsByFirestoreIds',
      'readMaintenanceIssueCommandServerState',
      'batchUpsertTickets',
    ]);
    expect(remote.batches.single.single.firestoreId, ticketId);
    expect(remote.batches.single.single.description, edit.description);
    final stored = await storedTicket();
    expect(stored!.isSynced, isTrue);
    expect(stored.description, edit.description);
  });

  test(
    'cached identity cannot permit an edit when exact verification is unavailable',
    () async {
      await local.saveTicket(serverState()..isSynced = false);
      remote.existing = <MaintenanceRecord>[serverState()];
      remote.readError = StateError('server read failed');

      final sync = service();
      await sync.syncTicketsForTest();

      expect(gateway.commands, isEmpty);
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isFalse);
      expect(sync.lastFailureDetails.single.isLikelyPermanent, isFalse);
    },
  );

  test(
    'unavailable exact readback after recovery does not write by another route',
    () async {
      await local.saveTicket(pending());
      remote.existing = <MaintenanceRecord>[serverState()];
      gateway.receipt = acceptedReceipt();
      remote.readError = Exception('server unavailable');

      final sync = service();
      await sync.syncTicketsForTest();

      expect(gateway.commands.single.commandId, commandId);
      expect(remote.calls, <String>[
        'getTicketsByFirestoreIds',
        'readMaintenanceIssueCommandServerState',
      ]);
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isFalse);
      expect(sync.lastFailureDetails.single.isLikelyPermanent, isFalse);
      expect(
        sync.lastFailureDetails.single.message,
        contains('could not be verified'),
      );
    },
  );

  test(
    'uncertain recovery invocation cannot fall back to a generic write',
    () async {
      await local.saveTicket(pending());
      remote.existing = <MaintenanceRecord>[serverState()];
      gateway.error = const WorkflowException(
        WorkflowErrorCode.unavailable,
        'response lost',
      );

      final sync = service();
      await sync.syncTicketsForTest();

      expect(gateway.commands.single.commandId, commandId);
      expect(remote.calls, <String>['getTicketsByFirestoreIds']);
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isFalse);
      expect(sync.lastFailureDetails.single.isLikelyPermanent, isFalse);
    },
  );

  for (final actor in <String?>[null, 'operator-2']) {
    test(
      'unadopted creation defers under actor $actor without another write',
      () async {
        await local.saveTicket(pending());
        remote.existing = <MaintenanceRecord>[serverState()];

        final sync = service(actor: actor);
        await sync.syncTicketsForTest();

        expect(gateway.commands, isEmpty);
        expect(remote.batches, isEmpty);
        expect((await storedTicket())!.isSynced, isFalse);
        expect(
          sync.lastFailureDetails.single.message,
          contains('original reporter'),
        );
      },
    );
  }

  test(
    'one contradictory ticket does not block an independent ordinary edit',
    () async {
      await local.saveTicket(pending());
      final otherServer = serverState()..firestoreId = 'ticket-independent';
      final otherEdit = serverState()
        ..firestoreId = 'ticket-independent'
        ..version = 2
        ..updatedAt = appliedAt.add(const Duration(minutes: 1))
        ..description = 'Independent edit'
        ..isSynced = false;
      await local.saveTicket(otherEdit);
      remote.existing = <MaintenanceRecord>[serverState(), otherServer];
      remote.serverState = serverState(loggedBy: 'operator-2');
      remote.serverStates['ticket-independent'] = otherServer;
      gateway.receipt = acceptedReceipt();

      final sync = service();
      await sync.syncTicketsForTest();

      expect(gateway.commands.single.commandId, commandId);
      expect(remote.batches.single.map((row) => row.firestoreId), <String>[
        'ticket-independent',
      ]);
      expect((await storedTicket())!.isSynced, isFalse);
      final storedOther = await database.maintenanceRecords
          .filter()
          .firestoreIdEqualTo('ticket-independent')
          .findFirst();
      expect(storedOther!.isSynced, isTrue);
      expect(storedOther.description, 'Independent edit');
      expect(sync.lastSuccessCount, 1);
      expect(sync.lastFailureCount, 1);
    },
  );

  test(
    'an edit while accepted creation is recovered survives without fallback',
    () async {
      await local.saveTicket(pending());
      remote.existing = <MaintenanceRecord>[serverState()];
      remote.serverState = serverState();
      gateway.receipt = acceptedReceipt();
      final released = Completer<void>();
      gateway.hold = released.future;

      final run = service().syncTicketsForTest();
      await gateway.entered.future;
      final edit = (await storedTicket())!
        ..version = 2
        ..updatedAt = appliedAt.add(const Duration(minutes: 1))
        ..description = 'Edited during recovery';
      await local.saveTicket(edit);
      released.complete();
      await run;

      expect(gateway.commands.single.commandId, commandId);
      expect(remote.batches, isEmpty);
      final stored = await storedTicket();
      expect(stored!.description, 'Edited during recovery');
      expect(stored.isSynced, isFalse);
    },
  );

  test('a newer local edit during submission is not overwritten', () async {
    // The snapshot is taken before the gateway call. If the operator edits the
    // ticket while the request is in flight, adopting the old snapshot would
    // discard that edit. The repository compares the snapshot before writing.
    await local.saveTicket(pending());
    gateway.receipt = acceptedReceipt();
    remote.serverState = serverState();

    final released = Completer<void>();
    gateway.hold = released.future;

    final run = service().syncTicketsForTest();
    await gateway.entered.future;

    // A legitimate newer local edit, while the submission is waiting.
    final inFlight = await storedTicket();
    await local.saveTicket(
      inFlight!
        ..description = 'Operator added detail while sending'
        ..version = inFlight.version + 1
        ..updatedAt = appliedAt.add(const Duration(minutes: 1)),
    );

    released.complete();
    await run;

    final stored = await storedTicket();
    expect(
      stored!.description,
      'Operator added detail while sending',
      reason: 'the newer local edit survives',
    );
    expect(
      stored.isSynced,
      isFalse,
      reason: 'stale-snapshot adoption is refused, so it stays pending',
    );
  });
}

/// Returns a scripted receipt, optionally waiting first so a concurrent local
/// edit can be made while the request is in flight.
class _Gateway implements WorkflowCommandGateway {
  final List<WorkflowCommand> commands = <WorkflowCommand>[];
  final entered = Completer<void>();
  WorkflowCommandReceipt? receipt;
  WorkflowException? error;
  Future<void>? hold;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    commands.add(command);
    if (!entered.isCompleted) entered.complete();
    if (hold != null) await hold;
    if (error != null) throw error!;
    final value = receipt;
    if (value == null) {
      throw const WorkflowException(
        WorkflowErrorCode.invalidArgument,
        'no receipt is scripted for this case',
      );
    }
    return value;
  }
}

class _Remote extends MaintenanceRepository {
  MaintenanceRecord? serverState;
  final Map<String, MaintenanceRecord> serverStates = {};
  Object? readError;
  final List<List<MaintenanceRecord>> batches = [];

  /// What the first lookup finds. Empty means the ticket never reached the
  /// server, which is the missing-ticket creation branch; returning a
  /// counterpart is what sends the service down the recovery branch instead.
  List<MaintenanceRecord> existing = const <MaintenanceRecord>[];

  final List<String> calls = <String>[];

  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> ids,
  ) async {
    calls.add('getTicketsByFirestoreIds');
    return existing;
  }

  @override
  Future<MaintenanceRecord?> readMaintenanceIssueCommandServerState(
    String firestoreId,
  ) async {
    calls.add('readMaintenanceIssueCommandServerState');
    if (readError != null) throw readError!;
    return serverStates[firestoreId] ?? serverState;
  }

  @override
  Future<void> batchUpsertTickets(List<MaintenanceRecord> records) async {
    calls.add('batchUpsertTickets');
    batches.add(List<MaintenanceRecord>.of(records));
  }

  /// Calls this double was not expected to receive.
  ///
  /// Throwing alone is not enough. Production catches recovery failures and
  /// falls through to other synchronisation paths, which catch their own
  /// errors, so an UnimplementedError can be swallowed and leave the ticket
  /// unsynchronised — exactly the outcome a negative test asserts. Recording
  /// the call as well turns "it named itself" into "it fails the test".
  final List<String> unexpected = <String>[];

  @override
  dynamic noSuchMethod(Invocation i) {
    unexpected.add(i.memberName.toString());
    throw UnimplementedError(i.memberName.toString());
  }
}

class _SilentAudit implements AuditRepository {
  @override
  dynamic noSuchMethod(Invocation i) async => null;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this._uid);
  final String? _uid;
  @override
  User? get currentUser => _uid == null ? null : _User(_uid);
}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String? get displayName => 'Operator $uid';
  @override
  String? get email => '$uid@example.invalid';
}

final _u = _Unused();

class _Unused {
  final planned = _UnusedPlanned();
  final serverCompletion = _UnusedServerCompletion();
  final jobDiary = _UnusedJobDiary();
  final jobModule = _UnusedJobModule();
  final templateGovernance = _UnusedTemplateGovernance();
  final directive = _UnusedDirective();
  final abnormality = _UnusedAbnormality();
  final knowledge = _UnusedKnowledge();
}

class _UnusedPlanned extends PlannedMaintenanceRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _UnusedServerCompletion implements PlannedJobServerCompletionService {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _UnusedJobDiary implements JobDiaryRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _UnusedJobModule implements JobModuleRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _UnusedTemplateGovernance implements TemplateGovernanceRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _UnusedDirective implements DirectiveRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _UnusedAbnormality implements AbnormalityRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _UnusedKnowledge implements BafKnowledgeRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}
