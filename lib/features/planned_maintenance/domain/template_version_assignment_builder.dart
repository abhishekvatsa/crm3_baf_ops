// FILE: lib/features/planned_maintenance/domain/template_version_assignment_builder.dart

import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../auth/data/user_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/job_module_model.dart';
import '../data/job_template_model.dart';
import '../data/template_governance_model.dart';
import 'template_version_snapshot_contract.dart';

const _assignmentUuid = Uuid();
const _jsonIndent = JsonEncoder.withIndent('  ');

class TemplateVersionAssignmentException implements Exception {
  final String message;

  const TemplateVersionAssignmentException(this.message);

  @override
  String toString() => message;
}

class PublishedTemplateAssignmentResult {
  final JobExecution execution;
  final List<JobModuleInstance> modules;

  const PublishedTemplateAssignmentResult({
    required this.execution,
    required this.modules,
  });
}

class TemplateVersionAssignmentPreview {
  final String templateName;
  final AssetType assetType;
  final List<String> assignedAgencies;
  final List<TemplateVersionModulePreview> modules;

  const TemplateVersionAssignmentPreview({
    required this.templateName,
    required this.assetType,
    required this.assignedAgencies,
    required this.modules,
  });
}

class TemplateVersionModulePreview {
  final String title;
  final String? code;
  final JobModuleDiscipline discipline;
  final int fieldCount;

  const TemplateVersionModulePreview({
    required this.title,
    required this.code,
    required this.discipline,
    required this.fieldCount,
  });
}

TemplateVersionAssignmentPreview previewTemplateVersionAssignment({
  required TemplatePackage package,
  required TemplateVersion version,
}) {
  final snapshotBundle = _snapshotBundleForAssignment(version);
  final jobSnapshot = snapshotBundle.jobSnapshot;
  final moduleSnapshots = snapshotBundle.moduleSnapshots;

  final templateName =
      _stringFrom(jobSnapshot, const [
        'jobName',
        'templateName',
        'title',
        'name',
      ]) ??
      _clean(package.title) ??
      'Published template';
  final assetType =
      _parseAssetType(
        _stringFrom(jobSnapshot, const [
              'applicableAssetType',
              'assetType',
              'asset_type',
            ]) ??
            package.assetType,
      ) ??
      AssetType.base;
  final assignedAgencies = _assignedAgenciesFrom(package, jobSnapshot);

  return TemplateVersionAssignmentPreview(
    templateName: templateName,
    assetType: assetType,
    assignedAgencies: assignedAgencies,
    modules: [
      for (var i = 0; i < moduleSnapshots.length; i++)
        TemplateVersionModulePreview(
          title: TemplateVersionSnapshotBundle.moduleTitle(
            moduleSnapshots[i],
            i,
          ),
          code: TemplateVersionSnapshotBundle.moduleCode(moduleSnapshots[i]),
          discipline: _parseModuleDiscipline(
            _stringFrom(moduleSnapshots[i], const [
              'discipline',
              'defaultDiscipline',
              'assignedDiscipline',
              'ownerDiscipline',
            ]),
          ),
          fieldCount: snapshotBundle.fieldsForModule(moduleSnapshots[i]).length,
        ),
    ],
  );
}

