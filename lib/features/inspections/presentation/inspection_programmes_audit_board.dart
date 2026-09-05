part of 'inspection_programmes_screen.dart';

typedef _InspectionAuditTargetCallback =
    void Function(
      InspectionCampaignTarget target,
      InspectionObservation? currentObservation,
    );

class _InspectionAuditBoard extends StatefulWidget {
  const _InspectionAuditBoard({
    required this.campaign,
    required this.nodes,
    required this.observations,
    required this.canRecord,
    required this.onTargetPressed,
  });

  final InspectionCampaign campaign;
  final List<AssetHierarchyNode> nodes;
  final List<InspectionObservation> observations;
  final bool canRecord;
  final _InspectionAuditTargetCallback onTargetPressed;

  @override
  State<_InspectionAuditBoard> createState() => _InspectionAuditBoardState();
}

class _InspectionAuditBoardState extends State<_InspectionAuditBoard> {
  late final ScrollController _headerHorizontalController;
  late final ScrollController _bodyHorizontalController;
  late final ScrollController _verticalController;
  bool _synchronizingHorizontalScroll = false;

  @override
  void initState() {
    super.initState();
    _headerHorizontalController = ScrollController();
    _bodyHorizontalController = ScrollController();
    _verticalController = ScrollController();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
  }

