import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/maintenance_creation_successor_review.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/maintenance_ticket_correction.dart';
import 'package:crm3_baf_ops/features/maintenance/repositories/maintenance_creation_successor_repository.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_creation_successor_service.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_create_command.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/isar_workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';

import '../tool/test_support/test_isar_core.dart';

const _ticketId = 'draft-review-ticket';
final _created = DateTime.utc(2026, 9, 21, 8);

AppUser _actor(String uid, {AppRole role = AppRole.si}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.test',
  roles: [role],
  isApproved: true,
  createdAt: _created,
);

MaintenanceRecord _record() => MaintenanceRecord()
  ..firestoreId = _ticketId
  ..loggedByUid = 'reporter'
  ..description = 'Original A'
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..maintenanceType = MaintenanceType.breakdown
  ..routedTo = RoutedTo.mechanical
  ..plantConditionEffect = MaintenanceIssuePlantConditionEffect.unfit
  ..assetHierarchyRefJson = const AssetHierarchyReference(
    scope: AssetHierarchyReferenceScope.physicalAsset,
    assetClassId: 'furnace-class',
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    assetInstanceId: 'furnace-7',
    nodeId: 'furnace-root',
    nodeVersion: 1,
    nodeName: 'Furnace',
    assetInstanceVersion: 1,
    assetNumber: 7,
    assetInstanceName: 'Furnace 7',
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Mechanical',
    accountableRoleKeys: ['seniorMechanical'],
    hierarchyPath: ['Furnace 7'],
  ).encode()
  ..qualityIntent = const IssueQualityIntent(
    assessment: IssueQualityAssessment.notSuspected,
  )
  ..startDate = _created.subtract(const Duration(hours: 1))
  ..createdAt = _created.subtract(const Duration(hours: 1))
  ..updatedAt = _created.subtract(const Duration(hours: 1))
  ..version = 1
  ..isSynced = false;

