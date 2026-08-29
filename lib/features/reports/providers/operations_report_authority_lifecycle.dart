part of 'operations_report_provider.dart';

/// Clears retained report inputs whenever the approved actor session changes.
///
/// The app root watches this provider continuously. Keeping it non-auto-dispose
/// ensures that a sign-out, revocation, or direct account switch is observed
/// even when no report screen is mounted.
final operationsReportAuthorityLifecycleProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (previous, next) {
    final previousActor = previous?.asData?.value;
    if (previousActor == null) return;
    final nextActor = next.asData?.value;
    if (nextActor?.uid == previousActor.uid &&
        nextActor?.canViewReports == true) {
      return;
    }
    ref.invalidate(operationsReportTicketsProvider);
    ref.invalidate(operationsReportExecutionsProvider);
    ref.invalidate(operationalEventsForReportsProvider);
    if (ref.exists(maintenanceDueStatesProvider)) {
      ref.invalidate(maintenanceDueStatesProvider);
    }
    if (ref.exists(allInspectionFindingsProvider)) {
      ref.invalidate(allInspectionFindingsProvider);
    }
    if (ref.exists(qualityWarningsForReportsProvider)) {
      ref.invalidate(qualityWarningsForReportsProvider);
    }
    if (ref.exists(qualityMonitoringRequestsForReportsProvider)) {
      ref.invalidate(qualityMonitoringRequestsForReportsProvider);
    }
    ref.invalidate(operationsReportAbnormalitiesProvider);
    if (ref.exists(openDirectivesProvider)) {
      ref.invalidate(openDirectivesProvider);
    }
    if (ref.exists(workflowAllLanesProvider)) {
      ref.invalidate(workflowAllLanesProvider);
    }
    if (ref.exists(workflowAllComplianceProvider)) {
      ref.invalidate(workflowAllComplianceProvider);
    }
    if (ref.exists(assetClassesProvider)) {
      ref.invalidate(assetClassesProvider);
    }
    if (ref.exists(allAssetInstancesProvider)) {
      ref.invalidate(allAssetInstancesProvider);
    }
    if (ref.exists(innerCoverProfilesProvider)) {
      ref.invalidate(innerCoverProfilesProvider);
    }
    if (ref.exists(assetOperationalConditionsProvider)) {
      ref.invalidate(assetOperationalConditionsProvider);
    }
    if (ref.exists(equipmentStatusProvider(null))) {
      ref.invalidate(equipmentStatusProvider(null));
    }
    if (ref.exists(plantAssetOverviewProvider)) {
      ref.invalidate(plantAssetOverviewProvider);
    }
    ref.invalidate(burnerConditionRoundsProvider);
    if (ref.exists(burnerConditionRoundCacheTrustProvider)) {
      ref.invalidate(burnerConditionRoundCacheTrustProvider);
    }
    if (ref.exists(criticalAlarmsForReportsProvider)) {
      ref.invalidate(criticalAlarmsForReportsProvider);
    }
    if (ref.exists(operationsReportClockProvider)) {
      ref.invalidate(operationsReportClockProvider);
    }
  });
});
