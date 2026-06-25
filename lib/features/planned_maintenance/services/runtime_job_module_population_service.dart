import 'package:cloud_functions/cloud_functions.dart';

import '../data/job_module_model.dart';

const runtimeJobModulePopulationCallableName =
    'mutateRuntimeJobModulePopulation';
const runtimeJobModulePopulationCallableRegion = 'asia-south1';

/// Canonical result of one server-governed active-population mutation.
class RuntimeJobModulePopulationResult {
  final JobModuleInstance module;
  final String operation;
  final bool idempotentReplay;

  /// Immutable parent population revision at which this mutation was accepted.
  final int acceptedAtPopulationVersion;

  /// Parent population revision when the server answered this request.
  final int currentParentPopulationVersion;

  const RuntimeJobModulePopulationResult({
    required this.module,
    required this.operation,
    required this.idempotentReplay,
    required this.acceptedAtPopulationVersion,
    required this.currentParentPopulationVersion,
  });
}

/// Server-governed gateway for active module-population changes.
///
/// Native authoring remains local-first. A newly-created module or an existing
/// module tombstone stays dirty until this callable atomically mutates the child,
/// advances the parent execution's server-only modulePopulationVersion and
/// records the immutable server audit.
class RuntimeJobModulePopulationService {
  final FirebaseFunctions? _functions;

  RuntimeJobModulePopulationService({FirebaseFunctions? functions})
    : _functions = functions;

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(
        region: runtimeJobModulePopulationCallableRegion,
      );

  Future<RuntimeJobModulePopulationResult> acceptModule(
    JobModuleInstance module, {
    String? preservationReason,
  }) {
    return _mutate(
      operation: 'create',
      module: module,
      preservationReason: preservationReason,
    );
  }

  Future<RuntimeJobModulePopulationResult> softDeleteModule(
    JobModuleInstance tombstone,
  ) {
    return _mutate(operation: 'softDelete', module: tombstone);
  }

  Future<RuntimeJobModulePopulationResult> _mutate({
    required String operation,
    required JobModuleInstance module,
    String? preservationReason,
  }) async {
    final moduleId = module.firestoreId?.trim();
    final executionId = module.jobExecutionFirestoreId?.trim();
    if (moduleId == null || moduleId.isEmpty) {
      throw const RuntimeJobModulePopulationException(
        code: 'invalid-argument',
        message:
            'A Firestore module identity is required before remote population mutation.',
        reasonCode: 'local-module-identity-missing',
      );
    }
    if (executionId == null || executionId.isEmpty) {
      throw const RuntimeJobModulePopulationException(
        code: 'invalid-argument',
        message:
            'A remote parent execution is required before mutating its module population.',
        reasonCode: 'local-parent-identity-missing',
      );
    }

    final callable = _client.httpsCallable(
      runtimeJobModulePopulationCallableName,
    );

    try {
      final result = await callable.call(<String, dynamic>{
        'operation': operation,
        'module': module.toMap(),
        if (preservationReason?.trim().isNotEmpty == true)
          'preservationReason': preservationReason!.trim(),
      });

      final raw = result.data;
      if (raw is! Map || raw['ok'] != true) {
        throw _invalidPopulationResponse(
          'Module population mutation returned a malformed success envelope.',
        );
      }
      final returnedOperation = _cleanString(raw['operation']);
      if (returnedOperation != operation) {
        throw _invalidPopulationResponse(
          'Module population mutation returned a mismatched operation.',
        );
      }

      final moduleRaw = raw['module'];
      if (moduleRaw is! Map) {
        throw _invalidPopulationResponse(
          'Module population mutation did not return the canonical module.',
        );
      }
      final moduleData = Map<String, dynamic>.from(moduleRaw);
      final returnedModuleId = _cleanString(moduleData['firestoreId']);
      final returnedExecutionId = _cleanString(
        moduleData['jobExecutionFirestoreId'],
      );
      if (returnedModuleId != moduleId || returnedExecutionId != executionId) {
        throw _invalidPopulationResponse(
          'Module population mutation returned a mismatched module identity.',
        );
      }

      if (raw['idempotentReplay'] is! bool) {
        throw _invalidPopulationResponse(
          'Module population mutation returned an invalid idempotentReplay flag.',
        );
      }
      final acceptedAtPopulationVersion = _requireNonNegativeInt(
        raw['acceptedAtPopulationVersion'],
        'acceptedAtPopulationVersion',
      );
      final currentParentPopulationVersion = _requireNonNegativeInt(
        raw['currentParentPopulationVersion'],
        'currentParentPopulationVersion',
      );
      if (currentParentPopulationVersion < acceptedAtPopulationVersion) {
        throw _invalidPopulationResponse(
          'Module population mutation returned a parent revision older than the immutable acceptance revision.',
        );
      }

      final idempotentReplay = raw['idempotentReplay'] as bool;
      final returnedModule = JobModuleInstance.fromMap(
        moduleData,
        returnedModuleId!,
      );
      if (operation == 'create' && !returnedModule.addedDuringExecution) {
        throw _invalidPopulationResponse(
          'Module population create returned a non-runtime module.',
        );
      }
      if (operation == 'create' &&
          !idempotentReplay &&
          returnedModule.isDeleted) {
        throw _invalidPopulationResponse(
          'A new module population create returned a deleted module.',
        );
      }
      if (operation == 'softDelete' && !returnedModule.isDeleted) {
        throw _invalidPopulationResponse(
          'Module population soft delete returned an active module.',
        );
      }

      return RuntimeJobModulePopulationResult(
        module: returnedModule,
        operation: returnedOperation!,
        idempotentReplay: idempotentReplay,
        acceptedAtPopulationVersion: acceptedAtPopulationVersion,
        currentParentPopulationVersion: currentParentPopulationVersion,
      );
    } on FirebaseFunctionsException catch (error) {
      throw RuntimeJobModulePopulationException.fromFirebase(error);
    } on RuntimeJobModulePopulationException {
      rethrow;
    } catch (error) {
      throw _invalidPopulationResponse(
        'Module population mutation returned an unreadable canonical module: $error',
      );
    }
  }
}

