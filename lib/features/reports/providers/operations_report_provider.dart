import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../models/operations_report.dart';

export '../../../core/providers/operations_report_clock_provider.dart';

part 'operations_report_authority_lifecycle.dart';

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
typedef _ReportIdentityScope = ({
  String actorUid,
  OperationsReportPeriodScope period,
  String executionIds,
  String ticketIds,
});
typedef _ReportIdentitySources = ({
  List<JobExecution> executions,
  List<MaintenanceRecord> tickets,
});

final operationsReportIdentitySourcesProvider = FutureProvider.autoDispose
    .family<_ReportIdentitySources, _ReportIdentityScope>((ref, scope) async {
      _requireReportActorUid(scope.actorUid);
      final executionIds = (jsonDecode(scope.executionIds) as List)
          .cast<String>();
      final ticketIds = (jsonDecode(scope.ticketIds) as List).cast<String>();
      // Both period streams derive from uncapped repository watches, so they
      // also invalidate exact identity reads when an out-of-period source
      // arrives or is corrected. The source IDs alone are not a freshness key.
      if (executionIds.isNotEmpty) {
        ref.watch(operationsReportExecutionsProvider(scope.period));
      }
      if (ticketIds.isNotEmpty) {
        ref.watch(operationsReportTicketsProvider(scope.period));
      }
      final executionRead = executionIds.isEmpty
          ? Future.value(<JobExecution>[])
          : ref
                .watch(plannedRepositoryProvider)
                .getExecutionsByFirestoreIds(executionIds);
      final ticketRead = ticketIds.isEmpty
          ? Future.value(<MaintenanceRecord>[])
          : ref
                .watch(maintenanceRepositoryProvider)
                .getTicketsByFirestoreIds(ticketIds);
      final sources = await Future.wait<Object>([executionRead, ticketRead]);
      return (
        executions: sources[0] as List<JobExecution>,
        tickets: sources[1] as List<MaintenanceRecord>,
      );
    });

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

