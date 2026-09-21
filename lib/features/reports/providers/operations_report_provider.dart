import 'dart:convert';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../../core/providers/operations_report_clock_provider.dart';
import '../../abnormalities/data/abnormality_model.dart';
import '../../abnormalities/providers/abnormality_provider.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/inner_cover_lifecycle.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/domain/plant_asset_overview.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/providers/burner_condition_round_provider.dart';
import '../../assets/providers/plant_asset_overview_provider.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../critical_alarm/domain/critical_alarm_models.dart';
import '../../critical_alarm/providers/critical_alarm_providers.dart';
import '../../directives/data/operational_directive_model.dart';
import '../../directives/providers/operational_directive_provider.dart';
import '../../inspections/data/inspection_campaign.dart';
import '../../inspections/providers/inspection_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../maintenance_workflow/data/compliance_request_record.dart';
import '../../maintenance_workflow/data/job_lane_record.dart';
import '../../maintenance_workflow/data/workflow_aggregate_record.dart';
import '../../maintenance_workflow/domain/compliance_visibility_policy.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../operational_events/data/operational_event.dart';
import '../../operational_events/providers/operational_event_provider.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/data/maintenance_intelligence.dart';
import '../../planned_maintenance/providers/maintenance_intelligence_provider.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../quality/data/quality_warning.dart';
import '../../quality/providers/quality_provider.dart';
import '../domain/operations_report_asset_inventory.dart';
import '../domain/operations_report_query_plan.dart';
import '../models/operations_report.dart';

export '../../../core/providers/operations_report_clock_provider.dart';

part 'operations_report_authority_lifecycle.dart';
part 'operations_report_identity_sources.dart';
part 'operations_report_builder.dart';

typedef OperationsReportPeriod = ({
  DateTime startInclusive,
  DateTime endExclusive,
});
typedef OperationsReportPeriodScope = ({
  String actorUid,
  DateTime startInclusive,
  DateTime endExclusive,
});
typedef OperationsReportScope = ({
  String actorUid,
  OperationsReportFilter filter,
});
typedef _ReportDimension = ({String disambiguator, String key, String label});

final operationsReportTicketsProvider = StreamProvider.autoDispose
    .family<List<MaintenanceRecord>, OperationsReportPeriodScope>((ref, scope) {
      _requireReportActorUid(scope.actorUid);
      return ref
          .watch(maintenanceRepositoryProvider)
          .watchTicketsOverlappingPeriod(
            scope.startInclusive,
            scope.endExclusive,
          );
    });

final operationsReportExecutionsProvider = StreamProvider.autoDispose
    .family<List<JobExecution>, OperationsReportPeriodScope>((ref, scope) {
      _requireReportActorUid(scope.actorUid);
      return ref
          .watch(plannedRepositoryProvider)
          .watchExecutionsOverlappingPeriod(
            scope.startInclusive,
            scope.endExclusive,
          );
    });

final operationsReportExecutionBatchProvider = StreamProvider.autoDispose
    .family<DecodedSnapshotBatch<JobExecution>, OperationsReportPeriodScope>((
      ref,
      scope,
    ) {
      _requireReportActorUid(scope.actorUid);
      final repository = ref.watch(plannedRepositoryProvider);
      if (repository is FirestorePlannedRepository) {
        return repository.watchExecutionsOverlappingPeriodWithCoverage(
          scope.startInclusive,
          scope.endExclusive,
        );
      }
      // Observe every native typed-stream update, including repository/provider
      // overrides. A one-shot .future here can freeze coverage at the first row set.
      return ref
          .watch(operationsReportExecutionsProvider(scope))
          .when(
            data: (records) => Stream.value(
              DecodedSnapshotBatch<JobExecution>(
                records: records,
                rejectedDocumentIds: const [],
              ),
            ),
            loading: () => const Stream.empty(),
            error: (error, stack) => Stream.error(error, stack),
          );
    });

