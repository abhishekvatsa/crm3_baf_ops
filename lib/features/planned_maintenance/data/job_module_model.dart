// FILE: lib/features/planned_maintenance/data/job_module_model.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:isar/isar.dart';

import '../../maintenance/data/maintenance_model.dart';
import '../models/component_action_model.dart';
import 'job_template_model.dart'
    show
        FieldDefinitionReadResult,
        FieldResponse,
        FieldResponseReadResult,
        PersistedFieldDefinitionPayload;

part 'job_module_model.g.dart';

// ─────────────────────────────────────────────────────────────
// FIRESTORE-SHAPE PARSING HELPERS
// ─────────────────────────────────────────────────────────────

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);

  try {
    final dynamic maybeTimestamp = value;
    final converted = maybeTimestamp.toDate();
    if (converted is DateTime) return converted;
  } catch (_) {
    // Fall through to null.
  }

  return null;
}

String? _cleanOptionalText(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _cleanStringList(dynamic value) {
  if (value is! List) return [];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String _normaliseEnumKey(dynamic value) {
  if (value == null) return '';
  return value
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

T _enumByNameOr<T extends Enum>(List<T> values, dynamic value, T fallback) {
  final key = _normaliseEnumKey(value);
  if (key.isEmpty) return fallback;

  for (final item in values) {
    if (_normaliseEnumKey(item.name) == key) return item;
  }

  return fallback;
}

JobModuleDiscipline _parseDiscipline(dynamic value) {
  final key = _normaliseEnumKey(value);

  if (key == 'ia' ||
      key == 'ianda' ||
      key == 'instrument' ||
      key == 'instrumentation') {
    return JobModuleDiscipline.instrumentation;
  }

  if (key == 'sic' ||
      key == 'shiftincharge' ||
      key == 'shiftcharge' ||
      key == 'shiftlead') {
    return JobModuleDiscipline.shiftInCharge;
  }

  return _enumByNameOr(
    JobModuleDiscipline.values,
    value,
    JobModuleDiscipline.shared,
  );
}

String? _laneKeyForModuleDiscipline(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.electrical:
      return 'elec';
    case JobModuleDiscipline.mechanical:
      return 'mech';
    case JobModuleDiscipline.instrumentation:
      return 'inst';
    case JobModuleDiscipline.operations:
    case JobModuleDiscipline.shiftInCharge:
      return 'oprn';
    case JobModuleDiscipline.emd:
      return 'emd';
    case JobModuleDiscipline.refractory:
      return 'red';
    case JobModuleDiscipline.safety:
    case JobModuleDiscipline.admin:
    case JobModuleDiscipline.shared:
    case JobModuleDiscipline.others:
      return 'shared';
  }
}

int? _parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

int _parseIntOr(dynamic value, int fallback) {
  return _parseIntOrNull(value) ?? fallback;
}

String _safeJsonObject(dynamic value) {
  if (value == null) return '{}';
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '{}';
    return trimmed;
  }
  if (value is Map) return jsonEncode(value);
  return '{}';
}

// ─────────────────────────────────────────────────────────────
// MODULE ENUMS
// ─────────────────────────────────────────────────────────────

/// Runtime lifecycle of one work/process module inside a planned job.
enum JobModuleStatus {
  notStarted,
  inProgress,
  draftSaved,
  submitted,
  accepted,
  reopened,
  notApplicable,
}

/// Why a module was attached to the job.
enum JobModuleUseMode {
  scheduledPM,
  troubleshooting,
  correctiveFollowUp,
  shutdownWork,
  preStartVerification,
  postRepairVerification,
  futurePackage,
  adHoc,
}

/// Execution lane for module ownership. Kept separate from JobDiaryDiscipline
/// so the module runtime layer can evolve independently from diary entries.
enum JobModuleDiscipline {
  mechanical,
  electrical,
  instrumentation,
  operations,
  emd,
  refractory,
  shiftInCharge,
  safety,
  admin,
  shared,
  others,
}

/// Broad safety class for gating and dossier visibility. The actual plant
/// procedure/permit remains authoritative.
enum JobModuleSafetyClass {
  normal,
  lotoRequired,
  gasRisk,
  hotSurface,
  pressureTest,
  liftingRisk,
  electricalPanel,
  combustionSpecialist,
  configurationControl,
}

// ─────────────────────────────────────────────────────────────
// JOB MODULE INSTANCE
// ─────────────────────────────────────────────────────────────

@Collection()
class JobModuleInstance {
  JobModuleInstance();

  Id id = Isar.autoIncrement;

  // ── Sync identity ──────────────────────────────────────────
  @Index()
  String? firestoreId;

  @Index()
  bool isSynced = false;

  int version = 1;

  // ── Parent job linkage ─────────────────────────────────────
  /// Preferred cross-device parent relation.
  @Index()
  String? jobExecutionFirestoreId;

  /// Defensive device-local link for mobile-only/offline repair utilities.
  /// Never serialize this Isar integer to Firestore or import it from remote.
  @Index()
  int? jobExecutionLocalId;

  /// Canonical accountable lane used by the workflow server. For ordinary
  /// jobs the workflow id equals jobExecutionFirestoreId.
  @Index()
  String? laneKey;

  int laneActivationGeneration = 1;

  /// Exact active lane document used by Firestore Rules to gate work.
  String? workflowLaneFirestoreId;

  // ── Template/module source linkage ─────────────────────────
  /// Current legacy JobTemplate id, if this module originated from a legacy
  /// template or a template-derived planned job.
  @Index()
  String? templateFirestoreId;

  String? templateName;

  /// Future TemplatePackage / TemplateVersion / TemplateModule references.
  @Index()
  String? templatePackageId;

  @Index()
  String? templateVersionId;

  @Index()
  String? templateModuleId;

  /// Manual/catalogue code such as B-01, F-03, FC-02, AT-01.
  @Index()
  String? moduleCode;

  /// Immutable module content captured when added to this job. This protects
  /// historical jobs from later master-template edits.
  String moduleSnapshotJson = '{}';

  /// Optional raw field definitions for this module snapshot, if the module is
  /// built from dynamic fields before TemplateVersion exists.
  String fieldDefinitionsJson = '[]';

  // ── Job context copied for cheap filtering and final dossier display ─────
  @Enumerated(EnumType.name)
  @Index()
  AssetType assetType = AssetType.base;

  @Index()
  int assetNumber = 0;

  int? chargeNoAtEvent;

  /// Optional JSON for Base-Furnace-InnerCover-Cooler pairing or similar
  /// operational context.
  String? pairedEquipmentJson;

  // ── Module identity and classification ─────────────────────
  @Index()
  late String moduleTitle;

  String? moduleDescription;

  @Enumerated(EnumType.name)
  @Index()
  JobModuleStatus status = JobModuleStatus.notStarted;

  @Enumerated(EnumType.name)
  @Index()
  JobModuleUseMode useMode = JobModuleUseMode.scheduledPM;

  @Enumerated(EnumType.name)
  @Index()
  JobModuleDiscipline discipline = JobModuleDiscipline.shared;

  @Enumerated(EnumType.name)
  @Index()
  JobModuleSafetyClass safetyClass = JobModuleSafetyClass.normal;

  @Index()
  bool isRequired = false;

  @Index()
  bool requiredForClosure = false;

  @Index()
  bool addedDuringExecution = false;

  /// Allows module ordering inside lanes or a preloaded package.
  int displayOrder = 0;

  // ── Technical context ──────────────────────────────────────
  String? functionalSection;
  String? componentGroup;
  String? subsystem;
  String? targetRef;
  List<String> targetRefs = [];
  List<String> procedureRefs = [];
  List<String> safetyConfirmations = [];
  List<String> tags = [];

  /// State prerequisites such as IDLE, cooled, drained, isolated, purged,
  /// removed, on maintenance stand, etc. Stored as text keys initially so the
  /// plant vocabulary can be reviewed before hardcoding.
  List<String> operationalStatePreconditions = [];

  // ── Runtime response/action payloads ───────────────────────
  String responsesJson = '[]';
  String actionsJson = '[]';

  /// Draft/submission notes are module-level. Running narrative notes remain
  /// in JobDiaryEntry so multiple users can append without overwriting.
  String? draftNote;
  String? submissionNote;
  String? acceptanceNote;
  String? reopenReason;
  String? notApplicableReason;
  String? pendingIssue;

  bool requiresFollowUp = false;

  // ── Actor metadata ─────────────────────────────────────────
  String? addedByUid;
  String? addedByName;
  DateTime? addedAt;
  String? addReason;

  String? createdByUid;
  String? createdByName;

  @Index()
  late DateTime createdAt;

  String? updatedByUid;
  String? updatedByName;
  late DateTime updatedAt;

  String? submittedByUid;
  String? submittedByName;
  DateTime? submittedAt;

  String? acceptedByUid;
  String? acceptedByName;
  DateTime? acceptedAt;

  String? reopenedByUid;
  String? reopenedByName;
  DateTime? reopenedAt;

  String? notApplicableByUid;
  String? notApplicableByName;
  DateTime? notApplicableAt;

  // ── Tombstone metadata ─────────────────────────────────────
  @Index()
  bool isDeleted = false;

  DateTime? deletedAt;
  String? deletedByUid;
  String? deletedByName;
  String? deleteReason;

  /// Free-form extension point for later app versions. Do not store primary
  /// query fields only here.
  String? metadataJson;

  @ignore
  String? get effectiveLaneKey =>
      _cleanOptionalText(laneKey) ?? _laneKeyForModuleDiscipline(discipline);

  @ignore
  String? get effectiveWorkflowLaneFirestoreId {
    final explicit = _cleanOptionalText(workflowLaneFirestoreId);
    if (explicit != null) return explicit;
    final executionId = _cleanOptionalText(jobExecutionFirestoreId);
    final lane = effectiveLaneKey;
    if (executionId == null || lane == null) return null;
    return '${executionId}_${lane}_$laneActivationGeneration';
  }

  // ─── Convenience getters ───────────────────────────────────
  @ignore
  bool get hasResponses => responses.isNotEmpty;

  @ignore
  bool get hasActions => actions.isNotEmpty;

  @ignore
  bool get isFinalisedForNormalUsers =>
      status == JobModuleStatus.submitted ||
      status == JobModuleStatus.accepted ||
      status == JobModuleStatus.notApplicable;

  @ignore
  bool get isOpenForWork =>
      !isDeleted &&
      status != JobModuleStatus.submitted &&
      status != JobModuleStatus.accepted &&
      status != JobModuleStatus.notApplicable;

  @ignore
  List<FieldResponse> get responses => FieldResponse.decode(
    responsesJson,
    source:
        firestoreId == null
            ? 'local job module $id'
            : 'job module $firestoreId',
  );

  @ignore
  FieldResponseReadResult get responsesReadResult => FieldResponse.tryDecode(
    responsesJson,
    source:
        firestoreId == null
            ? 'local job module $id'
            : 'job module $firestoreId',
  );

  @ignore
  FieldDefinitionReadResult get fieldDefinitionsReadResult =>
      PersistedFieldDefinitionPayload.tryDecode(
        fieldDefinitionsJson,
        source:
            firestoreId == null
                ? 'local job module $id'
                : 'job module $firestoreId',
      );

  set responses(List<FieldResponse> value) {
    responsesJson = FieldResponse.encode(value);
  }

  @ignore
  List<ComponentAction> get actions => ComponentAction.decode(
    actionsJson,
    source:
        firestoreId == null
            ? 'local job module $id'
            : 'job module $firestoreId',
  );

  @ignore
  ComponentActionReadResult get actionsReadResult => ComponentAction.tryDecode(
    actionsJson,
    source:
        firestoreId == null
            ? 'local job module $id'
            : 'job module $firestoreId',
  );

  set actions(List<ComponentAction> value) {
    actionsJson = ComponentAction.encode(value);
  }

  // ─── Audit snapshot ────────────────────────────────────────
  Map<String, dynamic> toAuditMap() => {
    'id': id,
    'firestoreId': firestoreId,
    'jobExecutionFirestoreId': jobExecutionFirestoreId,
    'templateFirestoreId': templateFirestoreId,
    'templatePackageId': templatePackageId,
    'templateVersionId': templateVersionId,
    'templateModuleId': templateModuleId,
    'moduleCode': moduleCode,
    'moduleTitle': moduleTitle,
    'assetType': assetType.name,
    'assetNumber': assetNumber,
    'discipline': discipline.name,
    'laneKey': effectiveLaneKey,
    'laneActivationGeneration': laneActivationGeneration,
    'workflowLaneFirestoreId': effectiveWorkflowLaneFirestoreId,
    'status': status.name,
    'isOpenForWork': isOpenForWork,
    'useMode': useMode.name,
    'safetyClass': safetyClass.name,
    'isRequired': isRequired,
    'requiredForClosure': requiredForClosure,
    'addedDuringExecution': addedDuringExecution,
    'requiresFollowUp': requiresFollowUp,
    'isDeleted': isDeleted,
  };

  // ─── Firestore serialization ───────────────────────────────
  Map<String, dynamic> toMap() => {
    'firestoreId': firestoreId,
    'jobExecutionFirestoreId': _cleanOptionalText(jobExecutionFirestoreId),
    'templateFirestoreId': _cleanOptionalText(templateFirestoreId),
    'templateName': _cleanOptionalText(templateName),
    'templatePackageId': _cleanOptionalText(templatePackageId),
    'templateVersionId': _cleanOptionalText(templateVersionId),
    'templateModuleId': _cleanOptionalText(templateModuleId),
    'moduleCode': _cleanOptionalText(moduleCode),
    'moduleSnapshotJson': _cleanOptionalText(moduleSnapshotJson) ?? '{}',
    'fieldDefinitionsJson': _cleanOptionalText(fieldDefinitionsJson) ?? '[]',
    'assetType': assetType.name,
    'assetNumber': assetNumber,
    'chargeNoAtEvent': chargeNoAtEvent,
    'pairedEquipmentJson': _cleanOptionalText(pairedEquipmentJson),
    'moduleTitle': moduleTitle.trim(),
    'moduleDescription': _cleanOptionalText(moduleDescription),
    'status': status.name,
    'useMode': useMode.name,
    'discipline': discipline.name,
    'laneKey': effectiveLaneKey,
    'laneActivationGeneration': laneActivationGeneration,
    'workflowLaneFirestoreId': effectiveWorkflowLaneFirestoreId,
    'isOpenForWork': isOpenForWork,
    'safetyClass': safetyClass.name,
    'isRequired': isRequired,
    'requiredForClosure': requiredForClosure,
    'addedDuringExecution': addedDuringExecution,
    'displayOrder': displayOrder,
    'functionalSection': _cleanOptionalText(functionalSection),
    'componentGroup': _cleanOptionalText(componentGroup),
    'subsystem': _cleanOptionalText(subsystem),
    'targetRef': _cleanOptionalText(targetRef),
    'targetRefs':
        targetRefs
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
    'procedureRefs':
        procedureRefs
            .map((ref) => ref.trim())
            .where((ref) => ref.isNotEmpty)
            .toList(),
    'safetyConfirmations':
        safetyConfirmations
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
    'tags':
        tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList(),
    'operationalStatePreconditions':
        operationalStatePreconditions
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
    // responsesJson is the canonical Firestore payload.
    // Do not also write the legacy structured 'responses' array.
    'responsesJson': responsesJson,
    'actionsJson': actionsJson,
    'draftNote': _cleanOptionalText(draftNote),
    'submissionNote': _cleanOptionalText(submissionNote),
    'acceptanceNote': _cleanOptionalText(acceptanceNote),
    'reopenReason': _cleanOptionalText(reopenReason),
    'notApplicableReason': _cleanOptionalText(notApplicableReason),
    'pendingIssue': _cleanOptionalText(pendingIssue),
    'requiresFollowUp': requiresFollowUp,
    'addedByUid': _cleanOptionalText(addedByUid),
    'addedByName': _cleanOptionalText(addedByName),
    'addedAt': addedAt?.toIso8601String(),
    'addReason': _cleanOptionalText(addReason),
    'createdByUid': _cleanOptionalText(createdByUid),
    'createdByName': _cleanOptionalText(createdByName),
    'createdAt': createdAt.toIso8601String(),
    'updatedByUid': _cleanOptionalText(updatedByUid),
    'updatedByName': _cleanOptionalText(updatedByName),
    'updatedAt': updatedAt.toIso8601String(),
    'submittedByUid': _cleanOptionalText(submittedByUid),
    'submittedByName': _cleanOptionalText(submittedByName),
    'submittedAt': submittedAt?.toIso8601String(),
    'acceptedByUid': _cleanOptionalText(acceptedByUid),
    'acceptedByName': _cleanOptionalText(acceptedByName),
    'acceptedAt': acceptedAt?.toIso8601String(),
    'reopenedByUid': _cleanOptionalText(reopenedByUid),
    'reopenedByName': _cleanOptionalText(reopenedByName),
    'reopenedAt': reopenedAt?.toIso8601String(),
    'notApplicableByUid': _cleanOptionalText(notApplicableByUid),
    'notApplicableByName': _cleanOptionalText(notApplicableByName),
    'notApplicableAt': notApplicableAt?.toIso8601String(),
    'isDeleted': isDeleted,
    'deletedAt': deletedAt?.toIso8601String(),
    'deletedByUid': _cleanOptionalText(deletedByUid),
    'deletedByName': _cleanOptionalText(deletedByName),
    'deleteReason': _cleanOptionalText(deleteReason),
    'version': version,
    'metadataJson': _cleanOptionalText(metadataJson),
  };

  factory JobModuleInstance.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final created = _parseTimestamp(map['createdAt']) ?? DateTime.now();
    final updated = _parseTimestamp(map['updatedAt']) ?? created;
    final added = _parseTimestamp(map['addedAt']);

    final instance =
        JobModuleInstance()
          ..firestoreId = documentId
          ..jobExecutionFirestoreId = _cleanOptionalText(
            map['jobExecutionFirestoreId'],
          )
          // Device-local Isar ids are never imported from Firestore.
          ..jobExecutionLocalId = null
          ..laneKey = _cleanOptionalText(map['laneKey'])
          ..laneActivationGeneration = _parseIntOr(
            map['laneActivationGeneration'],
            1,
          )
          ..workflowLaneFirestoreId = _cleanOptionalText(
            map['workflowLaneFirestoreId'],
          )
          ..templateFirestoreId = _cleanOptionalText(map['templateFirestoreId'])
          ..templateName = _cleanOptionalText(map['templateName'])
          ..templatePackageId = _cleanOptionalText(map['templatePackageId'])
          ..templateVersionId = _cleanOptionalText(map['templateVersionId'])
          ..templateModuleId = _cleanOptionalText(map['templateModuleId'])
          ..moduleCode = _cleanOptionalText(map['moduleCode'])
          ..moduleSnapshotJson = _safeJsonObject(map['moduleSnapshotJson'])
          ..fieldDefinitionsJson =
              map.containsKey('fieldDefinitionsJson')
                  ? PersistedFieldDefinitionPayload.readEncodedPayload(
                    map['fieldDefinitionsJson'],
                    field: 'fieldDefinitionsJson',
                    source: 'job module $documentId',
                  )
                  : '[]'
          ..assetType = _enumByNameOr(
            AssetType.values,
            map['assetType'],
            AssetType.base,
          )
          ..assetNumber = _parseIntOr(map['assetNumber'], 0)
          ..chargeNoAtEvent = _parseIntOrNull(map['chargeNoAtEvent'])
          ..pairedEquipmentJson = _cleanOptionalText(map['pairedEquipmentJson'])
          ..moduleTitle =
              _cleanOptionalText(map['moduleTitle']) ?? 'Untitled module'
          ..moduleDescription = _cleanOptionalText(map['moduleDescription'])
          ..status = _enumByNameOr(
            JobModuleStatus.values,
            map['status'],
            JobModuleStatus.notStarted,
          )
          ..useMode = _enumByNameOr(
            JobModuleUseMode.values,
            map['useMode'],
            JobModuleUseMode.scheduledPM,
          )
          ..discipline = _parseDiscipline(map['discipline'])
          ..safetyClass = _enumByNameOr(
            JobModuleSafetyClass.values,
            map['safetyClass'],
            JobModuleSafetyClass.normal,
          )
          ..isRequired = map['isRequired'] == true
          ..requiredForClosure = map['requiredForClosure'] == true
          ..addedDuringExecution = map['addedDuringExecution'] == true
          ..displayOrder = _parseIntOr(map['displayOrder'], 0)
          ..functionalSection = _cleanOptionalText(map['functionalSection'])
          ..componentGroup = _cleanOptionalText(map['componentGroup'])
          ..subsystem = _cleanOptionalText(map['subsystem'])
          ..targetRef = _cleanOptionalText(map['targetRef'])
          ..targetRefs = _cleanStringList(map['targetRefs'])
          ..procedureRefs = _cleanStringList(map['procedureRefs'])
          ..safetyConfirmations = _cleanStringList(map['safetyConfirmations'])
          ..tags = _cleanStringList(map['tags'])
          ..operationalStatePreconditions = _cleanStringList(
            map['operationalStatePreconditions'],
          )
          ..responsesJson =
              map.containsKey('responsesJson')
                  ? FieldResponse.readEncodedPayload(
                    map['responsesJson'],
                    field: 'responsesJson',
                    source: 'job module $documentId',
                  )
                  : '[]'
          ..actionsJson = ComponentAction.readEncodedPayload(
            map['actionsJson'],
            field: 'actionsJson',
            source: 'job module $documentId',
            allowMissing: !map.containsKey('actionsJson'),
          )
          ..draftNote = _cleanOptionalText(map['draftNote'])
          ..submissionNote = _cleanOptionalText(map['submissionNote'])
          ..acceptanceNote = _cleanOptionalText(map['acceptanceNote'])
          ..reopenReason = _cleanOptionalText(map['reopenReason'])
          ..notApplicableReason = _cleanOptionalText(map['notApplicableReason'])
          ..pendingIssue = _cleanOptionalText(map['pendingIssue'])
          ..requiresFollowUp = map['requiresFollowUp'] == true
          ..addedByUid = _cleanOptionalText(map['addedByUid'])
          ..addedByName = _cleanOptionalText(map['addedByName'])
          ..addedAt = added
          ..addReason = _cleanOptionalText(map['addReason'])
          ..createdByUid = _cleanOptionalText(map['createdByUid'])
          ..createdByName = _cleanOptionalText(map['createdByName'])
          ..createdAt = created
          ..updatedByUid = _cleanOptionalText(map['updatedByUid'])
          ..updatedByName = _cleanOptionalText(map['updatedByName'])
          ..updatedAt = updated
          ..submittedByUid = _cleanOptionalText(map['submittedByUid'])
          ..submittedByName = _cleanOptionalText(map['submittedByName'])
          ..submittedAt = _parseTimestamp(map['submittedAt'])
          ..acceptedByUid = _cleanOptionalText(map['acceptedByUid'])
          ..acceptedByName = _cleanOptionalText(map['acceptedByName'])
          ..acceptedAt = _parseTimestamp(map['acceptedAt'])
          ..reopenedByUid = _cleanOptionalText(map['reopenedByUid'])
          ..reopenedByName = _cleanOptionalText(map['reopenedByName'])
          ..reopenedAt = _parseTimestamp(map['reopenedAt'])
          ..notApplicableByUid = _cleanOptionalText(map['notApplicableByUid'])
          ..notApplicableByName = _cleanOptionalText(map['notApplicableByName'])
          ..notApplicableAt = _parseTimestamp(map['notApplicableAt'])
          ..isDeleted = map['isDeleted'] == true
          ..deletedAt = _parseTimestamp(map['deletedAt'])
          ..deletedByUid = _cleanOptionalText(map['deletedByUid'])
          ..deletedByName = _cleanOptionalText(map['deletedByName'])
          ..deleteReason = _cleanOptionalText(map['deleteReason'])
          ..version = _parseIntOr(map['version'], 1)
          ..metadataJson = _cleanOptionalText(map['metadataJson'])
          ..isSynced = true;

    // responsesJson is canonical. Only fall back to the legacy structured
    // 'responses' array for old records that do not contain responsesJson.
    final rawResponses = map['responses'];
    if (!map.containsKey('responsesJson') && rawResponses is List) {
      instance.responsesJson = FieldResponse.encodeLegacyPayload(
        rawResponses,
        source: 'job module $documentId',
      );
    }

    return instance;
  }
}
