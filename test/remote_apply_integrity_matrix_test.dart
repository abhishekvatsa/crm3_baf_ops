import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/remote_tombstone_apply_result.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_module_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

typedef _IntegrityCase = Future<void> Function(Isar isar);

void main() {
  setUpAll(initializeTestIsarCore);

  final cases = <String, _IntegrityCase>{
    'directive': _verifyDirective,
    'abnormality type': _verifyAbnormalityType,
    'charge abnormality': _verifyChargeAbnormality,
    'job template': _verifyJobTemplate,
    'job execution': _verifyJobExecution,
    'job diary': _verifyJobDiary,
    'job module': _verifyJobModule,
    'template package': _verifyTemplatePackage,
    'template version': _verifyTemplateVersion,
    'template publish audit': _verifyTemplateAudit,
  };

  for (final entry in cases.entries) {
    test('${entry.key} remote apply preserves dirty local evidence', () async {
      await _withIsar(entry.value);
    });
  }

  final cleanClockGuardCases = <String, _IntegrityCase>{
    'directive': _verifyDirectiveCleanClockGuard,
    'abnormality type': _verifyAbnormalityTypeCleanClockGuard,
    'charge abnormality': _verifyChargeAbnormalityCleanClockGuard,
    'job template': _verifyJobTemplateCleanClockGuard,
    'job execution': _verifyJobExecutionCleanClockGuard,
    'job diary': _verifyJobDiaryCleanClockGuard,
    'job module': _verifyJobModuleCleanClockGuard,
    'template package': _verifyTemplatePackageCleanClockGuard,
    'template version': _verifyTemplateVersionCleanClockGuard,
    'template publish audit': _verifyTemplateAuditCleanClockGuard,
  };

  for (final entry in cleanClockGuardCases.entries) {
    test(
      '${entry.key} remote apply preserves later clean evidence and requires reconciliation',
      () async => _withIsar(entry.value),
    );
  }
}

final _localTime = DateTime.utc(2026, 9, 6, 8);
final _remoteTime = DateTime.utc(2026, 9, 6, 9);

Future<void> _verifyDirective(Isar isar) async {
  final local = _directive('Local directive evidence', synced: false);
  await isar.writeTxn(() => isar.operationalDirectives.put(local));

  final result = await IsarDirectiveRepository().applyDirectiveFromRemote(
    _directive('Remote directive evidence', version: 7, time: _remoteTime),
  );
  final stored = await isar.operationalDirectives.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.description, 'Local directive evidence');
}

Future<void> _verifyAbnormalityType(Isar isar) async {
  final local = _abnormalityType('Local type evidence', synced: false);
  await isar.writeTxn(() => isar.abnormalityTypes.put(local));

  final result = await IsarAbnormalityRepository().applyTypeFromRemote(
    _abnormalityType('Remote type evidence', version: 7, time: _remoteTime),
  );
  final stored = await isar.abnormalityTypes.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.description, 'Local type evidence');
}

Future<void> _verifyChargeAbnormality(Isar isar) async {
  final local = _chargeAbnormality('Local abnormality evidence', synced: false);
  await isar.writeTxn(() => isar.collection<ChargeAbnormality>().put(local));

  final result = await IsarAbnormalityRepository().applyAbnormalityFromRemote(
    _chargeAbnormality(
      'Remote abnormality evidence',
      version: 7,
      time: _remoteTime,
    ),
  );
  final stored = await isar.collection<ChargeAbnormality>().get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.description, 'Local abnormality evidence');
}

Future<void> _verifyJobTemplate(Isar isar) async {
  final local = _jobTemplate('Local template evidence', synced: false);
  await isar.writeTxn(() => isar.jobTemplates.put(local));

  final result = await IsarPlannedRepository().applyTemplateFromRemote(
    _jobTemplate('Remote template evidence', version: 7, time: _remoteTime),
  );
  final stored = await isar.jobTemplates.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.description, 'Local template evidence');
}

Future<void> _verifyJobExecution(Isar isar) async {
  final local = _jobExecution('Local execution evidence', synced: false);
  await isar.writeTxn(() => isar.jobExecutions.put(local));

  final result = await IsarPlannedRepository().applyExecutionFromRemote(
    _jobExecution('Remote execution evidence', version: 7, time: _remoteTime),
  );
  final stored = await isar.jobExecutions.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.remarks, 'Local execution evidence');
}