class RuntimeJobModulePopulationException implements Exception {
  final String code;
  final String message;
  final Object? details;
  final String? reasonCode;

  const RuntimeJobModulePopulationException({
    required this.code,
    required this.message,
    this.details,
    this.reasonCode,
  });

  factory RuntimeJobModulePopulationException.fromFirebase(
    FirebaseFunctionsException error,
  ) {
    final details = error.details;
    final detailsMap = details is Map ? details : null;
    return RuntimeJobModulePopulationException(
      code: error.code,
      message:
          _cleanString(error.message) ??
          'Server-governed planned-job module population mutation failed.',
      details: details,
      reasonCode: _cleanString(detailsMap?['reasonCode']),
    );
  }

  bool get isDurableRejection {
    if (reasonCode == 'parent-execution-missing' ||
        reasonCode == 'local-parent-identity-missing') {
      // The execution header can legitimately arrive in a later sync pass.
      return false;
    }
    if (reasonCode == 'invalid-server-response') return true;
    return code == 'permission-denied' ||
        code == 'failed-precondition' ||
        code == 'invalid-argument' ||
        code == 'not-found' ||
        code == 'already-exists' ||
        code == 'data-loss';
  }

  bool get shouldRetryImmediately {
    if (reasonCode == 'invalid-server-response') return false;
    return code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        code == 'internal' ||
        code == 'aborted' ||
        code == 'resource-exhausted';
  }

