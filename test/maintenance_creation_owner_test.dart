import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_creation_owner.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import '../tool/test_support/test_isar_core.dart';

class _Gateway implements WorkflowCommandGateway, OriginBoundWorkflowCommandGateway {
  final envelopes = <String>[];
  bool loseResponse = false;
  bool malformed = false;
  void Function()? onDispatch;
  @override
  Future<WorkflowCommandReceipt> execute(WorkflowCommand command) => throw StateError('Legacy dispatch prohibited');
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(String envelope) async {
    envelopes.add(envelope);
    onDispatch?.call();
    if (loseResponse) throw const SocketException('Response lost after acceptance');
    final command = (jsonDecode(envelope) as Map)['command'] as Map;
    return WorkflowCommandReceipt(commandId: command['commandId'] as String,
      resultKey: malformed ? 'wrong-result' : 'maintenance-ticket-created', aggregateVersion: 1,
      result: {'ticketId': command['aggregateId'], 'auditId': 'server_maintenance_ticket_${command['commandId']}'},
      appliedAt: DateTime.utc(2026, 9, 20));
  }
}

WorkflowCommand _draft(String description) => WorkflowCommand(commandId: 'create-issue-a',
  type: WorkflowCommandType.createMaintenanceTicket, aggregateId: 'issue-a', expectedVersion: 0,
  payload: {'ticket': {'version': 1, 'description': description, 'qualityImpactAssessment': 'notSuspected'}});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late IsarWorkflowRepository repository;
  late _Gateway gateway;
  late String? actor;
  late DateTime clock;
  Future<void> open() async {
    database = await Isar.open([WorkflowCommandRecordSchema, WorkflowCommandReceiptRecordSchema],
      directory: directory.path, name: 'maintenance_creation_owner', inspector: false);
    repository = IsarWorkflowRepository(database);
  }
  MaintenanceCreationOwner owner() => MaintenanceCreationOwner(repository: repository,
    currentActorUid: () => actor,
    executor: WorkflowOnlineExecutor(connectivity: Connectivity(), gateway: gateway,
      repository: repository, now: () => clock, originActorUid: () => actor,
      checkConnectivity: () async => [ConnectivityResult.wifi]));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('maintenance_creation_owner_');
    await open();
    gateway = _Gateway(); actor = 'actor-a'; clock = DateTime.utc(2026, 9, 20);
  });
  tearDown(() async {
    await database.close(deleteFromDisk: true);
    directory.deleteSync(recursive: true);
  });

  test('lost response and process restart replay A while preserving successor B', () async {
    gateway.loseResponse = true;
    await expectLater(owner().execute(draft: _draft('A'), actorUid: 'actor-a'), throwsA(isA<SocketException>()));
    final original = gateway.envelopes.single;
    await database.close(); await open();
    clock = clock.add(const Duration(hours: 1)); gateway.loseResponse = false;
    final successor = _draft('B');
    final result = await owner().execute(draft: successor, actorUid: 'actor-a');
    expect(gateway.envelopes.last, original);
    expect(result.hasSuccessor, isTrue);
    expect((successor.payload['ticket'] as Map)['description'], 'B');
    expect((result.command.payload['ticket'] as Map)['description'], 'A');
    final cached = await owner().execute(draft: successor, actorUid: 'actor-a');
    expect(cached.hasSuccessor, isTrue);
    expect(gateway.envelopes, hasLength(2));
  });

  test('another account cannot claim original creation', () async {
    gateway.loseResponse = true;
    await expectLater(owner().execute(draft: _draft('A'), actorUid: 'actor-a'), throwsA(isA<SocketException>()));
    actor = 'actor-b'; clock = clock.add(const Duration(hours: 1)); gateway.loseResponse = false;
    await expectLater(owner().execute(draft: _draft('B'), actorUid: 'actor-b'), throwsStateError);
    expect(gateway.envelopes, hasLength(1));
  });

  test('invalid creation receipt is not settled as accepted', () async {
    gateway.malformed = true;
    await expectLater(owner().execute(draft: _draft('A'), actorUid: 'actor-a'), throwsStateError);
    expect(await repository.getReceipt('create-issue-a'), isNull);
    expect(await repository.getRetryCommand('create-issue-a'), isNotNull);
  });

  test('an account change during dispatch cannot report success to the new account', () async {
    gateway.onDispatch = () => actor = 'actor-b';
    await expectLater(owner().execute(draft: _draft('A'), actorUid: 'actor-a'), throwsA(anything));
    expect(gateway.envelopes, hasLength(1));
    expect((jsonDecode(gateway.envelopes.single) as Map)['originActorUid'], 'actor-a');
  });
}
