// FILE: lib/features/planned_maintenance/domain/published_runtime_module_catalogue.dart

import 'dart:convert';

import '../../auth/data/user_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';
import '../data/job_template_model.dart';
import '../data/template_governance_model.dart';
import 'template_version_snapshot_contract.dart';

const JsonEncoder _publishedRuntimeJson = JsonEncoder.withIndent('  ');

/// A governed module candidate parsed from a published TemplateVersion snapshot.
///
/// This is the source object for Issue 45's runtime-add catalogue. It does not
/// mutate a published TemplateVersion. It converts a frozen module snapshot into
/// a new JobModuleInstance for one active job, preserving the published source
/// metadata for audit/dossier review.
class PublishedRuntimeModuleCandidate {
  final String packageFirestoreId;
  final String? packageCode;
  final String? packageTitle;
  final String versionFirestoreId;
  final int versionNumber;
  final String? versionLabel;
  final String? contentHash;
  final int moduleIndex;
  final String moduleCode;
  final String moduleTitle;
  final String? templateModuleId;
  final String moduleSnapshotJson;
  final String fieldDefinitionsJson;
  final JobModuleDiscipline discipline;
  final JobModuleSafetyClass safetyClass;
  final JobModuleUseMode useMode;
  final bool requiredForClosure;
  final bool isRequired;
  final String? moduleDescription;
  final String? functionalSection;
  final String? componentGroup;
  final String? subsystem;
  final String? targetRef;
  final List<String> targetRefs;
  final List<String> procedureRefs;
  final List<String> safetyConfirmations;
  final List<String> operationalStatePreconditions;
  final List<String> tags;
  final int displayOrder;

  const PublishedRuntimeModuleCandidate({
    required this.packageFirestoreId,
    required this.packageCode,
    required this.packageTitle,
    required this.versionFirestoreId,
    required this.versionNumber,
    required this.versionLabel,
    required this.contentHash,
    required this.moduleIndex,
    required this.moduleCode,
    required this.moduleTitle,
    required this.templateModuleId,
    required this.moduleSnapshotJson,
    required this.fieldDefinitionsJson,
    required this.discipline,
    required this.safetyClass,
    required this.useMode,
    required this.requiredForClosure,
    required this.isRequired,
    required this.moduleDescription,
    required this.functionalSection,
    required this.componentGroup,
    required this.subsystem,
    required this.targetRef,
    required this.targetRefs,
    required this.procedureRefs,
    required this.safetyConfirmations,
    required this.operationalStatePreconditions,
    required this.tags,
    required this.displayOrder,
  });

  String get displayTitle => '$moduleCode - $moduleTitle';

  String get sourceLabel {
    final packagePart = packageCode ?? packageTitle ?? 'Published catalogue';
    final versionPart =
        versionLabel == null || versionLabel!.trim().isEmpty
            ? 'v$versionNumber'
            : 'v$versionNumber · $versionLabel';
    return '$packagePart · $versionPart';
  }

  /// Mirrors the existing elevated-runtime-add policy without tying it to the
  /// emergency/manual seed source. Published modules that are shared, safety
  /// classified, or closure-critical still require supervisory/Admin/SI control.
  bool requiresElevatedRuntimeAddControl({bool? requiredForClosureOverride}) {
    return safetyClass != JobModuleSafetyClass.normal ||
        discipline == JobModuleDiscipline.shared ||
        (requiredForClosureOverride ?? requiredForClosure);
  }

