import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
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
      <CollectionSchema<dynamic>>[MaintenanceRecordSchema],
      directory: directory.path,
      name: 'sync_b0',
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

  SyncService service() => SyncService(
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
    auth: _Auth(reporter),
    rejectionOwnerUidLookup: () => reporter,
    now: () => appliedAt,
  );

  Future<MaintenanceRecord?> storedTicket() async =>
      database.maintenanceRecords.filter().firestoreIdEqualTo(ticketId).findFirst();

  test('an accepted creation is validated and adopted into local storage', () async {
    await local.saveTicket(pending());
    gateway.receipt = acceptedReceipt();
    remote.serverState = serverState();

    await service().syncTicketsForTest();

    expect(gateway.commands, hasLength(1));
    expect(gateway.commands.single.commandId, commandId);

    final stored = await storedTicket();
    expect(stored, isNotNull);
    expect(stored!.isSynced, isTrue,
        reason: 'the real repository adopted the validated server state');
    expect(stored.version, 1);
  });

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
    expect(stored!.isSynced, isFalse,
        reason: 'a mismatched receipt must not produce local adoption');
  });

  test('server state that contradicts the receipt is refused', () async {
    await local.saveTicket(pending());
    gateway.receipt = acceptedReceipt();
    // Readback attributes the issue to someone else.
    remote.serverState = serverState(loggedBy: 'operator-2');

    await service().syncTicketsForTest();

    final stored = await storedTicket();
    expect(stored!.isSynced, isFalse,
        reason: 'exact server state must agree with the receipt');
  });

  test('a missing server record does not complete the creation', () async {
    await local.saveTicket(pending());
    gateway.receipt = acceptedReceipt();
    remote.serverState = null;

    await service().syncTicketsForTest();

    final stored = await storedTicket();
    expect(stored!.isSynced, isFalse);
  });

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
    expect(stored!.description, 'Operator added detail while sending',
        reason: 'the newer local edit survives');
    expect(stored.isSynced, isFalse,
        reason: 'stale-snapshot adoption is refused, so it stays pending');
  });
}

/// Returns a scripted receipt, optionally waiting first so a concurrent local
/// edit can be made while the request is in flight.
class _Gateway implements WorkflowCommandGateway {
  final List<WorkflowCommand> commands = <WorkflowCommand>[];
  final entered = Completer<void>();
  WorkflowCommandReceipt? receipt;
  Future<void>? hold;

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    commands.add(command);
    if (!entered.isCompleted) entered.complete();
    if (hold != null) await hold;
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

  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> ids,
  ) async => const <MaintenanceRecord>[];

  @override
  Future<MaintenanceRecord?> readMaintenanceIssueCommandServerState(
    String firestoreId,
  ) async => serverState;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _SilentAudit implements AuditRepository {
  @override
  dynamic noSuchMethod(Invocation i) async => null;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this._uid);
  final String _uid;
  @override
  User? get currentUser => _User(_uid);
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
