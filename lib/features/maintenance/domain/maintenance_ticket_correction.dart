import '../../../core/serialization/persisted_data_reader.dart';
import '../data/maintenance_model.dart';
import 'burner_lockout_case.dart';
import 'furnace_stuckup_case.dart';

String? cleanMaintenanceOptionalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? cleanMaintenanceTagText(String value) =>
    cleanMaintenanceOptionalText(value)?.toUpperCase();

class MaintenanceTicketCorrectionDraft {
  MaintenanceTicketCorrectionDraft({
    required Map<String, Object?> corrections,
    required String reason,
  }) : corrections = Map.unmodifiable(corrections),
       reason = reason.trim();

  final Map<String, Object?> corrections;
  final String reason;
}

MaintenanceTicketCorrectionDraft buildMaintenanceTicketCorrection({
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
  final sourceLabel =
      source.firestoreId == null
          ? 'local maintenance ${source.id}'
          : 'maintenance ${source.firestoreId}';
  if (!source.actionsReadResult.isValid) {
    throw PersistedDataFormatException(
      field: 'actionsJson',
      source: sourceLabel,
      detail: 'saved action evidence needs repair',
    );
  }
  if (!source.resolutionHistoryReadResult.isValid) {
    throw PersistedDataFormatException(
      field: 'resolutionHistoryJson',
      source: sourceLabel,
      detail: 'saved resolution history needs repair',
    );
  }
  final sourceLanePlan =
      source.issueLanePlanReadResult.value ??
      source.issueLanePlanForOtherDepartmentRepair;
  final cleanDescription = description.trim();
  if (cleanDescription.length < 5) {
    throw ArgumentError('Description must contain at least 5 characters.');
  }
  final cleanReason = reason.trim();
  if (cleanReason.length < 12) {
    throw ArgumentError(
      'Correction reason must contain at least 12 characters.',
    );
  }
  if (source.classification == burnerLockoutClassification) {
    final hasRedHot =
        source.burnerLockoutReadResult.value?.hasRedHotObservation == true;
    if (routedTo != RoutedTo.instrumentation ||
        maintenanceType != MaintenanceType.breakdown ||
        cleanMaintenanceOptionalText(component ?? '') != 'Burner system' ||
        cleanMaintenanceTagText(tag ?? '') != null ||
        cleanMaintenanceOptionalText(classification ?? '') !=
            burnerLockoutClassification ||
        (hasRedHot && !isCritical)) {
      throw StateError(
        'Burner identity, I&A routing, breakdown type, and red-hot criticality are fixed.',
      );
    }
  } else if (cleanMaintenanceOptionalText(classification ?? '') ==
      burnerLockoutClassification) {
    throw StateError(
      'A standard issue cannot be reclassified as a burner lockout.',
    );
  }
  if (source.classification == furnaceStuckupClassification) {
    if (routedTo != RoutedTo.mechanical ||
        maintenanceType != MaintenanceType.breakdown ||
        cleanMaintenanceOptionalText(component ?? '') !=
            'Furnace / Inner Cover interface' ||
        cleanMaintenanceTagText(tag ?? '') != null ||
        cleanMaintenanceOptionalText(classification ?? '') !=
            furnaceStuckupClassification) {
      throw StateError(
        'Furnace stuck-up identity, Mechanical routing, and breakdown type are fixed.',
      );
    }
  } else if (cleanMaintenanceOptionalText(classification ?? '') ==
      furnaceStuckupClassification) {
    throw StateError(
      'A standard issue cannot be reclassified as a Furnace stuck-up.',
    );
  }
  final routeChanges = routedTo != source.routedTo;
  final effectiveLanes =
      routeChanges
          ? <RoutedTo>{routedTo}
          : sourceLanePlan.assignedLanes.map(RoutedTo.values.byName).toSet();
  final cleanOtherDepartment = cleanMaintenanceOptionalText(
    otherDepartment ?? '',
  );
  if (effectiveLanes.contains(RoutedTo.others) &&
      (cleanOtherDepartment == null || cleanOtherDepartment.length < 2)) {
    throw ArgumentError('Other department must contain at least 2 characters.');
  }
  final proposed = <String, Object?>{
    'description': cleanDescription,
    'routedTo': routedTo.name,
    'maintenanceType': maintenanceType.name,
    'isCritical': isCritical,
    'component': cleanMaintenanceOptionalText(component ?? ''),
    'subsystem': cleanMaintenanceOptionalText(subsystem ?? ''),
    'tag': cleanMaintenanceTagText(tag ?? ''),
    'classification': cleanMaintenanceOptionalText(classification ?? ''),
    'otherDepartment':
        effectiveLanes.contains(RoutedTo.others) ? cleanOtherDepartment : null,
    'remarks': cleanMaintenanceOptionalText(remarks ?? ''),
  };
  final current = <String, Object?>{
    'description': source.description,
    'routedTo': source.routedTo.name,
    'maintenanceType': source.maintenanceType.name,
    'isCritical': source.isCritical,
    'component': cleanMaintenanceOptionalText(source.component ?? ''),
    'subsystem': cleanMaintenanceOptionalText(source.subsystem ?? ''),
    'tag': cleanMaintenanceTagText(source.tag ?? ''),
    'classification': cleanMaintenanceOptionalText(source.classification ?? ''),
    'otherDepartment': cleanMaintenanceOptionalText(
      source.otherDepartment ?? '',
    ),
    'remarks': cleanMaintenanceOptionalText(source.remarks ?? ''),
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
  return MaintenanceTicketCorrectionDraft(
    corrections: corrections,
    reason: cleanReason,
  );
}