  JobModuleInstance toJobModuleInstance({
    required JobExecution execution,
    required AppUser actor,
    required DateTime now,
    required String addReason,
    JobModuleDiscipline? disciplineOverride,
    JobModuleUseMode? useModeOverride,
    bool? requiredForClosureOverride,
    int? displayOrderOverride,
  }) {
    final effectiveRequiredForClosure =
        requiredForClosureOverride ?? requiredForClosure;
    final cleanAddReason = _clean(addReason);

    return JobModuleInstance()
      ..jobExecutionFirestoreId = _clean(execution.firestoreId)
      ..jobExecutionLocalId = execution.id
      ..templateFirestoreId = versionFirestoreId
      ..templateName = sourceLabel
      ..templatePackageId = packageFirestoreId
      ..templateVersionId = versionFirestoreId
      ..templateModuleId = templateModuleId ?? moduleCode
      ..moduleCode = moduleCode
      ..moduleSnapshotJson = moduleSnapshotJson
      ..fieldDefinitionsJson = fieldDefinitionsJson
      ..assetType = execution.assetType
      ..assetNumber = execution.assetNumber
      ..chargeNoAtEvent = execution.chargeNoAtEvent
      ..moduleTitle = moduleTitle
      ..moduleDescription = moduleDescription
      ..status = JobModuleStatus.notStarted
      ..useMode = useModeOverride ?? useMode
      ..discipline = disciplineOverride ?? discipline
      ..safetyClass = safetyClass
      ..isRequired = effectiveRequiredForClosure
      ..requiredForClosure = effectiveRequiredForClosure
      ..addedDuringExecution = true
      ..displayOrder = displayOrderOverride ?? now.millisecondsSinceEpoch
      ..functionalSection = functionalSection
      ..componentGroup = componentGroup
      ..subsystem = subsystem
      ..targetRef = targetRef
      ..targetRefs = List<String>.from(targetRefs)
      ..procedureRefs = List<String>.from(procedureRefs)
      ..safetyConfirmations = List<String>.from(safetyConfirmations)
      ..operationalStatePreconditions = List<String>.from(
        operationalStatePreconditions,
      )
      ..tags = <String>{
        moduleCode,
        if (packageCode != null) packageCode!,
        if (versionLabel != null) versionLabel!,
        ...tags,
      }.where((tag) => tag.trim().isNotEmpty).toList(growable: false)
      ..responsesJson = '[]'
      ..actionsJson = '[]'
      ..requiresFollowUp = false
      ..addedByUid = actor.uid
      ..addedByName = actor.name
      ..addedAt = now
      ..addReason = cleanAddReason
      ..createdByUid = actor.uid
      ..createdByName = actor.name
      ..createdAt = now
      ..updatedByUid = actor.uid
      ..updatedByName = actor.name
      ..updatedAt = now
      ..isDeleted = false
      ..version = 1
      ..metadataJson = _publishedRuntimeJson.convert(<String, dynamic>{
        'source': 'published_template_version_runtime_add',
        'packageFirestoreId': packageFirestoreId,
        if (packageCode != null) 'packageCode': packageCode,
        if (packageTitle != null) 'packageTitle': packageTitle,
        'versionFirestoreId': versionFirestoreId,
        'versionNumber': versionNumber,
        if (versionLabel != null) 'versionLabel': versionLabel,
        if (contentHash != null) 'contentHash': contentHash,
        'moduleIndex': moduleIndex,
        'moduleCode': moduleCode,
        'templateModuleId': templateModuleId ?? moduleCode,
        'runtimeAddReason': cleanAddReason,
      })
      ..isSynced = false;
  }
}

