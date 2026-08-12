// FILE: lib/features/planned_maintenance/data/job_module_model.dart

import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/services/remote_tombstone_apply_result.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/utils/asset_validator.dart';
import '../models/component_action_model.dart';
import 'job_template_model.dart'
    show
        FieldDefinitionReadResult,
        FieldResponse,
        FieldResponseReadResult,
        PersistedFieldDefinitionPayload;
import 'remote_job_timestamps.dart';

part 'job_module_model.g.dart';

// ─────────────────────────────────────────────────────────────
// FIRESTORE-SHAPE PARSING HELPERS
// ─────────────────────────────────────────────────────────────

String? _cleanOptionalText(dynamic value) {
  if (value == null) return null;
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
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

T _enumByNameOr<T extends Enum>(
  List<T> values,
  dynamic value,
  T fallback, {
  required String field,
  required String source,
}) {
  if (value == null) return fallback;
  if (value is! String) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an enum string (${value.runtimeType})',
    );
  }
  final key = _normaliseEnumKey(value);
  if (key.isEmpty) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'enum value cannot be blank',
    );
  }

  for (final item in values) {
    if (_normaliseEnumKey(item.name) == key) return item;
  }

  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'unknown enum value "$value"',
  );
}

JobModuleDiscipline _parseDiscipline(dynamic value, {required String source}) {
  if (value == null) return JobModuleDiscipline.shared;
  if (value is! String) {
    throw PersistedDataFormatException(
      field: 'discipline',
      source: source,
      detail: 'expected an enum string (${value.runtimeType})',
    );
  }
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
    field: 'discipline',
    source: source,
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

String _readJsonObjectText(
  dynamic value, {
  required String field,
  required String source,
}) {
  if (value == null) return '{}';
  if (value is String) {
    readRequiredJsonObject(value, field: field, source: source);
    return value;
  }
  if (value is Map) {
    try {
      final typed = Map<String, dynamic>.from(value);
      return jsonEncode(typed);
    } on TypeError {
      throw PersistedDataFormatException(
        field: field,
        source: source,
        detail: 'object keys must be strings',
      );
    }
  }
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'expected a JSON object (${value.runtimeType})',
  );
}

class ModuleSnapshotReadResult {
  final Map<String, dynamic> value;
  final FormatException? error;

  const ModuleSnapshotReadResult({required this.value, this.error});

  bool get isValid => error == null;
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
  ModuleSnapshotReadResult get moduleSnapshotReadResult {
    try {
      return ModuleSnapshotReadResult(
        value: readRequiredJsonObject(
          moduleSnapshotJson,
          field: 'moduleSnapshotJson',
          source:
              firestoreId == null
                  ? 'local job module $id'
                  : 'job module $firestoreId',
        ),
      );
    } on FormatException catch (error) {
      return ModuleSnapshotReadResult(
        value: const <String, dynamic>{},
        error: error,
      );
    }
  }

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
    final source = 'job module $documentId';
    final timestamps = readRemoteJobModuleTimestamps(map, source: source);
    if (map['isDeleted'] == true && timestamps.deletedAt == null) {
      requireRemoteTombstoneDeletedAt(
        timestamps.deletedAt,
        entityLabel: 'job module',
        firestoreId: documentId,
      );
    }
    final embeddedId = readRequiredPersistedString(
      map['firestoreId'],
      field: 'firestoreId',
      source: source,
    );
    if (embeddedId != documentId) {
      throw PersistedDataFormatException(
        field: 'firestoreId',
        source: source,
        detail: 'must match the document ID',
      );
    }
    final assetType = readRequiredPersistedEnum(
      AssetType.values,
      map['assetType'],
      field: 'assetType',
      source: source,
    );
    final assetNumber = readRequiredPersistedInt(
      map['assetNumber'],
      field: 'assetNumber',
      source: source,
      minimum: 1,
    );
    if (!AssetValidator.isValid(assetType, assetNumber)) {
      throw PersistedDataFormatException(
        field: 'assetNumber',
        source: source,
        detail: 'outside the governed range for ${assetType.name}',
      );
    }
    final status = _enumByNameOr(
      JobModuleStatus.values,
      map['status'],
      JobModuleStatus.notStarted,
      field: 'status',
      source: source,
    );
    final isDeleted =
        readOptionalPersistedBool(
          map['isDeleted'],
          field: 'isDeleted',
          source: source,
        ) ??
        false;
    final actionsJson = ComponentAction.readEncodedPayload(
      map['actionsJson'],
      field: 'actionsJson',
      source: source,
      allowMissing: !map.containsKey('actionsJson'),
    );
    ComponentAction.decode(actionsJson, source: source);

