part of 'fleet_status_screen.dart';

extension _FleetStatusReportActions on _FleetStatusScreenState {
  List<Widget> _assuranceSections(OperationsReport report) => [
    const _SectionTitle(
      title: 'Maintenance assurance',
      subtitle: 'Cadence, inspection follow-through and verification',
    ),
    const SizedBox(height: BafSpacing.sm),
    _MetricGrid(
      metrics: [
        _MetricData(
          'Overdue cadence',
          report.overdueMaintenanceCount,
          Icons.event_busy_outlined,
          BafColors.danger,
        ),
        _MetricData(
          'Due in 7 days',
          report.dueSoonMaintenanceCount,
          Icons.upcoming_outlined,
          BafColors.warning,
        ),
        _MetricData(
          'Active findings',
          report.activeInspectionFindingCount,
          Icons.fact_check_outlined,
          BafColors.maintenance,
        ),
        _MetricData(
          'Awaiting verification',
          report.awaitingInspectionVerificationCount,
          Icons.verified_outlined,
          BafColors.planned,
        ),
        _MetricData(
          'Quality decisions',
          report.qualityClosureRequestCount,
          Icons.gavel_outlined,
          BafColors.charges,
        ),
        _MetricData(
          'RA follow-through',
          report.pendingReannealingCount,
          Icons.replay_circle_filled_outlined,
          BafColors.instrument,
        ),
      ],
    ),
    if (report.activeInspectionFindings.isNotEmpty) ...[
      const SizedBox(height: BafSpacing.xl),
      _InspectionFindingsSection(findings: report.activeInspectionFindings),
    ],
  ];

  void _open(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: screen is CriticalAlarmScreen
            ? const RouteSettings(name: CriticalAlarmScreen.routeName)
            : null,
        builder: (_) => screen,
      ),
    );
  }

  Future<void> _createPdfReport({
    required OperationsReportFilter filter,
    required String actorUid,
    required String actorName,
    required String actorEmail,
    required OperationsReportDocumentPreset initialPreset,
    required List<AssetClassRecord> classes,
    required List<AssetInstanceRecord> assets,
    required List<InnerCoverProfile> innerCovers,
    required OperationsReportSelection selection,
  }) async {
    final furnaceAssets = furnaceAssetsForOperationsReport(
      assetClasses: classes,
      assets: assets,
      selectedAssetClassId: selection.assetClassId,
      selectedAssetInstanceId: selection.assetInstanceId,
    );
    final provenance = readApplicationReportProvenance(
      ref,
      completenessNotes: const <String>[
        'Period-bound maintenance, planned-work, event, quality-warning, '
            'abnormality and alarm populations are not silently truncated by '
            'interactive-screen row limits.',
        'Current Burner and UV rows use the latest accepted condition round '
            'for each included Furnace and state its observation time.',
      ],
    );
    final request = await showOperationsReportComposer(
      context: context,
      generatedByName: actorName,
      generatedByEmail: actorEmail,
      hasFurnaceScope: furnaceAssets.isNotEmpty,
      provenance: provenance,
      initialPreset: initialPreset,
    );
    if (!mounted || request == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OperationsReportPreparationScreen(
          actorUid: actorUid,
          filter: OperationsReportFilter(
            startDate: filter.startDate,
            endDate: filter.endDate,
            assetClassId: filter.assetClassId,
            assetInstanceId: filter.assetInstanceId,
            subjectKind: filter.subjectKind,
            queryPlan: OperationsReportQueryPlan.forSections(request.sections),
          ),
          request: request,
        ),
      ),
    );
  }
}

OperationsReportDocumentPreset _recommendedReportPreset(AppUser actor) {
  if (actor.isAdmin || actor.isSI || actor.isShiftSupervisor) {
    return OperationsReportDocumentPreset.executive;
  }
  if (actor.isOperations) {
    return OperationsReportDocumentPreset.safetyAndDisruption;
  }
  if (actor.isContractSupervisor ||
      actor.isMechanical ||
      actor.isElectrical ||
      actor.isInstrumentation ||
      actor.isRefractory) {
    return OperationsReportDocumentPreset.maintenance;
  }
  return OperationsReportDocumentPreset.executive;
}

String operationsReportAssetScopeLabel(
  List<AssetInstanceRecord> assets,
  List<InnerCoverProfile> innerCovers,
  OperationsReportSelection selection,
) {
  final assetInstanceId = selection.nativeAssetId;
  if (assetInstanceId == null) return 'All assets in scope';
  if (selection.subjectKind == OperationsReportSubjectKind.innerCover) {
    for (final cover in innerCovers) {
      if (cover.id == assetInstanceId) {
        return 'Inner Cover ${cover.serialNumber}';
      }
    }
    return 'Selected serial cover';
  }
  for (final asset in assets) {
    if (asset.id == assetInstanceId) return asset.name;
  }
  return 'Selected asset';
}
