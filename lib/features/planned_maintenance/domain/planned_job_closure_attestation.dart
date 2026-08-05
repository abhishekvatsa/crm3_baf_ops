import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../data/job_module_model.dart';

/// Tamper-evident planned-job closure evidence stored inside
/// JobExecution.metadataJson.
///
/// This deliberately avoids new JobExecution fields so Firestore completion
/// writes stay inside the existing rules-allowed `metadataJson` branch and no
/// Isar generated schema change is required.
class PlannedJobClosureAttestation {
  static const int schemaVersion = 1;
  static const String metadataKey = 'closureAttestation';

  final Map<String, dynamic> payload;
  final String canonicalJson;
  final String hash;

  const PlannedJobClosureAttestation._({
    required this.payload,
    required this.canonicalJson,
    required this.hash,
  });

  factory PlannedJobClosureAttestation.build({
    required String? executionFirestoreId,
    required List<JobModuleInstance> modules,
    required String completedByUid,
    required String? completedByName,
    required DateTime completedAt,
    required int executionVersionAtCompletion,
    required Map<String, int> guardIssueCounts,
  }) {
    final moduleSnapshots =
        modules.map(_moduleSnapshot).toList()..sort((left, right) {
          final leftKey = left['moduleKey']?.toString() ?? '';
          final rightKey = right['moduleKey']?.toString() ?? '';
          return leftKey.compareTo(rightKey);
        });

    final activeModules = modules.where((module) => !module.isDeleted).toList();
    final requiredModules =
        activeModules.where((module) => module.requiredForClosure).toList();

    final payload = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'executionFirestoreId': _cleanOptionalText(executionFirestoreId),
      'completedByUid': completedByUid.trim(),
      'completedByName': _cleanOptionalText(completedByName),
      'completedAt': completedAt.toUtc().toIso8601String(),
      'executionVersionAtCompletion': executionVersionAtCompletion,
      'moduleCounts': <String, dynamic>{
        'total': modules.length,
        'active': activeModules.length,
        'requiredForClosure': requiredModules.length,
        'deleted': modules.length - activeModules.length,
      },
      'guardIssueCounts': _normalisedIssueCounts(guardIssueCounts),
      'modules': moduleSnapshots,
    };

