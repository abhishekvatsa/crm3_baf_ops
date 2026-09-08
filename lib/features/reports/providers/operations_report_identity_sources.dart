part of 'operations_report_provider.dart';

// Owns actor-scoped observation and exact native-source reads for report
// identity joins. Period selection and report aggregation remain in the root;
// repositories retain persistence ownership.

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

final operationsReportAbnormalityIdentityProvider = StreamProvider.autoDispose
    .family<List<ChargeAbnormality>, ({String actorUid, int sourceChargeNo})>((
      ref,
      scope,
    ) {
      _requireReportActorUid(scope.actorUid);
      // Share the existing native charge watch between linked warnings. These
      // records supply exact identity only, never the report-period population.
      return ref
          .watch(abnormalityRepositoryProvider)
          .watchAbnormalitiesForCharge(scope.sourceChargeNo);
    });

bool _needsAbnormalityIdentity(
  QualityWarning warning,
  OperationsReportFilter filter,
  _ReportAssetIdentityMatcher identity,
) =>
    warning.sourceType == QualityWarningSourceType.abnormality &&
    warning.createdAt.isBefore(filter.endExclusive) &&
    (warning.closedAt == null ||
        warning.closedAt!.isAfter(filter.startInclusive)) &&
    warning.affectedAssets.any(
      (asset) =>
          asset.assetType == 'governedCustom' &&
          asset.assetHierarchyReference == null,
    ) &&
    !identity.warningMatchesOwnIdentity(warning);

// Shared by subscription eligibility and final report inclusion, so an already
// attributable mixed-asset warning does not depend on an unrelated source.
class _ReportAssetIdentityMatcher {
  _ReportAssetIdentityMatcher(
    OperationsReportFilter filter,
    List<AssetClassRecord> assetClasses,
    this.assetInstances,
  ) : assetInstanceId = filter.assetInstanceId,
      assetsById = {for (final asset in assetInstances) asset.id: asset} {
    final selectedAsset = assetsById[assetInstanceId];
    if (assetInstanceId != null && selectedAsset == null) {
      throw StateError('The selected physical asset is no longer available.');
    }
    if (filter.assetClassId != null &&
        selectedAsset != null &&
        selectedAsset.assetClassId != filter.assetClassId) {
      throw StateError(
        'The selected physical asset is outside the asset class.',
      );
    }
    effectiveClassId = filter.assetClassId ?? selectedAsset?.assetClassId;
    final candidates = <String, List<AssetClassRecord>>{};
    for (final item in assetClasses) {
      final key = item.legacyAssetTypeKey;
      if (key != null) candidates.putIfAbsent(key, () => []).add(item);
    }
    for (final entry in candidates.entries) {
      if (entry.value.length == 1) {
        legacyClasses[entry.key] = entry.value.single;
      }
    }
  }

  final String? assetInstanceId;
  final List<AssetInstanceRecord> assetInstances;
  final Map<String, AssetInstanceRecord> assetsById;
  final legacyClasses = <String, AssetClassRecord>{};
  late final String? effectiveClassId;

  bool matchesIdentity(String? classId, String? assetId) {
    if (effectiveClassId != null && classId != effectiveClassId) return false;
    if (assetInstanceId != null && assetId != assetInstanceId) return false;
    return true;
  }

  ({String? classId, String? assetId}) legacyIdentity(String type, int number) {
    final classId = legacyClasses[type]?.id;
    if (classId == null) return (classId: null, assetId: null);
    final matches = assetInstances
        .where(
          (asset) =>
              asset.assetClassId == classId && asset.assetNumber == number,
        )
        .map((asset) => asset.id)
        .toList(growable: false);
    if (matches.length > 1) {
      throw StateError('$type $number matches multiple physical assets.');
    }
    return (classId: classId, assetId: matches.firstOrNull);
  }

  ({String? classId, String? assetId}) referencedIdentity(
    AssetHierarchyReference reference,
    int number,
  ) {
    final asset = assetsById[reference.assetInstanceId];
    if (reference.assetInstanceId == null ||
        asset == null ||
        asset.assetClassId != reference.assetClassId ||
        asset.assetNumber != number ||
        reference.assetNumber != number) {
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

  bool warningMatchesOwnIdentity(QualityWarning warning) => warning
      .affectedAssets
      .where(
        (asset) =>
            asset.assetType != 'governedCustom' ||
            asset.assetHierarchyReference != null,
      )
      .any(
        (asset) => affectedAssetMatches(
          asset.assetType,
          asset.assetNumber,
          asset.assetHierarchyReference,
        ),
      );
}

final operationsReportExecutionIdentityChangesProvider = StreamProvider
    .autoDispose
    .family<List<JobExecution>, String>((ref, actorUid) {
      _requireReportActorUid(actorUid);
      // Web period queries exclude old completed/cancelled jobs. Observe their
      // changes too, without adding them to the report's period population.
      return ref.watch(plannedRepositoryProvider).watchAllExecutions();
    });

final operationsReportIdentitySourcesProvider = FutureProvider.autoDispose
    .family<_ReportIdentitySources, _ReportIdentityScope>((ref, scope) async {
      _requireReportActorUid(scope.actorUid);
      final executionIds = (jsonDecode(scope.executionIds) as List)
          .cast<String>();
      final ticketIds = (jsonDecode(scope.ticketIds) as List).cast<String>();
      final plannedRepository = executionIds.isEmpty
          ? null
          : ref.watch(plannedRepositoryProvider);
      final maintenanceRepository = ticketIds.isEmpty
          ? null
          : ref.watch(maintenanceRepositoryProvider);
      Future<List<JobExecution>>? executionObserverReady;
      // The source IDs alone are not a freshness key. The separate execution
      // observer covers historical records outside the web date-window queries.
      if (executionIds.isNotEmpty) {
        final observer = operationsReportExecutionIdentityChangesProvider(
          scope.actorUid,
        );
        final changes = ref.watch(observer);
        if (changes.hasError) {
          Error.throwWithStackTrace(
            changes.error!,
            changes.stackTrace ?? StackTrace.current,
          );
        }
        if (changes.isLoading) {
          executionObserverReady = ref.watch(observer.future);
        }
      }
      if (ticketIds.isNotEmpty) {
        // Maintenance period streams derive from the uncapped ticket watch on
        // both repositories, including updates outside the selected period.
        ref.watch(operationsReportTicketsProvider(scope.period));
      }
      if (executionObserverReady != null) await executionObserverReady;
      final executionRead = executionIds.isEmpty
          ? Future.value(<JobExecution>[])
          : plannedRepository!.getExecutionsByFirestoreIds(executionIds);
      final ticketRead = ticketIds.isEmpty
          ? Future.value(<MaintenanceRecord>[])
          : maintenanceRepository!.getTicketsByFirestoreIds(ticketIds);
      final sources = await Future.wait<Object>([executionRead, ticketRead]);
      return (
        executions: sources[0] as List<JobExecution>,
        tickets: sources[1] as List<MaintenanceRecord>,
      );
    });
