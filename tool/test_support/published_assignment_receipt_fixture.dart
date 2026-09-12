import 'dart:convert';

Map<String, dynamic> publishedAssignmentReceipt() => <String, dynamic>{
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
    'assetNumber': 101,
    'isCompleted': false,
    'assignedByUid': 'assigner-1',
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
      'assetNumber': 101,
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

Map<String, dynamic> retainedAssignmentReceipt(
  String requestId, {
  String actor = 'assigner-1',
}) {
  final response = publishedAssignmentReceipt();
  response['requestId'] = requestId;
  final execution = response['execution'] as Map<String, dynamic>;
  execution['assignedByUid'] = actor;
  final metadata = {
    'source': 'server_governed_published_template_assignment',
    'requestId': requestId,
    'publicationAuditId': 'audit-1',
    'assignmentAssetIdentity': {
      'assetClassId': 'class-base',
      'assetInstanceId': 'base-101',
      'assetNumber': 101,
    },
  };
  execution['metadataJson'] = jsonEncode(metadata);
  for (final module in response['modules'] as List) {
    module['createdByUid'] = actor;
    module['metadataJson'] = jsonEncode(metadata);
  }
  return response;
}