  @override
  void dispose() {
    _headerHorizontalController
      ..removeListener(_syncHeaderToBody)
      ..dispose();
    _bodyHorizontalController
      ..removeListener(_syncBodyToHeader)
      ..dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() => _synchronizeHorizontalControllers(
    source: _headerHorizontalController,
    target: _bodyHorizontalController,
  );

  void _syncBodyToHeader() => _synchronizeHorizontalControllers(
    source: _bodyHorizontalController,
    target: _headerHorizontalController,
  );

  void _synchronizeHorizontalControllers({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_synchronizingHorizontalScroll ||
        !source.hasClients ||
        !target.hasClients ||
        !target.position.hasContentDimensions) {
      return;
    }
    final targetOffset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - targetOffset).abs() < 0.5) return;
    _synchronizingHorizontalScroll = true;
    target.jumpTo(targetOffset);
    _synchronizingHorizontalScroll = false;
  }

  @override
  Widget build(BuildContext context) {
    final nodesById = <String, AssetHierarchyNode>{
      for (final node in widget.nodes) node.id: node,
    };
    final axes = _auditAxes(widget.campaign.targets, nodesById);
    final rows = _auditRows(widget.campaign.targets, axes);
    final currentByTarget = _currentObservationByTarget(
      widget.campaign.targets,
      widget.observations,
    );
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final identityWidth = (164.0 * textScale).clamp(164.0, 224.0);
    final headerHeight = 58 * textScale.clamp(1.0, 1.5);
    final rowHeight = 68 * textScale.clamp(1.0, 1.5);
    const cellWidth = 118.0;
    final gridWidth = axes.length * cellWidth;
    final boardHeight = (headerHeight + rows.length * rowHeight).clamp(
      180.0,
      470.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BafSectionHeading(
          title: 'Fleet audit board',
          subtitle:
              '${rows.length} row${rows.length == 1 ? '' : 's'} · ${axes.length} governed check${axes.length == 1 ? '' : 's'}',
          icon: Icons.grid_on_rounded,
        ),
        const SizedBox(height: BafSpacing.md),
        Container(
          height: boardHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: BafColors.card,
            border: Border.all(color: BafColors.borderStrong),
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
          child: Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: Row(
                  children: [
                    Container(
                      key: const ValueKey('inspection-audit-fixed-corner'),
                      width: identityWidth,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: const BoxDecoration(
                        color: BafColors.surfaceStrong,
                        border: Border(
                          right: BorderSide(color: BafColors.borderStrong),
                          bottom: BorderSide(color: BafColors.border),
                        ),
                      ),
                      child: Text(
                        widget.campaign.populationMode ==
                                InspectionCampaignPopulationMode
                                    .installedInnerCoversByBase
                            ? 'Base (Inner Cover)'
                            : _assetTypeLabel(widget.campaign.assetTypeKey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        key: const ValueKey(
                          'inspection-audit-scrollable-header',
                        ),
                        controller: _headerHorizontalController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: gridWidth,
                          height: headerHeight,
                          child: Row(
                            children: [
                              for (final axis in axes)
                                Container(
                                  key: ValueKey(
                                    'inspection-audit-header-${axis.key}',
                                  ),
                                  width: cellWidth,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: BafColors.surfaceStrong,
                                    border: Border(
                                      right: BorderSide(
                                        color: BafColors.border,
                                      ),
                                      bottom: BorderSide(
                                        color: BafColors.border,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    axis.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _verticalController,
                  child: SingleChildScrollView(
                    key: const ValueKey('inspection-audit-vertical-scroll'),
                    controller: _verticalController,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          key: const ValueKey(
                            'inspection-audit-fixed-identity-column',
                          ),
                          width: identityWidth,
                          child: Column(
                            children: [
                              for (final row in rows)
                                _InspectionAuditRowLabel(
                                  row: row,
                                  height: rowHeight,
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            key: const ValueKey(
                              'inspection-audit-scrollable-grid',
                            ),
                            controller: _bodyHorizontalController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: gridWidth,
                              child: Column(
                                children: [
                                  for (final row in rows)
                                    SizedBox(
                                      height: rowHeight,
                                      child: Row(
                                        children: [
                                          for (final axis in axes)
                                            SizedBox(
                                              width: cellWidth,
                                              child:
                                                  row.targetsByAxis[axis.key] ==
                                                          null
                                                      ? const _InspectionAuditEmptyCell()
                                                      : _InspectionAuditCell(
                                                        target:
                                                            row.targetsByAxis[axis
                                                                .key]!,
                                                        observation:
                                                            currentByTarget[row
                                                                .targetsByAxis[axis
                                                                    .key]!
                                                                .targetKey],
                                                        canRecord:
                                                            widget.canRecord,
                                                        onPressed:
                                                            widget
                                                                .onTargetPressed,
                                                      ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InspectionAuditAxis {
  const _InspectionAuditAxis({required this.key, required this.label});

  final String key;
  final String label;
}

class _InspectionAuditRow {
  const _InspectionAuditRow({
    required this.key,
    required this.label,
    required this.number,
    required this.targetsByAxis,
  });

  final String key;
  final String label;
  final int number;
  final Map<String, InspectionCampaignTarget> targetsByAxis;
}

List<_InspectionAuditAxis> _auditAxes(
  List<InspectionCampaignTarget> targets,
  Map<String, AssetHierarchyNode> nodesById,
) {
  final result = <String, _InspectionAuditAxis>{};
  for (final target in targets) {
    final key = _inspectionAxisKey(target);
    final component =
        target.componentNodeId == null
            ? null
            : nodesById[target.componentNodeId!]?.name;
    final label = switch ((component, target.physicalPosition)) {
      (final String component, final String position) =>
        '$component · $position',
      (final String component, null) => component,
      (null, final String position) => position,
      _ => 'Result',
    };
    result.putIfAbsent(key, () => _InspectionAuditAxis(key: key, label: label));
  }
  return result.values.toList(growable: false);
}

List<_InspectionAuditRow> _auditRows(
  List<InspectionCampaignTarget> targets,
  List<_InspectionAuditAxis> axes,
) {
  final grouped = <String, List<InspectionCampaignTarget>>{};
  for (final target in targets) {
    final rowKey =
        target.hasInstalledInnerCoverContext
            ? '${target.hostAssetInstanceId}|${target.linkageId}'
            : target.assetInstanceId;
    grouped.putIfAbsent(rowKey, () => <InspectionCampaignTarget>[]).add(target);
  }
  final rows = grouped.entries
    .map((entry) {
      final first = entry.value.first;
      final byAxis = <String, InspectionCampaignTarget>{
        for (final target in entry.value) _inspectionAxisKey(target): target,
      };
      return _InspectionAuditRow(
        key: entry.key,
        label: first.rowLabel,
        number: first.hostAssetNumber ?? first.assetNumber,
        targetsByAxis: byAxis,
      );
    })
    .toList(growable: false)..sort((left, right) {
    final number = left.number.compareTo(right.number);
    return number != 0 ? number : left.label.compareTo(right.label);
  });
  return rows;
}

Map<String, InspectionObservation> _currentObservationByTarget(
  List<InspectionCampaignTarget> targets,
  List<InspectionObservation> observations,
) {
  final observationsById = <String, InspectionObservation>{
    for (final observation in observations) observation.id: observation,
  };
  final result = <String, InspectionObservation>{};
  final certifiedTargetKeys = <String>{};
  for (final target in targets) {
    final certified = observationsById[target.lastObservationId];
    if (certified != null && certified.targetKey == target.targetKey) {
      result[target.targetKey] = certified;
      certifiedTargetKeys.add(target.targetKey);
    }
  }
  for (final observation in observations) {
    if (certifiedTargetKeys.contains(observation.targetKey)) continue;
    final current = result[observation.targetKey];
    if (current == null || observation.observedAt.isAfter(current.observedAt)) {
      result[observation.targetKey] = observation;
    }
  }
  return result;
}

String _inspectionAxisKey(InspectionCampaignTarget target) =>
    '${target.componentNodeId ?? 'asset'}|${target.physicalPosition ?? '-'}';

class _InspectionAuditRowLabel extends StatelessWidget {
  const _InspectionAuditRowLabel({required this.row, required this.height});

  final _InspectionAuditRow row;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('inspection-audit-row-${row.key}'),
    height: height,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(
      color: BafColors.card,
      border: Border(
        right: BorderSide(color: BafColors.borderStrong),
        bottom: BorderSide(color: BafColors.border),
      ),
    ),
    child: Text(
      row.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

class _InspectionAuditEmptyCell extends StatelessWidget {
  const _InspectionAuditEmptyCell();

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: BafColors.surfaceStrong,
      border: Border(
        right: BorderSide(color: BafColors.border),
        bottom: BorderSide(color: BafColors.border),
      ),
    ),
    child: const Text(
      'Not in scope',
      textAlign: TextAlign.center,
      style: TextStyle(color: BafColors.textSecondary, fontSize: 10),
    ),
  );
}

class _InspectionAuditCell extends StatelessWidget {
  const _InspectionAuditCell({
    required this.target,
    required this.observation,
    required this.canRecord,
    required this.onPressed,
  });

  final InspectionCampaignTarget target;
  final InspectionObservation? observation;
  final bool canRecord;
  final _InspectionAuditTargetCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled =
        canRecord &&
        target.disposition != InspectionTargetDisposition.excludedWithReason &&
        target.disposition != InspectionTargetDisposition.unavailable;
    final color = switch (target.disposition) {
      InspectionTargetDisposition.observed => BafColors.success,
      InspectionTargetDisposition.pending => BafColors.instrument,
      InspectionTargetDisposition.deferred => BafColors.warning,
      InspectionTargetDisposition.unavailable => BafColors.textSecondary,
      InspectionTargetDisposition.excludedWithReason => BafColors.textSecondary,
      InspectionTargetDisposition.requiresReaudit => BafColors.danger,
    };
    final text =
        observation?.displayValue ??
        switch (target.disposition) {
          InspectionTargetDisposition.pending => 'Record',
          InspectionTargetDisposition.observed => 'Recorded',
          InspectionTargetDisposition.deferred => 'Deferred',
          InspectionTargetDisposition.unavailable => 'Unavailable',
          InspectionTargetDisposition.excludedWithReason => 'Excluded',
          InspectionTargetDisposition.requiresReaudit => 'Re-audit',
        };
    return Material(
      color: color.withValues(alpha: 0.055),
      child: InkWell(
        key: ValueKey('inspection-audit-cell-${target.targetKey}'),
        onTap: enabled ? () => onPressed(target, observation) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: BafColors.border),
              bottom: BorderSide(color: BafColors.border),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                observation != null
                    ? Icons.task_alt_rounded
                    : target.disposition == InspectionTargetDisposition.pending
                    ? Icons.add_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
