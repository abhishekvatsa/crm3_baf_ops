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
import 'package:isar_community/isar.dart';

const build25UpgradeFixtureName = 'crm3_build25_core_fixture';
const build25UpgradeChargeId = 'build25-upgrade-charge';
const build25UpgradeIssueId = 'build25-upgrade-issue';

final build25UpgradeSchemas = <CollectionSchema<dynamic>>[
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

Charge build25UpgradeCharge() {
  final now = DateTime.utc(2026, 9, 6, 5, 30);
  return Charge()
    ..firestoreId = build25UpgradeChargeId
    ..chargeNo = 250906
    ..status = ChargeStatus.heat
    ..baseNo = 207
    ..furnaceNo = 22
    ..cycleType = 'Build 25 upgrade fixture'
    ..rawTelemetry = '{"temperature":710}'
    ..hasAbnormal = true
    ..createdAt = now
    ..updatedAt = now
    ..isSynced = true;
}

MaintenanceRecord build25UpgradeIssue() {
  final now = DateTime.utc(2026, 9, 6, 5, 30);
  return MaintenanceRecord()
    ..firestoreId = build25UpgradeIssueId
    ..version = 8
    ..isSynced = true
    ..assetType = AssetType.furnace
    ..assetNumber = 22
    ..component = 'Burner block 4'
    ..hierarchyPath = <String>['Combustion', 'Burner block 4']
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Build 25 populated upgrade fixture'
    ..routedTo = RoutedTo.mechanical
    ..loggedByUid = 'fixture-user'
    ..loggedByName = 'Build fixture'
    ..startDate = now
    ..createdAt = now
    ..updatedAt = now
    ..metadataJson = '{"fixture":"build25"}';
}
