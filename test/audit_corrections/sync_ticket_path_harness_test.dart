import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_repository.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step A of the quota-lifecycle work: prove the real ticket path can be
/// driven at all, before changing it again.
///
/// The previous attempt shipped a test that used real storage but copied the
/// service's private helpers. Disabling the production check outright left it
/// passing, so it demonstrated nothing about the service. The blocker was that
/// `_pushMissingMaintenanceTicket` read `FirebaseAuth.instance` directly; the
/// session is now injected the same way `GlobalPullService` already takes it.
///
/// These drive `SyncService` itself through `syncTicketsForTest`, which
/// delegates to the same `_syncTickets` that `syncAll` calls. Nothing here
/// reimplements service logic.
void main() {
  late _Gateway gateway;

  MaintenanceRecord ticket({
    String firestoreId = 'ticket-a1',
    String loggedByUid = 'operator-1',
  }) {
    final at = DateTime.utc(2026, 9, 11, 7);
    // Complete enough to build a real command. Without the asset reference and
    // quality intent the builder throws first, and an empty gateway would then
    // prove nothing about the actor guard.
    return MaintenanceRecord()
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
      ..firestoreId = firestoreId
      ..loggedByUid = loggedByUid
      ..isSynced = false
      ..assetType = AssetType.furnace
      ..assetNumber = 7
      ..maintenanceType = MaintenanceType.breakdown
      ..description = 'Harness fixture'
      ..routedTo = RoutedTo.mechanical
      ..startDate = at
      ..createdAt = at
      ..updatedAt = at;
  }

  SyncService service({
    required MaintenanceRepository local,
    FirebaseAuth? auth,
  }) {
    final unused = _Unused();
    final session = auth ?? _Auth('operator-1');
    return SyncService(
      maintenanceRepo: local,
      firestoreMaintenance: _RemoteMaintenance(),
      plannedRepo: unused.planned,
      firestorePlanned: unused.planned,
      serverCompletion: unused.serverCompletion,
      jobDiaryRepo: unused.jobDiary,
      firestoreJobDiary: unused.jobDiary,
      jobModuleRepo: unused.jobModule,
      firestoreJobModule: unused.jobModule,
      templateGovernanceRepo: unused.templateGovernance,
      firestoreTemplateGovernance: unused.templateGovernance,
      directiveRepo: unused.directive,
      firestoreDirective: unused.directive,
      abnormalityRepo: unused.abnormality,
      firestoreAbnormality: unused.abnormality,
      knowledgeRepo: unused.knowledge,
      auditRepository: unused.audit,
      maintenanceCommandGateway: gateway,
      auth: session,
      // Rejection ownership is a separate concern from execution authority and
      // is injected separately, but it reads the same session here so a
      // recorded rejection is attributed to whoever was actually signed in.
      rejectionOwnerUidLookup: () => session.currentUser?.uid,
      now: () => DateTime.utc(2026, 9, 11, 8),
    );
  }

  setUp(() => gateway = _Gateway());

  test('an empty local population reaches the service and submits nothing', () async {
    final local = _LocalMaintenance(const <MaintenanceRecord>[]);
    await service(local: local).syncTicketsForTest();

    // The real entry point ran: the service asked its repository for work.
    expect(local.unsyncedReads, 1);
    expect(gateway.commands, isEmpty);
  });

  test('the authorised reporter does reach the gateway', () async {
    // The control the other cases depend on. Without it, an empty gateway
    // could mean "refused" or "never got that far", and the negative cases
    // would pass for the wrong reason — which is how the previous attempt at
    // this suite failed a mutation check.
    final local = _LocalMaintenance(<MaintenanceRecord>[ticket()]);
    await service(local: local, auth: _Auth('operator-1')).syncTicketsForTest();

    expect(gateway.commands, hasLength(1));
    expect(gateway.commands.single.commandId, 'createMaintenanceTicket_ticket-a1');
    expect(gateway.commands.single.aggregateId, 'ticket-a1');
  });

  test('a signed-out session does not dispatch a pending ticket', () async {
    // Authorisation is unchanged by injecting the session. With no signed-in
    // account the path must refuse rather than invent an actor.
    final local = _LocalMaintenance(<MaintenanceRecord>[ticket()]);
    await service(local: local, auth: _Auth(null)).syncTicketsForTest();

    expect(gateway.commands, isEmpty,
        reason: 'no command may be built without an authenticated actor');
    expect(local.unsyncedReads, 1);
  });

  test('a different signed-in account does not dispatch another operator\'s ticket',
      () async {
    // The reporter is operator-1; operator-2 is signed in. The account signed
    // in now governs, and it is read per attempt rather than captured once.
    final local = _LocalMaintenance(
      <MaintenanceRecord>[ticket(loggedByUid: 'operator-1')],
    );
    await service(local: local, auth: _Auth('operator-2')).syncTicketsForTest();

    expect(gateway.commands, isEmpty,
        reason: 'a pending ticket is not resubmitted as a different actor');
  });

  test('the session is re-read per run, not captured at construction', () async {
    // One service, two runs, the account changing in between. A cached uid
    // would let the second run act as the first account.
    final auth = _Auth('operator-1');
    final local = _LocalMaintenance(<MaintenanceRecord>[ticket()]);
    final sync = service(local: local, auth: auth);

    await sync.syncTicketsForTest();
    expect(gateway.commands, hasLength(1), reason: 'first run is authorised');

    auth.becomeSignedOut();
    await sync.syncTicketsForTest();

    expect(gateway.commands, hasLength(1),
        reason: 'signing out between runs must be observed by the same service');
  });
}

