import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/planned_job_closure_attestation.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/planned_job_closure_guard.dart';

JobModuleInstance _module({
  required String id,
  required bool requiredForClosure,
  required JobModuleStatus status,
  List<Map<String, dynamic>> fields = const <Map<String, dynamic>>[],
  List<FieldResponse> responses = const <FieldResponse>[],
  bool requiresFollowUp = false,
  String? pendingIssue,
  bool isDeleted = false,
  int version = 1,
}) {
  final now = DateTime.utc(2026, 5, 15, 1, 2, 3);
  return JobModuleInstance()
    ..firestoreId = id
    ..moduleTitle = 'Module $id'
    ..moduleCode = 'M-$id'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..requiredForClosure = requiredForClosure
    ..status = status
    ..version = version
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..fieldDefinitionsJson = jsonEncode(fields)
    ..responses = responses
    ..requiresFollowUp = requiresFollowUp
    ..pendingIssue = pendingIssue
    ..createdAt = now
    ..updatedAt = now
    ..isDeleted = isDeleted;
}

FieldResponse _response(String key, dynamic value) {
  return FieldResponse(
    key: key,
    fieldLabel: key,
    fieldType: FieldType.text,
    value: value,
  );
}

JobModuleInstance _crossLanguageGoldenModule() {
  final now = DateTime.utc(2026, 5, 15, 1, 2, 3);
  return JobModuleInstance()
    ..id = 42
    ..firestoreId = 'module_gold_1'
    ..jobExecutionFirestoreId = 'exec_gold_1'
    ..jobExecutionLocalId = 99
    ..templateModuleId = 'template_module_gold_1'
    ..moduleTitle = 'Golden closure module'
    ..moduleCode = 'BAF-GOLD-01'
    ..assetType = AssetType.base
    ..assetNumber = 101
    ..requiredForClosure = true
    ..status = JobModuleStatus.accepted
    ..version = 3
    ..discipline = JobModuleDiscipline.mechanical
    ..safetyClass = JobModuleSafetyClass.normal
    ..fieldDefinitionsJson = jsonEncode([
      {'key': 'vt_reading', 'type': 'number', 'isRequired': true},
    ])
    ..responses = [
      FieldResponse(
        key: 'vt_reading',
        fieldLabel: 'vt_reading',
        fieldType: FieldType.text,
        value: '2.1 mm/s',
      ),
    ]
    ..requiresFollowUp = false
    ..pendingIssue = null
    ..createdAt = now
    ..updatedAt = now
    ..isDeleted = false;
}

PlannedJobClosureAttestation _attest(List<JobModuleInstance> modules) {
  return PlannedJobClosureGuard.assertReadyAndAttest(
    executionFirestoreId: 'exec-1',
    modules: modules,
    completedByUid: 'uid-1',
    completedByName: 'Supervisor',
    completedAt: DateTime.utc(2026, 5, 15, 8, 30),
    executionVersionAtCompletion: 4,
  );
}