Future<void> _verifyJobDiary(Isar isar) async {
  final local = _jobDiary('Local diary evidence', synced: false);
  await isar.writeTxn(() => isar.jobDiaryEntrys.put(local));

  final result = await IsarJobDiaryRepository().applyEntryFromRemote(
    _jobDiary('Remote diary evidence', version: 7, time: _remoteTime),
  );
  final stored = await isar.jobDiaryEntrys.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.note, 'Local diary evidence');
}

Future<void> _verifyJobModule(Isar isar) async {
  final local = _jobModule('Local module evidence', synced: false);
  await isar.writeTxn(() => isar.jobModuleInstances.put(local));

  final result = await IsarJobModuleRepository().applyModuleFromRemote(
    _jobModule('Remote module evidence', version: 7, time: _remoteTime),
  );
  final stored = await isar.jobModuleInstances.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.submissionNote, 'Local module evidence');
}

Future<void> _verifyTemplatePackage(Isar isar) async {
  final local = _templatePackage('Local package evidence', synced: false);
  await isar.writeTxn(() => isar.templatePackages.put(local));

  final result = await IsarTemplateGovernanceRepository()
      .applyPackageFromRemote(
        _templatePackage(
          'Remote package evidence',
          version: 7,
          time: _remoteTime,
        ),
      );
  final stored = await isar.templatePackages.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.description, 'Local package evidence');
}

Future<void> _verifyTemplateVersion(Isar isar) async {
  final local = _templateVersion('Local version evidence', synced: false);
  await isar.writeTxn(() => isar.templateVersions.put(local));

  final result = await IsarTemplateGovernanceRepository()
      .applyVersionFromRemote(
        _templateVersion(
          'Remote version evidence',
          version: 7,
          time: _remoteTime,
        ),
      );
  final stored = await isar.templateVersions.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.releaseNotes, 'Local version evidence');
}

Future<void> _verifyTemplateAudit(Isar isar) async {
  final local = _templateAudit('Local audit evidence', synced: false);
  await isar.writeTxn(() => isar.templatePublishAudits.put(local));

  final result = await IsarTemplateGovernanceRepository().applyAuditFromRemote(
    _templateAudit('Remote audit evidence', version: 7, time: _remoteTime),
  );
  final stored = await isar.templatePublishAudits.get(local.id);

  _expectDirtyPreserved(result);
  expect(stored!.reason, 'Local audit evidence');
}

Future<void> _verifyDirectiveCleanClockGuard(Isar isar) async {
  final local = _directive('Later local directive', time: _remoteTime);
  await isar.writeTxn(() => isar.operationalDirectives.put(local));

  final result = await IsarDirectiveRepository().applyDirectiveFromRemote(
    _directive('Older remote directive', version: 7, time: _localTime),
  );
  final stored = await isar.operationalDirectives.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.description, 'Later local directive');
}

Future<void> _verifyAbnormalityTypeCleanClockGuard(Isar isar) async {
  final local = _abnormalityType('Later local type', time: _remoteTime);
  await isar.writeTxn(() => isar.abnormalityTypes.put(local));

  final result = await IsarAbnormalityRepository().applyTypeFromRemote(
    _abnormalityType('Older remote type', version: 7, time: _localTime),
  );
  final stored = await isar.abnormalityTypes.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.description, 'Later local type');
}

Future<void> _verifyChargeAbnormalityCleanClockGuard(Isar isar) async {
  final local = _chargeAbnormality(
    'Later local abnormality',
    time: _remoteTime,
  );
  await isar.writeTxn(() => isar.collection<ChargeAbnormality>().put(local));

  final result = await IsarAbnormalityRepository().applyAbnormalityFromRemote(
    _chargeAbnormality(
      'Older remote abnormality',
      version: 7,
      time: _localTime,
    ),
  );
  final stored = await isar.collection<ChargeAbnormality>().get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.description, 'Later local abnormality');
}

Future<void> _verifyJobTemplateCleanClockGuard(Isar isar) async {
  final local = _jobTemplate('Later local template', time: _remoteTime);
  await isar.writeTxn(() => isar.jobTemplates.put(local));

  final result = await IsarPlannedRepository().applyTemplateFromRemote(
    _jobTemplate('Older remote template', version: 7, time: _localTime),
  );
  final stored = await isar.jobTemplates.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.description, 'Later local template');
}