final operationsReportAbnormalitiesProvider = FutureProvider.autoDispose
    .family<List<ChargeAbnormality>, String>((ref, actorUid) {
      _requireReportActorUid(actorUid);
      return ref.watch(abnormalityRepositoryProvider).getAllAbnormalities();
    });

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
      final periodScope = (
        actorUid: scope.actorUid,
        startInclusive: filter.startInclusive,
        endExclusive: filter.endExclusive,
      );
      final tickets = ref.watch(operationsReportTicketsProvider(periodScope));
      final executions = ref.watch(
        operationsReportExecutionsProvider(periodScope),
      );
      final events = ref.watch(
        operationalEventsForReportsProvider(scope.actorUid),
      );
      final dueStates = ref.watch(maintenanceDueStatesProvider);
      final inspectionFindings = ref.watch(allInspectionFindingsProvider);
      final qualityWarnings = ref.watch(
        qualityWarningsForReportsProvider(scope.actorUid),
      );
      final qualityMonitoring = ref.watch(
        qualityMonitoringRequestsForReportsProvider(scope.actorUid),
      );
      final abnormalities = ref.watch(
        operationsReportAbnormalitiesProvider(scope.actorUid),
      );
      final directives = ref.watch(openDirectivesProvider);
      final workflowLanes = ref.watch(workflowAllLanesProvider);
      final complianceRequests = ref.watch(workflowAllComplianceProvider);
      final criticalAlarms = ref.watch(
        criticalAlarmsForReportsProvider(scope.actorUid),
      );
      final classes = ref.watch(assetClassesProvider);
      final assets = ref.watch(allAssetInstancesProvider);
      final innerCovers = ref.watch(innerCoverProfilesProvider);
      final overview = ref.watch(plantAssetOverviewProvider);
      final asOf =
          ref.watch(operationsReportClockProvider).value ?? DateTime.now();
      final error =
          tickets.asError ??
          executions.asError ??
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
        _ReportIdentitySources identitySources = (
          executions: const [],
          tickets: const [],
        );
        if (filter.assetClassId != null || filter.assetInstanceId != null) {
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
            identityExecutions: identitySources.executions,
            identityTickets: identitySources.tickets,
            identityWorkflows: identityWorkflows,
            events: events.requireValue,
            dueStates: dueStates.requireValue,
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

OperationsReport buildOperationsReport({
  required OperationsReportFilter filter,
  required List<MaintenanceRecord> tickets,
  required List<JobExecution> executions,
  List<JobExecution> identityExecutions = const [],
  List<MaintenanceRecord> identityTickets = const [],
  List<WorkflowAggregateRecord> identityWorkflows = const [],
  required List<OperationalEvent> events,
  List<MaintenanceDueState> dueStates = const [],
  List<InspectionFinding> inspectionFindings = const [],
  List<QualityWarning> qualityWarnings = const [],
  List<QualityMonitoringRequest> qualityMonitoringRequests = const [],
  List<ChargeAbnormality> abnormalities = const [],
  List<OperationalDirective> directives = const [],
  List<JobLaneRecord> workflowLanes = const [],
  List<ComplianceRequestRecord> complianceRequests = const [],
  List<CriticalAlarm> criticalAlarms = const [],
  AppUser? actor,
  required List<AssetClassRecord> assetClasses,
  required List<AssetInstanceRecord> assetInstances,
  List<InnerCoverProfile> innerCoverProfiles = const [],
  required PlantAssetOverview overview,
  DateTime? asOf,
}) {
  if (filter.endExclusive.isBefore(filter.startInclusive) ||
      filter.endExclusive == filter.startInclusive) {
    throw ArgumentError('The report end date must not precede its start date.');
  }
  final assetsById = {for (final item in assetInstances) item.id: item};
  final selectedAsset = filter.assetInstanceId == null
      ? null
      : assetsById[filter.assetInstanceId];
  if (filter.assetInstanceId != null && selectedAsset == null) {
    throw StateError('The selected physical asset is no longer available.');
  }
  if (filter.assetClassId != null &&
      selectedAsset != null &&
      selectedAsset.assetClassId != filter.assetClassId) {
    throw StateError('The selected physical asset is outside the asset class.');
  }
  final effectiveClassId = filter.assetClassId ?? selectedAsset?.assetClassId;
  final reportAsOf = asOf ?? DateTime.now();
  final legacyClassCandidates = <String, List<AssetClassRecord>>{};
  for (final item in assetClasses) {
    final key = item.legacyAssetTypeKey;
    if (key == null) continue;
    legacyClassCandidates.putIfAbsent(key, () => []).add(item);
  }
  final legacyClasses = <String, AssetClassRecord>{};
  for (final entry in legacyClassCandidates.entries) {
    if (entry.value.length == 1) legacyClasses[entry.key] = entry.value.single;
  }

  String? ticketClassId(MaintenanceRecord ticket) =>
      ticket.assetHierarchyReference?.assetClassId ??
      legacyClasses[ticket.assetType.name]?.id;

  String? ticketAssetId(MaintenanceRecord ticket) {
    final reference = ticket.assetHierarchyReference;
    if (reference?.assetInstanceId != null) return reference!.assetInstanceId;
    final classId = ticketClassId(ticket);
    if (classId == null) return null;
    return assetInstances
        .where(
          (asset) =>
              asset.assetClassId == classId &&
              asset.assetNumber == ticket.assetNumber,
        )
        .map((asset) => asset.id)
        .firstOrNull;
  }

  String? dueStateClassId(MaintenanceDueState state) =>
      state.assetClassId ?? legacyClasses[state.assetTypeKey]?.id;

  ({String? classId, String? assetId}) legacyIdentity(
    String assetTypeKey,
    int assetNumber,
  ) {
    final classId = legacyClasses[assetTypeKey]?.id;
    if (classId == null) return (classId: null, assetId: null);
    final matches = assetInstances
        .where(
          (asset) =>
              asset.assetClassId == classId && asset.assetNumber == assetNumber,
        )
        .map((asset) => asset.id)
        .toList(growable: false);
    if (matches.length > 1) {
      throw StateError(
        '$assetTypeKey $assetNumber matches multiple physical assets.',
      );
    }
    return (classId: classId, assetId: matches.firstOrNull);
  }

  String? dueStateAssetId(MaintenanceDueState state) {
    if (state.assetInstanceId != null) return state.assetInstanceId;
    final classId = dueStateClassId(state);
    if (classId == null) return null;
    final matches = assetInstances
        .where(
          (asset) =>
              asset.assetClassId == classId &&
              asset.assetNumber == state.assetNumber,
        )
        .map((asset) => asset.id)
        .toList(growable: false);
    if (matches.length > 1) {
      throw StateError(
        'Maintenance due state ${state.id} matches multiple physical assets.',
      );
    }
    return matches.firstOrNull;
  }

  final executionIdentityCache =
      <JobExecution, ({String? classId, String? assetId})>{};

  ({String? classId, String? assetId}) executionIdentity(
    JobExecution execution,
  ) => executionIdentityCache.putIfAbsent(execution, () {
    final physicalIdentity = execution.assignmentPhysicalAssetIdentity;
    final reference = execution.assignmentAssetHierarchyReference;
    final classId =
        physicalIdentity?.assetClassId ??
        reference?.assetClassId ??
        legacyClasses[execution.assetType.name]?.id;
    if (classId == null &&
        execution.assetType == AssetType.governedCustom &&
        execution.isGovernedTemplateAssignment) {
      throw StateError(
        'Governed custom execution ${execution.firestoreId ?? execution.id} '
        'has no published asset hierarchy reference.',
      );
    }
    if (classId == null) return (classId: null, assetId: null);

    final referencedAssetId =
        physicalIdentity?.assetInstanceId ?? reference?.assetInstanceId;
    if (referencedAssetId != null) {
      final referencedAsset = assetsById[referencedAssetId];
      if (referencedAsset == null ||
          referencedAsset.assetClassId != classId ||
          referencedAsset.assetNumber != execution.assetNumber) {
        throw StateError(
          'Execution ${execution.firestoreId ?? execution.id} has '
          'inconsistent governed physical-asset identity.',
        );
      }
      return (classId: classId, assetId: referencedAssetId);
    }
    final matchingAssetIds = assetInstances
        .where(
          (asset) =>
              asset.assetClassId == classId &&
              asset.assetNumber == execution.assetNumber,
        )
        .map((asset) => asset.id)
        .toList(growable: false);
    if (matchingAssetIds.length > 1) {
      throw StateError(
        'Execution ${execution.firestoreId ?? execution.id} matches multiple '
        'physical assets in class $classId.',
      );
    }
    return (classId: classId, assetId: matchingAssetIds.firstOrNull);
  });

  String? executionClassId(JobExecution execution) =>
      executionIdentity(execution).classId;

  String? executionAssetId(JobExecution execution) =>
      executionIdentity(execution).assetId;

  bool matchesIdentity(String? classId, String? assetId) {
    if (effectiveClassId != null && classId != effectiveClassId) {
      return false;
    }
    if (filter.assetInstanceId != null && assetId != filter.assetInstanceId) {
      return false;
    }
    return true;
  }

  bool overlaps(DateTime start, DateTime? end) =>
      start.isBefore(filter.endExclusive) &&
      (end == null || end.isAfter(filter.startInclusive));

  final filteredTickets = tickets
      .where(
        (ticket) =>
            overlaps(ticket.startDate, ticket.endDate) &&
            matchesIdentity(ticketClassId(ticket), ticketAssetId(ticket)),
      )
      .toList();
  final filteredExecutions = executions
      .where(
        (execution) =>
            overlaps(
              execution.createdAt,
              execution.completedAt ?? execution.cancelledAt,
            ) &&
            matchesIdentity(
              executionClassId(execution),
              executionAssetId(execution),
            ),
      )
      .toList();
  final filteredDueStates = dueStates
      .where(
        (state) =>
            matchesIdentity(dueStateClassId(state), dueStateAssetId(state)),
      )
      .toList();
  bool isActiveFinding(InspectionFinding finding) => {
    InspectionFindingStatus.open,
    InspectionFindingStatus.correctiveActionLinked,
    InspectionFindingStatus.awaitingVerification,
  }.contains(finding.status);
  final filteredInspectionFindings =
      inspectionFindings
          .where(
            (finding) =>
                matchesIdentity(
                  finding.assetClassId,
                  finding.assetInstanceId,
                ) &&
                (isActiveFinding(finding) ||
                    (finding.latestObservedAt.isBefore(filter.endExclusive) &&
                        !finding.latestObservedAt.isBefore(
                          filter.startInclusive,
                        ))),
          )
          .toList()
        ..sort((left, right) {
          final activeOrder = (isActiveFinding(right) ? 1 : 0).compareTo(
            isActiveFinding(left) ? 1 : 0,
          );
          return activeOrder != 0
              ? activeOrder
              : right.updatedAt.compareTo(left.updatedAt);
        });

  bool legacyRecordMatches(String assetTypeKey, int assetNumber) {
    final identity = legacyIdentity(assetTypeKey, assetNumber);
    return matchesIdentity(identity.classId, identity.assetId);
  }

  ({String? classId, String? assetId}) referencedIdentity(
    AssetHierarchyReference reference,
    int assetNumber,
  ) {
    final asset = assetsById[reference.assetInstanceId];
    if (reference.assetInstanceId == null ||
        asset == null ||
        asset.assetClassId != reference.assetClassId ||
        asset.assetNumber != assetNumber ||
        reference.assetNumber != assetNumber) {
      throw StateError(
        'A report source has inconsistent physical-asset identity.',
      );
    }
    return (classId: reference.assetClassId, assetId: asset.id);
  }

  bool affectedAssetMatches(
    String type,
    int number,
    AssetHierarchyReference? reference,
  ) {
    final identity = reference == null
        ? legacyIdentity(type, number)
        : referencedIdentity(reference, number);
    if (type == 'governedCustom' && identity.classId == null) {
      throw StateError(
        'A custom-asset report source lacks a verifiable native '
        'asset reference. Its identity must be restored before filtering.',
      );
    }
    return matchesIdentity(identity.classId, identity.assetId);
  }

  final identityTicketsById = {
    for (final ticket in [...identityTickets, ...tickets])
      if (ticket.firestoreId != null) ticket.firestoreId!: ticket,
  };
  final identityExecutionsById = {
    for (final execution in [...identityExecutions, ...executions])
      if (execution.firestoreId != null) execution.firestoreId!: execution,
  };
  final identityWorkflowsById = {
    for (final workflow in identityWorkflows) workflow.firestoreId: workflow,
  };
  final abnormalitiesById = {
    for (final abnormality in abnormalities)
      if (abnormality.firestoreId != null)
        abnormality.firestoreId!: abnormality,
  };

  bool affectedAssetsMatch(QualityWarning warning) {
    if (effectiveClassId == null && filter.assetInstanceId == null) return true;
    return warning.affectedAssets.any((asset) {
      if (asset.assetHierarchyReference != null ||
          asset.assetType != 'governedCustom') {
        return affectedAssetMatches(
          asset.assetType,
          asset.assetNumber,
          asset.assetHierarchyReference,
        );
      }
      if (warning.sourceType == QualityWarningSourceType.issue) {
        final source = identityTicketsById[warning.sourceId];
        if (source != null &&
            source.assetType.name == asset.assetType &&
            source.assetNumber == asset.assetNumber) {
          return affectedAssetMatches(
            asset.assetType,
            asset.assetNumber,
            source.assetHierarchyReference,
          );
        }
      } else {
        final sourceAssets =
            abnormalitiesById[warning.sourceId]?.affectedAssets
                .where(
                  (source) =>
                      source.assetType.name == asset.assetType &&
                      source.assetNumber == asset.assetNumber,
                )
                .toList() ??
            const [];
        if (sourceAssets.isNotEmpty) {
          return sourceAssets.any(
            (source) => affectedAssetMatches(
              source.assetType.name,
              source.assetNumber,
              source.assetHierarchyReference,
            ),
          );
        }
      }
      throw StateError(
        'Quality warning ${warning.warningId} has no verifiable '
        'custom-asset identity in its native source.',
      );
    });
  }

  final filteredQualityWarnings =
      qualityWarnings
          .where(
            (warning) =>
                overlaps(warning.createdAt, warning.closedAt) &&
                affectedAssetsMatch(warning),
          )
          .toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  final filteredQualityMonitoring =
      qualityMonitoringRequests
          .where(
            (request) =>
                overlaps(request.createdAt, request.closedAt) &&
                legacyRecordMatches('base', request.baseNumber),
          )
          .toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

  bool abnormalityMatchesIdentity(ChargeAbnormality abnormality) {
    if (effectiveClassId == null && filter.assetInstanceId == null) return true;
    return abnormality.affectedAssets.any(
      (asset) => affectedAssetMatches(
        asset.assetType.name,
        asset.assetNumber,
        asset.assetHierarchyReference,
      ),
    );
  }

  final filteredAbnormalities =
      abnormalities
          .where(
            (record) =>
                !record.isDeleted &&
                !record.loggedAt.isBefore(filter.startInclusive) &&
                record.loggedAt.isBefore(filter.endExclusive) &&
                abnormalityMatchesIdentity(record),
          )
          .toList()
        ..sort((left, right) => right.loggedAt.compareTo(left.loggedAt));

  bool directiveMatchesIdentity(OperationalDirective directive) {
    if (effectiveClassId == null && filter.assetInstanceId == null) return true;
    final type = directive.assetType;
    final number = directive.assetNumber;
    return type != null &&
        number != null &&
        legacyRecordMatches(type.name, number);
  }

  final filteredDirectives =
      directives
          .where(
            (directive) =>
                !directive.isDeleted &&
                !directive.isClosed &&
                (actor == null || canUserSeeDirective(directive, actor)) &&
                directiveMatchesIdentity(directive),
          )
          .toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

  bool workflowRecordVisible(String laneKey, {String? raisedByUid}) =>
      actor == null ||
      actor.isAdmin ||
      actor.isSI ||
      actor.canAcknowledgeOrWorkMaintenanceLane(laneKey) ||
      (raisedByUid != null && raisedByUid == actor.uid);

  bool workflowIdentityMatches({
    required String type,
    required int number,
    String? workflowId,
    String? executionId,
    String? ticketId,
  }) {
    if (effectiveClassId == null && filter.assetInstanceId == null) return true;
    final workflow = identityWorkflowsById[workflowId];
    final execution =
        identityExecutionsById[executionId ??
            workflow?.jobExecutionFirestoreId];
    final ticket = identityTicketsById[ticketId];
    final candidates = <({String? classId, String? assetId})>[];
    if (workflow?.assetClassId != null && workflow?.assetInstanceId != null) {
      final asset = assetsById[workflow!.assetInstanceId];
      if (asset == null ||
          asset.assetClassId != workflow.assetClassId ||
          asset.assetNumber != number ||
          workflow.assetNumber != number ||
          workflow.assetTypeKey != type) {
        throw StateError(
          'Workflow $workflowId has inconsistent physical-asset identity.',
        );
      }
      candidates.add((classId: workflow.assetClassId, assetId: asset.id));
    }
    if (execution != null) {
      if (execution.assetNumber != number ||
          execution.assetType.name != type ||
          (workflow != null &&
              workflow.jobExecutionFirestoreId != execution.firestoreId)) {
        throw StateError(
          'A workflow report source refers to a different execution asset.',
        );
      }
      candidates.add(executionIdentity(execution));
    }
    if (ticket != null) {
      if (ticket.assetNumber != number || ticket.assetType.name != type) {
        throw StateError(
          'A compliance report source refers to a different issue asset.',
        );
      }
      final reference = ticket.assetHierarchyReference;
      candidates.add(
        reference == null
            ? legacyIdentity(type, number)
            : referencedIdentity(reference, number),
      );
    }
    final verified = candidates
        .where((item) => item.classId != null && item.assetId != null)
        .toSet();
    if (verified.length > 1) {
      throw StateError(
        'A workflow report source has conflicting native asset references.',
      );
    }
    final identity = verified.firstOrNull ?? legacyIdentity(type, number);
    if (type == 'governedCustom' && identity.classId == null) {
      throw StateError(
        'A custom workflow source lacks a verifiable native asset reference.',
      );
    }
    return matchesIdentity(identity.classId, identity.assetId);
  }

  final filteredWorkflowLanes =
      workflowLanes
          .where(
            (lane) =>
                !lane.isDeleted &&
                workflowRecordVisible(lane.laneKey) &&
                workflowIdentityMatches(
                  type: lane.assetTypeKey,
                  number: lane.assetNumber,
                  workflowId: lane.workflowFirestoreId,
                  executionId: lane.jobExecutionFirestoreId,
                ),
          )
          .toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  final filteredComplianceRequests =
      complianceRequests
          .where(
            (request) =>
                !request.isDeleted &&
                (actor == null ||
                    isComplianceRequestRelevantToUser(request, actor)) &&
                workflowIdentityMatches(
                  type: request.assetTypeKey,
                  number: request.assetNumber,
                  workflowId: request.linkedWorkflowId,
                  executionId: request.linkedExecutionFirestoreId,
                  ticketId: request.linkedMaintenanceFirestoreId,
                ),
          )
          .toList()
        ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));

  bool criticalAlarmMatchesIdentity(CriticalAlarm alarm) {
    if (effectiveClassId == null && filter.assetInstanceId == null) return true;
    final assetTypeKey = alarm.assetTypeKey;
    final assetNumber = alarm.assetNumber;
    return assetTypeKey != null &&
        assetNumber != null &&
        legacyRecordMatches(assetTypeKey, assetNumber);
  }

  final filteredCriticalAlarms =
      criticalAlarms
          .where(
            (alarm) =>
                overlaps(
                  alarm.raisedAt,
                  alarm.resolvedAt ?? alarm.withdrawnAt,
                ) &&
                criticalAlarmMatchesIdentity(alarm),
          )
          .toList()
        ..sort((left, right) => right.raisedAt.compareTo(left.raisedAt));

  bool isOverdue(MaintenanceDueState state) =>
      state.nextDueAt != null && state.nextDueAt!.isBefore(reportAsOf);
  bool isDueSoon(MaintenanceDueState state) {
    final dueAt = state.nextDueAt;
    return dueAt != null &&
        !dueAt.isBefore(reportAsOf) &&
        !dueAt.isAfter(reportAsOf.add(const Duration(days: 7)));
  }

  bool occurrenceMatchesIdentity(OperationalEventInterval occurrence) {
    if (occurrence.scope == OperationalEventScope.plantWide) return true;
    if (filter.assetInstanceId != null) {
      if (occurrence.scope == OperationalEventScope.assets) {
        return occurrence.affectedAssetInstanceIds.contains(
          filter.assetInstanceId,
        );
      }
      final selectedAsset = assetsById[filter.assetInstanceId];
      return selectedAsset != null &&
          occurrence.affectedAssetClassIds.contains(selectedAsset.assetClassId);
    }
    if (effectiveClassId != null) {
      if (occurrence.affectedAssetClassIds.contains(effectiveClassId)) {
        return true;
      }
      return occurrence.affectedAssetInstanceIds.any(
        (id) => assetsById[id]?.assetClassId == effectiveClassId,
      );
    }
    return true;
  }

  bool occurrenceMatchesReport(OperationalEventInterval occurrence) =>
      occurrence.overlaps(filter.startInclusive, filter.endExclusive) &&
      occurrenceMatchesIdentity(occurrence);

  bool eventMatches(OperationalEvent event) =>
      event.occurrencesUntil(reportAsOf).any(occurrenceMatchesReport);

  final filteredEvents = events.where(eventMatches).toList();
  final filteredOccurrences = <OperationalEventReportOccurrence>[];
  for (final event in events) {
    final occurrences = event.occurrencesUntil(reportAsOf).toList();
    for (var index = 0; index < occurrences.length; index++) {
      final occurrence = occurrences[index];
      if (!occurrenceMatchesReport(occurrence)) continue;
      filteredOccurrences.add(
        OperationalEventReportOccurrence(
          event: event,
          interval: occurrence,
          isCurrent: index == occurrences.length - 1,
        ),
      );
    }
  }
  filteredOccurrences.sort(
    (left, right) =>
        right.interval.startedAt.compareTo(left.interval.startedAt),
  );
  final filteredStates = overview.assets
      .where(
        (state) => matchesIdentity(state.asset.assetClassId, state.asset.id),
      )
      .toList();
  final inventory = buildOperationsReportAssetInventory(
    assetClasses: assetClasses,
    assetStates: filteredStates,
    innerCoverProfiles: innerCoverProfiles,
    selectedAssetClassId: effectiveClassId,
    selectedAssetInstanceId: filter.assetInstanceId,
  );

  List<CountedReportLabel> rank(
    _ReportDimension? Function(MaintenanceRecord) value,
  ) {
    final dimensions = <String, _ReportDimension>{};
    final counts = <String, int>{};
    for (final ticket in filteredTickets) {
      final dimension = value(ticket);
      if (dimension == null) continue;
      dimensions.putIfAbsent(dimension.key, () => dimension);
      counts.update(dimension.key, (count) => count + 1, ifAbsent: () => 1);
    }
    final labelOccurrences = <String, int>{};
    for (final dimension in dimensions.values) {
      final normalizedLabel = dimension.label.toLowerCase();
      labelOccurrences.update(
        normalizedLabel,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final result =
        counts.entries.map((entry) {
          final dimension = dimensions[entry.key]!;
          final duplicateLabel =
              labelOccurrences[dimension.label.toLowerCase()]! > 1;
          return CountedReportLabel(
            label: duplicateLabel
                ? '${dimension.label} · ${dimension.disambiguator}'
                : dimension.label,
            count: entry.value,
          );
        }).toList()..sort((left, right) {
          final count = right.count.compareTo(left.count);
          return count != 0
              ? count
              : left.label.toLowerCase().compareTo(right.label.toLowerCase());
        });
    return List<CountedReportLabel>.unmodifiable(result.take(8));
  }

  _ReportDimension? componentDimension(MaintenanceRecord ticket) {
    final reference = ticket.assetHierarchyReference;
    if (reference != null) {
      final componentPath = reference.hierarchyPath
          .map((segment) => segment.trim())
          .where((segment) => segment.isNotEmpty)
          .join(' / ');
      return (
        disambiguator: 'ref ${reference.assetClassId}/${reference.nodeId}',
        key: 'governed:${reference.assetClassId}:${reference.nodeId}',
        label:
            '${reference.assetClassName} - '
            '${componentPath.isEmpty ? reference.nodeName : componentPath}',
      );
    }
    final legacyLabel =
        ticket.component ??
        (ticket.hierarchyPath?.isNotEmpty == true
            ? ticket.hierarchyPath!.last
            : null);
    if (legacyLabel?.trim().isNotEmpty != true) return null;
    return (
      disambiguator: 'legacy',
      key: 'legacy-unmapped-component',
      label: 'Unmapped legacy component',
    );
  }

  _ReportDimension? recordedSubsystemPathDimension(MaintenanceRecord ticket) {
    final reference = ticket.assetHierarchyReference;
    if (reference != null && reference.hierarchyPath.length > 1) {
      final parentPath = reference.hierarchyPath.sublist(
        0,
        reference.hierarchyPath.length - 1,
      );
      final normalizedSegments = parentPath
          .map((segment) => segment.trim())
          .toList(growable: false);
      final encodedPath = jsonEncode(normalizedSegments);
      return (
        disambiguator: 'path $encodedPath',
        key: 'recorded-path:${reference.assetClassId}:$encodedPath',
        label:
            'Recorded path - ${reference.assetClassName} - '
            '${normalizedSegments.join(' > ')}',
      );
    }
    final hasLegacySubsystem =
        ticket.subsystem?.trim().isNotEmpty == true ||
        (ticket.hierarchyPath != null && ticket.hierarchyPath!.length > 1);
    if (!hasLegacySubsystem) return null;
    return (
      disambiguator: 'legacy',
      key: 'legacy-unmapped-subsystem-path',
      label: 'Unmapped legacy subsystem path',
    );
  }

  bool occurrenceAffectsClass(
    OperationalEventInterval occurrence,
    String classId,
  ) =>
      occurrence.scope == OperationalEventScope.plantWide ||
      occurrence.affectedAssetClassIds.contains(classId) ||
      occurrence.affectedAssetInstanceIds.any(
        (id) => assetsById[id]?.assetClassId == classId,
      );

  bool occurrenceMatchesClassSummary(
    OperationalEventInterval occurrence,
    String classId,
  ) =>
      occurrence.overlaps(filter.startInclusive, filter.endExclusive) &&
      (filter.assetInstanceId != null
          ? occurrenceMatchesIdentity(occurrence)
          : occurrenceAffectsClass(occurrence, classId));

  final selectedClasses = assetClasses
      .where(
        (assetClass) =>
            assetClass.isActive &&
            (effectiveClassId == null || assetClass.id == effectiveClassId),
      )
      .toList();
  final classSummaries =
      selectedClasses.map((assetClass) {
        final states = filteredStates
            .where((state) => state.asset.assetClassId == assetClass.id)
            .toList();
        final classTickets = filteredTickets
            .where((ticket) => ticketClassId(ticket) == assetClass.id)
            .toList();
        final classExecutions = filteredExecutions
            .where((execution) => executionClassId(execution) == assetClass.id)
            .toList();
        final classDueStates = filteredDueStates
            .where((state) => dueStateClassId(state) == assetClass.id)
            .toList();
        final classFindings = filteredInspectionFindings
            .where((finding) => finding.assetClassId == assetClass.id)
            .toList();
        final classInventory = inventory.forAssetClass(
          assetClass: assetClass,
          assetStates: states,
        );
        return AssetClassReportSummary(
          assetClassId: assetClass.id,
          assetClassName: assetClass.name,
          assetCount: classInventory.total,
          availableCount: classInventory.available,
          underMaintenanceCount: classInventory.underMaintenance,
          downCount: classInventory.down,
          unfitCount: classInventory.unfit,
          issueCount: classTickets.length,
          openIssueCount: classTickets
              .where((ticket) => !ticket.isResolved)
              .length,
          plannedJobCount: classExecutions.length,
          openPlannedJobCount: classExecutions
              .where((job) => !job.isCompleted && !job.isCancelled)
              .length,
          disruptionCount: events
              .expand((event) => event.occurrencesUntil(reportAsOf))
              .where(
                (occurrence) =>
                    occurrenceMatchesClassSummary(occurrence, assetClass.id),
              )
              .length,
          overdueMaintenanceCount: classDueStates.where(isOverdue).length,
          dueSoonMaintenanceCount: classDueStates.where(isDueSoon).length,
          activeInspectionFindingCount: classFindings
              .where(isActiveFinding)
              .length,
        );
      }).toList()..sort(
        (left, right) => left.assetClassName.toLowerCase().compareTo(
          right.assetClassName.toLowerCase(),
        ),
      );

  return OperationsReport(
    filter: filter,
    asOf: reportAsOf,
    tickets: List<MaintenanceRecord>.unmodifiable(filteredTickets),
    executions: List<JobExecution>.unmodifiable(filteredExecutions),
    events: List<OperationalEvent>.unmodifiable(filteredEvents),
    eventOccurrences: List<OperationalEventReportOccurrence>.unmodifiable(
      filteredOccurrences,
    ),
    dueStates: List<MaintenanceDueState>.unmodifiable(filteredDueStates),
    inspectionFindings: List<InspectionFinding>.unmodifiable(
      filteredInspectionFindings,
    ),
    assetStates: inventory.numberedAssetStates,
    innerCoverProfiles: inventory.innerCovers,
    classSummaries: List<AssetClassReportSummary>.unmodifiable(classSummaries),
    topComponents: rank(componentDimension),
    topSubsystemPaths: rank(recordedSubsystemPathDimension),
    sourceTicketCount: tickets.length,
    sourceExecutionCount: executions.length,
    sourceEventCount: events.length,
    sourceDueStateCount: dueStates.length,
    sourceInspectionFindingCount: inspectionFindings.length,
    disruptionCount: filteredOccurrences.length,
    openDisruptionCount: filteredOccurrences
        .where((occurrence) => occurrence.isOpen)
        .length,
    disruptionDuration: filteredOccurrences.fold(
      Duration.zero,
      (total, occurrence) =>
          total +
          occurrence.interval.durationWithin(
            filter.startInclusive,
            filter.endExclusive,
          ),
    ),
    inventoryAssetCount: inventory.total,
    inventoryAvailableAssetCount: inventory.available,
    inventoryUnderMaintenanceAssetCount: inventory.underMaintenance,
    inventoryDownAssetCount: inventory.down,
    inventoryUnfitAssetCount: inventory.unfit,
    qualityWarnings: List<QualityWarning>.unmodifiable(filteredQualityWarnings),
    qualityMonitoringRequests: List<QualityMonitoringRequest>.unmodifiable(
      filteredQualityMonitoring,
    ),
    abnormalities: List<ChargeAbnormality>.unmodifiable(filteredAbnormalities),
    directives: List<OperationalDirective>.unmodifiable(filteredDirectives),
    workflowLanes: List<JobLaneRecord>.unmodifiable(filteredWorkflowLanes),
    complianceRequests: List<ComplianceRequestRecord>.unmodifiable(
      filteredComplianceRequests,
    ),
    criticalAlarms: List<CriticalAlarm>.unmodifiable(filteredCriticalAlarms),
    sourceQualityWarningCount: qualityWarnings.length,
    sourceQualityMonitoringCount: qualityMonitoringRequests.length,
    sourceAbnormalityCount: abnormalities.length,
    sourceDirectiveCount: directives.length,
    sourceWorkflowLaneCount: workflowLanes.length,
    sourceComplianceRequestCount: complianceRequests.length,
    sourceCriticalAlarmCount: criticalAlarms.length,
  );
}
