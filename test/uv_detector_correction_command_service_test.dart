import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/services/uv_detector_correction_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_error.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);
  late Directory directory;
  late Isar database;
  late DurableSubmissionRepository journal;
  late UvDetectorCorrectionCommandService service;
  late _Gateway gateway;
  late String actor;
  late bool readbackAvailable;
  late int readbacks;

  Future<void> open() async {
    database = await Isar.open(
      [DurableSubmissionRecordSchema],
      name: 'uv_correction_recovery',
      directory: directory.path,
      inspector: false,
    );
    journal = DurableSubmissionRepository(database);
    service = UvDetectorCorrectionCommandService(
      gateway: gateway,
      currentActorUid: () => actor,
      durableStore: journal,
      confirmReadback: (_, original) async {
        expect(original, gateway.envelopes.first);
        readbacks++;
        if (!readbackAvailable) throw StateError('Server readback unavailable');
      },
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('uv_correction_');
    actor = 'admin-a';
    gateway = _Gateway();
    readbackAvailable = true;
    readbacks = 0;
    await open();
  });
  tearDown(() async {
    if (database.isOpen) await database.close(deleteFromDisk: true);
    if (directory.existsSync() && directory.listSync().isEmpty) {
      directory.deleteSync();
    }
  });
  Future<void> reopen() async {
    await database.close();
    await open();
  }

  Future<WorkflowCommandReceipt> submit({
    String correctionId = 'correction-a',
  }) => service.correct(
    correctionId: correctionId,
    eventId: 'event-a',
    expectedCurrentEventId: 'event-current',
    expectedCurrentActionPerformedAt: '2026-09-19T10:00:00.000Z',
    correctedActionPerformedAt: '2026-09-18T10:00:00.000Z',
    reason: 'Correct the physical installation date.',
    supersedesCorrectionId: 'prior-correction',
  );

  test(
    'saves original account and exact command before dispatch, then reconciles readback',
    () async {
      gateway.beforeReply = (envelope) async {
        final saved = (await service.pendingForEvent('event-a'))!;
        expect(saved.envelopeJson, envelope);
        expect(saved.state, DurableSubmissionState.sending);
      };
      final receipt = await submit();
      final envelope =
          jsonDecode(gateway.envelopes.single) as Map<String, dynamic>;
      expect(envelope['originActorUid'], 'admin-a');
      expect((envelope['command'] as Map)['aggregateId'], 'correction-a');
      expect(
        ((envelope['command'] as Map)['payload']
            as Map)['supersedesCorrectionId'],
        'prior-correction',
      );
      expect(
        (await journal.read(receipt.commandId))!.state,
        DurableSubmissionState.reconciled,
      );
      expect(readbacks, 1);
    },
  );

  test(
    'lost accepted reply recovers unchanged after native database reopen',
    () async {
      gateway.error = const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Reply lost',
      );
      await expectLater(submit(), throwsA(isA<WorkflowException>()));
      final saved = (await service.pendingForEvent('event-a'))!;
      expect(saved.state, DurableSubmissionState.uncertain);
      await reopen();
      gateway.error = null;
      final pending = (await service.pendingForEvent('event-a'))!;
      await service.resume(pending.submissionId);
      expect(gateway.envelopes, [saved.envelopeJson, saved.envelopeJson]);
      expect(
        (await journal.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'an unresolved correction blocks a fresh identity for the same event',
    () async {
      gateway.error = const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Reply lost',
      );
      await expectLater(submit(), throwsA(isA<WorkflowException>()));
      final saved = (await service.pendingForEvent('event-a'))!;
      await expectLater(
        submit(correctionId: 'replacement-identity'),
        throwsA(anything),
      );
      expect(gateway.envelopes, hasLength(1));
      expect(
        (await journal.read(saved.submissionId))!.envelopeJson,
        saved.envelopeJson,
      );
    },
  );

  test(
    'missing readback keeps accepted evidence through restart without redispatch',
    () async {
      readbackAvailable = false;
      await expectLater(submit(), throwsA(isA<StateError>()));
      final saved = (await service.pendingForEvent('event-a'))!;
      expect(saved.state.isAccepted, isTrue);
      await reopen();
      readbackAvailable = true;
      await service.resume(saved.submissionId);
      expect(gateway.envelopes, hasLength(1));
      expect(
        (await journal.read(saved.submissionId))!.state,
        DurableSubmissionState.reconciled,
      );
    },
  );

  test(
    'a different account cannot discover or resume the original correction',
    () async {
      gateway.error = const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Reply lost',
      );
      await expectLater(submit(), throwsA(isA<WorkflowException>()));
      final saved = (await service.pendingForEvent('event-a'))!;
      actor = 'admin-b';
      await expectLater(
        service.pendingForEvent('event-a'),
        throwsA(isA<WorkflowException>()),
      );
      await expectLater(
        service.resume(saved.submissionId),
        throwsA(isA<WorkflowException>()),
      );
      expect(gateway.envelopes, hasLength(1));
    },
  );

  test(
    'account changes during response retain acceptance without adopting it',
    () async {
      gateway.beforeReply = (_) async {
        actor = 'admin-b';
      };
      await expectLater(submit(), throwsA(isA<WorkflowException>()));
      final command =
          (jsonDecode(gateway.envelopes.single) as Map)['command'] as Map;
      final saved = (await journal.read(command['commandId'] as String))!;
      expect(saved.state.isAccepted, isTrue);
      expect(readbacks, 0);
      actor = 'admin-a';
      await service.resume(saved.submissionId);
      expect(gateway.envelopes, hasLength(1));
    },
  );

  test('mismatched receipt never becomes accepted or reconciled', () async {
    gateway.mutateResult = true;
    await expectLater(submit(), throwsA(isA<WorkflowException>()));
    final saved = (await service.pendingForEvent('event-a'))!;
    expect(saved.state, DurableSubmissionState.uncertain);
    expect(saved.receiptJson, isNull);
    expect(readbacks, 0);
  });

  test(
    'refusal after an uncertain earlier attempt does not release its resource',
    () async {
      gateway.error = const WorkflowException(
        WorkflowErrorCode.unavailable,
        'Reply lost',
      );
      await expectLater(submit(), throwsA(isA<WorkflowException>()));
      final saved = (await service.pendingForEvent('event-a'))!;
      gateway.error = const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'Stale',
        details: {'reasonCode': 'uv-detector-lifecycle-correction-stale'},
      );
      await expectLater(
        service.resume(saved.submissionId),
        throwsA(isA<WorkflowException>()),
      );
      expect(
        (await journal.read(saved.submissionId))!.state,
        DurableSubmissionState.uncertain,
      );
    },
  );

  test(
    'first-attempt current-installation conflict releases only the refused intent',
    () async {
      gateway.error = const WorkflowException(
        WorkflowErrorCode.failedPrecondition,
        'Current changed',
        details: {
          'reasonCode': 'uv-detector-lifecycle-current-version-conflict',
        },
      );
      await expectLater(submit(), throwsA(isA<WorkflowException>()));
      expect(await service.pendingForEvent('event-a'), isNull);
      final command =
          (jsonDecode(gateway.envelopes.single) as Map)['command'] as Map;
      expect(
        (await journal.read(command['commandId'] as String))!.state,
        DurableSubmissionState.rejected,
      );
    },
  );

  test(
    'a receipt with a different reviewed current time is not accepted',
    () async {
      gateway.mutateCurrentTime = true;
      await expectLater(submit(), throwsA(isA<WorkflowException>()));
      final saved = (await service.pendingForEvent('event-a'))!;
      expect(saved.state, DurableSubmissionState.uncertain);
      expect(saved.receiptJson, isNull);
      expect(readbacks, 0);
    },
  );

  test('missing reviewed current time is retained without dispatch', () async {
    final saved = await journal.prepare(
      DurableSubmissionDraft(
        submissionId: 'damaged-command',
        actorUid: actor,
        requestId: 'damaged-command',
        aggregateId: 'damaged-correction',
        resourceKey: UvDetectorCorrectionCommandService.resource('event-a'),
        protocol: 'maintenanceWorkflow.v2',
        envelopeJson: jsonEncode({
          'protocolVersion': 2,
          'originActorUid': actor,
          'command': {
            'commandId': 'damaged-command',
            'commandType': 'correctUvDetectorInstallation',
            'aggregateId': 'damaged-correction',
            'expectedVersion': 0,
            'payload': {
              'eventId': 'event-a',
              'expectedCurrentEventId': 'event-current',
              'correctedActionPerformedAt': '2026-09-18T10:00:00.000Z',
              'reason': 'Reviewed explanation',
              'supersedesCorrectionId': null,
            },
          },
        }),
      ),
    );
    await expectLater(
      service.resume(saved.submissionId),
      throwsA(isA<WorkflowException>()),
    );
    expect(gateway.envelopes, isEmpty);
    expect(
      (await journal.read(saved.submissionId))!.envelopeJson,
      saved.envelopeJson,
    );
  });

  test('unavailable native storage prevents dispatch', () async {
    await database.close(deleteFromDisk: true);
    await expectLater(submit(), throwsA(anything));
    expect(gateway.envelopes, isEmpty);
  });
}

