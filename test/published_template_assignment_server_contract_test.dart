import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_server_service.dart';

Map<String, dynamic> _canonicalResponse() => <String, dynamic>{
  'ok': true,
  'requestId': 'request-1',
  'executionId': 'execution-1',
  'idempotentReplay': false,
  'publicationAuditId': 'audit-1',
  'assignedAt': '2026-06-19T12:00:00.000Z',
  'execution': <String, dynamic>{
    'firestoreId': 'execution-1',
    'templateFirestoreId': 'version-1',
    'templateName': 'Governed job',
    'templatePackageId': 'package-1',
    'templateVersionId': 'version-1',
    'templateVersionNumber': 1,
    'templateContentHash': 'hash-1',
    'assetType': 'base',
    'assetNumber': 17,
    'isCompleted': false,
    'assignedAgencies': <String>['mechanical'],
    'responsesJson': '[]',
    'actionsJson': '[]',
    'version': 1,
    'isDeleted': false,
    'createdAt': '2026-06-19T12:00:00Z',
    'updatedAt': '2026-06-19T12:00:00Z',
  },
  'modules': <Map<String, dynamic>>[
    <String, dynamic>{
      'firestoreId': 'module-1',
      'jobExecutionFirestoreId': 'execution-1',
      'templateFirestoreId': 'version-1',
      'templatePackageId': 'package-1',
      'templateVersionId': 'version-1',
      'moduleCode': 'B-01',
      'moduleTitle': 'Base inspection',
      'moduleSnapshotJson': '{}',
      'fieldDefinitionsJson': '[]',
      'assetType': 'base',
      'assetNumber': 17,
      'status': 'notStarted',
      'useMode': 'scheduledPM',
      'discipline': 'mechanical',
      'safetyClass': 'normal',
      'isRequired': true,
      'requiredForClosure': true,
      'displayOrder': 0,
      'responsesJson': '[]',
      'actionsJson': '[]',
      'version': 1,
      'isDeleted': false,
      'createdAt': '2026-06-19T12:00:00Z',
      'updatedAt': '2026-06-19T12:00:00Z',
    },
  ],
};