class _Gateway implements OriginBoundWorkflowCommandGateway {
  final Future<WorkflowCommandReceipt> Function(String) run;
  _Gateway(this.run);
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) => run(envelopeJson);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar db;
  late IsarWorkflowRepository workflow;
  late DurableSubmissionRepository store;
  late MaintenanceCreationSuccessorRepository repository;
  late AppUser actor;
  late DateTime clock;
  late MaintenanceRecord server;
  late String originalEnvelope;
  late _Gateway gateway;
  late List<String> sent;
  late Map<String, WorkflowCommandReceipt> receipts;
  late Map<String, Map<String, dynamic>> audits;
  Future<void> Function()? onDispatch;
  Future<void> Function()? onReadServer;
  bool loseReply = false;
  bool denyAudit = false;

  MaintenanceRecord copyServer() {
    return _record()
      ..createdAt = server.createdAt
      ..updatedAt = server.updatedAt
      ..version = server.version
      ..description = server.description
      ..remarks = server.remarks
      ..component = server.component
      ..subsystem = server.subsystem
      ..tag = server.tag
      ..assetHierarchyRefJson = server.assetHierarchyRefJson
      ..hierarchyPath = server.hierarchyPath
      ..isCritical = server.isCritical
      ..loggedByUid = server.loggedByUid
      ..isSynced = true;
  }

  Future<void> open() async {
    db = await Isar.open(
      [
        MaintenanceRecordSchema,
        AuditEventSchema,
        DurableSubmissionRecordSchema,
        WorkflowCommandRecordSchema,
        WorkflowCommandReceiptRecordSchema,
      ],
      directory: directory.path,
      name: 'successor',
      inspector: false,
    );
    workflow = IsarWorkflowRepository(db);
    store = DurableSubmissionRepository(db, now: () => clock);
    repository = MaintenanceCreationSuccessorRepository(
      isar: db,
      workflow: workflow,
      readServer: (_) async {
        await onReadServer?.call();
        return copyServer();
      },
      readCorrectionAudit: (id) async {
        if (denyAudit) throw StateError('Readback unavailable');
        return Map<String, dynamic>.from(audits[id]!);
      },
    );
  }

  MaintenanceCreationSuccessorService service() =>
      MaintenanceCreationSuccessorService(
        repository: repository,
        store: store,
        gateway: gateway,
        currentActor: () => actor,
        now: () => clock,
      );
  Future<MaintenanceRecord> local() async =>
      (await db.maintenanceRecords.where().findAll()).single;
  Future<void> changeLocal(void Function(MaintenanceRecord) change) async {
    await db.writeTxn(() async {
      final row = await local();
      change(row);
      await db.maintenanceRecords.put(row);
    });
  }

  Future<List<AuditEvent>> localAudits() => db.auditEvents.where().findAll();
  Future<DurableSubmission> saved() async =>
      (await store.listForActor('supervisor', includeTerminal: true)).single;
  Future<void> apply(
    MaintenanceCreationSuccessorReview review, {
    bool acknowledged = true,
  }) => service().submit(
    review: review,
    draft: MaintenanceTicketCorrectionDraft(
      corrections: {'description': review.local.description},
      reason: 'Reviewed field notes',
    ),
    acknowledgeRetainedDifferences: acknowledged,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('maintenance_successor_');
    clock = _created.add(const Duration(hours: 2));
    actor = _actor('supervisor');
    sent = [];
    receipts = {};
    audits = {};
    onDispatch = null;
    onReadServer = null;
    loseReply = false;
    denyAudit = false;
    server = _record()
      ..createdAt = _created
      ..updatedAt = _created
      ..isSynced = true;
    await open();
    final original = buildMaintenanceIssueCreateCommand(
      _record(),
      createVersion: 1,
    );
    originalEnvelope = jsonEncode({
      'protocolVersion': 2,
      'originActorUid': 'reporter',
      'command': original.toMap(),
    });
    await workflow.saveReceipt(
      WorkflowCommandReceiptRecord()
        ..commandId = original.commandId
        ..aggregateId = _ticketId
        ..resultKey = 'maintenance-ticket-created'
        ..aggregateVersion = 1
        ..appliedAt = _created
        ..resultJson = jsonEncode({
          '__workflowAcceptedEnvelopeV1': originalEnvelope,
          'result': {
            'ticketId': _ticketId,
            'auditId': 'server_maintenance_ticket_${original.commandId}',
          },
        }),
    );
    await db.writeTxn(
      () => db.maintenanceRecords.put(
        _record()
          ..description = 'Newer B'
          ..version = 2
          ..updatedAt = clock,
      ),
    );
    gateway = _Gateway((envelope) async {
      sent.add(envelope);
      final raw = (jsonDecode(envelope) as Map)['command'] as Map;
      final id = raw['commandId'] as String;
      if (!receipts.containsKey(id)) {
        if (raw['expectedVersion'] != server.version) {
          throw const WorkflowException(
            WorkflowErrorCode.failedPrecondition,
            'Stale server',
            details: {'reasonCode': 'maintenance-ticket-version-conflict'},
          );
        }
        final payload = raw['payload'] as Map;
        final changes = Map<String, Object?>.from(
          payload['corrections'] as Map,
        );
        final before = {
          'firestoreId': _ticketId,
          'version': server.version,
          ...maintenanceCorrectionValues(server),
        };
        if (changes.containsKey('description')) {
          server.description = changes['description'] as String;
        }
        if (changes.containsKey('isCritical')) {
          server.isCritical = changes['isCritical'] as bool;
        }
        final target = payload['targetReferenceJson'];
        if (target is String) {
          final reference = jsonDecode(target) as Map;
          final path = List<String>.from(reference['hierarchyPath'] as List);
          server
            ..assetHierarchyRefJson = target
            ..component = reference['nodeName'] as String
            ..subsystem = path.length > 1 ? path[path.length - 2] : null
            ..tag = reference['componentTag'] as String?
            ..hierarchyPath = path;
        }
        final correctedFields = changes.keys.toSet();
        if (target != null) {
          correctedFields.addAll([
            'assetHierarchyRefJson',
            'component',
            'subsystem',
            'tag',
            'hierarchyPath',
          ]);
        }
        server
          ..version += 1
          ..updatedAt = clock;
        final receipt = WorkflowCommandReceipt(
          commandId: id,
          resultKey: 'maintenance-ticket-corrected',
          aggregateVersion: server.version,
          result: {
            'ticketId': _ticketId,
            'auditId': 'server_maintenance_ticket_$id',
            'correctedFields': correctedFields.toList()..sort(),
          },
          appliedAt: clock,
        );
        receipts[id] = receipt;
        audits[receipt.result['auditId'] as String] = {
          'schemaVersion': 1,
          'auditId': receipt.result['auditId'],
          'entityType': 'maintenance',
          'entityId': _ticketId,
          'operation': 'correctMaintenanceTicket',
          'action': 'update',
          'requestId': id,
          'resultVersion': receipt.aggregateVersion,
          'performedByUid': (jsonDecode(envelope) as Map)['originActorUid'],
          'performedByName': 'Supervisor',
          'reason': 'manualOverride',
          'severity': 'medium',
          'summary': 'Maintenance ticket corrected',
          'reasonNotes': payload['reason'],
          'timestamp': Timestamp.fromDate(clock),
          'beforeJson': jsonEncode(before),
          'afterJson': jsonEncode({
            'firestoreId': _ticketId,
            'version': server.version,
            ...maintenanceCorrectionValues(server),
            'assetHierarchyRefJson': server.assetHierarchyRefJson,
          }),
        };
        await onDispatch?.call();
      }
      if (loseReply) throw const SocketException('Accepted response lost');
      return receipts[id]!;
    });
  });
  tearDown(() async {
    await db.close(deleteFromDisk: true);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  test(
    'accepted A allows a distinct SI correction, retains complete B and preserves unselected C',
    () async {
      server
        ..remarks = 'Later server note'
        ..version = 3;
      await changeLocal(
        (row) => row.metadataJson =
            '${row.metadataJson!.substring(0, row.metadataJson!.length - 1)},"retainedUnknown":{"raw":"  precise B  "}}',
      );
      await db.close();
      await open();
      final review = await service().review(_ticketId);
      final exported =
          (jsonDecode(review.localSnapshotJson) as List).single as Map;
      expect(
        exported.keys,
        containsAll(MaintenanceRecordSchema.properties.keys),
      );
      await apply(review);
      expect(sent, hasLength(1));
      final command = (jsonDecode(sent.single) as Map)['command'] as Map;
      expect(command['commandType'], 'correctMaintenanceTicket');
      expect(command['expectedVersion'], 3);
      expect((jsonDecode(sent.single) as Map)['originActorUid'], 'supervisor');
      expect((await local()).description, 'Newer B');
      expect((await local()).remarks, 'Later server note');
      expect((await local()).isSynced, isTrue);
      expect((await saved()).state, DurableSubmissionState.reconciled);
      final audit = (await localAudits()).single;
      expect(audit.before!['localSnapshotJson'], review.localSnapshotJson);
      expect(audit.before!['originalEnvelopeJson'], originalEnvelope);
      expect(
        audit.before!['retainedUnsupportedChanges'],
        contains('retained assessment, lane or specialist metadata'),
      );
      expect(audit.after!['remoteMutationPerformed'], isTrue);
      expect(
        jsonDecode(
          (await workflow.getReceipt(
            maintenanceIssueCreateCommandIdForTicket(_ticketId),
          ))!.resultJson,
        )['__workflowAcceptedEnvelopeV1'],
        originalEnvelope,
      );
    },
  );

  test(
    'keep server records local-only reconciliation and complete unsupported history without dispatch',
    () async {
      await changeLocal(
        (row) => row
          ..endDate = clock
          ..status = TicketStatus.resolved
          ..isResolved = true
          ..assetNumber = 99
          ..actionsJson = '[{"unrecognized":"retained exactly"}]',
      );
      final review = await service().review(_ticketId);
      expect(review.unsupportedChanges, contains('assetNumber'));
      await service().keepServer(
        review: review,
        reason: 'Keep confirmed current issue',
        acknowledgeRetainedDifferences: true,
      );
      expect(sent, isEmpty);
      expect((await local()).assetNumber, 7);
      final audit = (await localAudits()).single;
      expect(audit.before!['localSnapshotJson'], review.localSnapshotJson);
      expect(
        audit.before!['retainedCorrectableFields'],
        contains('description'),
      );
      expect(audit.after!['remoteMutationPerformed'], isFalse);
      expect((await local()).isSynced, isTrue);
    },
  );

  test(
    'already equal server is an audited device reconciliation with no fake receipt',
    () async {
      server.description = 'Newer B';
      final review = await service().review(_ticketId);
      await service().keepServer(
        review: review,
        reason: 'Verified matching values',
        acknowledgeRetainedDifferences: true,
      );
      expect(sent, isEmpty);
      expect(
        await store.listForActor(actor.uid, includeTerminal: true),
        isEmpty,
      );
      expect(
        (await localAudits()).single.after!['kind'],
        'deviceReconciliation',
      );
    },
  );

  test(
    'all dispositions require explicit retained-difference acknowledgement',
    () async {
      final review = await service().review(_ticketId);
      await expectLater(apply(review, acknowledged: false), throwsStateError);
      await expectLater(
        service().keepServer(
          review: review,
          reason: 'Reason',
          acknowledgeRetainedDifferences: false,
        ),
        throwsStateError,
      );
      expect(sent, isEmpty);
      expect((await local()).isSynced, isFalse);
    },
  );

  test(
    'full native CAS refuses hidden raw-field changes without version or time changes',
    () async {
      final review = await service().review(_ticketId);
      await changeLocal(
        (row) => row.resolutionHistoryJson = '[{"later":"raw"}]',
      );
      await expectLater(apply(review), throwsStateError);
      await expectLater(
        service().keepServer(
          review: review,
          reason: 'Reason',
          acknowledgeRetainedDifferences: true,
        ),
        throwsStateError,
      );
      expect(sent, isEmpty);
      expect(await localAudits(), isEmpty);
      expect((await local()).resolutionHistoryJson, '[{"later":"raw"}]');
    },
  );

  test(
    'stale or contradictory same-version server observation refuses before dispatch',
    () async {
      final review = await service().review(_ticketId);
      server.description = 'Another server edit';
      await expectLater(apply(review), throwsStateError);
      server.description = 'Original A';
      server.version++;
      await expectLater(apply(review), throwsStateError);
      expect(sent, isEmpty);
    },
  );

  test(
    'lost reply and process restart replay exact correction and keep A unchanged',
    () async {
      loseReply = true;
      await expectLater(
        apply(await service().review(_ticketId)),
        throwsA(isA<SocketException>()),
      );
      final first = sent.single;
      final id = (await saved()).submissionId;
      await db.close();
      await open();
      clock = clock.add(const Duration(hours: 1));
      loseReply = false;
      await service().resume(id);
      expect(sent, [first, first]);
      expect(receipts, hasLength(1));
      expect((await local()).isSynced, isTrue);
    },
  );

  test(
    'wrong account cannot recover saved correction; original supervisor can',
    () async {
      loseReply = true;
      await expectLater(
        apply(await service().review(_ticketId)),
        throwsA(isA<SocketException>()),
      );
      final id = (await saved()).submissionId;
      actor = _actor('another-admin', role: AppRole.admin);
      loseReply = false;
      await expectLater(service().resume(id), throwsStateError);
      await expectLater(service().pending(_ticketId), throwsStateError);
      expect(sent, hasLength(1));
      actor = _actor('supervisor');
      clock = clock.add(const Duration(hours: 1));
      await service().resume(id);
      expect((await local()).isSynced, isTrue);
    },
  );

  test(
    'account switch after server acceptance retains receipt but cannot adopt under new account',
    () async {
      onDispatch = () async {
        actor = _actor('other');
      };
      await expectLater(
        apply(await service().review(_ticketId)),
        throwsStateError,
      );
      expect(
        (await saved()).state,
        DurableSubmissionState.acceptedPendingAdoption,
      );
      expect((await local()).isSynced, isFalse);
      expect(await localAudits(), isEmpty);
      actor = _actor('supervisor');
      await service().resume((await saved()).submissionId);
      expect(sent, hasLength(1));
      expect((await local()).isSynced, isTrue);
    },
  );

  test(
    'newer in-flight B is preserved and accepted owner settles so another review is reachable',
    () async {
      final review = await service().review(_ticketId);
      onDispatch = () => changeLocal(
        (row) => row
          ..description = 'Newer B2'
          ..resolutionHistoryJson = '[{"later":"history"}]',
      );
      await expectLater(
        apply(review),
        throwsA(isA<MaintenanceSuccessorNewerDraftRetained>()),
      );
      expect((await local()).description, 'Newer B2');
      expect((await local()).isSynced, isFalse);
      expect((await saved()).state, DurableSubmissionState.reconciled);
      expect(await service().pending(_ticketId), isNull);
      final audit = (await localAudits()).single;
      expect(audit.before!['localSnapshotJson'], review.localSnapshotJson);
      expect(audit.after!['localProjectionAdopted'], isFalse);
      expect(audit.after!['preservedNativeSnapshotJson'], contains('Newer B2'));
      onDispatch = null;
      final next = await service().review(_ticketId);
      expect(next.local.description, 'Newer B2');
      expect(next.server.description, 'Newer B');
      await apply(next);
      expect((await local()).description, 'Newer B2');
      expect((await local()).isSynced, isTrue);
      expect(sent, hasLength(2));
    },
  );

  test(
    'immutable audit corruption blocks adoption and later valid evidence recovers without redispatch',
    () async {
      denyAudit = true;
      await expectLater(
        apply(await service().review(_ticketId)),
        throwsStateError,
      );
      final row = await saved();
      final audit = audits.values.single;
      denyAudit = false;
      for (final key in [
        'reasonNotes',
        'resultVersion',
        'performedByUid',
        'requestId',
      ]) {
        final original = audit[key];
        audit[key] = 'altered';
        await expectLater(service().resume(row.submissionId), throwsStateError);
        expect((await local()).isSynced, isFalse);
        audit[key] = original;
      }
      final originalAfter = audit['afterJson'];
      final changed = Map<String, dynamic>.from(
        jsonDecode(originalAfter as String) as Map,
      )..['description'] = 'Not selected';
      audit['afterJson'] = jsonEncode(changed);
      await expectLater(service().resume(row.submissionId), throwsStateError);
      audit['afterJson'] = originalAfter;
      await service().resume(row.submissionId);
      expect(sent, hasLength(1));
      expect((await local()).isSynced, isTrue);
    },
  );

  test(
    'fresh registered target canonical labels override retained raw labels without false adoption failure',
    () async {
      final review = await service().review(_ticketId);
      final target =
          Map<String, dynamic>.from(
              jsonDecode(server.assetHierarchyRefJson!) as Map,
            )
            ..['nodeId'] = 'reviewed-new-node'
            ..['nodeName'] = 'Reviewed component'
            ..['hierarchyPath'] = ['Furnace 7', 'Reviewed component'];
      await service().submit(
        review: review,
        draft: MaintenanceTicketCorrectionDraft(
          corrections: {'component': 'Old raw B label'},
          reason: 'Explicitly reviewed new registered target',
          targetReferenceJson: jsonEncode(target),
        ),
        acknowledgeRetainedDifferences: true,
      );
      expect((await local()).component, 'Reviewed component');
      expect((await local()).isSynced, isTrue);
      expect((await localAudits()).single.before!['selectedCorrections'], {
        'component': 'Old raw B label',
      });
    },
  );

  test(
    'same-version contradictory server projection cannot masquerade as accepted readback',
    () async {
      denyAudit = true;
      await expectLater(
        apply(await service().review(_ticketId)),
        throwsStateError,
      );
      final row = await saved();
      denyAudit = false;
      server.description = 'Contradicts accepted correction';
      await expectLater(service().resume(row.submissionId), throwsStateError);
      expect((await local()).isSynced, isFalse);
      expect(await localAudits(), isEmpty);
      server.description = 'Newer B';
      await service().resume(row.submissionId);
      expect(sent, hasLength(1));
      expect((await local()).isSynced, isTrue);
    },
  );

  for (final reason in [
    'maintenance-ticket-department-review-required',
    'maintenance-ticket-route-locked',
    'maintenance-burner-specialization-immutable',
  ]) {
    test(
      'first-attempt precommit $reason leaves another review reachable',
      () async {
        gateway = _Gateway((envelope) async {
          sent.add(envelope);
          throw WorkflowException(
            WorkflowErrorCode.failedPrecondition,
            'Explicit refusal',
            details: {'reasonCode': reason},
          );
        });
        await expectLater(
          apply(await service().review(_ticketId)),
          throwsA(isA<WorkflowException>()),
        );
        expect((await saved()).state, DurableSubmissionState.rejected);
        expect(await service().pending(_ticketId), isNull);
        expect((await local()).isSynced, isFalse);
        expect((await saved()).displayMetadataJson, contains('Newer B'));
      },
    );
  }

  test(
    'later explicit refusal cannot erase uncertainty from an earlier lost reply',
    () async {
      loseReply = true;
      await expectLater(
        apply(await service().review(_ticketId)),
        throwsA(isA<SocketException>()),
      );
      final row = await saved();
      clock = clock.add(const Duration(hours: 1));
      gateway = _Gateway(
        (_) async => throw const WorkflowException(
          WorkflowErrorCode.failedPrecondition,
          'Later refusal',
          details: {'reasonCode': 'maintenance-ticket-version-conflict'},
        ),
      );
      await expectLater(
        service().resume(row.submissionId),
        throwsA(isA<WorkflowException>()),
      );
      expect((await saved()).state, DurableSubmissionState.uncertain);
      expect(await service().pending(_ticketId), isNotNull);
    },
  );

  test(
    'keep-server atomic adoption refuses a correction owner prepared during server read',
    () async {
      final review = await service().review(_ticketId);
      onReadServer = () async {
        onReadServer = null;
        const request = 'concurrent-correction';
        final command = {
          'commandId': request,
          'commandType': 'correctMaintenanceTicket',
          'aggregateId': _ticketId,
          'expectedVersion': review.server.version,
          'payload': {
            'reason': 'Concurrent review',
            'corrections': {'description': 'Newer B'},
          },
        };
        await store.prepare(
          DurableSubmissionDraft(
            submissionId: request,
            actorUid: actor.uid,
            requestId: request,
            aggregateId: _ticketId,
            resourceKey: MaintenanceCreationSuccessorService.resource(
              _ticketId,
            ),
            protocol: 'maintenanceWorkflow.v2',
            envelopeJson: jsonEncode({
              'protocolVersion': 2,
              'originActorUid': actor.uid,
              'command': command,
            }),
            displayMetadataJson: maintenanceReviewJson(
              review.evidence(
                reason: 'Concurrent review',
                corrections: {'description': 'Newer B'},
                disposition: 'correctSelectedFields',
              ),
            ),
          ),
        );
      };
      await expectLater(
        service().keepServer(
          review: review,
          reason: 'Keep current server',
          acknowledgeRetainedDifferences: true,
        ),
        throwsStateError,
      );
      expect((await local()).isSynced, isFalse);
      expect((await saved()).state, DurableSubmissionState.intent);
      expect(await localAudits(), isEmpty);
      expect(sent, isEmpty);
    },
  );

  test(
    'native audit timestamp admits exact producer value and refuses hidden precision or malformed fields',
    () async {
      denyAudit = true;
      await expectLater(
        apply(await service().review(_ticketId)),
        throwsStateError,
      );
      final row = await saved();
      final audit = audits.values.single;
      denyAudit = false;
      final instant = audit['timestamp'] as Timestamp;
      audit['timestamp'] = Timestamp(instant.seconds, instant.nanoseconds + 1);
      await expectLater(service().resume(row.submissionId), throwsStateError);
      expect((await local()).isSynced, isFalse);
      audit['timestamp'] = {
        'seconds': instant.seconds,
        'nanoseconds': instant.nanoseconds,
      };
      await expectLater(
        service().resume(row.submissionId),
        throwsA(isA<FormatException>()),
      );
      audit['timestamp'] = instant;
      audit['performedByName'] = 17;
      await expectLater(
        service().resume(row.submissionId),
        throwsA(isA<FormatException>()),
      );
      audit['performedByName'] = 'Supervisor';
      await service().resume(row.submissionId);
      expect((await local()).isSynced, isTrue);
      expect(sent, hasLength(1));
    },
  );

  test('uncertain A cannot be adopted or dispatched by supervisor', () async {
    await db.writeTxn(() => db.workflowCommandReceiptRecords.clear());
    await expectLater(service().review(_ticketId), throwsStateError);
    expect(sent, isEmpty);
    expect((await local()).description, 'Newer B');
  });

  test('inconsistent accepted A or creation identity fails closed', () async {
    server.loggedByUid = 'different-reporter';
    await expectLater(service().review(_ticketId), throwsStateError);
    server.loggedByUid = 'reporter';
    final receipt = (await workflow.getReceipt(
      maintenanceIssueCreateCommandIdForTicket(_ticketId),
    ))!;
    receipt.resultJson = jsonEncode({
      'result': {'ticketId': _ticketId},
    });
    await workflow.saveReceipt(receipt);
    await expectLater(service().review(_ticketId), throwsStateError);
    expect(sent, isEmpty);
  });

  test('duplicate device identity cannot choose a row to overwrite', () async {
    await db.writeTxn(
      () => db.maintenanceRecords.put(_record()..description = 'Duplicate'),
    );
    await expectLater(service().review(_ticketId), throwsStateError);
    expect(await db.maintenanceRecords.count(), 2);
    expect(sent, isEmpty);
  });

  test(
    'actor failure after projection put rolls back both projection and audit',
    () async {
      final review = await service().review(_ticketId);
      var checks = 0;
      await expectLater(
        repository.keepServer(
          review: review,
          server: copyServer(),
          evidence: Map<String, dynamic>.from(
            review.evidence(
              reason: 'Reviewed',
              corrections: {},
              disposition: 'keepServer',
            ),
          ),
          reviewerUid: actor.uid,
          reviewerName: actor.name,
          reviewedAt: clock,
          requireActor: () {
            if (++checks == 3) throw StateError('Account changed');
          },
          requireNoPendingCorrection: () async {},
        ),
        throwsStateError,
      );
      expect((await local()).description, 'Newer B');
      expect((await local()).isSynced, isFalse);
      expect(await localAudits(), isEmpty);
    },
  );
}
