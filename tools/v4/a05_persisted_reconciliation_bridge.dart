import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_availability_record.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_operational_condition.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/audit/repositories/audit_repository.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/maintenance/data/frequent_issue_definition.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event_issue_link.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';

const _supportedCollections = <String>{
  'asset_classes',
  'asset_component_instances',
  'asset_hierarchy_nodes',
  'asset_instances',
  'asset_availability_current',
  'asset_condition_declarations',
  'asset_operational_conditions',
  'asset_tag_claims',
  'base_inner_cover_assignments',
  'burner_condition_rounds',
  'critical_alarm_contacts',
  'critical_alarms',
  'frequent_issue_definitions',
  'furnace_stuckup_cases',
  'inner_cover_fabrications',
  'inner_cover_linkages',
  'inner_cover_profiles',
  'inspection_campaigns',
  'inspection_definitions',
  'inspection_findings',
  'inspection_observations',
  'audit_logs',
  'maintenance_class_definitions',
  'maintenance_completion_events',
  'maintenance_due_states',
  'maintenance_plans',
  'maintenance_records',
  'operational_events',
  'operational_event_issue_links',
  'quality_monitoring_requests',
  'quality_warnings',
};

Future<void> main() async {
  try {
    final input = jsonDecode(await stdin.transform(utf8.decoder).join());
    stdout.write(jsonEncode(reconcileA05Envelope(input)));
  } catch (_) {
    stderr.write('A-05 reconciliation bridge rejected its input.');
    exitCode = 64;
  }
}

Map<String, Object?> reconcileA05Envelope(dynamic input) {
  if (input is! Map || input['records'] is! List) {
    throw const FormatException('invalid bridge envelope');
  }
  final results = <Map<String, Object?>>[];
  for (final rawRecord in input['records'] as List<dynamic>) {
    results.add(_reconcileRecord(rawRecord));
  }
  return <String, Object?>{
    'schemaVersion': 1,
    'supportedCollections': _supportedCollections.toList()..sort(),
    'results': results,
  };
}

Map<String, Object?> _reconcileRecord(dynamic rawRecord) {
  String? pseudonym;
  String? collection;
  try {
    if (rawRecord is! Map) throw const FormatException('record must be a map');
    pseudonym = _requiredString(rawRecord['subjectPseudonym']);
    collection = _requiredString(rawRecord['collection']);
    final documentId = _requiredString(rawRecord['documentId']);
    final restored = _restoreFirestoreValue(rawRecord['data']);
    if (restored is! Map) throw const FormatException('data must be a map');
    final data = Map<String, dynamic>.from(restored);

    switch (collection) {
      case 'asset_classes':
        AssetClassRecord.fromMap(data, documentId);
      case 'asset_hierarchy_nodes':
        AssetHierarchyNode.fromMap(data, documentId);
      case 'asset_instances':
        AssetInstanceRecord.fromMap(data, documentId);
      case 'asset_availability_current':
        AssetAvailabilityRecord.fromMap(data, documentId);
      case 'asset_condition_declarations':
        AssetConditionDeclarationRecord.fromMap(data, documentId);
      case 'asset_operational_conditions':
        AssetOperationalConditionRecord.fromMap(data, documentId);
      case 'burner_condition_rounds':
        BurnerConditionRound.fromMap(data, documentId);
      case 'critical_alarm_contacts':
        CriticalAlarmContact.fromFirestore(data, documentId);
      case 'critical_alarms':
        CriticalAlarm.fromFirestore(data, documentId);
      case 'frequent_issue_definitions':
        FrequentIssueDefinition.fromMap(data, documentId);
      case 'furnace_stuckup_cases':
        FurnaceStuckupRecord.fromMap(data, documentId);
      case 'asset_component_instances':
        InstalledComponentRecord.fromMap(data, documentId);
      case 'asset_tag_claims':
        AssetTagClaimRecord.fromMap(data, documentId);
      case 'inner_cover_profiles':
        InnerCoverProfile.fromMap(data, documentId);
      case 'base_inner_cover_assignments':
        BaseInnerCoverAssignment.fromMap(data, documentId);
      case 'inner_cover_linkages':
        InnerCoverLinkage.fromMap(data, documentId);
      case 'inner_cover_fabrications':
        InnerCoverFabricationDossier.fromMap(data, documentId);
      case 'inspection_campaigns':
        InspectionCampaign.fromMap(data, documentId);
      case 'inspection_definitions':
        InspectionDefinition.fromMap(data, documentId);
      case 'inspection_findings':
        InspectionFinding.fromMap(data, documentId);
      case 'inspection_observations':
        InspectionObservation.fromMap(data, documentId);
      case 'audit_logs':
        decodePersistedAuditEvent(data, documentId: documentId);
      case 'maintenance_class_definitions':
        MaintenanceClassDefinition.fromMap(data, documentId);
      case 'maintenance_completion_events':
        MaintenanceCompletionEvent.fromMap(data, documentId);
      case 'maintenance_due_states':
        MaintenanceDueState.fromMap(data, documentId);
      case 'maintenance_plans':
        MaintenancePlan.fromMap(data, documentId);
      case 'maintenance_records':
        readRemoteMaintenanceRecord(data, documentId: documentId);
      case 'operational_events':
        OperationalEvent.fromMap(data, documentId);
      case 'operational_event_issue_links':
        OperationalEventIssueLink.fromMap(data, documentId);
      case 'quality_warnings':
        QualityWarning.fromMap(data, documentId);
      case 'quality_monitoring_requests':
        QualityMonitoringRequest.fromMap(data, documentId);
      default:
        throw UnsupportedError('unsupported collection');
    }
    return <String, Object?>{
      'collection': collection,
      'subjectPseudonym': pseudonym,
      'result': 'PASS',
    };
  } catch (error) {
    return <String, Object?>{
      if (collection != null) 'collection': collection,
      if (pseudonym != null) 'subjectPseudonym': pseudonym,
      'result': 'FAIL',
      'errorType': switch (error) {
        PersistedDataFormatException() => 'PERSISTED_DATA_FORMAT',
        UnsupportedError() => 'UNSUPPORTED_COLLECTION',
        _ => 'DECODER_REJECTION',
      },
      if (error is PersistedDataFormatException) 'field': error.fieldName,
    };
  }
}

dynamic _restoreFirestoreValue(dynamic value) {
  if (value is List) return value.map(_restoreFirestoreValue).toList();
  if (value is! Map) return value;
  if (value['__a05FirestoreType'] == 'timestamp') {
    final seconds = value['seconds'];
    final nanoseconds = value['nanoseconds'];
    if (seconds is! int || nanoseconds is! int) {
      throw const FormatException('invalid timestamp transport');
    }
    return Timestamp(seconds, nanoseconds);
  }
  if (value['__a05FirestoreType'] == 'nonFiniteNumber') {
    return switch (value['value']) {
      'NaN' => double.nan,
      'Infinity' => double.infinity,
      '-Infinity' => double.negativeInfinity,
      _ => throw const FormatException('invalid non-finite transport'),
    };
  }
  return Map<String, dynamic>.fromEntries(
    value.entries.map(
      (entry) => MapEntry(
        _requiredString(entry.key),
        _restoreFirestoreValue(entry.value),
      ),
    ),
  );
}

String _requiredString(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  throw const FormatException('required string missing');
}