  String get operatorMessage {
    switch (reasonCode) {
      case 'parent-execution-completed':
        return 'The module was preserved locally because its planned job is already completed remotely.';
      case 'parent-execution-missing':
        return 'The module was preserved locally because its parent planned job is not available remotely yet.';
      case 'parent-execution-deleted':
        return 'The module was preserved locally because its parent planned job was deleted remotely.';
      case 'module-identity-conflict':
      case 'module-already-deleted-conflict':
      case 'population-mutation-owner-mismatch':
        return 'This module identity is already bound to different remote content. The local copy was preserved.';
      case 'module-missing':
      case 'module-parent-mismatch':
        return 'The remote module identity is missing or belongs to another planned job. The local copy was preserved.';
      case 'parent-asset-mismatch':
      case 'parent-charge-mismatch':
        return 'The module operational identity does not match its remote parent. The local copy was preserved.';
      case 'runtime-module-classification-required':
        return 'Client-created runtime modules must be explicitly classified as added during execution.';
      case 'new-module-already-deleted':
        return 'A module deleted before its first remote acceptance remains a local no-op and is not created remotely.';
      case 'new-module-delete-provenance-present':
        return 'A first remote acceptance cannot also claim deletion provenance. The local copy was preserved.';
      case 'governed-initial-module-server-only':
        return 'Published-template modules must be created by the governed assignment service.';
      case 'local-parent-identity-missing':
        return 'The module remains local because its parent job has not received a remote identity.';
      case 'local-module-identity-missing':
        return 'The module remains local because it has no remote identity.';
      case 'module-actor-preservation-role-required':
      case 'module-actor-preservation-reason-required':
      case 'module-delete-actor-mismatch':
        return 'The module was preserved locally because its actor provenance requires controlled supervisor preservation.';
      case 'module-delete-role-required':
        return 'Only a lifecycle supervisor, SI, or administrator may remove this remote module from the active population.';
      case 'module-delete-version-stale':
        return 'The local module tombstone is stale. The latest remote module must be reconciled before deletion.';
      case 'remote-tombstone-divergence':
        return 'A different authoritative remote tombstone exists. The fresher local deletion evidence was preserved for controlled reconciliation.';
      case 'module-lifecycle-role-denied':
      case 'module-lifecycle-history-inconsistent':
      case 'module-lifecycle-provenance-missing':
      case 'module-lifecycle-time-order-invalid':
      case 'module-reopen-history-missing':
        return 'The module was preserved locally because its lifecycle state or actor history is not valid for this uploader.';
      case 'elevated-runtime-module-role-required':
        return 'This closure-critical or elevated runtime module requires supervisor, SI, or administrator confirmation.';
      case 'module-population-version-invalid':
      case 'module-population-schema-version-invalid':
      case 'module-population-evidence-invalid':
      case 'parent-population-version-regressed':
      case 'population-audit-missing':
      case 'population-audit-mismatch':
      case 'population-audit-preexisting':
        return 'The planned job has invalid module-population governance evidence. The local record was preserved for controlled repair.';
      case 'invalid-server-response':
        return 'The server returned an invalid population-mutation response. The local evidence was preserved and automatic retry was held.';
      case 'user-not-approved':
      case 'role-not-authorized':
        return 'The signed-in user is not approved or authorized to change this planned job’s module population.';
      case 'unexpected-module-fields':
      case 'module-payload-too-large':
      case 'unsupported-operation':
      case 'soft-delete-payload-not-deleted':
      case 'invalid-object':
      case 'invalid-text':
      case 'invalid-document-id':
      case 'invalid-integer':
      case 'invalid-boolean':
      case 'invalid-enum':
      case 'invalid-timestamp':
      case 'invalid-string-array':
      case 'invalid-json-text':
      case 'malformed-json-text':
      case 'wrong-json-shape':
      case 'non-json-value':
      case 'non-json-number':
        return 'The local module payload is not valid for governed remote acceptance. The evidence was preserved for repair.';
    }

    switch (code) {
      case 'unauthenticated':
        return 'Sign in again before synchronizing this planned-job module.';
      case 'permission-denied':
        return 'You are not authorized to change this planned job’s remote module population.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'The module remains stored locally. Check connectivity and retry synchronization.';
      default:
        return message;
    }
  }

  @override
  String toString() => operatorMessage;
}

String? _cleanString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _requireNonNegativeInt(Object? value, String fieldName) {
  int? parsed;
  if (value is int) {
    parsed = value;
  } else if (value is num && value.isFinite && value == value.roundToDouble()) {
    parsed = value.toInt();
  }
  if (parsed == null || parsed < 0) {
    throw _invalidPopulationResponse(
      'Module population mutation returned an invalid $fieldName.',
    );
  }
  return parsed;
}

RuntimeJobModulePopulationException _invalidPopulationResponse(String message) {
  return RuntimeJobModulePopulationException(
    code: 'internal',
    message: message,
    reasonCode: 'invalid-server-response',
  );
}
