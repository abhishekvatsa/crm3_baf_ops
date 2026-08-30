import 'dart:convert';
import 'dart:io';

// ignore_for_file: file_names, invalid_use_of_protected_member

import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';
import 'package:crm3_baf_ops/core/services/operational_assurance_local_repair.dart';
import 'package:crm3_baf_ops/core/services/planned_job_local_link_repair.dart';
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/charges/data/charge_model.dart';
import 'package:crm3_baf_ops/features/directives/data/operational_directive_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_attempt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_prompt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/job_lane_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_aggregate_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_receipt_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_event_record.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import '../tool/test_support/test_isar_core.dart';

const _fixtureName = 'crm3_70k_populated_fixture';
const _v2FixtureName = 'crm3_70k_governed_v2_fixture';
const _v3FixtureName = 'crm3_70k_operational_assurance_v3_fixture';
const _v6FixtureName = 'crm3_70k_maintenance_reopen_v6_fixture';
const _generationId = '123e4567-e89b-42d3-a456-426614174000';
const _rotatedGenerationId = '223e4567-e89b-42d3-a456-426614174000';
const _governedV2FixtureFingerprint =
    '70k-governed-test-v2:v1-base-plus-workflow-control-plane';

final List<CollectionSchema<dynamic>> _currentSchemas =
    <CollectionSchema<dynamic>>[
      ChargeSchema,
      MaintenanceRecordSchema,
      JobTemplateSchema,
      JobExecutionSchema,
      JobDiaryEntrySchema,
      JobModuleInstanceSchema,
      TemplatePackageSchema,
      TemplateVersionSchema,
      TemplatePublishAuditSchema,
      BafKnowledgeRowSchema,
      BafKnowledgeMatrixMetaStoreSchema,
      OperationalDirectiveSchema,
      AuditEventSchema,
      SyncRejectionSchema,
      AbnormalityTypeSchema,
      ChargeAbnormalitySchema,
      WorkflowAggregateRecordSchema,
      JobLaneRecordSchema,
      ComplianceRequestRecordSchema,
      ComplianceAttemptRecordSchema,
      EquipmentStatusRecordSchema,
      EquipmentPromptRecordSchema,
      WorkflowEventRecordSchema,
      WorkflowCommandRecordSchema,
      WorkflowCommandReceiptRecordSchema,
    ];

Map<String, dynamic> _object(Object? value) {
  return Map<String, dynamic>.from(value! as Map);
}

class _FileIsarSchemaProvenanceStore implements IsarSchemaProvenanceStore {
  final File file;

  _FileIsarSchemaProvenanceStore(this.file);

  Future<Map<String, Object?>> _read() async {
    if (!await file.exists()) return <String, Object?>{};
    return Map<String, Object?>.from(
      jsonDecode(await file.readAsString()) as Map,
    );
  }

  Future<bool> _write(Map<String, Object?> value) async {
    final encoded = jsonEncode(value);
    await file.writeAsString(encoded, flush: true);
    return await file.readAsString() == encoded;
  }

  Future<void> initializeLegacyV1() async {
    await _write(<String, Object?>{
      'canonical': null,
      'legacyVersion': 1,
      'legacyFingerprint': IsarSchemaMigrator.v1SchemaFingerprint,
    });
  }

  @override
  Future<String?> readCanonicalMarkerJson() async {
    return (await _read())['canonical'] as String?;
  }

  @override
  Future<bool> writeCanonicalMarkerJson(String encoded) async {
    final value = await _read();
    value['canonical'] = encoded;
    return _write(value);
  }

  @override
  Future<int?> readLegacySchemaVersion() async {
    return (await _read())['legacyVersion'] as int?;
  }

  @override
  Future<String?> readLegacySchemaFingerprint() async {
    return (await _read())['legacyFingerprint'] as String?;
  }

  @override
  Future<bool> clearLegacySchemaMarker() async {
    final value = await _read();
    value['legacyVersion'] = null;
    value['legacyFingerprint'] = null;
    return _write(value);
  }
}

Future<Map<String, String>> _copyDataFiles(
  Directory source,
  Directory destination,
) async {
  await destination.create(recursive: true);
  final hashes = <String, String>{};
  await for (final entity in source.list(followLinks: false)) {
    if (entity is! File) continue;
    final fileName = entity.uri.pathSegments.last;
    if (!fileName.endsWith('.isar') && fileName != '70k_marker_state.json') {
      continue;
    }
    final bytes = await entity.readAsBytes();
    await File(
      '${destination.path}/$fileName',
    ).writeAsBytes(bytes, flush: true);
    hashes[fileName] = sha256.convert(bytes).toString().toUpperCase();
  }
  return hashes;
}