/// Parse all runtime-add candidates from a published TemplateVersion.
///
/// This is intentionally pure and side-effect free. The caller decides whether
/// to show these candidates in UI, exclude already-attached modules, or fall
/// back to the Emergency/manual seed catalogue.
List<PublishedRuntimeModuleCandidate>
publishedRuntimeModuleCandidatesFromVersion({
  required TemplateVersion version,
  TemplatePackage? package,
  AssetType? assetType,
  Set<String> existingModuleCodes = const <String>{},
  Set<String> existingTemplateModuleIds = const <String>{},
  bool excludeExisting = true,
}) {
  if (!version.isPublished) {
    throw StateError(
      'Runtime module catalogue can only use published TemplateVersions.',
    );
  }

  final versionId = _clean(version.firestoreId);
  if (versionId == null) {
    throw StateError('Published TemplateVersion is missing firestoreId.');
  }

  final packageId =
      _clean(version.packageFirestoreId) ?? _clean(package?.firestoreId);
  if (packageId == null) {
    throw StateError(
      'Published TemplateVersion is missing packageFirestoreId.',
    );
  }

  final bundle =
      TemplateVersionSnapshotBundle.fromRawJson(
        jobTemplateSnapshotJson: version.jobTemplateSnapshotJson,
        moduleSnapshotsJson: version.moduleSnapshotsJson,
        fieldDefinitionsJson: version.fieldDefinitionsJson,
        checklistJson: version.checklistJson,
      ).requireValidForAssignment();

  final existingCodes = existingModuleCodes.map(_normaliseKey).toSet();
  final existingTemplateIds =
      existingTemplateModuleIds.map(_normaliseKey).toSet();

  final candidates = <PublishedRuntimeModuleCandidate>[];
  for (var index = 0; index < bundle.moduleSnapshots.length; index++) {
    final snapshot = bundle.moduleSnapshots[index];
    if (assetType != null && !_moduleAppliesToAsset(snapshot, assetType)) {
      continue;
    }

    final code = TemplateVersionSnapshotBundle.moduleCode(snapshot)?.trim();
    if (code == null || code.isEmpty) continue;

    final templateModuleId = _stringFrom(snapshot, const [
      'templateModuleId',
      'moduleId',
      'id',
      'key',
    ]);

    if (excludeExisting) {
      final normalizedCode = _normaliseKey(code);
      final normalizedTemplateId = _normaliseKey(templateModuleId);
      if (existingCodes.contains(normalizedCode) ||
          (normalizedTemplateId.isNotEmpty &&
              existingTemplateIds.contains(normalizedTemplateId))) {
        continue;
      }
    }

    final fields = bundle.fieldsForModule(snapshot);
    final packageCode = _clean(package?.packageCode);
    final packageTitle = _clean(package?.title);
    final versionLabel = _clean(version.versionLabel);
    final contentHash = _clean(version.contentHash);
    final targetRefs = _stringListFrom(snapshot, const [
      'targetRefs',
      'targets',
    ]);
    final procedureRefs = _stringListFrom(snapshot, const [
      'procedureRefs',
      'procedures',
    ]);
    final tags = <String>{
      code,
      if (packageCode != null) packageCode,
      if (packageTitle != null) packageTitle,
      ..._stringListFrom(snapshot, const ['tags', 'deviceTags', 'targetRefs']),
      ...procedureRefs,
      ...targetRefs,
    }.where((tag) => tag.trim().isNotEmpty).toList(growable: false);

    candidates.add(
      PublishedRuntimeModuleCandidate(
        packageFirestoreId: packageId,
        packageCode: packageCode,
        packageTitle: packageTitle,
        versionFirestoreId: versionId,
        versionNumber: version.versionNumber,
        versionLabel: versionLabel,
        contentHash: contentHash,
        moduleIndex: index,
        moduleCode: code,
        moduleTitle: TemplateVersionSnapshotBundle.moduleTitle(snapshot, index),
        templateModuleId: templateModuleId,
        moduleSnapshotJson: _publishedRuntimeJson.convert(snapshot),
        fieldDefinitionsJson: _publishedRuntimeJson.convert(fields),
        discipline: _parseModuleDiscipline(
          _stringFrom(snapshot, const [
            'discipline',
            'defaultDiscipline',
            'assignedDiscipline',
            'ownerDiscipline',
          ]),
        ),
        safetyClass: _parseSafetyClass(
          _stringFrom(snapshot, const ['safetyClass', 'defaultSafetyClass']),
        ),
        useMode: _parseUseMode(
          _stringFrom(snapshot, const ['useMode', 'defaultUseMode']),
        ),
        requiredForClosure: _boolFrom(snapshot, const [
          'requiredForClosure',
          'requiredForCloseout',
          'required',
        ], fallback: true),
        isRequired: _boolFrom(snapshot, const [
          'isRequired',
          'required',
        ], fallback: true),
        moduleDescription: _stringFrom(snapshot, const [
          'moduleDescription',
          'description',
          'closedDossierOutput',
        ]),
        functionalSection: _stringFrom(snapshot, const [
          'functionalSection',
          'section',
        ]),
        componentGroup: _stringFrom(snapshot, const [
          'componentGroup',
          'component',
        ]),
        subsystem: _stringFrom(snapshot, const [
          'subsystem',
          'catalogueArea',
          'area',
        ]),
        targetRef: _stringFrom(snapshot, const ['targetRef']),
        targetRefs: targetRefs,
        procedureRefs: procedureRefs,
        safetyConfirmations: _stringListFrom(snapshot, const [
          'safetyConfirmations',
        ]),
        operationalStatePreconditions: _stringListFrom(snapshot, const [
          'operationalStatePreconditions',
          'preconditions',
        ]),
        tags: tags,
        displayOrder: _intFrom(snapshot, const [
          'displayOrder',
          'order',
          'sequence',
        ], fallback: index),
      ),
    );
  }

  candidates.sort((a, b) {
    final orderCompare = a.displayOrder.compareTo(b.displayOrder);
    if (orderCompare != 0) return orderCompare;
    return a.moduleCode.compareTo(b.moduleCode);
  });
  return candidates;
}