    final canonicalJson = _canonicalJson(payload);
    return PlannedJobClosureAttestation._(
      payload: payload,
      canonicalJson: canonicalJson,
      hash: _sha256Hex(canonicalJson),
    );
  }

  Map<String, dynamic> toMetadataEnvelope() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'hash': hash,
    'canonicalJson': canonicalJson,
  };

  static String mergeIntoMetadataJson(
    String? existingMetadataJson,
    PlannedJobClosureAttestation attestation,
  ) {
    final metadata = _decodeMetadataJson(existingMetadataJson);
    metadata[metadataKey] = attestation.toMetadataEnvelope();
    return jsonEncode(metadata);
  }

  static Map<String, dynamic> _decodeMetadataJson(String? metadataJson) {
    final cleaned = metadataJson?.trim();
    if (cleaned == null || cleaned.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return <String, dynamic>{'legacyMetadataValue': decoded};
    } catch (_) {
      return <String, dynamic>{'legacyMetadataJson': cleaned};
    }
  }

  static Map<String, dynamic> _normalisedIssueCounts(
    Map<String, int> guardIssueCounts,
  ) {
    return <String, dynamic>{
      'openRequiredModule': guardIssueCounts['openRequiredModule'] ?? 0,
      'waitingAcceptance': guardIssueCounts['waitingAcceptance'] ?? 0,
      'missingRequiredEvidence':
          guardIssueCounts['missingRequiredEvidence'] ?? 0,
      'pendingIssueOrFollowUp': guardIssueCounts['pendingIssueOrFollowUp'] ?? 0,
    };
  }

  static Map<String, dynamic> _moduleSnapshot(JobModuleInstance module) {
    final fieldRead = module.fieldDefinitionsReadResult;
    final responseRead = module.responsesReadResult;
    final actionRead = module.actionsReadResult;
    if (!fieldRead.isValid || !responseRead.isValid || !actionRead.isValid) {
      throw StateError(
        'Cannot attest closure: saved module evidence for '
        '${module.moduleTitle} needs repair.',
      );
    }
    final definitions = fieldRead.entries;
    final ordinaryRequiredKeys =
        definitions
            .where(
              (definition) =>
                  _fieldDefinitionRequired(definition) &&
                  !_isSafetyGateDefinition(definition),
            )
            .map(_fieldDefinitionKey)
            .where((key) => key != null && key.isNotEmpty)
            .cast<String>()
            .toList()
          ..sort();

    final hasAnyOrdinaryField = definitions.any(
      (definition) => !_isSafetyGateDefinition(definition),
    );

    final responsesByKey = <String, dynamic>{
      for (final response in responseRead.entries) response.key: response.value,
    };

    final missingRequiredKeys =
        ordinaryRequiredKeys
            .where((key) => !_hasEvidenceValue(responsesByKey[key]))
            .toList();

    final responseEvidenceByRequiredKey = <String, dynamic>{
      for (final key in ordinaryRequiredKeys)
        key: _responseEvidenceSummary(responsesByKey[key]),
    };

    final hasPendingIssue =
        module.pendingIssue != null && module.pendingIssue!.trim().isNotEmpty;

    final snapshot = <String, dynamic>{
      'moduleKey': _moduleKey(module),
      'firestoreId': _cleanOptionalText(module.firestoreId),
      'localId': module.id,
      'jobExecutionFirestoreId': _cleanOptionalText(
        module.jobExecutionFirestoreId,
      ),
      'jobExecutionLocalId': module.jobExecutionLocalId,
      'templateModuleId': _cleanOptionalText(module.templateModuleId),
      'moduleCode': _cleanOptionalText(module.moduleCode),
      'moduleTitle': module.moduleTitle.trim(),
      'version': module.version,
      'status': module.status.name,
      'requiredForClosure': module.requiredForClosure,
      'isDeleted': module.isDeleted,
      'requiresFollowUp': module.requiresFollowUp,
      'hasPendingIssue': hasPendingIssue,
      'pendingIssueHash':
          hasPendingIssue ? _sha256Hex(module.pendingIssue!.trim()) : null,
      'hasResponses': responseRead.entries.isNotEmpty,
      'hasAnyOrdinaryField': hasAnyOrdinaryField,
      'ordinaryRequiredFieldKeys': ordinaryRequiredKeys,
      'missingRequiredEvidenceKeys': missingRequiredKeys,
      'responseEvidenceByRequiredKey': responseEvidenceByRequiredKey,
      'fieldDefinitionsHash': _sha256Hex(module.fieldDefinitionsJson),
      'responsesHash': _sha256Hex(module.responsesJson),
    };

    snapshot['snapshotHash'] = _sha256Hex(_canonicalJson(snapshot));
    return snapshot;
  }

  static String _moduleKey(JobModuleInstance module) {
    final firestoreId = _cleanOptionalText(module.firestoreId);
    if (firestoreId != null) return 'firestore:$firestoreId';

    final templateModuleId = _cleanOptionalText(module.templateModuleId);
    if (templateModuleId != null) {
      return 'templateModule:$templateModuleId:${module.id}';
    }

    return 'local:${module.id}';
  }

  static Map<String, dynamic> _responseEvidenceSummary(dynamic value) {
    final hasEvidence = _hasEvidenceValue(value);
    return <String, dynamic>{
      'hasEvidence': hasEvidence,
      'valueHash': hasEvidence ? _sha256Hex(_canonicalJson(value)) : null,
    };
  }

  static bool _fieldDefinitionRequired(Map<String, dynamic> definition) {
    return definition['required'] == true || definition['isRequired'] == true;
  }

  static String? _fieldDefinitionKey(Map<String, dynamic> definition) {
    for (final key in const ['fieldId', 'key', 'id', 'name']) {
      final raw = definition[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    return null;
  }

  static bool _isSafetyGateDefinition(Map<String, dynamic> definition) {
    final raw = definition['type'] ?? definition['fieldType'] ?? '';
    final key = raw.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );
    return key == 'safetygate' || key == 'safetyconfirmation';
  }

  static bool _hasEvidenceValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    return true;
  }

  static String? _cleanOptionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _sha256Hex(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  static String _canonicalJson(dynamic value) {
    return jsonEncode(_canonicalValue(value));
  }

  static dynamic _canonicalValue(dynamic value) {
    if (value is Map) {
      final entries = <String, dynamic>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
      final keys = entries.keys.toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonicalValue(entries[key]),
      };
    }

    if (value is Iterable) {
      return value.map(_canonicalValue).toList(growable: false);
    }

    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }

    if (value is num || value is bool || value == null || value is String) {
      return value;
    }

    return value.toString();
  }
}