void main() {
  group('PlannedJobClosureAttestation', () {
    test('matches TypeScript golden attestation hash fixture', () {
      final attestation = PlannedJobClosureGuard.assertReadyAndAttest(
        executionFirestoreId: 'exec_gold_1',
        modules: [_crossLanguageGoldenModule()],
        completedByUid: 'uid_gold',
        completedByName: 'Shift Supervisor',
        completedAt: DateTime.utc(2026, 5, 15, 8, 30),
        executionVersionAtCompletion: 5,
      );

      expect(
        attestation.hash,
        '815359e2224faef4c3d6c7925053c0013d2b326cc57092025a4584ff9d98b4ee',
      );
      expect(
        attestation.canonicalJson,
        contains('"moduleKey":"firestore:module_gold_1"'),
      );

      final modules = attestation.payload['modules'] as List<dynamic>;
      expect(
        modules.single['snapshotHash'],
        '16181a9bf6da5e2399917925c29c6ab29d8631cc3efb310e8eab2a439d1e20b1',
      );
    });

    test('builds deterministic metadata envelope for ready modules', () {
      final attestation = _attest([
        _module(
          id: 'required-accepted',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
          fields: const [
            {'key': 'temperature', 'type': 'text', 'isRequired': true},
          ],
          responses: [_response('temperature', 'ok')],
        ),
      ]);

      expect(attestation.hash, hasLength(64));
      expect(attestation.payload['schemaVersion'], 1);
      expect(attestation.payload['executionFirestoreId'], 'exec-1');

      final metadata = attestation.toMetadataEnvelope();
      expect(metadata['schemaVersion'], 1);
      expect(metadata['hash'], attestation.hash);
      expect(metadata['canonicalJson'], attestation.canonicalJson);

      expect(attestation.payload['moduleCounts']['requiredForClosure'], 1);
      expect(
        attestation.payload['guardIssueCounts']['missingRequiredEvidence'],
        0,
      );
    });

    test('hash is stable when module order changes', () {
      final first = _attest([
        _module(
          id: 'b',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
        ),
        _module(
          id: 'a',
          requiredForClosure: true,
          status: JobModuleStatus.notApplicable,
        ),
      ]);

      final second = _attest([
        _module(
          id: 'a',
          requiredForClosure: true,
          status: JobModuleStatus.notApplicable,
        ),
        _module(
          id: 'b',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
        ),
      ]);

      expect(second.hash, first.hash);
      expect(second.canonicalJson, first.canonicalJson);
    });

    test('hash changes when validated module evidence changes', () {
      final first = _attest([
        _module(
          id: 'required-accepted',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
          fields: const [
            {'key': 'amps', 'type': 'text', 'isRequired': true},
          ],
          responses: [_response('amps', '12.3')],
        ),
      ]);

      final second = _attest([
        _module(
          id: 'required-accepted',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
          fields: const [
            {'key': 'amps', 'type': 'text', 'isRequired': true},
          ],
          responses: [_response('amps', '12.4')],
        ),
      ]);

      expect(second.hash, isNot(first.hash));
    });

    test(
      'captures evidence, follow-up and pending-issue state without raw value',
      () {
        final attestation = _attest([
          _module(
            id: 'required-na',
            requiredForClosure: true,
            status: JobModuleStatus.notApplicable,
            fields: const [
              {'key': 'remarks', 'type': 'text', 'isRequired': true},
            ],
            responses: [_response('remarks', 'not applicable due shutdown')],
            version: 7,
          ),
          _module(
            id: 'optional-attention',
            requiredForClosure: false,
            status: JobModuleStatus.inProgress,
            requiresFollowUp: true,
            pendingIssue: 'inspect after next cycle',
          ),
        ]);

        final modules = attestation.payload['modules'] as List<dynamic>;
        final module = modules.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['firestoreId'] == 'required-na',
        );
        final optionalModule = modules.cast<Map<String, dynamic>>().firstWhere(
          (entry) => entry['firestoreId'] == 'optional-attention',
        );

        expect(module['version'], 7);
        expect(module['status'], JobModuleStatus.notApplicable.name);
        expect(module['ordinaryRequiredFieldKeys'], ['remarks']);
        expect(module['missingRequiredEvidenceKeys'], isEmpty);
        expect(module['responsesHash'], isA<String>());
        expect(
          module['responseEvidenceByRequiredKey']['remarks']['hasEvidence'],
          isTrue,
        );
        expect(
          module['responseEvidenceByRequiredKey']['remarks']['valueHash'],
          isA<String>(),
        );
        expect(
          module.toString(),
          isNot(contains('not applicable due shutdown')),
        );

        expect(optionalModule['requiresFollowUp'], isTrue);
        expect(optionalModule['hasPendingIssue'], isTrue);
        expect(optionalModule['pendingIssueHash'], isA<String>());
        expect(
          optionalModule.toString(),
          isNot(contains('inspect after next cycle')),
        );
      },
    );

    test('metadata merge preserves existing metadata object', () {
      final attestation = _attest([
        _module(
          id: 'required-accepted',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
        ),
      ]);

      final merged = PlannedJobClosureAttestation.mergeIntoMetadataJson(
        '{"existingKey":"existingValue"}',
        attestation,
      );

      final decoded = jsonDecode(merged) as Map<String, dynamic>;
      expect(decoded['existingKey'], 'existingValue');
      expect(
        decoded[PlannedJobClosureAttestation.metadataKey]['hash'],
        attestation.hash,
      );
    });

    test('metadata merge preserves invalid legacy metadata text', () {
      final attestation = _attest([
        _module(
          id: 'required-accepted',
          requiredForClosure: true,
          status: JobModuleStatus.accepted,
        ),
      ]);

      final merged = PlannedJobClosureAttestation.mergeIntoMetadataJson(
        'legacy free text',
        attestation,
      );

      final decoded = jsonDecode(merged) as Map<String, dynamic>;
      expect(decoded['legacyMetadataJson'], 'legacy free text');
      expect(decoded, contains(PlannedJobClosureAttestation.metadataKey));
    });

    test(
      'guard integration throws before attestation when closure is not ready',
      () {
        expect(
          () => PlannedJobClosureGuard.assertReadyAndAttest(
            executionFirestoreId: 'exec-1',
            modules: [
              _module(
                id: 'required-open',
                requiredForClosure: true,
                status: JobModuleStatus.inProgress,
              ),
            ],
            completedByUid: 'uid-1',
            completedByName: 'Supervisor',
            completedAt: DateTime.utc(2026, 5, 15, 8, 30),
            executionVersionAtCompletion: 4,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