bool _moduleAppliesToAsset(Map<String, dynamic> snapshot, AssetType assetType) {
  final rawValues = <String>[
    ..._stringListFrom(snapshot, const [
      'assetTypes',
      'applicableAssetTypes',
      'assetFamilies',
      'assetFamily',
    ]),
    if (_stringFrom(snapshot, const ['assetType']) case final asset?) asset,
  ];

  if (rawValues.isEmpty) return true;

  final target = _normaliseKey(assetType.name);
  return rawValues.any((raw) {
    final normalized = _normaliseKey(raw);
    return normalized == 'all' ||
        normalized == 'any' ||
        normalized == target ||
        _parseAssetType(raw) == assetType;
  });
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _stringFrom(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is num || value is bool) return value.toString();
  }
  return null;
}

int _intFrom(
  Map<String, dynamic> map,
  List<String> keys, {
  required int fallback,
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}

bool _boolFrom(
  Map<String, dynamic> map,
  List<String> keys, {
  required bool fallback,
}) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    if (value is String) {
      final cleaned = value.trim().toLowerCase();
      if (cleaned == 'true' || cleaned == 'yes' || cleaned == 'required') {
        return true;
      }
      if (cleaned == 'false' || cleaned == 'no' || cleaned == 'optional') {
        return false;
      }
    }
  }
  return fallback;
}

List<String> _stringListFrom(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    final list = _stringList(value);
    if (list.isNotEmpty) return list;
  }
  return <String>[];
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,;/|]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return <String>[];
}

AssetType? _parseAssetType(String? value) {
  final normalized = _normaliseKey(value);
  if (normalized.isEmpty) return null;
  for (final type in AssetType.values) {
    if (_normaliseKey(type.name) == normalized) return type;
  }
  switch (normalized) {
    case 'furnace':
    case 'baffurnace':
      return AssetType.furnace;
    case 'base':
      return AssetType.base;
    case 'innercover':
    case 'innercovers':
      return AssetType.innerCover;
    case 'forcedcooler':
    case 'cooler':
    case 'forcedcoolers':
      return AssetType.forceCooler;
  }
  return null;
}

JobModuleDiscipline _parseModuleDiscipline(String? value) {
  final normalized = _normaliseKey(value);
  switch (normalized) {
    case 'mechanical':
      return JobModuleDiscipline.mechanical;
    case 'electrical':
      return JobModuleDiscipline.electrical;
    case 'instrumentation':
    case 'instrument':
    case 'ia':
    case 'ianda':
    case 'instrumentationautomation':
    case 'instrumentationandautomation':
      return JobModuleDiscipline.instrumentation;
    case 'operations':
    case 'operation':
      return JobModuleDiscipline.operations;
    case 'emd':
      return JobModuleDiscipline.emd;
    case 'refractory':
      return JobModuleDiscipline.refractory;
    case 'safety':
      return JobModuleDiscipline.safety;
    case 'others':
      return JobModuleDiscipline.others;
    case 'shared':
      return JobModuleDiscipline.shared;
  }
  return JobModuleDiscipline.shared;
}

JobModuleSafetyClass _parseSafetyClass(String? value) {
  final normalized = _normaliseKey(value);
  for (final item in JobModuleSafetyClass.values) {
    if (_normaliseKey(item.name) == normalized) return item;
  }
  switch (normalized) {
    case 'critical':
    case 'safetycritical':
      return JobModuleSafetyClass.lotoRequired;
    case 'highrisk':
    case 'high':
    case 'confinedspace':
    case 'hydrogen':
    case 'gastrain':
    case 'gas':
      return JobModuleSafetyClass.gasRisk;
    case 'lifting':
    case 'liftingrisk':
      return JobModuleSafetyClass.liftingRisk;
    case 'electricalpanel':
      return JobModuleSafetyClass.electricalPanel;
    case 'combustion':
    case 'combustionspecialist':
      return JobModuleSafetyClass.combustionSpecialist;
    case 'configuration':
    case 'configurationcontrol':
      return JobModuleSafetyClass.configurationControl;
  }
  return JobModuleSafetyClass.normal;
}

JobModuleUseMode _parseUseMode(String? value) {
  final normalized = _normaliseKey(value);
  for (final item in JobModuleUseMode.values) {
    if (_normaliseKey(item.name) == normalized) return item;
  }
  switch (normalized) {
    case 'scheduled':
    case 'scheduledpm':
    case 'pm':
      return JobModuleUseMode.scheduledPM;
    case 'conditional':
    case 'conditionbased':
      return JobModuleUseMode.scheduledPM;
    case 'adhoc':
    case 'runtime':
      return JobModuleUseMode.adHoc;
  }
  return JobModuleUseMode.scheduledPM;
}

String _normaliseKey(String? value) =>
    (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
