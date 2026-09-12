import 'dart:convert';

import 'package:isar_community/isar.dart';

import '../data/job_module_model.dart';
import '../data/job_template_model.dart';
import 'published_template_assignment_server_service.dart';

/// Called only inside the submission store's reconciliation transaction. A
/// missing module/identity conflict rolls back the execution and marker too.
Future<void> adoptPublishedAssignmentInTransaction(
  Isar database,
  PublishedTemplateAssignmentServerResult accepted,
  void Function() requireOriginalActor,
) async {
  final incoming = accepted.execution;
  final executions = await database.jobExecutions
      .filter()
      .firestoreIdEqualTo(incoming.firestoreId!)
      .findAll();
  requireOriginalActor();
  if (executions.length > 1) _conflict();
  if (executions.isEmpty) {
    await database.jobExecutions.put(incoming);
  } else {
    final existing = executions.single;
    if (existing.templateFirestoreId != incoming.templateFirestoreId ||
        existing.templatePackageId != incoming.templatePackageId ||
        existing.templateVersionId != incoming.templateVersionId ||
        existing.templateVersionNumber != incoming.templateVersionNumber ||
        existing.templateContentHash != incoming.templateContentHash ||
        existing.assetType != incoming.assetType ||
        existing.assetNumber != incoming.assetNumber ||
        existing.assignedByUid != incoming.assignedByUid ||
        !existing.createdAt.isAtSameMomentAs(incoming.createdAt) ||
        !_sameOrigin(existing.metadataJson, incoming.metadataJson)) {
      _conflict();
    }
    if (existing.isSynced &&
        existing.version == incoming.version &&
        !_samePersistedProjection(existing.toMap(), incoming.toMap())) {
      _conflict();
    }
    if (existing.isSynced &&
        existing.version < incoming.version &&
        !existing.updatedAt.isAfter(incoming.updatedAt) &&
        !existing.isDeleted) {
      incoming.id = existing.id;
      await database.jobExecutions.put(incoming);
    }
  }
  requireOriginalActor();
  for (final incoming in accepted.modules) {
    final modules = await database.jobModuleInstances
        .filter()
        .firestoreIdEqualTo(incoming.firestoreId!)
        .findAll();
    requireOriginalActor();
    if (modules.length > 1) _conflict();
    incoming.jobExecutionLocalId = null;
    if (modules.isEmpty) {
      await database.jobModuleInstances.put(incoming);
      continue;
    }
    final existing = modules.single;
    if (existing.jobExecutionFirestoreId != incoming.jobExecutionFirestoreId ||
        existing.templateFirestoreId != incoming.templateFirestoreId ||
        existing.templatePackageId != incoming.templatePackageId ||
        existing.templateVersionId != incoming.templateVersionId ||
        existing.templateModuleId != incoming.templateModuleId ||
        existing.moduleCode != incoming.moduleCode ||
        existing.assetType != incoming.assetType ||
        existing.assetNumber != incoming.assetNumber ||
        existing.createdByUid != incoming.createdByUid ||
        !existing.createdAt.isAtSameMomentAs(incoming.createdAt) ||
        !_sameOrigin(existing.metadataJson, incoming.metadataJson)) {
      _conflict();
    }
    if (existing.isSynced &&
        existing.version == incoming.version &&
        !_samePersistedProjection(existing.toMap(), incoming.toMap())) {
      _conflict();
    }
    if (existing.isSynced &&
        existing.version < incoming.version &&
        !existing.updatedAt.isAfter(incoming.updatedAt) &&
        !existing.isDeleted) {
      incoming.id = existing.id;
      await database.jobModuleInstances.put(incoming);
    }
  }
  requireOriginalActor();
}

bool _sameOrigin(String? left, String? right) {
  if (left == null || right == null) return false;
  final a = jsonDecode(left);
  final b = jsonDecode(right);
  if (a is! Map || b is! Map) return false;
  return const [
    'source',
    'requestId',
    'publicationAuditId',
    'sourceMaintenancePlanId',
    'sourceMaintenancePlanVersion',
    'assignmentAssetIdentity',
    'assignmentInnerCoverPosition',
  ].every((key) => _sameJsonValue(a[key], b[key]));
}

// The public persisted shapes omit native row IDs and local sync bookkeeping.
// JSON object order and a timestamp's timezone spelling are not differences in
// business state. Clean rows at one version must otherwise agree completely.
bool _samePersistedProjection(Map<String, dynamic> a, Map<String, dynamic> b) {
  Map<String, dynamic> normalize(Map<String, dynamic> source) =>
      source.map((key, value) {
        if (value is String && key.endsWith('Json')) {
          return MapEntry(key, jsonDecode(value));
        }
        if (value is String && key.endsWith('At')) {
          return MapEntry(key, DateTime.parse(value).toUtc().toIso8601String());
        }
        return MapEntry(key, value);
      });
  return _sameJsonValue(normalize(a), normalize(b));
}

bool _sameJsonValue(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) && _sameJsonValue(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        List.generate(
          left.length,
          (index) => index,
        ).every((index) => _sameJsonValue(left[index], right[index]));
  }
  return left == right;
}

Never _conflict() => throw const PublishedTemplateAssignmentServerException(
  code: 'local-identity-conflict',
  message:
      'The assignment is accepted, but existing local work has conflicting origin or version evidence. All work is retained for review.',
);