/// Builds a local assignment-shaped preview for tests and migration tools.
///
/// Production governed assignment must use
/// `PublishedTemplateAssignmentServerService`; only the server can re-read the
/// canonical active package/version/audit triad and create the execution plus
/// frozen modules atomically.
@Deprecated(
  'Production governed assignment must use PublishedTemplateAssignmentServerService.',
)
PublishedTemplateAssignmentResult buildAssignmentFromPublishedTemplateVersion({
  required TemplatePackage package,
  required TemplateVersion version,
  required AppUser actor,
  required int assetNumber,
  required AssetType assetType,
  int? chargeNoAtEvent,
  String? remarks,
  DateTime? now,
}) {
  if (!version.isAssignable) {
    throw StateError('Only published template versions can be assigned.');
  }
  final packageId = _clean(package.firestoreId);
  final versionId = _clean(version.firestoreId);
  if (packageId == null || versionId == null) {
    throw StateError(
      'Published package/version must have Firestore IDs before assignment.',
    );
  }

  final effectiveNow = now ?? DateTime.now();
  final preview = previewTemplateVersionAssignment(
    package: package,
    version: version,
  );
  final snapshotBundle = _snapshotBundleForAssignment(version);
  final jobSnapshot = snapshotBundle.jobSnapshot;
  final moduleSnapshots = snapshotBundle.moduleSnapshots;
  final templateContentHash =
      version.contentHash ?? version.computeContentHash();
  final executionFirestoreId = _assignmentUuid.v4();
  final templateName = preview.templateName;
  final assignedAgencies = preview.assignedAgencies;

  final execution =
      JobExecution()
        ..firestoreId = executionFirestoreId
        // Compatibility bridge: legacy runtime/dossier code expects a template ref.
        // For governed assignments, use the immutable TemplateVersion ID as the
        // source pointer and keep first-class governance fields below.
        ..templateFirestoreId = versionId
        ..templateName = templateName
        ..templatePackageId = packageId
        ..templateVersionId = versionId
        ..templateVersionNumber = version.versionNumber
        ..templateVersionLabel = _clean(version.versionLabel)
        ..templateContentHash = templateContentHash
        ..templatePackageCode = _clean(package.packageCode)
        ..assetType = assetType
        ..assetNumber = assetNumber
        ..isCompleted = false
        ..assignedByUid = actor.uid
        ..assignedByName = actor.name
        ..assignedAgencies = assignedAgencies
        ..chargeNoAtEvent = chargeNoAtEvent
        ..remarks = _clean(remarks)
        ..teamsInvolved = <String>[]
        ..responsesJson = '[]'
        ..actionsJson = '[]'
        ..version = 1
        ..metadataJson = _encodeObject({
          'source': 'published_template_version_assignment',
          'packageFirestoreId': packageId,
          'packageCode': package.packageCode,
          'packageTitle': package.title,
          'versionFirestoreId': versionId,
          'versionNumber': version.versionNumber,
          'versionLabel': version.versionLabel,
          'contentHash': templateContentHash,
          'jobTemplateSnapshot': jobSnapshot,
        })
        ..isDeleted = false
        ..createdAt = effectiveNow
        ..updatedAt = effectiveNow
        ..isSynced = false;

  final modules = <JobModuleInstance>[];
  for (var index = 0; index < moduleSnapshots.length; index++) {
    final snapshot = moduleSnapshots[index];
    final code = TemplateVersionSnapshotBundle.moduleCode(snapshot);
    final fields = snapshotBundle.fieldsForModule(snapshot);
    final module =
        JobModuleInstance()
          ..firestoreId = _assignmentUuid.v4()
          ..jobExecutionFirestoreId = executionFirestoreId
          ..templateFirestoreId = versionId
          ..templateName = templateName
          ..templatePackageId = packageId
          ..templateVersionId = versionId
          ..templateModuleId = _stringFrom(snapshot, const [
            'templateModuleId',
            'moduleId',
            'id',
            'key',
          ])
          ..moduleCode = code
          ..moduleSnapshotJson = _encodeObject(snapshot)
          ..fieldDefinitionsJson = _encodeList(fields)
          ..assetType = assetType
          ..assetNumber = assetNumber
          ..chargeNoAtEvent = chargeNoAtEvent
          ..pairedEquipmentJson = _jsonStringOrNull(
            snapshot['pairedEquipmentJson'],
          )
          ..moduleTitle = TemplateVersionSnapshotBundle.moduleTitle(
            snapshot,
            index,
          )
          ..moduleDescription = _stringFrom(snapshot, const [
            'moduleDescription',
            'description',
            'closedDossierOutput',
          ])
          ..status = JobModuleStatus.notStarted
          ..useMode = _parseUseMode(
            _stringFrom(snapshot, const ['useMode', 'defaultUseMode']),
          )
          ..discipline = _parseModuleDiscipline(
            _stringFrom(snapshot, const [
              'discipline',
              'defaultDiscipline',
              'assignedDiscipline',
              'ownerDiscipline',
            ]),
          )
          ..safetyClass = _parseSafetyClass(
            _stringFrom(snapshot, const ['safetyClass', 'defaultSafetyClass']),
          )
          ..isRequired = _boolFrom(snapshot, const [
            'isRequired',
            'required',
          ], fallback: true)
          ..requiredForClosure = _boolFrom(snapshot, const [
            'requiredForClosure',
            'requiredForCloseout',
            'required',
          ], fallback: true)
          ..addedDuringExecution = false
          ..displayOrder = _intFrom(snapshot, const [
            'displayOrder',
            'order',
            'sequence',
          ], fallback: index)
          ..functionalSection = _stringFrom(snapshot, const [
            'functionalSection',
            'section',
          ])
          ..componentGroup = _stringFrom(snapshot, const [
            'componentGroup',
            'component',
          ])
          ..subsystem = _stringFrom(snapshot, const [
            'subsystem',
            'catalogueArea',
            'area',
          ])
          ..targetRef = _stringFrom(snapshot, const ['targetRef'])
          ..targetRefs = _stringListFrom(snapshot, const [
            'targetRefs',
            'targets',
          ])
          ..procedureRefs = _stringListFrom(snapshot, const [
            'procedureRefs',
            'procedures',
          ])
          ..safetyConfirmations = _stringListFrom(snapshot, const [
            'safetyConfirmations',
          ])
          ..tags = _moduleTags(package, version, snapshot, code)
          ..operationalStatePreconditions = _stringListFrom(snapshot, const [
            'operationalStatePreconditions',
            'preconditions',
          ])
          ..responsesJson = '[]'
          ..actionsJson = '[]'
          ..requiresFollowUp = false
          ..addedByUid = actor.uid
          ..addedByName = actor.name
          ..addedAt = effectiveNow
          ..addReason =
              'Assigned from published TemplateVersion v${version.versionNumber}'
          ..createdByUid = actor.uid
          ..createdByName = actor.name
          ..createdAt = effectiveNow
          ..updatedByUid = actor.uid
          ..updatedByName = actor.name
          ..updatedAt = effectiveNow
          ..isDeleted = false
          ..version = 1
          ..metadataJson = _encodeObject({
            'source': 'published_template_version_assignment',
            'packageFirestoreId': packageId,
            'versionFirestoreId': versionId,
            'versionNumber': version.versionNumber,
            'contentHash': templateContentHash,
            'moduleIndex': index,
          })
          ..isSynced = false;
    modules.add(module);
  }

  if (modules.isEmpty) {
    throw StateError(
      'Published template version has no module snapshots to assign.',
    );
  }

  return PublishedTemplateAssignmentResult(
    execution: execution,
    modules: modules,
  );
}

