import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';
import '../data/job_template_model.dart';

const publishedTemplateAssignmentCallableName =
    'assignPublishedTemplateVersion';
const publishedTemplateAssignmentCallableRegion = 'asia-south1';

const _assignmentRequestUuid = Uuid();

String newPublishedTemplateAssignmentRequestId() => _assignmentRequestUuid.v4();

class PublishedTemplateAssignmentRequest {
  final String requestId;
  final String packageFirestoreId;
  final String versionFirestoreId;
  final int expectedVersionNumber;
  final String expectedContentHash;
  final AssetType assetType;
  final int assetNumber;
  final String? assetClassId;
  final String? assetInstanceId;
  final String? sourcePlanId;
  final int? sourcePlanExpectedVersion;
  final int? chargeNoAtEvent;
  final String? remarks;

  const PublishedTemplateAssignmentRequest({
    required this.requestId,
    required this.packageFirestoreId,
    required this.versionFirestoreId,
    required this.expectedVersionNumber,
    required this.expectedContentHash,
    required this.assetType,
    required this.assetNumber,
    this.assetClassId,
    this.assetInstanceId,
    this.sourcePlanId,
    this.sourcePlanExpectedVersion,
    this.chargeNoAtEvent,
    this.remarks,
  });

  Map<String, dynamic> toCallableData() {
    _requireCompleteGovernedIdentity();
    return <String, dynamic>{
      'requestId': requestId,
      'packageId': packageFirestoreId,
      'versionId': versionFirestoreId,
      'expectedVersionNumber': expectedVersionNumber,
      'expectedContentHash': expectedContentHash,
      'assetType': assetType.name,
      'assetNumber': assetNumber,
      if (_clean(assetClassId) != null) 'assetClassId': _clean(assetClassId),
      if (_clean(assetInstanceId) != null)
        'assetInstanceId': _clean(assetInstanceId),
      if (_clean(sourcePlanId) != null) 'sourcePlanId': _clean(sourcePlanId),
      if (sourcePlanExpectedVersion != null)
        'sourcePlanExpectedVersion': sourcePlanExpectedVersion,
      if (chargeNoAtEvent != null) 'chargeNoAtEvent': chargeNoAtEvent,
      if (_clean(remarks) != null) 'remarks': _clean(remarks),
    };
  }