CollectionSchema<OBJ> _v1SchemaFromGovernedBaseline<OBJ>(
  CollectionSchema<OBJ> current,
  Map<String, dynamic> baseline,
) {
  expect(current.id, baseline['collectionId']);

  final baselineProperties = _object(baseline['properties']);
  final properties = <String, PropertySchema>{};
  for (final entry in baselineProperties.entries) {
    final expected = _object(entry.value);
    final property = current.properties[entry.key];
    expect(property, isNotNull, reason: '${current.name}.${entry.key} missing');
    expect(
      property!.type.name,
      expected['type'],
      reason: '${current.name}.${entry.key} type changed',
    );
    properties[entry.key] = PropertySchema(
      id: expected['id'] as int,
      name: entry.key,
      type: property.type,
      enumMap: property.enumMap,
      target: property.target,
    );
  }

  final baselineIndexes = _object(baseline['indexes']);
  final indexes = <String, IndexSchema>{};
  for (final entry in baselineIndexes.entries) {
    final expected = _object(entry.value);
    final index = current.indexes[entry.key];
    expect(index, isNotNull, reason: '${current.name}.${entry.key} missing');

    final expectedProperties =
        (expected['properties'] as List<dynamic>).map(_object).toList();
    expect(index!.properties, hasLength(expectedProperties.length));
    final baselineIndexProperties = <IndexPropertySchema>[];
    for (var position = 0; position < expectedProperties.length; position++) {
      final actualProperty = index.properties[position];
      final expectedProperty = expectedProperties[position];
      expect(actualProperty.name, expectedProperty['name']);
      expect(actualProperty.type.name, expectedProperty['type']);
      expect(actualProperty.caseSensitive, expectedProperty['caseSensitive']);
      baselineIndexProperties.add(
        IndexPropertySchema(
          name: expectedProperty['name'] as String,
          type: IndexType.values.byName(expectedProperty['type'] as String),
          caseSensitive: expectedProperty['caseSensitive'] as bool,
        ),
      );
    }
    indexes[entry.key] = IndexSchema(
      id: expected['id'] as int,
      name: entry.key,
      unique: expected['unique'] as bool,
      replace: expected['replace'] as bool,
      properties: baselineIndexProperties,
    );
  }

  return CollectionSchema<OBJ>(
    id: current.id,
    name: current.name,
    properties: properties,
    estimateSize: current.estimateSize,
    serialize: current.serialize,
    deserialize: current.deserialize,
    deserializeProp: current.deserializeProp,
    idName: current.idName,
    indexes: indexes,
    links: current.links,
    embeddedSchemas: current.embeddedSchemas,
    getId: current.getId,
    getLinks: current.getLinks,
    attach: current.attach,
    version: current.version,
  );
}

