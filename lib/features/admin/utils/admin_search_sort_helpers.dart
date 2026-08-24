import '../../planned_maintenance/data/job_template_model.dart';

import 'admin_ticket_helpers.dart';

bool templateMatchesAdminSearch(JobTemplate template, String query) {
  if (query.isEmpty) return true;
  return template.jobName.toLowerCase().contains(query) ||
      (template.description?.toLowerCase().contains(query) ?? false) ||
      template.applicableAssetType.name.toLowerCase().contains(query) ||
      template.assignedAgencies.any(
        (agency) => agency.toLowerCase().contains(query),
      ) ||
      (template.component?.toLowerCase().contains(query) ?? false) ||
      (template.subsystem?.toLowerCase().contains(query) ?? false) ||
      (template.createdByName?.toLowerCase().contains(query) ?? false);
}

bool executionMatchesAdminSearch(JobExecution execution, String query) {
  if (query.isEmpty) return true;
  final completionLabel =
      execution.isDeleted
          ? 'deleted'
          : execution.isCancelled
          ? 'cancelled'
          : execution.isCompleted
          ? 'completed'
          : 'open';
  return (execution.templateName?.toLowerCase().contains(query) ?? false) ||
      execution.assetType.name.toLowerCase().contains(query) ||
      execution.assetNumber.toString().contains(query) ||
      execution.assignedAgencies.any(
        (agency) => agency.toLowerCase().contains(query),
      ) ||
      (execution.assignedByName?.toLowerCase().contains(query) ?? false) ||
      (execution.completedByName?.toLowerCase().contains(query) ?? false) ||
      (execution.cancelledByName?.toLowerCase().contains(query) ?? false) ||
      (execution.cancellationReason?.toLowerCase().contains(query) ?? false) ||
      (execution.remarks?.toLowerCase().contains(query) ?? false) ||
      completionLabel.contains(query);
}

int compareTemplatesForAdmin(JobTemplate a, JobTemplate b) {
  final deletedCompare = (a.isDeleted ? 1 : 0).compareTo(b.isDeleted ? 1 : 0);
  if (deletedCompare != 0) return deletedCompare;
  final typeCompare = a.applicableAssetType.index.compareTo(
    b.applicableAssetType.index,
  );
  if (typeCompare != 0) return typeCompare;
  return a.jobName.toLowerCase().compareTo(b.jobName.toLowerCase());
}

int compareExecutionsForAdmin(JobExecution a, JobExecution b) {
  final deletedCompare = (a.isDeleted ? 1 : 0).compareTo(b.isDeleted ? 1 : 0);
  if (deletedCompare != 0) return deletedCompare;
  return b.updatedAt.compareTo(a.updatedAt);
}

String formatAgencyList(List<String> agencies) {
  final cleaned =
      agencies
          .map((agency) => agency.trim())
          .where((agency) => agency.isNotEmpty)
          .map((agency) => agency.toUpperCase())
          .toList();
  if (cleaned.isEmpty) return 'No agencies';
  return cleaned.join(', ');
}

String? templateScopeLabel(JobTemplate template) {
  final component = cleanAdminOptionalText(template.component ?? '');
  if (component != null) return component;
  final hierarchy =
      template.hierarchyPath
          ?.map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
  if (hierarchy != null && hierarchy.isNotEmpty) return 'Scoped';
  return null;
}
