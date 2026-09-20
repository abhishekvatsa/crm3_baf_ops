import 'dart:convert';

import 'published_template_assignment_server_service.dart';

/// The accepted assignment is immutable; response/work versions are observations
/// reconciled separately by the existing atomic adopter, never receipt identity.
String publishedAssignmentAcceptanceIdentity(
  PublishedTemplateAssignmentServerResult value,
) {
  Object? canonical(Object? input) {
    if (input is Map) {
      return {
        for (final key in (input.keys.cast<String>().toList()..sort()))
          key: canonical(input[key]),
      };
    }
    if (input is List) return input.map(canonical).toList();
    return input;
  }

  Map<String, Object?> origin(String? raw) {
    final map = jsonDecode(raw!) as Map;
    return {
      for (final key in const [
        'source',
        'requestId',
        'publicationAuditId',
        'sourceMaintenancePlanId',
        'sourceMaintenancePlanVersion',
        'assignmentAssetIdentity',
        'assignmentInnerCoverPosition',
      ])
        key: map[key],
    };
  }

  Map<String, Object?> select(Map<String, dynamic> map, List<String> keys) => {
    for (final key in keys) key: map[key],
  };
  final modules = [...value.modules]
    ..sort((a, b) => a.firestoreId!.compareTo(b.firestoreId!));
  return jsonEncode(
    canonical({
      'requestId': value.requestId,
      'publicationAuditId': value.publicationAuditFirestoreId,
      'assignedAt': value.assignedAt.toUtc().toIso8601String(),
      'execution': select(value.execution.toMap(), const [
        'firestoreId',
        'templateFirestoreId',
        'templatePackageId',
        'templateVersionId',
        'templateVersionNumber',
        'templateContentHash',
        'assetType',
        'assetNumber',
        'assignedByUid',
      ]),
      'origin': origin(value.execution.metadataJson),
      'modules': modules
          .map(
            (module) => {
              ...select(module.toMap(), const [
                'firestoreId',
                'jobExecutionFirestoreId',
                'templateFirestoreId',
                'templatePackageId',
                'templateVersionId',
                'templateModuleId',
                'moduleCode',
                'assetType',
                'assetNumber',
                'createdByUid',
              ]),
              'createdAt': module.createdAt.toUtc().toIso8601String(),
              'origin': origin(module.metadataJson),
            },
          )
          .toList(),
    }),
  );
}