Future<void> _verifyJobExecutionCleanClockGuard(Isar isar) async {
  final local = _jobExecution('Later local execution', time: _remoteTime);
  await isar.writeTxn(() => isar.jobExecutions.put(local));

  final result = await IsarPlannedRepository().applyExecutionFromRemote(
    _jobExecution('Older remote execution', version: 7, time: _localTime),
  );
  final stored = await isar.jobExecutions.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.remarks, 'Later local execution');
}

Future<void> _verifyJobDiaryCleanClockGuard(Isar isar) async {
  final local = _jobDiary('Later local diary', time: _remoteTime);
  await isar.writeTxn(() => isar.jobDiaryEntrys.put(local));

  final result = await IsarJobDiaryRepository().applyEntryFromRemote(
    _jobDiary('Older remote diary', version: 7, time: _localTime),
  );
  final stored = await isar.jobDiaryEntrys.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.note, 'Later local diary');
}

Future<void> _verifyJobModuleCleanClockGuard(Isar isar) async {
  final local = _jobModule('Later local module', time: _remoteTime);
  await isar.writeTxn(() => isar.jobModuleInstances.put(local));

  final result = await IsarJobModuleRepository().applyModuleFromRemote(
    _jobModule('Older remote module', version: 7, time: _localTime),
  );
  final stored = await isar.jobModuleInstances.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.submissionNote, 'Later local module');
}

Future<void> _verifyTemplatePackageCleanClockGuard(Isar isar) async {
  final local = _templatePackage('Later local package', time: _remoteTime);
  await isar.writeTxn(() => isar.templatePackages.put(local));

  final result = await IsarTemplateGovernanceRepository()
      .applyPackageFromRemote(
        _templatePackage('Older remote package', version: 7, time: _localTime),
      );
  final stored = await isar.templatePackages.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.description, 'Later local package');
}

Future<void> _verifyTemplateVersionCleanClockGuard(Isar isar) async {
  final local = _templateVersion('Later local version', time: _remoteTime);
  await isar.writeTxn(() => isar.templateVersions.put(local));

  final result = await IsarTemplateGovernanceRepository()
      .applyVersionFromRemote(
        _templateVersion('Older remote version', version: 7, time: _localTime),
      );
  final stored = await isar.templateVersions.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.releaseNotes, 'Later local version');
}

Future<void> _verifyTemplateAuditCleanClockGuard(Isar isar) async {
  final local = _templateAudit('Later local audit', time: _remoteTime);
  await isar.writeTxn(() => isar.templatePublishAudits.put(local));

  final result = await IsarTemplateGovernanceRepository().applyAuditFromRemote(
    _templateAudit('Older remote audit', version: 7, time: _localTime),
  );
  final stored = await isar.templatePublishAudits.get(local.id);

  _expectCleanClockGuard(result);
  expect(stored!.reason, 'Later local audit');
}

void _expectDirtyPreserved(RemoteRecordApplyResult<Object> result) {
  expect(result.outcome, RemoteRecordApplyOutcome.localDirtyPreserved);
  expect(result.remoteIsNewer, isTrue);
}

void _expectCleanClockGuard(RemoteRecordApplyResult<Object> result) {
  expect(result.outcome.name, 'cleanLocalReconciliationRequired');
  expect(result.remoteIsNewer, isTrue);
  expect(result.applied, isFalse);
  expect(result.localRecord, isNotNull);
}

