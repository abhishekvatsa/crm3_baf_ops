import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/features/assets/repositories/uv_detector_correction_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'uv_detector_installation_correction_test.dart' as fixtures;

void main() {
  final original = <String, dynamic>{
    'schemaVersion': 1,
    'version': 1,
    'eventId': 'event-a',
    'eventType': 'replacement',
    'resultingCondition': 'serviceable',
    'installationDiscipline': 'instrumentation',
    'assetClassId': 'furnace',
    'assetClassCode': 'FURNACE',
    'assetClassName': 'Furnace',
    'assetInstanceId': 'furnace-a',
    'assetInstanceName': 'Furnace 1',
    'assetNumber': 1,
    'hierarchyNodeId': 'uv',
    'hierarchyNodeName': 'UV flame scanner',
    'hierarchyPath': ['Furnace', 'UV flame scanner'],
    'componentTag': 'UV-1',
    'burnerPosition': 1,
    'replacementDisposition': 'newPart',
    'performedByName': 'Technician',
    'sourceType': 'workflowPlannedJob',
    'sourceId': 'execution-a',
    'sourceModuleId': 'module-a',
    'sourceActionId': 'action-a',
    'sourceActionIndex': 0,
    'actionPerformedAt': '2026-09-18T10:00:00.000Z',
    'completedAt': '2026-09-19T10:00:00.000Z',
    'recordedAt': '2026-09-19T10:00:00.000Z',
    'completedByUid': 'supervisor',
    'completedByName': 'Supervisor',
    'isDeleted': false,
  };
  final correction = fixtures.correction('first')
    ..['correctedActionPerformedAt'] = '2026-09-17T10:00:00.000Z';
  final command = <String, dynamic>{
    'commandId': 'request-a',
    'commandType': 'correctUvDetectorInstallation',
    'aggregateId': 'first',
    'expectedVersion': 0,
    'payload': <String, dynamic>{
      'eventId': 'event-a',
      'expectedCurrentEventId': 'current-a',
      'expectedCurrentActionPerformedAt': '2026-09-19T10:00:00.000Z',
      'correctedActionPerformedAt': '2026-09-17T10:00:00.000Z',
      'reason': 'Correct physical time.',
      'supersedesCorrectionId': null,
    },
  };
  final envelope = jsonEncode({
    'protocolVersion': 2,
    'originActorUid': 'admin-a',
    'command': command,
  });
  final current = {
    'currentEventId': 'current-a',
    'actionPerformedAt': '2026-09-19T10:00:00.000Z',
  };
  final audit = <String, dynamic>{
    'schemaVersion': 2,
    'auditId': 'server_uv_detector_correction_request-a',
    'entityType': 'uvDetectorInstallationCorrection',
    'entityId': 'first',
    'action': 'update',
    'operation': 'correctUvDetectorInstallation',
    'performedByUid': 'admin-a',
    'performedByName': 'Admin A',
    'timestamp': '2026-09-20T10:00:00.000Z',
    'reason': 'correction',
    'reasonNotes': 'Correct physical time.',
    'summary': 'UV detector installation time corrected',
    'severity': 'medium',
    'beforeJson': jsonEncode({
      'correctedEvent': original,
      'correctionInForce': {},
      'currentInstallation': {},
    }),
    'afterJson': jsonEncode({
      'correction': correction,
      'currentInstallation': current,
    }),
    'requestId': 'request-a',
    'resultVersion': 1,
    'commandFingerprint':
        UvDetectorCorrectionRepository.retainedAuditFingerprint(command),
  };
  final receipt = WorkflowCommandReceipt(
    commandId: 'request-a',
    resultKey: 'uv-detector-installation-corrected',
    aggregateVersion: 1,
    appliedAt: DateTime.utc(2026, 9, 20, 10),
    result: {
      'correctionId': 'first',
      'correctsEventId': 'event-a',
      'expectedCurrentEventId': 'current-a',
      'expectedCurrentActionPerformedAt': '2026-09-19T10:00:00.000Z',
      'assetInstanceId': 'furnace-a',
      'burnerPosition': 1,
      'recordedActionPerformedAt': '2026-09-18T10:00:00.000Z',
      'correctedActionPerformedAt': '2026-09-17T10:00:00.000Z',
      'supersedesCorrectionId': null,
      'currentEventId': 'current-a',
      'currentActionPerformedAt': '2026-09-19T10:00:00.000Z',
      'auditSchemaVersion': 2,
      'auditId': 'server_uv_detector_correction_request-a',
      'auditFingerprint':
          UvDetectorCorrectionRepository.retainedAuditFingerprint(audit),
    },
  );

  test(
    'actual retained readback binds the complete correction and original subject to accepted audit',
    () {
      final nativeAudit = {
        ...audit,
        'timestamp': Timestamp.fromDate(receipt.appliedAt),
      };
      final nativeCorrection = {
        ...correction,
        'correctedAt': Timestamp.fromDate(receipt.appliedAt),
      };
      expect(
        UvDetectorCorrectionRepository.verifyRetainedEvidence(
          nativeCorrection,
          'first',
          receipt,
          envelope,
          originalData: original,
          auditData: nativeAudit,
        ).reviewerName,
        'Admin A',
      );
    },
  );
  test(
    'native original Timestamp JSON retained by backend audit matches server Timestamp readback',
    () {
      final retainedOriginal = Map<String, dynamic>.from(original);
      final nativeOriginal = Map<String, dynamic>.from(original);
      for (final field in ['actionPerformedAt', 'completedAt', 'recordedAt']) {
        final instant = DateTime.parse(original[field] as String);
        retainedOriginal[field] = <String, dynamic>{
          '_seconds': instant.millisecondsSinceEpoch ~/ 1000,
          '_nanoseconds': 0,
        };
        nativeOriginal[field] = Timestamp.fromDate(instant);
      }
      final currentInstant = DateTime.parse(current['actionPerformedAt']!);
      final retainedCurrent = {
        ...current,
        'actionPerformedAt': {
          '_seconds': currentInstant.millisecondsSinceEpoch ~/ 1000,
          '_nanoseconds': 0,
        },
      };
      final nativeAudit = {
        ...audit,
        'beforeJson': jsonEncode({
          'correctedEvent': retainedOriginal,
          'correctionInForce': {},
          'currentInstallation': {},
        }),
        'afterJson': jsonEncode({
          'correction': correction,
          'currentInstallation': retainedCurrent,
        }),
      };
      final nativeReceipt = WorkflowCommandReceipt(
        commandId: receipt.commandId,
        resultKey: receipt.resultKey,
        aggregateVersion: receipt.aggregateVersion,
        appliedAt: receipt.appliedAt,
        result: {
          ...receipt.result,
          'auditFingerprint':
              UvDetectorCorrectionRepository.retainedAuditFingerprint(
                nativeAudit,
              ),
        },
      );
      UvDetectorCorrectionRepository.verifyRetainedEvidence(
        correction,
        'first',
        nativeReceipt,
        envelope,
        originalData: nativeOriginal,
        auditData: nativeAudit,
      );
      for (final nanos in [1, 1001, -1, 1000000000, 0.5]) {
        (retainedOriginal['actionPerformedAt'] as Map)['_nanoseconds'] = nanos;
        final invalidAudit = {
          ...nativeAudit,
          'beforeJson': jsonEncode({
            'correctedEvent': retainedOriginal,
            'correctionInForce': {},
            'currentInstallation': {},
          }),
        };
        final invalidReceipt = WorkflowCommandReceipt(
          commandId: receipt.commandId,
          resultKey: receipt.resultKey,
          aggregateVersion: receipt.aggregateVersion,
          appliedAt: receipt.appliedAt,
          result: {
            ...receipt.result,
            'auditFingerprint':
                UvDetectorCorrectionRepository.retainedAuditFingerprint(
                  invalidAudit,
                ),
          },
        );
        expect(
          () => UvDetectorCorrectionRepository.verifyRetainedEvidence(
            correction,
            'first',
            invalidReceipt,
            envelope,
            originalData: nativeOriginal,
            auditData: invalidAudit,
          ),
          throwsA(anything),
        );
      }
    },
  );
  for (final mutation in <String, Object?>{
    'assetClassId': 'other-class',
    'assetNumber': 2,
    'componentTag': 'UV-2',
    'correctedByName': 'Other reviewer',
  }.entries) {
    test(
      'retained readback rejects correction ${mutation.key} drift omitted from receipt scalar fields',
      () {
        expect(
          () => UvDetectorCorrectionRepository.verifyRetainedEvidence(
            {...correction, mutation.key: mutation.value},
            'first',
            receipt,
            envelope,
            originalData: original,
            auditData: audit,
          ),
          throwsStateError,
        );
      },
    );
  }
  test('retained readback rejects unsupported or missing receipt evidence', () {
    for (final result in [
      {...receipt.result, 'unsupported': true},
      {...receipt.result}..remove('currentEventId'),
      {...receipt.result, 'auditSchemaVersion': 2.0},
      {
        ...receipt.result,
        'currentActionPerformedAt': '2026-09-19T10:00:00.000001Z',
      },
    ]) {
      final invalid = WorkflowCommandReceipt(
        commandId: receipt.commandId,
        resultKey: receipt.resultKey,
        aggregateVersion: receipt.aggregateVersion,
        result: result,
        appliedAt: receipt.appliedAt,
      );
      expect(
        () => UvDetectorCorrectionRepository.verifyRetainedEvidence(
          correction,
          'first',
          invalid,
          envelope,
          originalData: original,
          auditData: audit,
        ),
        throwsA(anything),
      );
    }
  });
  test(
    'retained readback rejects audit replacement, altered original and sub-millisecond timestamp',
    () {
      for (final replacement in [
        {...audit, 'performedByName': 'Changed'},
        {...audit, 'commandFingerprint': 'sha256:altered'},
        {
          ...audit,
          'afterJson': jsonEncode({
            'correction': {...correction, 'correctedByName': 'Changed'},
            'currentInstallation': current,
          }),
        },
        {
          ...audit,
          'timestamp': Timestamp(
            receipt.appliedAt.millisecondsSinceEpoch ~/ 1000,
            1,
          ),
        },
      ]) {
        expect(
          () => UvDetectorCorrectionRepository.verifyRetainedEvidence(
            correction,
            'first',
            receipt,
            envelope,
            originalData: original,
            auditData: replacement,
          ),
          throwsA(anything),
        );
      }
      expect(
        () => UvDetectorCorrectionRepository.verifyRetainedEvidence(
          correction,
          'first',
          receipt,
          envelope,
          originalData: {
            ...original,
            'assetClassName': 'Altered original snapshot',
          },
          auditData: audit,
        ),
        throwsStateError,
      );
    },
  );
}