  /// Stable fingerprint of the assignment meaning, excluding [requestId].
  ///
  /// The UI reuses the same request ID only while this fingerprint is
  /// unchanged. If the user changes package, version, asset, charge or remarks,
  /// the next submission receives a new idempotency ID.
  String get payloadFingerprint {
    _requireCompleteGovernedIdentity();
    final canonical = jsonEncode(<String, dynamic>{
      'packageId': packageFirestoreId,
      'versionId': versionFirestoreId,
      'expectedVersionNumber': expectedVersionNumber,
      'expectedContentHash': expectedContentHash,
      'assetType': assetType.name,
      'assetNumber': assetNumber,
      if (_clean(assetClassId) != null) 'assetClassId': _clean(assetClassId),
      if (_clean(assetInstanceId) != null)
        'assetInstanceId': _clean(assetInstanceId),
      if (_clean(sourcePlanId) != null) 'sourcePlanId': _clean(sourcePlanId),
      if (sourcePlanExpectedVersion != null)
        'sourcePlanExpectedVersion': sourcePlanExpectedVersion,
      'chargeNoAtEvent': chargeNoAtEvent,
      'remarks': _clean(remarks),
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  void _requireCompleteGovernedIdentity() {
    final hasClass = _clean(assetClassId) != null;
    final hasInstance = _clean(assetInstanceId) != null;
    if (hasClass != hasInstance) {
      throw StateError(
        'Governed assignment identity requires both assetClassId and assetInstanceId.',
      );
    }
    final hasPlan = _clean(sourcePlanId) != null;
    if (hasPlan != (sourcePlanExpectedVersion != null) ||
        (sourcePlanExpectedVersion != null && sourcePlanExpectedVersion! < 1)) {
      throw StateError(
        'A source maintenance plan requires its identity and positive expected version.',
      );
    }
  }
}

class PublishedTemplateAssignmentServerResult {
  final JobExecution execution;
  final List<JobModuleInstance> modules;
  final String requestId;
  final bool idempotentReplay;
  final String publicationAuditFirestoreId;
  final DateTime assignedAt;

  const PublishedTemplateAssignmentServerResult({
    required this.execution,
    required this.modules,
    required this.requestId,
    required this.idempotentReplay,
    required this.publicationAuditFirestoreId,
    required this.assignedAt,
  });

  factory PublishedTemplateAssignmentServerResult.fromCallableData(
    Object? raw, {
    required String fallbackRequestId,
    PublishedTemplateAssignmentRequest? expectedRequest,
  }) {
    if (raw is! Map || raw['ok'] != true) {
      throw const FormatException(
        'Server assignment returned an invalid response object.',
      );
    }
    final map = Map<String, dynamic>.from(raw);

    final executionRaw = map['execution'];
    if (executionRaw is! Map) {
      throw const FormatException(
        'Server assignment did not return a JobExecution.',
      );
    }
    final executionMap = Map<String, dynamic>.from(executionRaw);
    final executionId = _requiredResponseText(
      map['executionId'],
      field: 'executionId',
    );
    final executionDocumentId = _requiredResponseText(
      executionMap['firestoreId'],
      field: 'execution.firestoreId',
    );
    if (executionDocumentId != executionId) {
      throw const FormatException(
        'Server assignment returned mismatched JobExecution identities.',
      );
    }
    final execution = JobExecution.fromMap(executionMap, executionId)
      ..isSynced = true;

    final modulesRaw = map['modules'];
    if (modulesRaw is! List || modulesRaw.isEmpty) {
      throw const FormatException(
        'Server assignment did not return frozen JobModuleInstances.',
      );
    }
    final modules = <JobModuleInstance>[];
    final moduleIds = <String>{};
    for (final rawModule in modulesRaw) {
      if (rawModule is! Map) {
        throw const FormatException(
          'Server assignment returned an invalid module payload.',
        );
      }
      final moduleMap = Map<String, dynamic>.from(rawModule);
      final moduleId = _requiredResponseText(
        moduleMap['firestoreId'],
        field: 'modules.firestoreId',
      );
      if (!moduleIds.add(moduleId)) {
        throw FormatException(
          'Server assignment returned duplicate module identity $moduleId.',
        );
      }
      final module = JobModuleInstance.fromMap(moduleMap, moduleId)
        ..isSynced = true;
      if (_clean(module.jobExecutionFirestoreId) != executionId) {
        throw FormatException(
          'Server assignment returned module $moduleId for a different JobExecution.',
        );
      }
      modules.add(module);
    }

    final requestId = _requiredResponseText(
      map['requestId'],
      field: 'requestId',
    );
    if (requestId != fallbackRequestId) {
      throw FormatException(
        'Server assignment request identity changed. Expected '
        '$fallbackRequestId, received $requestId.',
      );
    }

    if (map['idempotentReplay'] is! bool) {
      throw const FormatException(
        'Server assignment returned an invalid replay flag.',
      );
    }
    final publicationAuditId = _requiredResponseText(
      map['publicationAuditId'],
      field: 'publicationAuditId',
    );
    final assignedAt = readRequiredPersistedDateTime(
      map['assignedAt'],
      field: 'assignedAt',
      source: 'assignPublishedTemplateVersion/$requestId',
    );
    if ((map['assignedAt'] as String).trim() !=
        assignedAt.toUtc().toIso8601String()) {
      throw PersistedDataFormatException(
        field: 'assignedAt',
        source: 'assignPublishedTemplateVersion/$requestId',
        detail: 'must be a canonical UTC ISO instant',
      );
    }
    if (!execution.createdAt.isAtSameMomentAs(assignedAt)) {
      throw const FormatException(
        'Server assignment timestamp did not match its JobExecution.',
      );
    }
    if (expectedRequest != null) {
      _validateAssignmentResponseMeaning(
        request: expectedRequest,
        execution: execution,
        modules: modules,
      );
    }

    return PublishedTemplateAssignmentServerResult(
      execution: execution,
      modules: modules,
      requestId: requestId,
      idempotentReplay: map['idempotentReplay'] as bool,
      publicationAuditFirestoreId: publicationAuditId,
      assignedAt: assignedAt,
    );
  }
}

class PublishedTemplateAssignmentServerService {
  final FirebaseFunctions? _functions;

  PublishedTemplateAssignmentServerService({FirebaseFunctions? functions})
    : _functions = functions;

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(
        region: publishedTemplateAssignmentCallableRegion,
      );

  Future<PublishedTemplateAssignmentServerResult> assign({
    required PublishedTemplateAssignmentRequest request,
  }) async {
    final callable = _client.httpsCallable(
      publishedTemplateAssignmentCallableName,
    );

    try {
      final result = await callable.call(request.toCallableData());
      return PublishedTemplateAssignmentServerResult.fromCallableData(
        result.data,
        fallbackRequestId: request.requestId,
        expectedRequest: request,
      );
    } on FirebaseFunctionsException catch (error) {
      throw PublishedTemplateAssignmentServerException.fromFirebase(error);
    } on FormatException catch (error) {
      throw PublishedTemplateAssignmentServerException(
        code: 'invalid-response',
        message: error.message,
      );
    }
  }
}

void _validateAssignmentResponseMeaning({
  required PublishedTemplateAssignmentRequest request,
  required JobExecution execution,
  required List<JobModuleInstance> modules,
}) {
  final executionMatches =
      execution.templateFirestoreId == request.versionFirestoreId &&
      execution.templatePackageId == request.packageFirestoreId &&
      execution.templateVersionId == request.versionFirestoreId &&
      execution.templateVersionNumber == request.expectedVersionNumber &&
      execution.templateContentHash == request.expectedContentHash &&
      execution.assetType == request.assetType &&
      execution.assetNumber == request.assetNumber &&
      execution.chargeNoAtEvent == request.chargeNoAtEvent &&
      _clean(execution.remarks) == _clean(request.remarks);
  if (!executionMatches) {
    throw const FormatException(
      'Server assignment response did not match the submitted assignment meaning.',
    );
  }
  for (final module in modules) {
    if (module.templateFirestoreId != request.versionFirestoreId ||
        module.templatePackageId != request.packageFirestoreId ||
        module.templateVersionId != request.versionFirestoreId ||
        module.assetType != request.assetType ||
        module.assetNumber != request.assetNumber) {
      throw const FormatException(
        'Server assignment module did not match the submitted assignment meaning.',
      );
    }
  }
  final expectedClassId = _clean(request.assetClassId);
  final expectedInstanceId = _clean(request.assetInstanceId);
  if (expectedClassId == null && expectedInstanceId == null) return;
  final physicalIdentity = execution.assignmentPhysicalAssetIdentity;
  if (physicalIdentity == null ||
      physicalIdentity.assetClassId != expectedClassId ||
      physicalIdentity.assetInstanceId != expectedInstanceId ||
      physicalIdentity.assetNumber != request.assetNumber) {
    throw const FormatException(
      'Server assignment response did not preserve the selected physical asset identity.',
    );
  }
}

class PublishedTemplateAssignmentServerException implements Exception {
  final String code;
  final String message;
  final Object? details;
  final String? reasonCode;

  const PublishedTemplateAssignmentServerException({
    required this.code,
    required this.message,
    this.details,
    this.reasonCode,
  });

  factory PublishedTemplateAssignmentServerException.fromFirebase(
    FirebaseFunctionsException error,
  ) {
    final details = error.details;
    final detailsMap = details is Map ? details : null;
    final reasonCode = _clean(detailsMap?['reasonCode']?.toString());
    return PublishedTemplateAssignmentServerException(
      code: error.code,
      message:
          _clean(error.message) ??
          'Server-governed published-template assignment failed.',
      details: details,
      reasonCode: reasonCode,
    );
  }

  bool get isRetryable =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'internal' ||
      code == 'resource-exhausted';

  String get operatorMessage {
    switch (code) {
      case 'unauthenticated':
        return 'Sign in again before assigning this governed job.';
      case 'permission-denied':
        return 'You are not authorized to assign this governed job.';
      case 'not-found':
        return 'The server could not find the active package, version, or publication audit. Pull latest governance data and try again.';
      case 'failed-precondition':
      case 'aborted':
        return message;
      case 'invalid-argument':
        return message;
      case 'already-exists':
        return 'This request identity is already bound to different assignment content. Change the form or reload before retrying.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The assignment server could not be reached. Check connectivity and retry; the same request identity will be reused safely.';
      case 'invalid-response':
        return 'The assignment server returned an invalid response. Do not create a second job manually; pull latest data and contact Admin/SI.';
      default:
        return message;
    }
  }

  @override
  String toString() => operatorMessage;
}

final publishedTemplateAssignmentServerServiceProvider =
    Provider<PublishedTemplateAssignmentServerService>((ref) {
      return PublishedTemplateAssignmentServerService();
    });

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _requiredResponseText(Object? value, {required String field}) {
  if (value is! String) {
    throw FormatException('Server assignment returned invalid $field.');
  }
  final cleaned = _clean(value);
  if (cleaned == null) {
    throw FormatException('Server assignment returned empty $field.');
  }
  return cleaned;
}