class _Gateway implements OriginBoundWorkflowCommandGateway {
  final envelopes = <String>[];
  WorkflowException? error;
  bool mutateResult = false;
  bool mutateCurrentTime = false;
  Future<void> Function(String)? beforeReply;
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    envelopes.add(envelopeJson);
    await beforeReply?.call(envelopeJson);
    if (error case final failure?) throw failure;
    final envelope = jsonDecode(envelopeJson) as Map<String, dynamic>;
    final command = envelope['command'] as Map<String, dynamic>;
    final payload = command['payload'] as Map<String, dynamic>;
    return WorkflowCommandReceipt(
      commandId: command['commandId'] as String,
      resultKey: 'uv-detector-installation-corrected',
      aggregateVersion: 1,
      appliedAt: DateTime.utc(2026, 9, 20),
      result: {
        'correctionId': command['aggregateId'],
        'correctsEventId': mutateResult ? 'another-event' : payload['eventId'],
        'expectedCurrentEventId': payload['expectedCurrentEventId'],
        'expectedCurrentActionPerformedAt': mutateCurrentTime
            ? '2026-09-19T10:01:00.000Z'
            : payload['expectedCurrentActionPerformedAt'],
        'correctedActionPerformedAt': payload['correctedActionPerformedAt'],
        'supersedesCorrectionId': payload['supersedesCorrectionId'],
        'auditId': 'server_uv_detector_correction_${command['commandId']}',
        'recordedActionPerformedAt': '2026-09-19T10:00:00.000Z',
        'currentEventId': 'current-a',
        'currentActionPerformedAt': '2026-09-19T10:00:00.000Z',
        'auditSchemaVersion': 2,
        'auditFingerprint':
            'sha256:0000000000000000000000000000000000000000000000000000000000000000',
        'assetInstanceId': 'furnace-a',
        'burnerPosition': 1,
      },
    );
  }
}
