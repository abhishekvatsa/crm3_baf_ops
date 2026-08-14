import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance/data/maintenance_model.dart';

String? cleanAdminOptionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? cleanAdminTagText(String value) {
  return cleanAdminOptionalText(value)?.toUpperCase();
}

class AdminTicketCorrectionDraft {
  final Map<String, Object?> corrections;
  final String reason;

  AdminTicketCorrectionDraft({
    required Map<String, Object?> corrections,
    required String reason,
  }) : corrections = Map.unmodifiable(corrections),
       reason = reason.trim();
}

AdminTicketCorrectionDraft buildAdminTicketCorrection({
  required MaintenanceRecord source,
  required String description,
  required RoutedTo routedTo,
  required MaintenanceType maintenanceType,
  required bool isCritical,
  required String? component,
  required String? subsystem,
  required String? tag,
  required String? classification,
  required String? otherDepartment,
  required String? remarks,
  required String reason,
}) {
  if (!source.actionsReadResult.isValid) {
    throw PersistedDataFormatException(
      field: 'actionsJson',
      source:
          source.firestoreId == null
              ? 'local maintenance ${source.id}'
              : 'maintenance ${source.firestoreId}',
      detail: 'saved action evidence needs repair',
    );
  }
  if (!source.resolutionHistoryReadResult.isValid) {
    throw PersistedDataFormatException(
      field: 'resolutionHistoryJson',
      source:
          source.firestoreId == null
              ? 'local maintenance ${source.id}'
              : 'maintenance ${source.firestoreId}',
      detail: 'saved resolution history needs repair',
    );
  }
  final cleanDescription = description.trim();
  if (cleanDescription.length < 3) {
    throw ArgumentError('Description must contain at least 3 characters.');
  }
  final cleanReason = reason.trim();
  if (cleanReason.length < 12) {
    throw ArgumentError(
      'Correction reason must contain at least 12 characters.',
    );
  }
  final proposed = <String, Object?>{
    'description': cleanDescription,
    'routedTo': routedTo.name,
    'maintenanceType': maintenanceType.name,
    'isCritical': isCritical,
    'component': cleanAdminOptionalText(component ?? ''),
    'subsystem': cleanAdminOptionalText(subsystem ?? ''),
    'tag': cleanAdminTagText(tag ?? ''),
    'classification': cleanAdminOptionalText(classification ?? ''),
    'otherDepartment':
        routedTo == RoutedTo.others
            ? cleanAdminOptionalText(otherDepartment ?? '')
            : null,
    'remarks': cleanAdminOptionalText(remarks ?? ''),
  };
  final current = <String, Object?>{
    'description': source.description,
    'routedTo': source.routedTo.name,
    'maintenanceType': source.maintenanceType.name,
    'isCritical': source.isCritical,
    'component': cleanAdminOptionalText(source.component ?? ''),
    'subsystem': cleanAdminOptionalText(source.subsystem ?? ''),
    'tag': cleanAdminTagText(source.tag ?? ''),
    'classification': cleanAdminOptionalText(source.classification ?? ''),
    'otherDepartment': cleanAdminOptionalText(source.otherDepartment ?? ''),
    'remarks': cleanAdminOptionalText(source.remarks ?? ''),
  };
  final corrections = <String, Object?>{};
  for (final entry in proposed.entries) {
    if (current[entry.key] != entry.value) {
      corrections[entry.key] = entry.value;
    }
  }
  if (corrections.isEmpty) {
    throw StateError('Make at least one correction before saving.');
  }
  return AdminTicketCorrectionDraft(
    corrections: corrections,
    reason: cleanReason,
  );
}