final operationsReportAbnormalitiesProvider = StreamProvider.autoDispose
    .family<List<ChargeAbnormality>, String>((ref, actorUid) {
      _requireReportActorUid(actorUid);
      final repository = ref.watch(abnormalityRepositoryProvider);
      if (repository is FirestoreAbnormalityRepository ||
          repository is IsarAbnormalityRepository) {
        return repository.watchAllAbnormalities();
      }
      // Keep lightweight repositories and test doubles compatible while still
      // making the report's current quality population refresh after changes.
      return _pollReportAbnormalities(repository);
    });

Stream<List<ChargeAbnormality>> _pollReportAbnormalities(
  AbnormalityRepository repository,
) async* {
  yield await repository.getAllAbnormalities();
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 5))) {
    yield await repository.getAllAbnormalities();
  }
}

final operationsReportProvider = Provider.autoDispose
    .family<AsyncValue<OperationsReport>, OperationsReportScope>((ref, scope) {
      ref.watch(operationsReportAuthorityLifecycleProvider);
      final actor = ref.watch(currentAppUserProvider);
      if (actor.isLoading) return const AsyncLoading();
      if (actor.hasError) {
        return AsyncError(actor.error!, actor.stackTrace ?? StackTrace.current);
      }
      final authorizedActor = actor.value;
      if (authorizedActor == null ||
          !authorizedActor.canViewReports ||
          authorizedActor.uid != scope.actorUid) {
        return AsyncError(
          StateError('Approved report access is required.'),
          StackTrace.current,
        );
      }
      final filter = scope.filter;
      final plan = filter.queryPlan;
      final periodScope = (
        actorUid: scope.actorUid,
        startInclusive: filter.startInclusive,
        endExclusive: filter.endExclusive,
      );
      final tickets = plan.includes(OperationsReportSource.issues)
          ? ref.watch(operationsReportTicketsProvider(periodScope))
          : const AsyncData<List<MaintenanceRecord>>([]);
      final executions = plan.includes(OperationsReportSource.plannedWork)
          ? ref.watch(operationsReportExecutionsProvider(periodScope))
          : const AsyncData<List<JobExecution>>([]);
      final executionBatch = plan.includes(OperationsReportSource.plannedWork)
          ? ref.watch(operationsReportExecutionBatchProvider(periodScope))
          : const AsyncData(
              DecodedSnapshotBatch<JobExecution>(
                records: [],
                rejectedDocumentIds: [],
              ),
            );
      final events = plan.includes(OperationsReportSource.disruptions)
          ? ref.watch(operationalEventsForReportsProvider(scope.actorUid))
          : const AsyncData<List<OperationalEvent>>([]);
      final dueStates = plan.includes(OperationsReportSource.cadence)
          ? ref.watch(maintenanceDueStatesProvider)
          : const AsyncData(
              DecodedSnapshotBatch<MaintenanceDueState>(
                records: [],
                rejectedDocumentIds: [],
              ),
            );
      final inspectionFindings =
          plan.includes(OperationsReportSource.inspections)
          ? ref.watch(allInspectionFindingsProvider)
          : const AsyncData<List<InspectionFinding>>([]);
      final qualityWarnings =
          plan.includes(OperationsReportSource.qualityWarnings)
          ? ref.watch(qualityWarningsForReportsProvider(scope.actorUid))
          : const AsyncData<List<QualityWarning>>([]);
      final qualityMonitoring = plan.includes(OperationsReportSource.monitoring)
          ? ref.watch(
              qualityMonitoringRequestsForReportsProvider(scope.actorUid),
            )
          : const AsyncData<List<QualityMonitoringRequest>>([]);
      final abnormalities = plan.includes(OperationsReportSource.abnormalities)
          ? ref.watch(operationsReportAbnormalitiesProvider(scope.actorUid))
          : const AsyncData<List<ChargeAbnormality>>([]);
      final directives = plan.includes(OperationsReportSource.directives)
          ? ref.watch(openDirectivesProvider)
          : const AsyncData<List<OperationalDirective>>([]);
      final workflowLanes = plan.includes(OperationsReportSource.workflowLanes)
          ? ref.watch(workflowAllLanesProvider)
          : const AsyncData<List<JobLaneRecord>>([]);
      final complianceRequests =
          plan.includes(OperationsReportSource.compliance)
          ? ref.watch(workflowAllComplianceProvider)
          : const AsyncData<List<ComplianceRequestRecord>>([]);
      final criticalAlarms = plan.includes(OperationsReportSource.alarms)
          ? ref.watch(criticalAlarmsForReportsProvider(scope.actorUid))
          : const AsyncData<List<CriticalAlarm>>([]);
      final classes = ref.watch(assetClassesProvider);
      final assets = ref.watch(allAssetInstancesProvider);
      final innerCovers = ref.watch(innerCoverProfilesProvider);
      final overview = plan.includes(OperationsReportSource.plantCondition)
          ? ref.watch(plantAssetOverviewProvider)
          : const AsyncData(PlantAssetOverview(classes: [], assets: []));
      final asOf =
          ref.watch(operationsReportClockProvider).value ?? DateTime.now();
      final error =
          tickets.asError ??
          executions.asError ??
          executionBatch.asError ??
          events.asError ??
          dueStates.asError ??
          inspectionFindings.asError ??
          qualityWarnings.asError ??
          qualityMonitoring.asError ??
          abnormalities.asError ??
          directives.asError ??
          workflowLanes.asError ??
          complianceRequests.asError ??
          criticalAlarms.asError ??
          classes.asError ??
          assets.asError ??
          innerCovers.asError ??
          overview.asError;
      if (error != null) return AsyncError(error.error, error.stackTrace);
      if (tickets.isLoading ||
          executions.isLoading ||
          executionBatch.isLoading ||
          events.isLoading ||
          dueStates.isLoading ||
          inspectionFindings.isLoading ||
          qualityWarnings.isLoading ||
          qualityMonitoring.isLoading ||
          abnormalities.isLoading ||
          directives.isLoading ||
          workflowLanes.isLoading ||
          complianceRequests.isLoading ||
          criticalAlarms.isLoading ||
          classes.isLoading ||
          assets.isLoading ||
          innerCovers.isLoading ||
          overview.isLoading) {
        return const AsyncLoading();
      }
      try {
        final identityWorkflows = <WorkflowAggregateRecord>[];
        final identityAbnormalities = <String, ChargeAbnormality?>{};
        _ReportIdentitySources identitySources = (
          executions: const [],
          tickets: const [],
        );
        if (filter.assetClassId != null || filter.assetInstanceId != null) {
          final identity = _ReportAssetIdentityMatcher(
            filter,
            classes.requireValue,
            assets.requireValue,
            innerCovers.requireValue,
          );
          for (final warning in qualityWarnings.requireValue.where(
            (warning) => _needsAbnormalityIdentity(warning, filter, identity),
          )) {
            final sources = ref.watch(
              operationsReportAbnormalityIdentityProvider((
                actorUid: scope.actorUid,
                sourceChargeNo: warning.sourceChargeNo,
              )),
            );
            if (sources.hasError) {
              return AsyncError(
                sources.error!,
                sources.stackTrace ?? StackTrace.current,
              );
            }
            if (sources.isLoading) return const AsyncLoading();
            final matches = sources.requireValue
                .where(
                  (source) =>
                      !source.isDeleted &&
                      source.firestoreId == warning.sourceId,
                )
                .toList();
            if (matches.length > 1) {
              throw StateError(
                'A quality warning has conflicting native abnormality sources.',
              );
            }
            // Explicit absence must mask the old cached row, so deleted or
            // inaccessible source identity cannot silently remain in a report.
            identityAbnormalities[warning.sourceId] = matches.isEmpty
                ? null
                : matches.single;
          }
          final workflowIds = <String>{
            for (final lane in workflowLanes.requireValue)
              if (!lane.isDeleted && lane.assetTypeKey == 'governedCustom')
                lane.workflowFirestoreId,
            for (final request in complianceRequests.requireValue)
              if (!request.isDeleted &&
                  request.assetTypeKey == 'governedCustom' &&
                  request.linkedWorkflowId != null)
                request.linkedWorkflowId!,
          };
          for (final id in workflowIds) {
            final workflow = ref.watch(workflowRecordProvider(id));
            if (workflow.hasError) {
              return AsyncError(
                workflow.error!,
                workflow.stackTrace ?? StackTrace.current,
              );
            }
            if (workflow.isLoading) return const AsyncLoading();
            if (workflow.value != null) identityWorkflows.add(workflow.value!);
          }
          final knownExecutionIds = executions.requireValue
              .map((item) => item.firestoreId)
              .toSet();
          final knownTicketIds = tickets.requireValue
              .map((item) => item.firestoreId)
              .toSet();
          final executionIds = <String>{
            for (final lane in workflowLanes.requireValue)
              if (!lane.isDeleted && lane.assetTypeKey == 'governedCustom')
                lane.jobExecutionFirestoreId,
            for (final request in complianceRequests.requireValue)
              if (!request.isDeleted &&
                  request.assetTypeKey == 'governedCustom' &&
                  request.linkedExecutionFirestoreId != null)
                request.linkedExecutionFirestoreId!,
            for (final workflow in identityWorkflows)
              workflow.jobExecutionFirestoreId,
          }.where((id) => !knownExecutionIds.contains(id)).toList()..sort();
          final ticketIds = <String>{
            for (final warning in qualityWarnings.requireValue)
              if (warning.sourceType == QualityWarningSourceType.issue &&
                  warning.affectedAssets.any(
                    (asset) =>
                        asset.assetType == 'governedCustom' &&
                        asset.assetHierarchyReference == null,
                  ))
                warning.sourceId,
            for (final request in complianceRequests.requireValue)
              if (!request.isDeleted &&
                  request.assetTypeKey == 'governedCustom' &&
                  request.linkedMaintenanceFirestoreId != null)
                request.linkedMaintenanceFirestoreId!,
          }.where((id) => !knownTicketIds.contains(id)).toList()..sort();
          if (executionIds.isNotEmpty || ticketIds.isNotEmpty) {
            final sources = ref.watch(
              operationsReportIdentitySourcesProvider((
                actorUid: scope.actorUid,
                period: periodScope,
                executionIds: jsonEncode(executionIds),
                ticketIds: jsonEncode(ticketIds),
              )),
            );
            if (sources.hasError) {
              return AsyncError(
                sources.error!,
                sources.stackTrace ?? StackTrace.current,
              );
            }
            if (sources.isLoading) return const AsyncLoading();
            identitySources = sources.requireValue;
          }
        }
        return AsyncData(
          buildOperationsReport(
            filter: filter,
            tickets: tickets.requireValue,
            executions: executions.requireValue,
            unreadableExecutionCount:
                executionBatch.requireValue.rejectedDocumentIds.length,
            sourceExecutionCount: executionBatch.requireValue.rawCount,
            identityExecutions: identitySources.executions,
            identityTickets: identitySources.tickets,
            identityWorkflows: identityWorkflows,
            identityAbnormalities: identityAbnormalities,
            events: events.requireValue,
            dueStates: dueStates.requireValue.records,
            unreadableDueStateCount:
                dueStates.requireValue.rejectedDocumentIds.length,
            inspectionFindings: inspectionFindings.requireValue,
            qualityWarnings: qualityWarnings.requireValue,
            qualityMonitoringRequests: qualityMonitoring.requireValue,
            abnormalities: abnormalities.requireValue,
            directives: directives.requireValue,
            workflowLanes: workflowLanes.requireValue,
            complianceRequests: complianceRequests.requireValue,
            criticalAlarms: criticalAlarms.requireValue,
            actor: authorizedActor,
            assetClasses: classes.requireValue,
            assetInstances: assets.requireValue,
            innerCoverProfiles: innerCovers.requireValue,
            overview: overview.requireValue,
            asOf: asOf,
          ),
        );
      } catch (error, stackTrace) {
        return AsyncError(error, stackTrace);
      }
    });

void _requireReportActorUid(String actorUid) {
  if (actorUid.trim().isEmpty) {
    throw StateError('An approved actor UID is required for report reads.');
  }
}