OperationalDirective _directive(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return OperationalDirective()
    ..firestoreId = 'matrix-directive'
    ..title = 'Integrity directive'
    ..description = evidence
    ..directedTo = AppRole.operations
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

AbnormalityType _abnormalityType(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return AbnormalityType()
    ..firestoreId = 'matrix-abnormality-type'
    ..code = 'MATRIX_TYPE'
    ..title = 'Integrity abnormality type'
    ..description = evidence
    ..category = AbnormalityCategory.process
    ..severity = AbnormalitySeverity.medium
    ..applicableAssetTypes = <AssetType>[AssetType.furnace]
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

ChargeAbnormality _chargeAbnormality(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return ChargeAbnormality()
    ..firestoreId = 'matrix-charge-abnormality'
    ..sourceChargeNo = 51139
    ..abnormalityTypeId = 'matrix-abnormality-type'
    ..abnormalityTypeTitle = 'Integrity abnormality type'
    ..abnormalityTypeCode = 'MATRIX_TYPE'
    ..category = AbnormalityCategory.process
    ..severity = AbnormalitySeverity.medium
    ..affectedAssets = const <AffectedAssetRef>[
      AffectedAssetRef(assetType: AssetType.furnace, assetNumber: 7),
    ]
    ..observedReason = 'Integrity observation'
    ..description = evidence
    ..loggedAt = _localTime
    ..updatedAt = timestamp
    ..loggedByUid = 'operator-1'
    ..loggedByName = 'Operator One'
    ..version = version
    ..isSynced = synced;
}

JobTemplate _jobTemplate(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return JobTemplate()
    ..firestoreId = 'matrix-job-template'
    ..jobName = 'Integrity job template'
    ..description = evidence
    ..applicableAssetType = AssetType.furnace
    ..assignedAgencies = <String>[RoutedTo.mechanical.name]
    ..fieldsJson = '[]'
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

JobExecution _jobExecution(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return JobExecution()
    ..firestoreId = 'matrix-job-execution'
    ..templateFirestoreId = 'matrix-job-template'
    ..templateName = 'Integrity job template'
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..assignedAgencies = <String>[RoutedTo.mechanical.name]
    ..remarks = evidence
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

JobDiaryEntry _jobDiary(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return JobDiaryEntry()
    ..firestoreId = 'matrix-job-diary'
    ..jobExecutionFirestoreId = 'matrix-job-execution'
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..kind = JobDiaryKind.note
    ..discipline = JobDiaryDiscipline.mechanical
    ..note = evidence
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

JobModuleInstance _jobModule(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return JobModuleInstance()
    ..firestoreId = 'matrix-job-module'
    ..jobExecutionFirestoreId = 'matrix-job-execution'
    ..templateFirestoreId = 'matrix-job-template'
    ..moduleCode = 'MATRIX-01'
    ..moduleTitle = 'Integrity job module'
    ..moduleSnapshotJson = '{}'
    ..fieldDefinitionsJson = '[]'
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..discipline = JobModuleDiscipline.mechanical
    ..submissionNote = evidence
    ..responsesJson = '[]'
    ..actionsJson = '[]'
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

TemplatePackage _templatePackage(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return TemplatePackage()
    ..firestoreId = 'matrix-template-package'
    ..packageCode = 'MATRIX-PACKAGE'
    ..title = 'Integrity template package'
    ..description = evidence
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

TemplateVersion _templateVersion(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return TemplateVersion()
    ..firestoreId = 'matrix-template-version'
    ..packageFirestoreId = 'matrix-template-package'
    ..versionNumber = 1
    ..versionLabel = 'v1'
    ..releaseNotes = evidence
    ..jobTemplateSnapshotJson = '{}'
    ..moduleSnapshotsJson = '[]'
    ..fieldDefinitionsJson = '[]'
    ..checklistJson = '[]'
    ..createdAt = _localTime
    ..updatedAt = timestamp
    ..version = version
    ..isSynced = synced;
}

TemplatePublishAudit _templateAudit(
  String evidence, {
  int version = 2,
  DateTime? time,
  bool synced = true,
}) {
  final timestamp = time ?? _localTime;
  return TemplatePublishAudit()
    ..firestoreId = 'matrix-template-audit'
    ..packageFirestoreId = 'matrix-template-package'
    ..versionFirestoreId = 'matrix-template-version'
    ..action = TemplatePublishAuditAction.edited
    ..performedAt = _localTime
    ..updatedAt = timestamp
    ..reason = evidence
    ..version = version
    ..isSynced = synced;
}

Future<void> _withIsar(_IntegrityCase body) async {
  final directory = await Directory.systemTemp.createTemp(
    'remote_apply_integrity_matrix_',
  );
  final isar = await Isar.open(<CollectionSchema<dynamic>>[
    OperationalDirectiveSchema,
    AbnormalityTypeSchema,
    ChargeAbnormalitySchema,
    JobTemplateSchema,
    JobExecutionSchema,
    JobDiaryEntrySchema,
    JobModuleInstanceSchema,
    TemplatePackageSchema,
    TemplateVersionSchema,
    TemplatePublishAuditSchema,
  ], directory: directory.path);
  app.isar = isar;
  try {
    await body(isar);
  } finally {
    await isar.close(deleteFromDisk: true);
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
