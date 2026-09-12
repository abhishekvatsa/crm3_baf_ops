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
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_create_command.dart';
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

  SyncService service({String? actor = reporter, FirebaseAuth? auth}) =>
      SyncService(
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
        auth: auth ?? _Auth(actor),
        rejectionOwnerUidLookup: () => reporter,
        now: () => appliedAt,
      );

  Future<MaintenanceRecord?> storedTicket() async => database.maintenanceRecords
      .filter()
      .firestoreIdEqualTo(ticketId)
      .findFirst();

  Future<void> persist(MaintenanceRecord record) async {
    await database.writeTxn(() => database.maintenanceRecords.put(record));
  }

  MaintenanceRecord deletion() => pending()
    ..createdAt = appliedAt
    ..version = 2
    ..updatedAt = appliedAt.add(const Duration(minutes: 30))
    ..isDeleted = true
    ..deletedAt = appliedAt.add(const Duration(minutes: 30))
    ..deletedByUid = reporter
    ..deletedByName = 'Operator'
    ..deleteReason = 'Duplicate issue';

  MaintenanceRecord reopened() => pending()
    ..createdAt = appliedAt
    ..version = 3
    ..updatedAt = appliedAt.add(const Duration(minutes: 20))
    ..reopenedByUid = reporter
    ..reopenedByName = 'Operator'
    ..reopenedAt = appliedAt.add(const Duration(minutes: 20))
    ..reopenReason = 'Fault returned'
    ..remarks = 'Fault returned'
    ..resolutionHistory = <ResolutionHistory>[
      ResolutionHistory(
        resolvedByUid: reporter,
        resolvedByName: 'Operator',
        resolvedAt: appliedAt.add(const Duration(minutes: 10)),
        remarks: 'Checked and restored',
      ),
    ];

  Future<void> reopenDatabase() async {
    await database.close();
    database = await Isar.open(
      <CollectionSchema<dynamic>>[MaintenanceRecordSchema, SyncRejectionSchema],
      directory: directory.path,
      inspector: false,
    );
    app.isar = database;
    local = IsarMaintenanceRepository(auditRepository: _SilentAudit());
  }

  test(
    'cached absence cannot settle an existing server issue deletion',
    () async {
      await persist(deletion());
      remote.serverState = serverState();
      // The lookup is empty but exact server state is active. The successful
      // batch double proves the service must actually send the deletion.
      await service().syncTicketsForTest();
      expect(remote.calls, contains('readMaintenanceIssueCommandServerState'));
      expect(remote.batches.single.single.isDeleted, isTrue);
      expect((await storedTicket())!.isSynced, isTrue);
      expect(gateway.commands, isEmpty);
    },
  );

  test(
    'cached tombstone cannot settle deletion while server remains active',
    () async {
      await persist(deletion());
      remote.existing = <MaintenanceRecord>[deletion()];
      remote.serverState = serverState();
      await service().syncTicketsForTest();
      expect(remote.batches, hasLength(1));
      expect((await storedTicket())!.isSynced, isTrue);
    },
  );

  test(
    'authoritative absence preserves deletion through reopen and late creation',
    () async {
      await persist(deletion());
      final first = service();
      await first.syncTicketsForTest();
      expect(first.lastSuccessCount, 0);
      expect(
        first.lastFailureDetails.single.message,
        contains('still be in flight'),
      );
      expect((await storedTicket())!.isSynced, isFalse);
      expect(remote.batches, isEmpty);
      expect(gateway.commands, isEmpty);
      await reopenDatabase();
      expect((await storedTicket())!.isDeleted, isTrue);
      expect((await storedTicket())!.isSynced, isFalse);
      remote.serverState = serverState();
      await service().syncTicketsForTest();
      expect(remote.batches.single.single.isDeleted, isTrue);
      expect((await storedTicket())!.isSynced, isTrue);
    },
  );

  test(
    'unavailable deletion evidence retains work while unrelated edit proceeds',
    () async {
      await persist(deletion());
      final other = serverState()..firestoreId = 'other-ticket';
      final edit = serverState()
        ..firestoreId = 'other-ticket'
        ..description = 'Unrelated changed detail'
        ..version = 2
        ..isSynced = false;
      await persist(edit);
      remote.existing = <MaintenanceRecord>[other];
      remote.serverStates['other-ticket'] = other;
      remote.beforeServerRead = (id) async {
        if (id == ticketId) {
          throw const WorkflowException(
            WorkflowErrorCode.unavailable,
            'Server connection unavailable',
          );
        }
      };
      await service().syncTicketsForTest();
      expect((await storedTicket())!.isSynced, isFalse);
      expect(remote.batches.single.single.firestoreId, 'other-ticket');
      expect(gateway.commands, isEmpty);
    },
  );

  test(
    'confirmed tombstone settles only the unchanged local deletion',
    () async {
      await persist(deletion());
      remote.serverState = deletion();
      await service().syncTicketsForTest();
      expect((await storedTicket())!.isSynced, isTrue);
      expect(remote.batches, isEmpty);
      final pendingAgain = (await storedTicket())!..isSynced = false;
      await persist(pendingAgain);
      remote.beforeServerRead = (_) async {
        final edit = (await storedTicket())!
          ..deleteReason = 'A newer operator correction'
          ..version += 1;
        await persist(edit);
      };
      await service().syncTicketsForTest();
      expect((await storedTicket())!.isSynced, isFalse);
      expect(
        (await storedTicket())!.deleteReason,
        'A newer operator correction',
      );
      expect(remote.batches, isEmpty);
    },
  );

  test(
    'unadopted creation identity does not authorize a deletion fallback',
    () async {
      await persist(
        deletion()..createdAt = appliedAt.subtract(const Duration(hours: 1)),
      );
      remote.serverState = serverState();
      await service().syncTicketsForTest();
      expect((await storedTicket())!.isSynced, isFalse);
      expect(remote.batches, isEmpty);
      expect(gateway.commands, isEmpty);
    },
  );

  test(
    'close and reopen complete through exact field steps without batch',
    () async {
      await persist(reopened());
      remote.serverState = serverState();
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      await service().syncTicketsForTest();
      expect(remote.steps.map((step) => step['status']), <String>[
        'resolved',
        'open',
      ]);
      expect(remote.batches, isEmpty);
      expect(remote.unexpected, isEmpty);
      expect((await storedTicket())!.isSynced, isTrue);
      expect(
        (await storedTicket())!.resolutionHistoryJson,
        reopened().resolutionHistoryJson,
      );
    },
  );

  test(
    'partial lifecycle failure never uses capable batch and resumes after restart',
    () async {
      await persist(reopened());
      remote.serverState = serverState();
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      remote.onStep = (step) async {
        if (step['status'] == 'open') {
          throw const WorkflowException(
            WorkflowErrorCode.unavailable,
            'Temporarily unavailable',
          );
        }
        remote.lifecycleFields!.addAll(step);
      };
      final sync = service();
      await sync.syncTicketsForTest();
      expect(remote.lifecycleFields!['status'], 'resolved');
      expect(remote.batches, isEmpty, reason: 'this batch double can succeed');
      expect((await storedTicket())!.isSynced, isFalse);
      expect(sync.lastFailureDetails.single.message, contains('no fallback'));
      await reopenDatabase();
      remote.serverState = readRemoteMaintenanceRecord(
        remote.lifecycleFields!,
        documentId: ticketId,
      );
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.onStep = null;
      remote.steps.clear();
      await service().syncTicketsForTest();
      expect(remote.steps.map((step) => step['status']), <String>['open']);
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isTrue);
    },
  );

  test(
    'lost final confirmation converges after restart without any new write',
    () async {
      await persist(reopened());
      remote.serverState = serverState();
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      remote.onLifecycleRead = () async {
        if (remote.lifecycleFields!['status'] == 'open') {
          throw const WorkflowException(
            WorkflowErrorCode.unavailable,
            'Readback unavailable',
          );
        }
        return Map<String, dynamic>.of(remote.lifecycleFields!);
      };
      await service().syncTicketsForTest();
      expect(remote.steps, hasLength(2));
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isFalse);
      await reopenDatabase();
      remote.serverState = readRemoteMaintenanceRecord(
        remote.lifecycleFields!,
        documentId: ticketId,
      );
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.onLifecycleRead = null;
      remote.steps.clear();
      await service().syncTicketsForTest();
      expect(remote.steps, isEmpty);
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isTrue);
    },
  );

  test(
    'contradictory lifecycle readback retains local work and durable hold',
    () async {
      await persist(reopened());
      remote.serverState = serverState();
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      remote.onLifecycleRead = () async => <String, dynamic>{
        ...remote.lifecycleFields!,
        'closedByUid': 'different-actor',
      };
      await service().syncTicketsForTest();
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isFalse);
      await reopenDatabase();
      final attempts = remote.steps.length;
      await service().syncTicketsForTest();
      expect(remote.steps, hasLength(attempts));
      expect(remote.batches, isEmpty);
      expect(
        (await storedTicket())!.resolutionHistoryJson,
        reopened().resolutionHistoryJson,
      );
    },
  );

  test(
    'confirmed lifecycle preserves a concurrent local operator edit',
    () async {
      await persist(reopened());
      remote.serverState = serverState();
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      remote.onStep = (step) async {
        remote.lifecycleFields!.addAll(step);
        if (step['status'] == 'open') {
          final edit = (await storedTicket())!
            ..description = 'New operator evidence during replay'
            ..version += 1;
          await persist(edit);
        }
      };
      await service().syncTicketsForTest();
      expect(remote.steps, hasLength(2));
      expect(remote.batches, isEmpty);
      expect(
        (await storedTicket())!.description,
        'New operator evidence during replay',
      );
      expect((await storedTicket())!.isSynced, isFalse);
    },
  );

  test(
    'lost close confirmation converges after restart without repeating closure',
    () async {
      final intent = pending()
        ..createdAt = appliedAt
        ..version = 2
        ..isResolved = true
        ..status = TicketStatus.resolved
        ..closedByUid = reporter
        ..closedByName = 'Operator'
        ..endDate = appliedAt.add(const Duration(minutes: 10))
        ..updatedAt = appliedAt.add(const Duration(minutes: 10));
      await persist(intent);
      remote.serverState = serverState();
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      remote.onLifecycleRead = () async => throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Readback unavailable',
      );
      await service().syncTicketsForTest();
      expect(remote.steps, hasLength(1));
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isFalse);
      await reopenDatabase();
      remote.serverState = readRemoteMaintenanceRecord(
        remote.lifecycleFields!,
        documentId: ticketId,
      );
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.onLifecycleRead = null;
      remote.steps.clear();
      await service().syncTicketsForTest();
      expect(remote.steps, isEmpty);
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isTrue);
    },
  );

  for (final boundary in <String>[
    'matching closure',
    'closing actor',
    'closing time',
    'closing remarks',
    'closing actions',
    'closure history',
    'subject',
    'signed-in actor',
    'account change during confirmation',
  ]) {
    test(
      'rebased closure restart validates $boundary before adopting server v4',
      () async {
        final intent = pending()
          ..createdAt = appliedAt
          ..version = 2
          ..isResolved = true
          ..status = TicketStatus.resolved
          ..closedByUid = reporter
          ..closedByName = 'Operator'
          ..endDate = appliedAt.add(const Duration(minutes: 10))
          ..updatedAt = appliedAt.add(const Duration(minutes: 10))
          ..remarks = 'Checked and restored';
        await persist(intent);
        final acknowledged = serverState()
          ..version = 3
          ..status = TicketStatus.acknowledged
          ..acknowledgedByUid = 'supervisor-1'
          ..acknowledgedByName = 'Supervisor'
          ..acknowledgedAt = appliedAt.add(const Duration(minutes: 5))
          ..updatedAt = appliedAt.add(const Duration(minutes: 5));
        remote.serverState = acknowledged;
        remote.existing = <MaintenanceRecord>[acknowledged];
        remote.lifecycleFields = _serverFields(acknowledged);
        remote.onLifecycleRead = () async => throw const WorkflowException(
          WorkflowErrorCode.unavailable,
          'Committed closure readback unavailable',
        );

        await service().syncTicketsForTest();
        expect(remote.steps, hasLength(1));
        expect(remote.steps.single['version'], 4);
        expect(remote.lifecycleFields!['status'], 'resolved');
        expect(remote.lifecycleFields!['version'], 4);
        expect(remote.batches, isEmpty);
        expect((await storedTicket())!.version, 2);
        expect((await storedTicket())!.isSynced, isFalse);

        await reopenDatabase();
        remote.serverState = readRemoteMaintenanceRecord(
          remote.lifecycleFields!,
          documentId: ticketId,
        );
        remote.existing = <MaintenanceRecord>[remote.serverState!];
        remote.steps.clear();
        final confirmingAuth = _Auth(
          boundary == 'signed-in actor' ? 'operator-2' : reporter,
        );
        remote.onLifecycleRead = () async {
          final observed = Map<String, dynamic>.of(remote.lifecycleFields!);
          // Change only the second exact read, after the initial state check,
          // so no cached/first-read match can authorize local settlement.
          switch (boundary) {
            case 'closing actor':
              observed['closedByUid'] = 'different-actor';
            case 'closing time':
              observed['endDate'] = appliedAt
                  .add(const Duration(minutes: 11))
                  .toIso8601String();
            case 'closing remarks':
              observed['remarks'] = 'Another closure';
            case 'closing actions':
              observed['actionsJson'] = '[{"unrelated":true}]';
            case 'closure history':
              observed['resolutionHistoryJson'] =
                  reopened().resolutionHistoryJson;
            case 'subject':
              observed['description'] = 'Another fault';
            case 'account change during confirmation':
              confirmingAuth._uid = 'operator-2';
          }
          return observed;
        };
        await service(auth: confirmingAuth).syncTicketsForTest();

        expect(remote.steps, isEmpty);
        expect(remote.batches, isEmpty, reason: 'the batch double can succeed');
        expect(gateway.commands, isEmpty);
        final saved = (await storedTicket())!;
        if (boundary == 'matching closure') {
          expect(saved.isSynced, isTrue);
          expect(saved.version, 4);
          expect(saved.closedByUid, reporter);
          expect(saved.remarks, intent.remarks);
          expect(saved.endDate?.toUtc(), intent.endDate?.toUtc());
          expect(saved.acknowledgedByUid, 'supervisor-1');
        } else {
          expect(saved.isSynced, isFalse);
          expect(saved.version, 2);
          expect(saved.closedByUid, intent.closedByUid);
          expect(saved.remarks, intent.remarks);
          expect(saved.description, intent.description);
          expect(saved.resolutionHistoryJson, intent.resolutionHistoryJson);
          if (boundary == 'account change during confirmation') {
            confirmingAuth._uid = reporter;
            remote.onLifecycleRead = null;
            await service(auth: confirmingAuth).syncTicketsForTest();
            expect((await storedTicket())!.isSynced, isTrue);
            expect((await storedTicket())!.version, 4);
            expect(remote.steps, isEmpty);
            expect(remote.batches, isEmpty);
          }
        }
      },
    );
  }

  for (final boundary in <String>[
    'changed subject',
    'different actor',
    'missing actor',
  ]) {
    test(
      'completed lifecycle convergence refuses $boundary without a batch write',
      () async {
        final intent = reopened();
        await persist(intent);
        remote.serverState = serverState();
        remote.existing = <MaintenanceRecord>[remote.serverState!];
        remote.lifecycleFields = _serverFields(remote.serverState!);
        await service().syncTicketsForTest();
        expect((await storedTicket())!.isSynced, isTrue);
        await persist(intent..isSynced = false);
        remote.serverState = readRemoteMaintenanceRecord(
          remote.lifecycleFields!,
          documentId: ticketId,
        );
        remote.existing = <MaintenanceRecord>[remote.serverState!];
        remote.steps.clear();
        if (boundary == 'changed subject') {
          remote.onLifecycleRead = () async => <String, dynamic>{
            ...remote.lifecycleFields!,
            'description': 'Changed after the first server read',
          };
        }
        await service(
          actor: boundary == 'different actor'
              ? 'operator-2'
              : boundary == 'missing actor'
              ? null
              : reporter,
        ).syncTicketsForTest();
        expect(remote.steps, isEmpty);
        expect(remote.batches, isEmpty);
        expect((await storedTicket())!.isSynced, isFalse);
        expect((await storedTicket())!.description, intent.description);
        expect(gateway.commands, isEmpty);
      },
    );
  }

  test(
    'committed lifecycle write errors converge through exact readback',
    () async {
      await persist(reopened());
      remote.serverState = serverState();
      remote.existing = <MaintenanceRecord>[remote.serverState!];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      remote.onStep = (step) async {
        remote.lifecycleFields!.addAll(step);
        throw const WorkflowException(
          WorkflowErrorCode.unavailable,
          'Response lost',
        );
      };
      await service().syncTicketsForTest();
      expect(remote.steps, hasLength(2));
      expect(remote.batches, isEmpty);
      expect((await storedTicket())!.isSynced, isTrue);
    },
  );

  test(
    'uncertain lifecycle does not prevent an unrelated ordinary edit',
    () async {
      await persist(reopened());
      final other = serverState()..firestoreId = 'other-ticket';
      await persist(
        serverState()
          ..firestoreId = 'other-ticket'
          ..description = 'Unrelated new detail'
          ..version = 2
          ..isSynced = false,
      );
      remote.serverState = serverState();
      remote.serverStates['other-ticket'] = other;
      remote.existing = <MaintenanceRecord>[remote.serverState!, other];
      remote.lifecycleFields = _serverFields(remote.serverState!);
      remote.onLifecycleRead = () async => throw const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Readback unavailable',
      );
      await service().syncTicketsForTest();
      expect(remote.steps, hasLength(1));
      expect(remote.batches.single.single.firestoreId, 'other-ticket');
      expect((await storedTicket())!.isSynced, isFalse);
    },
  );

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

  test(
    'a contradictory recovery hold survives reopening the local store',
    () async {
      await local.saveTicket(pending());
      remote.existing = <MaintenanceRecord>[serverState()];
      gateway.receipt = acceptedReceipt();
      remote.serverState = serverState(loggedBy: 'operator-2');
      await service().syncTicketsForTest();
      expect(await database.syncRejections.count(), 1);
      expect(remote.batches, isEmpty);
      await database.close();
      database = await Isar.open(
        <CollectionSchema<dynamic>>[
          MaintenanceRecordSchema,
          SyncRejectionSchema,
        ],
        directory: directory.path,
        inspector: false,
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
      expect(
        nextPass.lastFailureDetails.single.message,
        contains('retry held'),
      );
      expect(
        (await database.syncRejections.where().findFirst())!.isResolved,
        isFalse,
      );
    },
  );

  test(
    'an unreadable hold collection cannot authorize automatic sending',
    () async {
      await local.saveTicket(pending());
      await database.close();
      // This fixture opens the business collection without its hold collection,
      // producing a real storage lookup error rather than an empty hold result.
      database = await Isar.open(
        <CollectionSchema<dynamic>>[MaintenanceRecordSchema],
        directory: directory.path,
        inspector: false,
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
      expect(
        sync.lastFailureDetails.single.message,
        contains('holds could not be verified'),
      );
    },
  );

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
  Future<void> Function(String)? beforeServerRead;
  Map<String, dynamic>? lifecycleFields;
  final List<Map<String, dynamic>> steps = [];
  Future<void> Function(Map<String, dynamic>)? onStep;
  Future<Map<String, dynamic>?> Function()? onLifecycleRead;
  final List<List<MaintenanceRecord>> batches = [];

  /// The cache-capable lookup, deliberately independent of exact server reads.
  /// An empty result does not establish that the server has no ticket.
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
    await beforeServerRead?.call(firestoreId);
    if (readError != null) throw readError!;
    return serverStates[firestoreId] ?? serverState;
  }

  @override
  Future<void> applyRemoteMaintenanceLifecycleReplayStepForSync(
    String firestoreId,
    Map<String, dynamic> stepData,
  ) async {
    calls.add('applyRemoteMaintenanceLifecycleReplayStepForSync');
    steps.add(Map<String, dynamic>.of(stepData));
    if (onStep != null) {
      await onStep!(stepData);
    } else {
      lifecycleFields!.addAll(stepData);
    }
  }

  @override
  Future<Map<String, dynamic>?>
  readRemoteMaintenanceLifecycleReplayFieldsForSync(String firestoreId) async {
    calls.add('readRemoteMaintenanceLifecycleReplayFieldsForSync');
    if (onLifecycleRead != null) return await onLifecycleRead!();
    return lifecycleFields == null
        ? null
        : Map<String, dynamic>.of(lifecycleFields!);
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

Map<String, dynamic> _serverFields(MaintenanceRecord record) =>
    <String, dynamic>{
      ...Map<String, dynamic>.from(
        buildMaintenanceIssueCreateCommand(
              record,
              createVersion: 1,
            ).payload['ticket']!
            as Map,
      ),
      'firestoreId': record.firestoreId,
      'version': record.version,
      'loggedByUid': record.loggedByUid,
      'loggedByName': record.loggedByName,
      'createdAt': record.createdAt.toIso8601String(),
      'updatedAt': record.updatedAt.toIso8601String(),
      'isDeleted': record.isDeleted,
      'status': record.status.name,
      'isResolved': record.isResolved,
      'metadataJson': record.metadataJson,
      'actionsJson': record.actionsJson,
      'resolutionHistoryJson': record.resolutionHistoryJson,
    };

class _SilentAudit implements AuditRepository {
  @override
  dynamic noSuchMethod(Invocation i) async => null;
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this._uid);
  String? _uid;
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