    final instance =
        JobModuleInstance()
          ..firestoreId = embeddedId
          ..jobExecutionFirestoreId = readRequiredPersistedString(
            map['jobExecutionFirestoreId'],
            field: 'jobExecutionFirestoreId',
            source: source,
          )
          // Device-local Isar ids are never imported from Firestore.
          ..jobExecutionLocalId = null
          ..laneKey = _readOptionalModuleString(map, 'laneKey', source)
          ..laneActivationGeneration =
              readOptionalPersistedInt(
                map['laneActivationGeneration'],
                field: 'laneActivationGeneration',
                source: source,
                minimum: 1,
              ) ??
              1
          ..workflowLaneFirestoreId = _readOptionalModuleString(
            map,
            'workflowLaneFirestoreId',
            source,
          )
          ..templateFirestoreId = _readOptionalModuleString(
            map,
            'templateFirestoreId',
            source,
          )
          ..templateName = _readOptionalModuleString(
            map,
            'templateName',
            source,
          )
          ..templatePackageId = _readOptionalModuleString(
            map,
            'templatePackageId',
            source,
          )
          ..templateVersionId = _readOptionalModuleString(
            map,
            'templateVersionId',
            source,
          )
          ..templateModuleId = _readOptionalModuleString(
            map,
            'templateModuleId',
            source,
          )
          ..moduleCode = _readOptionalModuleString(map, 'moduleCode', source)
          ..moduleSnapshotJson = _readJsonObjectText(
            map['moduleSnapshotJson'],
            field: 'moduleSnapshotJson',
            source: source,
          )
          ..fieldDefinitionsJson =
              map.containsKey('fieldDefinitionsJson')
                  ? PersistedFieldDefinitionPayload.readEncodedPayload(
                    map['fieldDefinitionsJson'],
                    field: 'fieldDefinitionsJson',
                    source: source,
                  )
                  : '[]'
          ..assetType = assetType
          ..assetNumber = assetNumber
          ..chargeNoAtEvent = readOptionalPersistedInt(
            map['chargeNoAtEvent'],
            field: 'chargeNoAtEvent',
            source: source,
            minimum: 1,
          )
          ..pairedEquipmentJson = _readOptionalModuleString(
            map,
            'pairedEquipmentJson',
            source,
            emptyAsNull: false,
          )
          ..moduleTitle = readRequiredPersistedString(
            map['moduleTitle'],
            field: 'moduleTitle',
            source: source,
          )
          ..moduleDescription = _readOptionalModuleString(
            map,
            'moduleDescription',
            source,
          )
          ..status = status
          ..useMode = _enumByNameOr(
            JobModuleUseMode.values,
            map['useMode'],
            JobModuleUseMode.scheduledPM,
            field: 'useMode',
            source: source,
          )
          ..discipline = _parseDiscipline(map['discipline'], source: source)
          ..safetyClass = _enumByNameOr(
            JobModuleSafetyClass.values,
            map['safetyClass'],
            JobModuleSafetyClass.normal,
            field: 'safetyClass',
            source: source,
          )
          ..isRequired =
              readOptionalPersistedBool(
                map['isRequired'],
                field: 'isRequired',
                source: source,
              ) ??
              false
          ..requiredForClosure =
              readOptionalPersistedBool(
                map['requiredForClosure'],
                field: 'requiredForClosure',
                source: source,
              ) ??
              false
          ..addedDuringExecution =
              readOptionalPersistedBool(
                map['addedDuringExecution'],
                field: 'addedDuringExecution',
                source: source,
              ) ??
              false
          ..displayOrder =
              readOptionalPersistedInt(
                map['displayOrder'],
                field: 'displayOrder',
                source: source,
                minimum: 0,
              ) ??
              0
          ..functionalSection = _readOptionalModuleString(
            map,
            'functionalSection',
            source,
          )
          ..componentGroup = _readOptionalModuleString(
            map,
            'componentGroup',
            source,
          )
          ..subsystem = _readOptionalModuleString(map, 'subsystem', source)
          ..targetRef = _readOptionalModuleString(map, 'targetRef', source)
          ..targetRefs = readOptionalPersistedStringList(
            map['targetRefs'],
            field: 'targetRefs',
            source: source,
          )
          ..procedureRefs = readOptionalPersistedStringList(
            map['procedureRefs'],
            field: 'procedureRefs',
            source: source,
          )
          ..safetyConfirmations = readOptionalPersistedStringList(
            map['safetyConfirmations'],
            field: 'safetyConfirmations',
            source: source,
          )
          ..tags = readOptionalPersistedStringList(
            map['tags'],
            field: 'tags',
            source: source,
          )
          ..operationalStatePreconditions = readOptionalPersistedStringList(
            map['operationalStatePreconditions'],
            field: 'operationalStatePreconditions',
            source: source,
          )
          ..responsesJson =
              map.containsKey('responsesJson')
                  ? FieldResponse.readEncodedPayload(
                    map['responsesJson'],
                    field: 'responsesJson',
                    source: source,
                  )
                  : '[]'
          ..actionsJson = actionsJson
          ..draftNote = _readOptionalModuleString(map, 'draftNote', source)
          ..submissionNote = _readOptionalModuleString(
            map,
            'submissionNote',
            source,
          )
          ..acceptanceNote = _readOptionalModuleString(
            map,
            'acceptanceNote',
            source,
          )
          ..reopenReason = _readOptionalModuleString(
            map,
            'reopenReason',
            source,
          )
          ..notApplicableReason = _readOptionalModuleString(
            map,
            'notApplicableReason',
            source,
          )
          ..pendingIssue = _readOptionalModuleString(
            map,
            'pendingIssue',
            source,
          )
          ..requiresFollowUp =
              readOptionalPersistedBool(
                map['requiresFollowUp'],
                field: 'requiresFollowUp',
                source: source,
              ) ??
              false
          ..addedByUid = _readOptionalModuleString(map, 'addedByUid', source)
          ..addedByName = _readOptionalModuleString(map, 'addedByName', source)
          ..addedAt = timestamps.addedAt
          ..addReason = _readOptionalModuleString(map, 'addReason', source)
          ..createdByUid = _readOptionalModuleString(
            map,
            'createdByUid',
            source,
          )
          ..createdByName = _readOptionalModuleString(
            map,
            'createdByName',
            source,
          )
          ..createdAt = timestamps.createdAt
          ..updatedByUid = _readOptionalModuleString(
            map,
            'updatedByUid',
            source,
          )
          ..updatedByName = _readOptionalModuleString(
            map,
            'updatedByName',
            source,
          )
          ..updatedAt = timestamps.updatedAt
          ..submittedByUid = _readOptionalModuleString(
            map,
            'submittedByUid',
            source,
          )
          ..submittedByName = _readOptionalModuleString(
            map,
            'submittedByName',
            source,
          )
          ..submittedAt = timestamps.submittedAt
          ..acceptedByUid = _readOptionalModuleString(
            map,
            'acceptedByUid',
            source,
          )
          ..acceptedByName = _readOptionalModuleString(
            map,
            'acceptedByName',
            source,
          )
          ..acceptedAt = timestamps.acceptedAt
          ..reopenedByUid = _readOptionalModuleString(
            map,
            'reopenedByUid',
            source,
          )
          ..reopenedByName = _readOptionalModuleString(
            map,
            'reopenedByName',
            source,
          )
          ..reopenedAt = timestamps.reopenedAt
          ..notApplicableByUid = _readOptionalModuleString(
            map,
            'notApplicableByUid',
            source,
          )
          ..notApplicableByName = _readOptionalModuleString(
            map,
            'notApplicableByName',
            source,
          )
          ..notApplicableAt = timestamps.notApplicableAt
          ..isDeleted = isDeleted
          ..deletedAt = timestamps.deletedAt
          ..deletedByUid = _readOptionalModuleString(
            map,
            'deletedByUid',
            source,
          )
          ..deletedByName = _readOptionalModuleString(
            map,
            'deletedByName',
            source,
          )
          ..deleteReason = _readOptionalModuleString(
            map,
            'deleteReason',
            source,
          )
          ..version = readRequiredPersistedInt(
            map['version'],
            field: 'version',
            source: source,
            minimum: 1,
          )
          ..metadataJson = _readOptionalModuleString(
            map,
            'metadataJson',
            source,
            emptyAsNull: false,
          )
          ..isSynced = true;

