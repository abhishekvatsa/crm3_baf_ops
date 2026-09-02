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
        settings:
            screen is CriticalAlarmScreen
                ? const RouteSettings(name: CriticalAlarmScreen.routeName)
                : null,
        builder: (_) => screen,
      ),
    );
  }

  Future<void> _createPdfReport({
    required OperationsReport report,
    required String actorUid,
    required String actorName,
    required String actorEmail,
    required OperationsReportDocumentPreset initialPreset,
    required List<AssetClassRecord> classes,
    required List<AssetInstanceRecord> assets,
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

    var currentBurnerRounds = const <String, BurnerConditionRound>{};
    if (request.sections.contains(OperationsReportSection.burnerUvCondition) &&
        furnaceAssets.isNotEmpty) {
      final messenger = ScaffoldMessenger.of(context);
      final progress = messenger.showSnackBar(
        const SnackBar(
          duration: Duration(days: 1),
          content: Row(
            children: <Widget>[
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text('Loading current Burner and UV evidence...'),
              ),
            ],
          ),
        ),
      );
      try {
        currentBurnerRounds = await ref.read(
          latestBurnerConditionRoundsProvider(
            LatestBurnerConditionRoundsQuery(
              actorUid: actorUid,
              assetInstanceIds: furnaceAssets.map((asset) => asset.id),
            ),
          ).future,
        );
      } on Object catch (error) {
        progress.close();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'The current Burner and UV evidence could not be verified: $error',
            ),
            backgroundColor: BafColors.danger,
          ),
        );
        return;
      }
      progress.close();
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => OperationsReportPdfPreviewScreen(
              report: report,
              request: request,
              assetClassLabel: _assetClassScopeLabel(
                classes,
                selection.assetClassId,
              ),
              assetLabel: _assetScopeLabel(assets, selection.assetInstanceId),
              furnaceAssets: furnaceAssets,
              currentBurnerRounds: currentBurnerRounds,
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

String _assetClassScopeLabel(
  List<AssetClassRecord> classes,
  String? assetClassId,
) {
  if (assetClassId == null) return 'All asset classes';
  for (final assetClass in classes) {
    if (assetClass.id == assetClassId) return assetClass.name;
  }
  return 'Selected asset class';
}

String _assetScopeLabel(
  List<AssetInstanceRecord> assets,
  String? assetInstanceId,
) {
  if (assetInstanceId == null) return 'All assets in scope';
  for (final asset in assets) {
    if (asset.id == assetInstanceId) return asset.name;
  }
  return 'Selected asset';
}