TemplateVersionSnapshotBundle _snapshotBundleForAssignment(
  TemplateVersion version,
) {
  try {
    return TemplateVersionSnapshotBundle.fromRawJson(
      jobTemplateSnapshotJson: version.jobTemplateSnapshotJson,
      moduleSnapshotsJson: version.moduleSnapshotsJson,
      fieldDefinitionsJson: version.fieldDefinitionsJson,
      checklistJson: version.checklistJson,
    ).requireValidForAssignment();
  } on TemplateVersionSnapshotException catch (error) {
    throw TemplateVersionAssignmentException(error.message);
  }
}

String _encodeObject(Map<String, dynamic> value) => _jsonIndent.convert(value);

String _encodeList(List<Map<String, dynamic>> value) =>
    _jsonIndent.convert(value);

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
        .toList();
  }
  if (value is String && value.trim().isNotEmpty) {
    return value
        .split(RegExp(r'[,;/|]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return <String>[];
}

String? _jsonStringOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) return value.trim();
  if (value is Map) return _encodeObject(Map<String, dynamic>.from(value));
  if (value is List) {
    return _jsonIndent.convert(value);
  }
  return null;
}

AssetType? _parseAssetType(String? value) {
  final normalized = _normaliseKey(value);
  if (normalized.isEmpty) {
    return null;
  }
  for (final type in AssetType.values) {
    if (_normaliseKey(type.name) == normalized) {
      return type;
    }
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
    case 'shiftincharge':
    case 'shift':
      return JobModuleDiscipline.shiftInCharge;
    case 'safety':
      return JobModuleDiscipline.safety;
    case 'admin':
      return JobModuleDiscipline.admin;
    case 'refractory':
    case 'others':
    case 'other':
      return JobModuleDiscipline.others;
    case 'shared':
    case 'multi':
    case 'multidiscipline':
    default:
      return JobModuleDiscipline.shared;
  }
}

JobModuleUseMode _parseUseMode(String? value) {
  final normalized = _normaliseKey(value);
  for (final mode in JobModuleUseMode.values) {
    if (_normaliseKey(mode.name) == normalized) return mode;
  }
  return JobModuleUseMode.scheduledPM;
}

JobModuleSafetyClass _parseSafetyClass(String? value) {
  final normalized = _normaliseKey(value);
  for (final safetyClass in JobModuleSafetyClass.values) {
    if (_normaliseKey(safetyClass.name) == normalized) return safetyClass;
  }
  return JobModuleSafetyClass.normal;
}

String _normaliseKey(String? value) {
  return value
          ?.trim()
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '') ??
      '';
}

List<String> _assignedAgenciesFrom(
  TemplatePackage package,
  Map<String, dynamic> jobSnapshot,
) {
  final fromSnapshot = _stringListFrom(jobSnapshot, const [
    'assignedAgencies',
    'agencies',
    'disciplines',
    'disciplineScope',
  ]);
  final fromPackage = _stringList(package.disciplineScope);
  final combined = <String>{
    ...fromSnapshot.map(_normaliseAgency),
    ...fromPackage.map(_normaliseAgency),
  }..removeWhere((item) => item.isEmpty);
  return combined.isEmpty
      ? <String>['mechanical']
      : (combined.toList()..sort());
}

String _normaliseAgency(String value) {
  final normalized = _normaliseKey(value);
  switch (normalized) {
    case 'mechanical':
      return 'mechanical';
    case 'electrical':
      return 'electrical';
    case 'instrumentation':
    case 'instrument':
    case 'ia':
    case 'ianda':
      return 'instrumentation';
    case 'operations':
      return 'operations';
    case 'refractory':
    case 'others':
      return 'refractory';
    case 'shared':
      return 'shared';
    case 'safety':
      return 'safety';
    default:
      return normalized;
  }
}

List<String> _moduleTags(
  TemplatePackage package,
  TemplateVersion version,
  Map<String, dynamic> snapshot,
  String? code,
) {
  final tags = <String>{
    if (_clean(package.packageCode) != null) package.packageCode.trim(),
    if (code != null && code.trim().isNotEmpty) code.trim(),
    ..._stringListFrom(snapshot, const ['tags']),
    ..._stringListFrom(snapshot, const ['procedureRefs', 'procedures']),
    'templateVersion:v${version.versionNumber}',
  };
  tags.removeWhere((item) => item.trim().isEmpty);
  return tags.toList()..sort();
}