    // responsesJson is canonical. Only fall back to the legacy structured
    // 'responses' array for old records that do not contain responsesJson.
    final rawResponses = map['responses'];
    if (!map.containsKey('responsesJson') && rawResponses is List) {
      instance.responsesJson = FieldResponse.encodeLegacyPayload(
        rawResponses,
        source: source,
      );
    } else if (!map.containsKey('responsesJson') && rawResponses != null) {
      throw PersistedDataFormatException(
        field: 'responses',
        source: source,
        detail: 'expected a legacy array (${rawResponses.runtimeType})',
      );
    }

    final persistedOpen = readOptionalPersistedBool(
      map['isOpenForWork'],
      field: 'isOpenForWork',
      source: source,
    );
    if (persistedOpen != null && persistedOpen != instance.isOpenForWork) {
      throw PersistedDataFormatException(
        field: 'isOpenForWork',
        source: source,
        detail: 'must agree with status ${instance.status.name}',
      );
    }

    if (instance.isDeleted) {
      requireRemoteTombstoneDeletedAt(
        instance.deletedAt,
        entityLabel: 'job module',
        firestoreId: instance.firestoreId,
      );
    } else if (instance.deletedAt != null ||
        instance.deletedByUid != null ||
        instance.deletedByName != null ||
        instance.deleteReason != null) {
      throw PersistedDataFormatException(
        field: 'isDeleted',
        source: source,
        detail: 'active modules cannot carry deletion state',
      );
    }
    if (instance.updatedAt.isBefore(instance.createdAt)) {
      throw PersistedDataFormatException(
        field: 'updatedAt',
        source: source,
        detail: 'cannot precede createdAt',
      );
    }

    return instance;
  }
}

String? _readOptionalModuleString(
  Map<String, dynamic> map,
  String field,
  String source, {
  bool emptyAsNull = true,
}) => readOptionalPersistedString(
  map[field],
  field: field,
  source: source,
  emptyAsNull: emptyAsNull,
);