/// Records what the service asked for, and returns a controlled population.
class _LocalMaintenance extends MaintenanceRepository {
  _LocalMaintenance(this._unsynced);

  final List<MaintenanceRecord> _unsynced;
  int unsyncedReads = 0;

  @override
  Future<List<MaintenanceRecord>> getUnsyncedTickets() async {
    unsyncedReads++;
    return _unsynced;
  }

  // Anything else the path reaches for names itself rather than returning a
  // silent default, so the test cannot drift away from the real dependencies.
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

/// The remote side. Returns no remote counterpart, which is the condition
/// that sends a pending ticket down the creation-push branch.
class _RemoteMaintenance extends MaintenanceRepository {
  @override
  Future<List<MaintenanceRecord>> getTicketsByFirestoreIds(
    List<String> ids,
  ) async => const <MaintenanceRecord>[];

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

/// Captures dispatches without reaching a network.
///
/// Refuses with a non-retryable workflow code so the caller's own retry
/// predicate ends the attempt immediately and the dispatch count is exact. A
/// plain error would be treated as unknown and retried three times, which
/// would hide how many submissions the service actually made.
class _Gateway implements WorkflowCommandGateway {
  final List<WorkflowCommand> commands = <WorkflowCommand>[];

  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) async {
    commands.add(command);
    throw const WorkflowException(
      WorkflowErrorCode.invalidArgument,
      'no receipt is scripted for this case',
    );
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this._uid);

  String? _uid;
  void becomeSignedOut() => _uid = null;

  @override
  User? get currentUser => _uid == null ? null : _User(_uid!);
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

/// Everything the ticket path must not touch. Any call names itself.
class _Unused {
  final maintenance = _UnusedMaintenance();
  final planned = _UnusedPlanned();
  final serverCompletion = _UnusedServerCompletion();
  final jobDiary = _UnusedJobDiary();
  final jobModule = _UnusedJobModule();
  final templateGovernance = _UnusedTemplateGovernance();
  final directive = _UnusedDirective();
  final abnormality = _UnusedAbnormality();
  final knowledge = _UnusedKnowledge();
  final audit = _UnusedAudit();
}

class _UnusedMaintenance extends MaintenanceRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
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

class _UnusedAudit implements AuditRepository {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}
