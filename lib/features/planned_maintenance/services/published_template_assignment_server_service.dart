import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/persistence/durable_submission.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';
import '../data/job_template_model.dart';

const publishedTemplateAssignmentCallableName =
    'assignPublishedTemplateVersion';
const publishedTemplateAssignmentCallableRegion = 'asia-south1';
const publishedTemplateAssignmentV2CallableName =
    'assignPublishedTemplateVersionV2';

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

  factory PublishedTemplateAssignmentRequest.fromCallableData(
    Map<String, dynamic> raw,
  ) {
    const requiredKeys = {
      'requestId',
      'packageId',
      'versionId',
      'expectedVersionNumber',
      'expectedContentHash',
      'assetType',
      'assetNumber',
    };
    const optionalKeys = {
      'assetClassId',
      'assetInstanceId',
      'sourcePlanId',
      'sourcePlanExpectedVersion',
      'chargeNoAtEvent',
      'remarks',
    };
    if (!raw.keys.toSet().containsAll(requiredKeys) ||
        raw.keys.any(
          (key) => !requiredKeys.contains(key) && !optionalKeys.contains(key),
        )) {
      throw const FormatException(
        'The saved assignment request has missing or unsupported fields.',
      );
    }
    String text(String key) {
      final value = raw[key];
      if (value is! String || value.trim().isEmpty || value != value.trim()) {
        throw FormatException('The saved assignment $key is invalid.');
      }
      return value;
    }

    int positive(String key) {
      final value = raw[key];
      if (value is! int || value < 1 || value > 9007199254740991) {
        throw FormatException('The saved assignment $key is invalid.');
      }
      return value;
    }

    final type = AssetType.values
        .where((value) => value.name == raw['assetType'])
        .singleOrNull;
    if (type == null) {
      throw const FormatException(
        'The saved assignment asset type is invalid.',
      );
    }
    final request = PublishedTemplateAssignmentRequest(
      requestId: text('requestId'),
      packageFirestoreId: text('packageId'),
      versionFirestoreId: text('versionId'),
      expectedVersionNumber: positive('expectedVersionNumber'),
      expectedContentHash: text('expectedContentHash'),
      assetType: type,
      assetNumber: positive('assetNumber'),
      assetClassId: raw.containsKey('assetClassId')
          ? text('assetClassId')
          : null,
      assetInstanceId: raw.containsKey('assetInstanceId')
          ? text('assetInstanceId')
          : null,
      sourcePlanId: raw.containsKey('sourcePlanId')
          ? text('sourcePlanId')
          : null,
      sourcePlanExpectedVersion: raw.containsKey('sourcePlanExpectedVersion')
          ? positive('sourcePlanExpectedVersion')
          : null,
      chargeNoAtEvent: raw.containsKey('chargeNoAtEvent')
          ? positive('chargeNoAtEvent')
          : null,
      remarks: raw.containsKey('remarks') ? text('remarks') : null,
    );
    request._requireCompleteGovernedIdentity();
    return request;
  }

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
    String? expectedOriginActorUid,
    bool allowCompletedProjection = false,
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
        expectedOriginActorUid: expectedOriginActorUid,
        allowCompletedProjection: allowCompletedProjection,
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
  final String? Function()? currentActorUid;

  PublishedTemplateAssignmentServerService({
    FirebaseFunctions? functions,
    this.currentActorUid,
  }) : _functions = functions;

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(
        region: publishedTemplateAssignmentCallableRegion,
      );

  /// V2 dispatch consumes the original wrapper; the durable caller owns retry
  /// and settlement. Return the validated complete receipt for native retention.
  Future<Map<String, dynamic>> assignFrozenEnvelope(String envelopeJson) async {
    final outer = durableSubmissionJsonObject(envelopeJson);
    final origin = outer['originActorUid'];
    if (outer.length != 3 ||
        outer['protocolVersion'] != 2 ||
        origin is! String ||
        origin.trim().isEmpty ||
        origin != origin.trim() ||
        outer['request'] is! Map<String, dynamic>) {
      throw const FormatException(
        'The saved assignment does not prove its original account.',
      );
    }
    final request = PublishedTemplateAssignmentRequest.fromCallableData(
      outer['request'] as Map<String, dynamic>,
    );
    final live = currentActorUid == null
        ? FirebaseAuth.instance.currentUser?.uid
        : currentActorUid!();
    if (live != origin) {
      throw const PublishedTemplateAssignmentServerException(
        code: 'origin-account-mismatch',
        message:
            'Return to the account that saved this assignment. Nothing was sent.',
      );
    }
    try {
      final response = await _client
          .httpsCallable(publishedTemplateAssignmentV2CallableName)
          .call(outer);
      PublishedTemplateAssignmentServerResult.fromCallableData(
        response.data,
        fallbackRequestId: request.requestId,
        expectedRequest: request,
        expectedOriginActorUid: origin,
        allowCompletedProjection: true,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      throw PublishedTemplateAssignmentServerException.fromFirebase(error);
    }
  }

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
  String? expectedOriginActorUid,
  bool allowCompletedProjection = false,
}) {
  final origin = !allowCompletedProjection || execution.metadataJson == null
      ? null
      : durableSubmissionJsonObject(execution.metadataJson!);
  // Finalization may replace remarks with the completion note. Its current
  // projection is not the original input; the protected request/assignment
  // origin still binds the accepted creation. Ordinary mismatches remain errors.
  final completedProjection =
      allowCompletedProjection &&
      expectedOriginActorUid != null &&
      execution.assignedByUid == expectedOriginActorUid &&
      execution.isCompleted &&
      !execution.isDeleted &&
      !execution.isCancelled &&
      execution.version > 1 &&
      origin?['source'] == 'server_governed_published_template_assignment' &&
      origin?['requestId'] == request.requestId;
  final executionMatches =
      execution.templateFirestoreId == request.versionFirestoreId &&
      execution.templatePackageId == request.packageFirestoreId &&
      execution.templateVersionId == request.versionFirestoreId &&
      execution.templateVersionNumber == request.expectedVersionNumber &&
      execution.templateContentHash == request.expectedContentHash &&
      execution.assetType == request.assetType &&
      execution.assetNumber == request.assetNumber &&
      execution.chargeNoAtEvent == request.chargeNoAtEvent &&
      (_clean(execution.remarks) == _clean(request.remarks) ||
          completedProjection);
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
