import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

import '../data/job_module_model.dart';
import 'module_composer_models.dart';

const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

/// Canonical module-registry snapshot for one [ComposerModuleDraft].
///
/// The registry deliberately freezes one module revision at a time. This
/// helper mirrors the composer/publisher snapshot structure closely enough to
/// recover a module later, while keeping the registry independent of
/// TemplateVersion records.
class ModuleRegistrySnapshotBundle {
  const ModuleRegistrySnapshotBundle({
    required this.moduleSnapshotJson,
    required this.fieldDefinitionsJson,
    required this.checklistJson,
  });

  final String moduleSnapshotJson;
  final String fieldDefinitionsJson;
  final String checklistJson;

  Map<String, dynamic> get moduleSnapshot => _decodeObject(moduleSnapshotJson);

  List<Map<String, dynamic>> get fieldDefinitions =>
      _decodeObjectList(fieldDefinitionsJson);

  List<Map<String, dynamic>> get checklistItems =>
      _decodeObjectList(checklistJson);

  String get contentHash => stableModuleRegistryContentHashStrict(
    moduleSnapshotJson: moduleSnapshotJson,
    fieldDefinitionsJson: fieldDefinitionsJson,
    checklistJson: checklistJson,
  );
}

ModuleRegistrySnapshotBundle moduleRegistrySnapshotFromDraft(
  ComposerModuleDraft module,
) {
  final sortedFields = [...module.fields]
    ..sort((a, b) => a.order.compareTo(b.order));
  final sortedChecklist = [...module.checklistItems]
    ..sort((a, b) => a.order.compareTo(b.order));

  return ModuleRegistrySnapshotBundle(
    moduleSnapshotJson: _jsonEncoder.convert(_moduleToRegistrySnapshot(module)),
    fieldDefinitionsJson: _jsonEncoder.convert(
      sortedFields
          .map((field) => field.toMap(moduleCode: module.moduleCode))
          .toList(),
    ),
    checklistJson: _jsonEncoder.convert(
      sortedChecklist
          .map((item) => item.toMap(moduleCode: module.moduleCode))
          .toList(),
    ),
  );
}

String stableModuleRegistryContentHash({
  required String moduleSnapshotJson,
  required String fieldDefinitionsJson,
  required String checklistJson,
}) {
  final canonical = _jsonEncoder.convert(<String, dynamic>{
    'moduleSnapshot': _canonicalJsonValue(_decodeObject(moduleSnapshotJson)),
    'fieldDefinitions': _canonicalJsonValue(
      _decodeObjectList(fieldDefinitionsJson),
    ),
    'checklist': _canonicalJsonValue(_decodeObjectList(checklistJson)),
  });
  final digest = sha256.convert(utf8.encode(canonical)).toString();
  return 'mrg1-sha256:$digest';
}

/// Computes the canonical registry content hash in strict governance mode.
///
/// Unlike [stableModuleRegistryContentHash], this rejects malformed JSON and
/// non-object/non-list payload roots instead of normalising them to empty
/// content. Use this on publish/governance paths where a malformed registry
/// revision must not receive a stable-looking content hash.
String stableModuleRegistryContentHashStrict({
  required String moduleSnapshotJson,
  required String fieldDefinitionsJson,
  required String checklistJson,
}) {
  final canonical = _jsonEncoder.convert(<String, dynamic>{
    'moduleSnapshot': _canonicalJsonValue(
      _decodeObjectStrict(moduleSnapshotJson, 'moduleSnapshotJson'),
    ),
    'fieldDefinitions': _canonicalJsonValue(
      _decodeObjectListStrict(fieldDefinitionsJson, 'fieldDefinitionsJson'),
    ),
    'checklist': _canonicalJsonValue(
      _decodeObjectListStrict(checklistJson, 'checklistJson'),
    ),
  });
  final digest = sha256.convert(utf8.encode(canonical)).toString();
  return 'mrg1-sha256:$digest';
}

/// Validates that registry revision JSON is strict, canonical-hashable, and
/// optionally matches the persisted [expectedContentHash].
void validateModuleRegistrySnapshotPayload({
  required String moduleSnapshotJson,
  required String fieldDefinitionsJson,
  required String checklistJson,
  String? expectedContentHash,
}) {
  final actualHash = stableModuleRegistryContentHashStrict(
    moduleSnapshotJson: moduleSnapshotJson,
    fieldDefinitionsJson: fieldDefinitionsJson,
    checklistJson: checklistJson,
  );
  final expected = expectedContentHash?.trim();
  if (expected != null && expected.isNotEmpty && expected != actualHash) {
    throw FormatException(
      'Registry content hash mismatch: expected $expected but computed '
      '$actualHash.',
    );
  }
}

Map<String, dynamic> _moduleToRegistrySnapshot(ComposerModuleDraft module) {
  return <String, dynamic>{
    'moduleCode': module.moduleCode,
    'moduleTitle': module.title,
    'moduleDescription': module.description,
    'assetType': module.assetType.name,
    'discipline': module.discipline.name,
    'useMode': module.useMode.name,
    'safetyClass': module.primarySafetyClass.name,
    'isRequired': module.requiredForClosure,
    'requiredForClosure': module.requiredForClosure,
    'displayOrder': 0,
    'functionalSection': module.functionalSection,
    'componentGroup': module.componentGroup,
    'subsystem': module.subsystem,
    'targetRefs': module.targetRefs,
    'deviceTagRefs': module.deviceTagRefs,
    'procedureRefs': module.procedureRefs,
    'operationalStatePreconditions': module.operationalStatePreconditions,
    'metadata': <String, dynamic>{
      ...module.metadata,
      'ownerDisciplines': module.ownerDisciplines,
      'primaryOwner': module.primaryOwner,
      'requiresJointReview': module.requiresJointReview,
      'safetyClasses': module.safetyClasses,
      'frequency': module.frequency.name,
      'partRefs': module.partRefs,
      'sourceManualRef': module.sourceManualRef,
      'sourceKnowledgeId': module.sourceKnowledgeId,
      'sourceSeedCode': module.sourceSeedCode,
      'sourceReadiness': module.sourceReadiness.name,
      'confidence': module.confidence.name,
      'authoringNotes': module.authoringNotes,
      'sharedSubmissionPolicy':
          module.discipline == JobModuleDiscipline.shared
              ? 'admin_si_supervisor_only'
              : 'discipline_or_supervisor_policy',
    },
  };
}

Map<String, dynamic> _decodeObjectStrict(String raw, String label) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw FormatException('$label must be a JSON object.');
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('$label must be a valid JSON object: $error');
  }
}

List<Map<String, dynamic>> _decodeObjectListStrict(String raw, String label) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! List) {
      throw FormatException('$label must be a JSON array.');
    }
    return decoded
        .map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          throw FormatException('$label must contain only JSON objects.');
        })
        .toList(growable: false);
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('$label must be a valid JSON array: $error');
  }
}

Map<String, dynamic> _decodeObject(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    // Content-hash tests and callers treat malformed snapshots as empty.
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _decodeObjectList(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
  } catch (_) {
    // Content-hash tests and callers treat malformed snapshots as empty.
  }
  return const <Map<String, dynamic>>[];
}

dynamic _canonicalJsonValue(dynamic value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return <String, dynamic>{
      for (final key in keys) key: _canonicalJsonValue(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalJsonValue).toList(growable: false);
  }
  return value;
}