void main() {
  test('assignment request fingerprint excludes request id', () {
    const first = PublishedTemplateAssignmentRequest(
      requestId: 'request-a',
      packageFirestoreId: 'package-1',
      versionFirestoreId: 'version-1',
      expectedVersionNumber: 1,
      expectedContentHash: 'hash-1',
      assetType: AssetType.base,
      assetNumber: 17,
      remarks: 'Inspect',
    );
    const second = PublishedTemplateAssignmentRequest(
      requestId: 'request-b',
      packageFirestoreId: 'package-1',
      versionFirestoreId: 'version-1',
      expectedVersionNumber: 1,
      expectedContentHash: 'hash-1',
      assetType: AssetType.base,
      assetNumber: 17,
      remarks: 'Inspect',
    );

    expect(first.payloadFingerprint, second.payloadFingerprint);
  });

  test('parses canonical execution and modules returned by callable', () {
    final result = PublishedTemplateAssignmentServerResult.fromCallableData(
      <String, dynamic>{
        'ok': true,
        'requestId': 'request-1',
        'executionId': 'execution-1',
        'idempotentReplay': false,
        'publicationAuditId': 'audit-1',
        'assignedAt': '2026-06-19T12:00:00.000Z',
        'execution': <String, dynamic>{
          'firestoreId': 'execution-1',
          'templateFirestoreId': 'version-1',
          'templateName': 'Governed job',
          'templatePackageId': 'package-1',
          'templateVersionId': 'version-1',
          'templateVersionNumber': 1,
          'templateContentHash': 'hash-1',
          'assetType': 'base',
          'assetNumber': 17,
          'isCompleted': false,
          'assignedAgencies': <String>['mechanical'],
          'responsesJson': '[]',
          'actionsJson': '[]',
          'version': 1,
          'isDeleted': false,
          'createdAt': '2026-06-19T12:00:00Z',
          'updatedAt': '2026-06-19T12:00:00Z',
        },
        'modules': <Map<String, dynamic>>[
          <String, dynamic>{
            'firestoreId': 'module-1',
            'jobExecutionFirestoreId': 'execution-1',
            'templateFirestoreId': 'version-1',
            'templatePackageId': 'package-1',
            'templateVersionId': 'version-1',
            'moduleCode': 'B-01',
            'moduleTitle': 'Base inspection',
            'moduleSnapshotJson': '{}',
            'fieldDefinitionsJson': '[]',
            'assetType': 'base',
            'assetNumber': 17,
            'status': 'notStarted',
            'useMode': 'scheduledPM',
            'discipline': 'mechanical',
            'safetyClass': 'normal',
            'isRequired': true,
            'requiredForClosure': true,
            'displayOrder': 0,
            'responsesJson': '[]',
            'actionsJson': '[]',
            'version': 1,
            'isDeleted': false,
            'createdAt': '2026-06-19T12:00:00Z',
            'updatedAt': '2026-06-19T12:00:00Z',
          },
        ],
      },
      fallbackRequestId: 'request-1',
    );

    expect(result.execution.firestoreId, 'execution-1');
    expect(result.execution.isSynced, isTrue);
    expect(result.modules.single.firestoreId, 'module-1');
    expect(result.modules.single.isSynced, isTrue);
    expect(result.publicationAuditFirestoreId, 'audit-1');
  });
  test('rejects response modules linked to another execution', () {
    expect(
      () => PublishedTemplateAssignmentServerResult.fromCallableData(
        <String, dynamic>{
          'requestId': 'request-1',
          'execution': <String, dynamic>{
            'firestoreId': 'execution-1',
            'templateFirestoreId': 'version-1',
            'assetType': 'base',
            'assetNumber': 17,
            'createdAt': '2026-06-19T12:00:00Z',
            'updatedAt': '2026-06-19T12:00:00Z',
          },
          'modules': <Map<String, dynamic>>[
            <String, dynamic>{
              'firestoreId': 'module-1',
              'jobExecutionFirestoreId': 'execution-2',
              'moduleSnapshotJson': '{}',
              'fieldDefinitionsJson': '[]',
              'moduleTitle': 'Mismatch',
              'assetType': 'base',
              'assetNumber': 17,
              'createdAt': '2026-06-19T12:00:00Z',
              'updatedAt': '2026-06-19T12:00:00Z',
            },
          ],
        },
        fallbackRequestId: 'request-1',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a changed response request identity', () {
    expect(
      () => PublishedTemplateAssignmentServerResult.fromCallableData(
        <String, dynamic>{
          'requestId': 'request-other',
          'execution': <String, dynamic>{
            'firestoreId': 'execution-1',
            'templateFirestoreId': 'version-1',
            'assetType': 'base',
            'assetNumber': 17,
            'createdAt': '2026-06-19T12:00:00Z',
            'updatedAt': '2026-06-19T12:00:00Z',
          },
          'modules': <Map<String, dynamic>>[
            <String, dynamic>{
              'firestoreId': 'module-1',
              'jobExecutionFirestoreId': 'execution-1',
              'moduleSnapshotJson': '{}',
              'fieldDefinitionsJson': '[]',
              'moduleTitle': 'Base inspection',
              'assetType': 'base',
              'assetNumber': 17,
              'createdAt': '2026-06-19T12:00:00Z',
              'updatedAt': '2026-06-19T12:00:00Z',
            },
          ],
        },
        fallbackRequestId: 'request-1',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('requires exact callable response evidence fields', () {
    final invalidValues = <String, Object?>{
      'ok': false,
      'requestId': 7,
      'executionId': null,
      'idempotentReplay': 'false',
      'publicationAuditId': 9,
      'assignedAt': 20260619,
    };

    for (final entry in invalidValues.entries) {
      final response = _canonicalResponse()..[entry.key] = entry.value;
      expect(
        () => PublishedTemplateAssignmentServerResult.fromCallableData(
          response,
          fallbackRequestId: 'request-1',
        ),
        throwsA(isA<FormatException>()),
        reason: '${entry.key} must fail closed',
      );
    }
  });

  test('requires top-level and embedded execution identity to match', () {
    final response = _canonicalResponse();
    (response['execution'] as Map<String, dynamic>)['firestoreId'] =
        'execution-other';

    expect(
      () => PublishedTemplateAssignmentServerResult.fromCallableData(
        response,
        fallbackRequestId: 'request-1',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('requires assignment chronology to match the execution', () {
    final malformed = _canonicalResponse()..['assignedAt'] = 'not-a-date';
    final nonCanonical =
        _canonicalResponse()..['assignedAt'] = '2026-06-19T12:00:00Z';
    final mismatched =
        _canonicalResponse()..['assignedAt'] = '2026-06-19T12:00:01.000Z';

    for (final response in <Map<String, dynamic>>[
      malformed,
      nonCanonical,
      mismatched,
    ]) {
      expect(
        () => PublishedTemplateAssignmentServerResult.fromCallableData(
          response,
          fallbackRequestId: 'request-1',
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('rejects duplicate module identities', () {
    final response = _canonicalResponse();
    final modules = response['modules'] as List<Map<String, dynamic>>;
    modules.add(Map<String, dynamic>.from(modules.single));

    expect(
      () => PublishedTemplateAssignmentServerResult.fromCallableData(
        response,
        fallbackRequestId: 'request-1',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
