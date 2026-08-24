import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/domain/maintenance_ticket_correction.dart';

String? cleanAdminOptionalText(String value) =>
    cleanMaintenanceOptionalText(value);

String? cleanAdminTagText(String value) => cleanMaintenanceTagText(value);

typedef AdminTicketCorrectionDraft = MaintenanceTicketCorrectionDraft;

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
}) => buildMaintenanceTicketCorrection(
  source: source,
  description: description,
  routedTo: routedTo,
  maintenanceType: maintenanceType,
  isCritical: isCritical,
  component: component,
  subsystem: subsystem,
  tag: tag,
  classification: classification,
  otherDepartment: otherDepartment,
  remarks: remarks,
  reason: reason,
);