List<CollectionSchema<dynamic>> _loadRepositoryProvenV1Schemas() {
  final baseline =
      jsonDecode(
            File(
              'docs/v4_2_r1/CANONICAL_ISAR_SCHEMA_BASELINE.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  expect(baseline['schemaVersion'], 1);
  expect(
    baseline['canonicalMainCommit'],
    '633c58bb0d936011e391b42627f8b8f02c510e95',
  );

  final collections = _object(baseline['collections']);
  Map<String, dynamic> collection(String name) {
    expect(collections[name], isNotNull, reason: 'Missing baseline $name');
    return _object(collections[name]);
  }

  return <CollectionSchema<dynamic>>[
    _v1SchemaFromGovernedBaseline<OperationalDirective>(
      OperationalDirectiveSchema,
      collection('OperationalDirective'),
    ),
    _v1SchemaFromGovernedBaseline<JobTemplate>(
      JobTemplateSchema,
      collection('JobTemplate'),
    ),
    _v1SchemaFromGovernedBaseline<JobExecution>(
      JobExecutionSchema,
      collection('JobExecution'),
    ),
    _v1SchemaFromGovernedBaseline<TemplatePackage>(
      TemplatePackageSchema,
      collection('TemplatePackage'),
    ),
    _v1SchemaFromGovernedBaseline<TemplateVersion>(
      TemplateVersionSchema,
      collection('TemplateVersion'),
    ),
    _v1SchemaFromGovernedBaseline<TemplatePublishAudit>(
      TemplatePublishAuditSchema,
      collection('TemplatePublishAudit'),
    ),
    _v1SchemaFromGovernedBaseline<BafKnowledgeRow>(
      BafKnowledgeRowSchema,
      collection('BafKnowledgeRow'),
    ),
    _v1SchemaFromGovernedBaseline<BafKnowledgeMatrixMetaStore>(
      BafKnowledgeMatrixMetaStoreSchema,
      collection('BafKnowledgeMatrixMetaStore'),
    ),
    _v1SchemaFromGovernedBaseline<JobDiaryEntry>(
      JobDiaryEntrySchema,
      collection('JobDiaryEntry'),
    ),
    _v1SchemaFromGovernedBaseline<JobModuleInstance>(
      JobModuleInstanceSchema,
      collection('JobModuleInstance'),
    ),
    _v1SchemaFromGovernedBaseline<MaintenanceRecord>(
      MaintenanceRecordSchema,
      collection('MaintenanceRecord'),
    ),
    _v1SchemaFromGovernedBaseline<AbnormalityType>(
      AbnormalityTypeSchema,
      collection('AbnormalityType'),
    ),
    _v1SchemaFromGovernedBaseline<ChargeAbnormality>(
      ChargeAbnormalitySchema,
      collection('ChargeAbnormality'),
    ),
    _v1SchemaFromGovernedBaseline<AuditEvent>(
      AuditEventSchema,
      collection('AuditEvent'),
    ),
    _v1SchemaFromGovernedBaseline<SyncRejection>(
      SyncRejectionSchema,
      collection('SyncRejection'),
    ),
    _v1SchemaFromGovernedBaseline<Charge>(ChargeSchema, collection('Charge')),
  ];
}

List<CollectionSchema<dynamic>> _loadGovernedV2FixtureSchemas() {
  return <CollectionSchema<dynamic>>[
    ..._loadRepositoryProvenV1Schemas(),
    WorkflowAggregateRecordSchema,
    JobLaneRecordSchema,
    ComplianceRequestRecordSchema,
    ComplianceAttemptRecordSchema,
    EquipmentStatusRecordSchema,
    EquipmentPromptRecordSchema,
    WorkflowEventRecordSchema,
    WorkflowCommandRecordSchema,
    WorkflowCommandReceiptRecordSchema,
  ];
}

CollectionSchema<ComplianceRequestRecord> _v3ComplianceRequestSchema() {
  const v4Fields = <String>{
    'coordinationBasis',
    'defermentBasisKey',
    'operationsResourceKey',
    'operationsSupportTypeKey',
    'raisedUnderCoordination',
    'requestPurposeKey',
    'requestedLocation',
  };
  final retained = ComplianceRequestRecordSchema.properties.entries
      .where((entry) => !v4Fields.contains(entry.key))
      .toList(growable: false);
  final properties = <String, PropertySchema>{};
  for (var index = 0; index < retained.length; index++) {
    final entry = retained[index];
    final property = entry.value;
    properties[entry.key] = PropertySchema(
      id: index,
      name: entry.key,
      type: property.type,
      enumMap: property.enumMap,
      target: property.target,
    );
  }
  final indexes = Map<String, IndexSchema>.from(
    ComplianceRequestRecordSchema.indexes,
  )..remove('requestPurposeKey');
  return CollectionSchema<ComplianceRequestRecord>(
    id: ComplianceRequestRecordSchema.id,
    name: ComplianceRequestRecordSchema.name,
    properties: properties,
    estimateSize: ComplianceRequestRecordSchema.estimateSize,
    serialize: ComplianceRequestRecordSchema.serialize,
    deserialize: ComplianceRequestRecordSchema.deserialize,
    deserializeProp: ComplianceRequestRecordSchema.deserializeProp,
    idName: ComplianceRequestRecordSchema.idName,
    indexes: indexes,
    links: ComplianceRequestRecordSchema.links,
    embeddedSchemas: ComplianceRequestRecordSchema.embeddedSchemas,
    getId: ComplianceRequestRecordSchema.getId,
    getLinks: ComplianceRequestRecordSchema.getLinks,
    attach: ComplianceRequestRecordSchema.attach,
    version: ComplianceRequestRecordSchema.version,
  );
}

List<CollectionSchema<dynamic>> _loadRepositoryProvenV3Schemas() =>
    <CollectionSchema<dynamic>>[
      for (final schema in _currentSchemas)
        if (schema.name == ComplianceRequestRecordSchema.name)
          _v3ComplianceRequestSchema()
        else
          schema,
    ];

CollectionSchema<MaintenanceRecord> _v6MaintenanceRecordSchema() {
  const postV6Fields = <String>{
    'plantConditionEffect',
    'reopenReason',
    'reopenedAt',
    'reopenedByName',
    'reopenedByUid',
  };
  final retained = MaintenanceRecordSchema.properties.entries
      .where((entry) => !postV6Fields.contains(entry.key))
      .toList(growable: false);
  final properties = <String, PropertySchema>{};
  for (var index = 0; index < retained.length; index++) {
    final entry = retained[index];
    final property = entry.value;
    properties[entry.key] = PropertySchema(
      id: index,
      name: entry.key,
      type: property.type,
      enumMap: property.enumMap,
      target: property.target,
    );
  }
  return CollectionSchema<MaintenanceRecord>(
    id: MaintenanceRecordSchema.id,
    name: MaintenanceRecordSchema.name,
    properties: properties,
    estimateSize: MaintenanceRecordSchema.estimateSize,
    serialize: MaintenanceRecordSchema.serialize,
    deserialize: MaintenanceRecordSchema.deserialize,
    deserializeProp: MaintenanceRecordSchema.deserializeProp,
    idName: MaintenanceRecordSchema.idName,
    indexes: MaintenanceRecordSchema.indexes,
    links: MaintenanceRecordSchema.links,
    embeddedSchemas: MaintenanceRecordSchema.embeddedSchemas,
    getId: MaintenanceRecordSchema.getId,
    getLinks: MaintenanceRecordSchema.getLinks,
    attach: MaintenanceRecordSchema.attach,
    version: MaintenanceRecordSchema.version,
  );
}

List<CollectionSchema<dynamic>> _loadRepositoryProvenV6Schemas() =>
    <CollectionSchema<dynamic>>[
      for (final schema in _currentSchemas)
        if (schema.name == MaintenanceRecordSchema.name)
          _v6MaintenanceRecordSchema()
        else
          schema,
    ];

Future<void> _populateRepresentativeRows(Isar isar) async {
  final now = DateTime.utc(2026, 8, 11, 12);
  final template =
      JobTemplate()
        ..firestoreId = '70k-template-v1'
        ..jobName = '70K migration fixture'
        ..description = 'Repository-proven v1 populated fixture'
        ..applicableAssetType = AssetType.base
        ..assignedAgencies = <String>['mechanical']
        ..fieldsJson = '[]'
        ..createdAt = now
        ..updatedAt = now
        ..version = 1;
  final execution =
      JobExecution()
        ..firestoreId = '70k-execution-v1'
        ..templateFirestoreId = '70k-template-v1'
        ..templateName = template.jobName
        ..assetType = AssetType.base
        ..assetNumber = 209
        ..assignedAgencies = <String>['mechanical']
        ..responsesJson = '[{"key":"pressure","value":"ok"}]'
        ..actionsJson = '[{"action":"inspect"}]'
        ..createdAt = now
        ..updatedAt = now
        ..version = 1
        ..isSynced = true;

  await isar.writeTxn(() async {
    await isar.jobTemplates.put(template);
    await isar.jobExecutions.put(execution);
  });

  final module =
      JobModuleInstance()
        ..firestoreId = '70k-module-v1'
        ..jobExecutionFirestoreId = execution.firestoreId
        ..jobExecutionLocalId = execution.id
        ..templateFirestoreId = template.firestoreId
        ..moduleTitle = 'Inspect base seal'
        ..moduleSnapshotJson = '{"code":"B-01"}'
        ..fieldDefinitionsJson = '[]'
        ..assetType = AssetType.base
        ..assetNumber = 209
        ..responsesJson = '[{"key":"condition","value":"sound"}]'
        ..actionsJson = '[{"action":"inspect"}]'
        ..createdAt = now
        ..updatedAt = now
        ..version = 1
        ..isSynced = true;

  await isar.writeTxn(() async {
    await isar.jobModuleInstances.put(module);
  });

  final diary =
      JobDiaryEntry()
        ..firestoreId = '70k-diary-v1'
        ..jobExecutionFirestoreId = execution.firestoreId
        ..jobExecutionLocalId = execution.id
        ..moduleInstanceFirestoreId = module.firestoreId
        ..moduleInstanceLocalId = module.id
        ..templateFirestoreId = template.firestoreId
        ..templateName = template.jobName
        ..assetType = AssetType.base
        ..assetNumber = 209
        ..kind = JobDiaryKind.observation
        ..discipline = JobDiaryDiscipline.mechanical
        ..note = 'Seal condition recorded before schema migration.'
        ..createdAt = now
        ..updatedAt = now
        ..version = 1
        ..isSynced = true;

  await isar.writeTxn(() async {
    await isar.jobDiaryEntrys.put(diary);
  });
}

void _expectCurrentA05LocalDisposition({
  required JobTemplate template,
  required JobExecution execution,
  required JobModuleInstance module,
  required JobDiaryEntry diary,
}) {
  expect(template.fieldsReadResult.isValid, isTrue);
  expect(execution.responsesReadResult.isValid, isTrue);
  expect(module.moduleSnapshotReadResult.isValid, isTrue);
  expect(module.fieldDefinitionsReadResult.isValid, isTrue);
  expect(module.responsesReadResult.isValid, isTrue);
  expect(diary.jobExecutionFirestoreId, execution.firestoreId);
  expect(diary.moduleInstanceFirestoreId, module.firestoreId);

  const legacyActions = '[{"action":"inspect"}]';
  expect(execution.actionsJson, legacyActions);
  expect(module.actionsJson, legacyActions);
  for (final result in [
    execution.actionsReadResult,
    module.actionsReadResult,
  ]) {
    expect(result.isValid, isFalse);
    expect(result.entries, isEmpty);
    expect(result.error.toString(), contains('field "asset"'));
  }
  expect(() => execution.actions, throwsA(isA<FormatException>()));
  expect(() => module.actions, throwsA(isA<FormatException>()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestIsarCore();
  });

  test(
    'repository-proven populated v1 migrates to v9 with rows and relationships intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'crm3_70k_populated_v1_',
      );
      Isar? isar;
      try {
        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _fixtureName,
        );
        await _populateRepresentativeRows(isar);
        await isar.close();
        isar = null;

        final repositoryV1Schemas = _loadRepositoryProvenV1Schemas();
        expect(repositoryV1Schemas, hasLength(16));
        isar = await Isar.open(
          repositoryV1Schemas,
          directory: directory.path,
          name: _fixtureName,
        );
        await isar.close();
        isar = null;

        final markerStore = InMemoryIsarSchemaProvenanceStore(
          legacyVersion: 1,
          legacyFingerprint: IsarSchemaMigrator.v1SchemaFingerprint,
        );
        final preparation = await IsarSchemaMigrator.prepareBeforeOpen(
          store: markerStore,
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
          databaseGenerationIdFactory: () => _generationId,
        );
        expect(
          preparation.result.outcome,
          IsarSchemaMigrationOutcome.legacyMarkerMigrated,
        );
        expect(preparation.marker.state, IsarSchemaMarkerState.prepared);
        expect(preparation.marker.sourceSchemaVersion, 1);

        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _fixtureName,
        );
        final repair = await repairPlannedJobLocalLinks(isar);
        expect(repair.repairedModules, 1);
        expect(repair.repairedDiaryExecutionLinks, 1);
        expect(repair.repairedDiaryModuleLinks, 1);
        expect(
          (await repairLegacyOperationalAssuranceRequests(
            isar,
          )).normalizedLegacyRequests,
          0,
        );
        final committed = await preparation.commitAfterSuccessfulOpen();
        expect(committed.state, IsarSchemaMarkerState.committed);
        expect(committed.databaseGenerationId, _generationId);
        expect(markerStore.legacyVersion, isNull);
        expect(markerStore.legacyFingerprint, isNull);

        final template =
            await isar.jobTemplates
                .filter()
                .firestoreIdEqualTo('70k-template-v1')
                .findFirst();
        final execution =
            await isar.jobExecutions
                .filter()
                .firestoreIdEqualTo('70k-execution-v1')
                .findFirst();
        final module =
            await isar.jobModuleInstances
                .filter()
                .firestoreIdEqualTo('70k-module-v1')
                .findFirst();
        final diary =
            await isar.jobDiaryEntrys
                .filter()
                .firestoreIdEqualTo('70k-diary-v1')
                .findFirst();

        expect(template?.jobName, '70K migration fixture');
        expect(execution?.templateFirestoreId, template?.firestoreId);
        expect(module?.jobExecutionFirestoreId, execution?.firestoreId);
        expect(module?.templateFirestoreId, template?.firestoreId);
        expect(diary?.jobExecutionFirestoreId, execution?.firestoreId);
        expect(diary?.moduleInstanceFirestoreId, module?.firestoreId);
        expect(module?.jobExecutionLocalId, isNull);
        expect(diary?.jobExecutionLocalId, isNull);
        expect(diary?.moduleInstanceLocalId, isNull);
        _expectCurrentA05LocalDisposition(
          template: template!,
          execution: execution!,
          module: module!,
          diary: diary!,
        );
        expect(await isar.workflowAggregateRecords.where().count(), 0);
        expect(await isar.workflowCommandRecords.where().count(), 0);
      } finally {
        if (isar?.isOpen ?? false) {
          await isar!.close(deleteFromDisk: true);
        }
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'populated v3 compliance request migrates through v9 without evidence loss',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'crm3_70k_operational_assurance_v3_',
      );
      Isar? isar;
      try {
        final now = DateTime.utc(2026, 8, 14, 5, 30);
        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _v3FixtureName,
        );
        final legacyRequest =
            ComplianceRequestRecord()
              ..firestoreId = 'legacy-compliance-v3'
              ..isSynced = true
              ..version = 7
              ..title = 'Confirm crane isolation'
              ..description = 'Confirm the crane is isolated before work.'
              ..originLaneKey = 'mech'
              ..targetLaneKey = 'oprn'
              ..statusKey = 'acknowledged'
              ..conditionTypeKey = 'manual'
              ..requestPurposeKey = 'assurance'
              ..priorityKey = 'high'
              ..raisedByUid = 'mech-supervisor'
              ..raisedByName = 'Mechanical Supervisor'
              ..raisedAt = now
              ..acknowledgedByUid = 'operations-user'
              ..acknowledgedByName = 'Operations User'
              ..acknowledgedAt = now.add(const Duration(minutes: 5))
              ..linkedWorkflowId = 'workflow-v3'
              ..linkedExecutionFirestoreId = 'execution-v3'
              ..assetTypeKey = 'furnace'
              ..assetNumber = 7
              ..createdAt = now
              ..updatedAt = now.add(const Duration(minutes: 5));
        await isar.writeTxn(() async {
          await isar!.complianceRequestRecords.put(legacyRequest);
        });
        await isar.close();
        isar = null;

        final v3Schemas = _loadRepositoryProvenV3Schemas();
        expect(v3Schemas, hasLength(_currentSchemas.length));
        final v3Compliance = v3Schemas.singleWhere(
          (schema) => schema.name == ComplianceRequestRecordSchema.name,
        );
        expect(v3Compliance.properties, hasLength(68));
        expect(v3Compliance.properties, isNot(contains('requestPurposeKey')));
        isar = await Isar.open(
          v3Schemas,
          directory: directory.path,
          name: _v3FixtureName,
        );
        await isar.close();
        isar = null;

        final markerStore = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson:
              const IsarSchemaProvenanceMarker(
                state: IsarSchemaMarkerState.committed,
                schemaVersion: 3,
                schemaFingerprint: IsarSchemaMigrator.v3SchemaFingerprint,
                databaseGenerationId: _generationId,
                origin: IsarSchemaMarkerOrigin.freshInstall,
                sourceSchemaVersion: null,
                sourceSchemaFingerprint: null,
              ).encode(),
        );
        final preparation = await IsarSchemaMigrator.prepareBeforeOpen(
          store: markerStore,
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
        );
        expect(preparation.result.fromVersion, 3);
        expect(preparation.result.toVersion, 9);
        expect(preparation.marker.state, IsarSchemaMarkerState.prepared);
        expect(preparation.marker.databaseGenerationId, _generationId);

        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _v3FixtureName,
        );
        final beforeRepair =
            await isar.complianceRequestRecords
                .filter()
                .firestoreIdEqualTo('legacy-compliance-v3')
                .findFirst();
        expect(beforeRepair, isNotNull);
        expect(beforeRepair!.requestPurposeKey, isEmpty);

        final firstRepair = await repairLegacyOperationalAssuranceRequests(
          isar,
        );
        expect(firstRepair.normalizedLegacyRequests, 1);
        final secondRepair = await repairLegacyOperationalAssuranceRequests(
          isar,
        );
        expect(secondRepair.normalizedLegacyRequests, 0);

        final migrated =
            await isar.complianceRequestRecords
                .filter()
                .firestoreIdEqualTo('legacy-compliance-v3')
                .findFirst();
        expect(migrated, isNotNull);
        expect(migrated!.requestPurposeKey, 'assurance');
        expect(migrated.title, legacyRequest.title);
        expect(migrated.description, legacyRequest.description);
        expect(migrated.originLaneKey, 'mech');
        expect(migrated.targetLaneKey, 'oprn');
        expect(migrated.statusKey, 'acknowledged');
        expect(migrated.raisedByUid, 'mech-supervisor');
        expect(migrated.acknowledgedByUid, 'operations-user');
        expect(migrated.raisedAt?.toUtc(), now);
        expect(
          migrated.acknowledgedAt?.toUtc(),
          now.add(const Duration(minutes: 5)),
        );
        expect(migrated.version, 7);
        expect(migrated.isSynced, isTrue);
        expect(migrated.coordinationBasis, isNull);
        expect(migrated.raisedUnderCoordination, isFalse);

        final committed = await preparation.commitAfterSuccessfulOpen();
        expect(committed.schemaVersion, 9);
        expect(committed.state, IsarSchemaMarkerState.committed);
        expect(committed.databaseGenerationId, _generationId);
      } finally {
        if (isar?.isOpen ?? false) {
          await isar!.close(deleteFromDisk: true);
        }
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'populated v6 maintenance ticket migrates to v9 and pending reopen remains replayable',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'crm3_70k_maintenance_reopen_v6_',
      );
      Isar? isar;
      try {
        final now = DateTime.utc(2026, 8, 24, 3, 30);
        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _v6FixtureName,
        );
        final legacyTicket =
            MaintenanceRecord()
              ..firestoreId = 'legacy-maintenance-v6'
              ..version = 9
              ..isSynced = true
              ..assetType = AssetType.furnace
              ..assetNumber = 7
              ..maintenanceType = MaintenanceType.breakdown
              ..description = 'Legacy v6 burner inspection'
              ..routedTo = RoutedTo.instrumentation
              ..startDate = now
              ..createdAt = now
              ..updatedAt = now;
        final legacyPendingReopen =
            MaintenanceRecord()
              ..firestoreId = 'legacy-pending-reopen-v6'
              ..version = 11
              ..isSynced = false
              ..assetType = AssetType.furnace
              ..assetNumber = 8
              ..maintenanceType = MaintenanceType.breakdown
              ..description = 'Legacy v6 reopened burner inspection'
              ..routedTo = RoutedTo.instrumentation
              ..startDate = now
              ..createdAt = now
              ..updatedAt = now.add(const Duration(minutes: 45))
              ..remarks = 'Returned for detector correction'
              ..resolutionHistory = <ResolutionHistory>[
                ResolutionHistory(
                  resolvedByUid: 'si-supervisor-1',
                  resolvedByName: 'Senior Instrumentation',
                  resolvedAt: now.add(const Duration(minutes: 30)),
                ),
              ];
        await isar.writeTxn(() async {
          await isar!.maintenanceRecords.put(legacyTicket);
          await isar.maintenanceRecords.put(legacyPendingReopen);
        });
        await isar.close();
        isar = null;

        final v6Schemas = _loadRepositoryProvenV6Schemas();
        final v6Maintenance = v6Schemas.singleWhere(
          (schema) => schema.name == MaintenanceRecordSchema.name,
        );
        expect(v6Maintenance.properties, hasLength(67));
        expect(v6Maintenance.properties, isNot(contains('reopenedAt')));
        isar = await Isar.open(
          v6Schemas,
          directory: directory.path,
          name: _v6FixtureName,
        );
        await isar.close();
        isar = null;

        final markerStore = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson:
              const IsarSchemaProvenanceMarker(
                state: IsarSchemaMarkerState.committed,
                schemaVersion: 6,
                schemaFingerprint: IsarSchemaMigrator.v6SchemaFingerprint,
                databaseGenerationId: _generationId,
                origin: IsarSchemaMarkerOrigin.freshInstall,
                sourceSchemaVersion: null,
                sourceSchemaFingerprint: null,
              ).encode(),
        );
        final preparation = await IsarSchemaMigrator.prepareBeforeOpen(
          store: markerStore,
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
        );
        expect(preparation.result.fromVersion, 6);
        expect(preparation.result.toVersion, 9);

        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _v6FixtureName,
        );
        final migrated =
            await isar.maintenanceRecords
                .filter()
                .firestoreIdEqualTo('legacy-maintenance-v6')
                .findFirst();
        expect(migrated, isNotNull);
        expect(migrated!.description, legacyTicket.description);
        expect(migrated.version, 9);
        expect(migrated.isSynced, isTrue);
        expect(migrated.reopenedByUid, isNull);
        expect(migrated.reopenedByName, isNull);
        expect(migrated.reopenedAt, isNull);
        expect(migrated.reopenReason, isNull);

        final migratedPendingReopen =
            await isar.maintenanceRecords
                .filter()
                .firestoreIdEqualTo('legacy-pending-reopen-v6')
                .findFirst();
        expect(migratedPendingReopen, isNotNull);
        expect(migratedPendingReopen!.version, 11);
        expect(migratedPendingReopen.isSynced, isFalse);
        expect(migratedPendingReopen.resolutionHistory, hasLength(1));
        expect(migratedPendingReopen.reopenedByUid, isNull);
        expect(migratedPendingReopen.reopenedByName, isNull);
        expect(migratedPendingReopen.reopenedAt, isNull);
        expect(migratedPendingReopen.reopenReason, isNull);
        expect(
          maintenanceHasLegacyPendingReopenEvidence(migratedPendingReopen),
          isTrue,
        );

        final committed = await preparation.commitAfterSuccessfulOpen();
        expect(committed.schemaVersion, 9);
        expect(committed.state, IsarSchemaMarkerState.committed);
        expect(committed.databaseGenerationId, _generationId);
      } finally {
        if (isar?.isOpen ?? false) {
          await isar!.close(deleteFromDisk: true);
        }
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'governed populated v2 rehearsal stays unsupported by production and migrates only under its isolated adoption plan',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'crm3_70k_governed_v2_',
      );
      Isar? isar;
      try {
        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _v2FixtureName,
        );
        await _populateRepresentativeRows(isar);
        await isar.close();
        isar = null;

        final governedV2Schemas = _loadGovernedV2FixtureSchemas();
        expect(governedV2Schemas, hasLength(25));
        isar = await Isar.open(
          governedV2Schemas,
          directory: directory.path,
          name: _v2FixtureName,
        );
        await isar.close();
        isar = null;

        final productionStore = InMemoryIsarSchemaProvenanceStore(
          legacyVersion: 2,
          legacyFingerprint: _governedV2FixtureFingerprint,
        );
        await expectLater(
          IsarSchemaMigrator.prepareBeforeOpen(
            store: productionStore,
            databaseDirectoryPath: directory.path,
            hasExistingLocalStore: true,
          ),
          throwsA(
            isA<IsarSchemaMigrationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'stored-schema-fingerprint-unrecognized',
            ),
          ),
        );
        expect(productionStore.canonicalMarkerJson, isNull);

        var v2ToV3StepRuns = 0;
        final adoptionPlan = IsarSchemaMigrationPlan(
          currentVersion: IsarSchemaMigrator.currentSchemaVersion,
          schemaFingerprint: IsarSchemaMigrator.currentSchemaFingerprint,
          acceptedFingerprintsByVersion: const <int, Set<String>>{
            2: <String>{_governedV2FixtureFingerprint},
            3: <String>{IsarSchemaMigrator.v3SchemaFingerprint},
            4: <String>{IsarSchemaMigrator.v4SchemaFingerprint},
            5: <String>{IsarSchemaMigrator.v5SchemaFingerprint},
            6: <String>{IsarSchemaMigrator.v6SchemaFingerprint},
            7: <String>{IsarSchemaMigrator.v7SchemaFingerprint},
            8: <String>{IsarSchemaMigrator.v8SchemaFingerprint},
            9: <String>{IsarSchemaMigrator.currentSchemaFingerprint},
          },
          stepsByTargetVersion: <int, IsarSchemaMigrationStep>{
            3: (context) async {
              expect(context.fromVersion, 2);
              expect(context.toVersion, 3);
              expect(context.hasExistingLocalStore, isTrue);
              v2ToV3StepRuns++;
            },
            4: (context) async {
              expect(context.fromVersion, 3);
              expect(context.toVersion, 4);
            },
            5: (context) async {
              expect(context.fromVersion, 4);
              expect(context.toVersion, 5);
            },
            6: (context) async {
              expect(context.fromVersion, 5);
              expect(context.toVersion, 6);
            },
            7: (context) async {
              expect(context.fromVersion, 6);
              expect(context.toVersion, 7);
            },
            8: (context) async {
              expect(context.fromVersion, 7);
              expect(context.toVersion, 8);
            },
            9: (context) async {
              expect(context.fromVersion, 8);
              expect(context.toVersion, 9);
            },
          },
        );
        final adoptionStore = InMemoryIsarSchemaProvenanceStore(
          legacyVersion: 2,
          legacyFingerprint: _governedV2FixtureFingerprint,
        );
        final preparation = await IsarSchemaMigrator.prepareBeforeOpen(
          store: adoptionStore,
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
          plan: adoptionPlan,
          databaseGenerationIdFactory: () => _generationId,
        );
        expect(v2ToV3StepRuns, 1);
        expect(preparation.marker.state, IsarSchemaMarkerState.prepared);
        expect(preparation.marker.sourceSchemaVersion, 2);
        expect(
          preparation.marker.sourceSchemaFingerprint,
          _governedV2FixtureFingerprint,
        );

        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: _v2FixtureName,
        );
        await repairPlannedJobLocalLinks(isar);
        final committed = await preparation.commitAfterSuccessfulOpen();
        expect(committed.state, IsarSchemaMarkerState.committed);
        expect(committed.databaseGenerationId, _generationId);

        final template =
            await isar.jobTemplates
                .filter()
                .firestoreIdEqualTo('70k-template-v1')
                .findFirst();
        final execution =
            await isar.jobExecutions
                .filter()
                .firestoreIdEqualTo('70k-execution-v1')
                .findFirst();
        final module =
            await isar.jobModuleInstances
                .filter()
                .firestoreIdEqualTo('70k-module-v1')
                .findFirst();
        final diary =
            await isar.jobDiaryEntrys
                .filter()
                .firestoreIdEqualTo('70k-diary-v1')
                .findFirst();
        expect(module?.jobExecutionFirestoreId, execution?.firestoreId);
        expect(diary?.jobExecutionFirestoreId, execution?.firestoreId);
        expect(diary?.moduleInstanceFirestoreId, module?.firestoreId);
        _expectCurrentA05LocalDisposition(
          template: template!,
          execution: execution!,
          module: module!,
          diary: diary!,
        );
      } finally {
        if (isar?.isOpen ?? false) {
          await isar!.close(deleteFromDisk: true);
        }
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'durable restart rehearsal preserves generation across PREPARED, open, repair and COMMITTED boundaries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'crm3_70k_interruptions_',
      );
      final markerFile = File('${directory.path}/70k_marker_state.json');
      const name = 'crm3_70k_interruption_fixture';
      Isar? isar;
      try {
        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: name,
        );
        await _populateRepresentativeRows(isar);
        await isar.close();
        isar = null;
        isar = await Isar.open(
          _loadRepositoryProvenV1Schemas(),
          directory: directory.path,
          name: name,
        );
        await isar.close();
        isar = null;

        final firstStore = _FileIsarSchemaProvenanceStore(markerFile);
        await firstStore.initializeLegacyV1();
        final preparedBeforeOpen = await IsarSchemaMigrator.prepareBeforeOpen(
          store: firstStore,
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
          databaseGenerationIdFactory: () => _generationId,
        );
        expect(preparedBeforeOpen.marker.state, IsarSchemaMarkerState.prepared);

        // Forced stop at PREPARED: a new store instance reads only durable
        // marker state and resumes the same generation.
        final afterPreparedRestart = await IsarSchemaMigrator.prepareBeforeOpen(
          store: _FileIsarSchemaProvenanceStore(markerFile),
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
        );
        expect(
          afterPreparedRestart.result.outcome,
          IsarSchemaMigrationOutcome.preparedOpenResumed,
        );
        expect(afterPreparedRestart.marker.databaseGenerationId, _generationId);

        // Forced stop immediately after Isar open: no COMMITTED marker exists.
        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: name,
        );
        await isar.close();
        isar = null;
        final afterOpenRestart = await IsarSchemaMigrator.prepareBeforeOpen(
          store: _FileIsarSchemaProvenanceStore(markerFile),
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
        );
        expect(afterOpenRestart.marker.databaseGenerationId, _generationId);
        expect(afterOpenRestart.marker.state, IsarSchemaMarkerState.prepared);

        // Forced stop after post-open repair: the repair is durable but the
        // marker remains PREPARED, so restart must rerun it idempotently.
        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: name,
        );
        final firstRepair = await repairPlannedJobLocalLinks(isar);
        expect(firstRepair.totalRepairs, 3);
        await isar.close();
        isar = null;
        final afterRepairRestart = await IsarSchemaMigrator.prepareBeforeOpen(
          store: _FileIsarSchemaProvenanceStore(markerFile),
          databaseDirectoryPath: directory.path,
          hasExistingLocalStore: true,
        );
        expect(afterRepairRestart.marker.databaseGenerationId, _generationId);
        expect(afterRepairRestart.marker.state, IsarSchemaMarkerState.prepared);

        isar = await Isar.open(
          _currentSchemas,
          directory: directory.path,
          name: name,
        );
        final repeatedRepair = await repairPlannedJobLocalLinks(isar);
        expect(repeatedRepair.totalRepairs, 0);
        final committed = await afterRepairRestart.commitAfterSuccessfulOpen();
        expect(committed.state, IsarSchemaMarkerState.committed);
        expect(committed.databaseGenerationId, _generationId);
        await isar.close();
        isar = null;

        // Restart after COMMITTED is stable and does not rotate or rerun the
        // migration path.
        final afterCommittedRestart =
            await IsarSchemaMigrator.prepareBeforeOpen(
              store: _FileIsarSchemaProvenanceStore(markerFile),
              databaseDirectoryPath: directory.path,
              hasExistingLocalStore: true,
            );
        expect(
          afterCommittedRestart.result.outcome,
          IsarSchemaMigrationOutcome.alreadyCurrent,
        );
        expect(
          afterCommittedRestart.marker.databaseGenerationId,
          _generationId,
        );
        expect(
          await _FileIsarSchemaProvenanceStore(
            markerFile,
          ).readLegacySchemaVersion(),
          isNull,
        );
      } finally {
        if (isar?.isOpen ?? false) {
          await isar!.close(deleteFromDisk: true);
        }
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'backup restores populated rows while an empty rebuild rotates generation',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'crm3_70k_backup_rebuild_',
      );
      final liveDirectory = Directory('${root.path}/live');
      final backupDirectory = Directory('${root.path}/backup');
      final restoreDirectory = Directory('${root.path}/restore');
      await liveDirectory.create(recursive: true);
      final liveMarker = File('${liveDirectory.path}/70k_marker_state.json');
      const name = 'crm3_70k_backup_fixture';
      Isar? isar;
      try {
        final freshStore = _FileIsarSchemaProvenanceStore(liveMarker);
        final freshPreparation = await IsarSchemaMigrator.prepareBeforeOpen(
          store: freshStore,
          databaseDirectoryPath: liveDirectory.path,
          hasExistingLocalStore: false,
          databaseGenerationIdFactory: () => _generationId,
        );
        isar = await Isar.open(
          _currentSchemas,
          directory: liveDirectory.path,
          name: name,
        );
        await _populateRepresentativeRows(isar);
        await freshPreparation.commitAfterSuccessfulOpen();
        await isar.close();
        isar = null;

        final backupHashes = await _copyDataFiles(
          liveDirectory,
          backupDirectory,
        );
        expect(backupHashes.keys, contains('$name.isar'));
        expect(backupHashes.keys, contains('70k_marker_state.json'));

        await for (final entity in liveDirectory.list(followLinks: false)) {
          if (entity is File && entity.path.endsWith('.isar')) {
            await entity.delete();
          }
        }
        final replacementPreparation =
            await IsarSchemaMigrator.prepareBeforeOpen(
              store: _FileIsarSchemaProvenanceStore(liveMarker),
              databaseDirectoryPath: liveDirectory.path,
              hasExistingLocalStore: false,
              databaseGenerationIdFactory: () => _rotatedGenerationId,
            );
        expect(
          replacementPreparation.result.outcome,
          IsarSchemaMigrationOutcome.storeReplacementInitialized,
        );
        expect(
          replacementPreparation.marker.databaseGenerationId,
          _rotatedGenerationId,
        );
        expect(
          replacementPreparation.marker.databaseGenerationId,
          isNot(_generationId),
        );
        isar = await Isar.open(
          _currentSchemas,
          directory: liveDirectory.path,
          name: name,
        );
        expect(await isar.jobExecutions.where().count(), 0);
        await replacementPreparation.commitAfterSuccessfulOpen();
        await isar.close();
        isar = null;

        final restoredHashes = await _copyDataFiles(
          backupDirectory,
          restoreDirectory,
        );
        expect(restoredHashes, backupHashes);
        final restoredMarker = File(
          '${restoreDirectory.path}/70k_marker_state.json',
        );
        final restorePreparation = await IsarSchemaMigrator.prepareBeforeOpen(
          store: _FileIsarSchemaProvenanceStore(restoredMarker),
          databaseDirectoryPath: restoreDirectory.path,
          hasExistingLocalStore: true,
        );
        expect(
          restorePreparation.result.outcome,
          IsarSchemaMigrationOutcome.alreadyCurrent,
        );
        expect(restorePreparation.marker.databaseGenerationId, _generationId);
        isar = await Isar.open(
          _currentSchemas,
          directory: restoreDirectory.path,
          name: name,
        );
        expect(await isar.jobTemplates.where().count(), 1);
        expect(await isar.jobExecutions.where().count(), 1);
        expect(await isar.jobModuleInstances.where().count(), 1);
        expect(await isar.jobDiaryEntrys.where().count(), 1);
        final restoredTemplate =
            await isar.jobTemplates
                .filter()
                .firestoreIdEqualTo('70k-template-v1')
                .findFirst();
        final restoredExecution =
            await isar.jobExecutions
                .filter()
                .firestoreIdEqualTo('70k-execution-v1')
                .findFirst();
        final restoredModule =
            await isar.jobModuleInstances
                .filter()
                .firestoreIdEqualTo('70k-module-v1')
                .findFirst();
        final restoredDiary =
            await isar.jobDiaryEntrys
                .filter()
                .firestoreIdEqualTo('70k-diary-v1')
                .findFirst();
        expect(restoredModule?.jobExecutionFirestoreId, '70k-execution-v1');
        _expectCurrentA05LocalDisposition(
          template: restoredTemplate!,
          execution: restoredExecution!,
          module: restoredModule!,
          diary: restoredDiary!,
        );
      } finally {
        if (isar?.isOpen ?? false) {
          await isar!.close(deleteFromDisk: true);
        }
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
