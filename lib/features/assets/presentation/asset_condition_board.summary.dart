part of 'asset_condition_board.dart';

/// Home keeps each equipment class legible before showing any drilled-in detail.
class _HomePlantClassOverview extends StatefulWidget {
  const _HomePlantClassOverview({
    required this.overview,
    required this.onOpen,
    this.onOpenClass,
  });
  final PlantAssetOverview overview;
  final VoidCallback onOpen;
  final ValueChanged<String>? onOpenClass;

  @override
  State<_HomePlantClassOverview> createState() =>
      _HomePlantClassOverviewState();
}

class _HomePlantClassOverviewState extends State<_HomePlantClassOverview> {
  String? _selectedClass;
  final _expandedCovers = <String>{};
  bool _restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: 'home-class-overview');
    if (saved is Map<String, Object?>) {
      _selectedClass = saved['class'] as String?;
      _expandedCovers.addAll((saved['covers'] as List<String>?) ?? const []);
    }
  }

  void _remember() =>
      PageStorage.maybeOf(context)?.writeState(context, <String, Object?>{
        'class': _selectedClass,
        'covers': _expandedCovers.toList(),
      }, identifier: 'home-class-overview');

  void _openClass(String id) {
    final open = widget.onOpenClass;
    if (open == null) {
      widget.onOpen();
    } else {
      open(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.overview;
    final equipment = value.classes
        .where((c) => c.assetClass.legacyAssetTypeKey != 'innerCover')
        .toList();
    final covers = value.classes
        .where((c) => c.assetClass.legacyAssetTypeKey == 'innerCover')
        .toList();
    final selected = equipment
        .where((c) => c.assetClass.id == _selectedClass)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(BafSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth <
                  235 * MediaQuery.textScalerOf(context).scale(16) / 16;
              const title = Text(
                'Plant condition',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BafColors.assets.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(BafRadius.small),
                        ),
                        child: const Icon(
                          Icons.precision_manufacturing_outlined,
                          color: BafColors.assets,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: BafSpacing.sm),
                      if (stacked)
                        const Spacer()
                      else
                        const Expanded(child: title),
                      IconButton(
                        tooltip: 'Open plant condition',
                        onPressed: widget.onOpen,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: BafColors.assets,
                        ),
                      ),
                    ],
                  ),
                  if (stacked)
                    const Padding(
                      padding: EdgeInsets.only(bottom: BafSpacing.sm),
                      child: title,
                    ),
                ],
              );
            },
          ),
          const Text(
            'Availability by equipment class',
            style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: BafSpacing.md),
          if (equipment.isEmpty &&
              covers.isEmpty &&
              value.unclassifiedAssets.isEmpty)
            Text(
              value.hasCompleteEvidence
                  ? 'No active physical assets are registered yet.'
                  : 'No active assets could be verified from the available evidence.',
              style: const TextStyle(color: BafColors.textSecondary),
            ),
          if (equipment.isNotEmpty) const _HomeClassColumnLabels(),
          for (final summary in equipment)
            _HomePlantClassRow(
              summary: summary,
              selected: summary.assetClass.id == _selectedClass,
              onTap: () {
                setState(() {
                  _selectedClass = _selectedClass == summary.assetClass.id
                      ? null
                      : summary.assetClass.id;
                });
                _remember();
              },
            ),
          // Detail follows every summary row, keeping the cross-class comparison stable.
          if (selected != null)
            _HomePlantClassDetails(
              summary: selected,
              onOpen: () => _openClass(selected.assetClass.id),
            ),
          if (!value.hasCompleteEvidence) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              value.unverifiedWorkflowEvidence > 0
                  ? 'Evidence incomplete · ${value.unverifiedWorkflowEvidence} condition unverified. Known restrictions remain shown.'
                  : 'Evidence incomplete · recorded counts may not cover the whole inventory.',
              key: const ValueKey('plant-condition-evidence-summary'),
              style: const TextStyle(color: BafColors.warning, fontSize: 12),
            ),
          ],
          for (final orphan in value.unclassifiedAssets)
            TextButton(
              onPressed: widget.onOpen,
              key: ValueKey('plant-home-unclassified-${orphan.asset.id}'),
              child: Text(
                '${orphan.asset.assetClassName} ${orphan.asset.assetNumber} · class unverified${_orphanRestrictions(orphan)}',
                textAlign: TextAlign.start,
              ),
            ),
          if (value.innerCovers.any(
            (cover) => !covers.any(
              (c) => c.assetClass.id == cover.profile.assetClassId,
            ),
          ))
            TextButton(
              key: const ValueKey('plant-home-unclassified-covers'),
              onPressed: widget.onOpen,
              child: Text(
                'Inner Covers: ${value.innerCovers.where((cover) => !covers.any((c) => c.assetClass.id == cover.profile.assetClassId)).length} class unverified',
                textAlign: TextAlign.start,
              ),
            ),
          for (final summary in covers) ...[
            const Divider(height: BafSpacing.xl),
            _coverDisclosure(
              summary,
              value.innerCoverStock?.forClass(summary.assetClass.id),
            ),
          ],
          if (value.baseCoverReconciliation case final reconciliation?)
            BaseCoverReconciliationPanel(
              summary: reconciliation,
              compact: true,
              onReviewBase: (row) {
                if (widget.onOpenClass != null) {
                  _openClass(row.base.assetClassId);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AssetConditionBoard(
                        initialAssetClassId: row.base.assetClassId,
                      ),
                    ),
                  );
                }
              },
              onReviewLinks: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const InnerCoverLifecycleScreen(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _orphanRestrictions(PlantAssetState asset) {
    final labels = <String>[
      if (asset.isDown) 'Down',
      if (asset.isUnfit) 'Unfit',
      if (asset.isIssueUnavailable) 'Unavailable by issue',
      if (asset.isUnderMaintenance) 'Maintenance',
      if (asset.isTemporarilyBlocked) 'Stuck-up',
      if (asset.isStandby) 'Standby',
      if (asset.isAdministrativelyOutOfService) 'Out of service',
    ];
    return labels.isEmpty ? '' : ' · ${labels.join(', ')}';
  }

  Widget _coverDisclosure(
    PlantAssetClassSummary summary,
    InnerCoverStockSummary? stock,
  ) {
    final id = summary.assetClass.id;
    final expanded = _expandedCovers.contains(id);
    final messages = <String>[];
    if (stock != null) {
      if (stock.excluded case final count? when count > 0) {
        messages.add('$count excluded');
      }
      if (stock.assessmentRequired case final count? when count > 0) {
        messages.add('$count need assessment');
      }
      if (!stock.inventoryConfirmed ||
          !stock.linkageConfirmed ||
          !stock.bulgeEvidenceConfirmed ||
          !stock.dependencyEvidenceConfirmed ||
          stock.unverified > 0) {
        messages.add('Evidence unverified');
      }
      if (stock.review.isNotEmpty) {
        messages.add('${stock.review.length} to review');
      }
    } else {
      final review = summary.innerCovers.where((c) => !c.isAvailable).length;
      if (review > 0) messages.add('$review to review');
      if (summary.unverifiedWorkflowEvidence > 0 ||
          !summary.inventoryComplete) {
        messages.add('Evidence unverified');
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            key: ValueKey('plant-inner-cover-toggle-$id'),
            borderRadius: BorderRadius.circular(BafRadius.small),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedCovers.remove(id);
                } else {
                  _expandedCovers.add(id);
                }
              });
              _remember();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: BafSpacing.sm),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_outlined,
                    color: BafColors.steel,
                    size: 20,
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.assetClass.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          messages.isEmpty
                              ? 'Stock & condition details'
                              : messages.join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: messages.isEmpty
                                ? BafColors.textSecondary
                                : BafColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: BafColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          Column(
            key: ValueKey('plant-inner-cover-details-$id'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stock != null)
                InnerCoverStockPanel(summary: stock)
              else
                _fallbackCoverDetails(summary),
              TextButton(
                onPressed: () => _openClass(id),
                child: const Text('Open Plant condition for all inner covers.'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _fallbackCoverDetails(PlantAssetClassSummary summary) {
    final review = summary.innerCovers.where((c) => !c.isAvailable).toList()
      ..sort(
        (a, b) => a.profile.serialNumber.compareTo(b.profile.serialNumber),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.isNotEmpty)
          ExpansionTile(
            key: PageStorageKey(
              'plant-inner-cover-review-${summary.assetClass.id}',
            ),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: BafSpacing.sm),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            expandedAlignment: Alignment.centerLeft,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              'Review ${review.length} inner cover${review.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${summary.available} available · ${summary.unavailable} unavailable · ${summary.unverifiedAvailability} unverified',
              style: const TextStyle(
                fontSize: 12,
                color: BafColors.textSecondary,
              ),
            ),
            children: [
              for (final cover in review)
                Text(
                  'Inner Cover ${cover.profile.serialNumber}: ${cover.conditionSummary}',
                  style: const TextStyle(fontSize: 12),
                ),
            ],
          ),
        const Text(
          'Candidates need a physical check before use.',
          style: TextStyle(fontSize: 12, color: BafColors.textSecondary),
        ),
      ],
    );
  }
}

bool _useClassColumns(BuildContext context, double width) =>
    width >= 300 && MediaQuery.textScalerOf(context).scale(12) / 12 <= 1.2;

class _HomeClassColumnLabels extends StatelessWidget {
  const _HomeClassColumnLabels();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!_useClassColumns(context, constraints.maxWidth)) {
        return const SizedBox.shrink();
      }
      return const Padding(
        padding: EdgeInsets.fromLTRB(
          BafSpacing.sm,
          0,
          BafSpacing.sm,
          BafSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                'Equipment',
                style: TextStyle(fontSize: 10, color: BafColors.textSecondary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Available',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: BafColors.textSecondary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: BafColors.textSecondary),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'Unverified',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: BafColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _HomePlantClassRow extends StatelessWidget {
  const _HomePlantClassRow({
    required this.summary,
    required this.selected,
    required this.onTap,
  });
  final PlantAssetClassSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final id = summary.assetClass.id;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _useClassColumns(context, constraints.maxWidth);
        return Padding(
          padding: const EdgeInsets.only(bottom: BafSpacing.sm),
          child: Material(
            color: selected
                ? BafColors.assets.withValues(alpha: 0.06)
                : BafColors.surfaceTint,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(BafRadius.small),
              side: BorderSide(
                color: selected ? BafColors.assets : BafColors.border,
              ),
            ),
            child: Semantics(
              button: true,
              expanded: selected,
              child: InkWell(
                key: ValueKey('plant-class-row-$id'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(BafRadius.small),
                child: Padding(
                  padding: EdgeInsets.all(
                    compact ? BafSpacing.sm : BafSpacing.md,
                  ),
                  child: compact
                      ? _compactRow()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final stacked =
                                    constraints.maxWidth <
                                    215 *
                                        MediaQuery.textScalerOf(
                                          context,
                                        ).scale(14) /
                                        14;
                                final registered = Text(
                                  '${summary.total} ${summary.inventoryComplete ? 'registered' : 'recorded'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: BafColors.textSecondary,
                                  ),
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            summary.assetClass.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: BafSpacing.sm),
                                        if (!stacked)
                                          Flexible(child: registered),
                                        const SizedBox(width: BafSpacing.xs),
                                        Icon(
                                          selected
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          size: 18,
                                          color: BafColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                    if (stacked)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: BafSpacing.xs,
                                        ),
                                        child: registered,
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: BafSpacing.sm),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final minimum =
                                    74 *
                                    MediaQuery.textScalerOf(context).scale(11) /
                                    11;
                                final columns =
                                    ((constraints.maxWidth + 8) / (minimum + 8))
                                        .floor()
                                        .clamp(1, 3);
                                final width =
                                    (constraints.maxWidth - 8 * (columns - 1)) /
                                    columns;
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _count(
                                      width,
                                      'Available',
                                      summary.available,
                                      BafColors.success,
                                      'plant-class-available-$id',
                                    ),
                                    _count(
                                      width,
                                      'Unavailable',
                                      summary.unavailable,
                                      summary.unavailable > 0
                                          ? BafColors.danger
                                          : BafColors.textSecondary,
                                      'plant-class-unavailable-$id',
                                    ),
                                    _count(
                                      width,
                                      'Unverified',
                                      summary.unverifiedAvailability,
                                      summary.unverifiedWorkflowEvidence > 0
                                          ? BafColors.warning
                                          : BafColors.textSecondary,
                                      'plant-class-unverified-$id',
                                    ),
                                  ],
                                );
                              },
                            ),
                            if (summary.unverifiedWorkflowEvidence >
                                summary.unverifiedAvailability)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: BafSpacing.xs,
                                ),
                                child: Text(
                                  '${summary.unverifiedWorkflowEvidence} with incomplete condition evidence',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: BafColors.warning,
                                  ),
                                ),
                              ),
                            if (!summary.inventoryComplete)
                              const Padding(
                                padding: EdgeInsets.only(top: BafSpacing.xs),
                                child: Text(
                                  'Inventory incomplete',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: BafColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _compactRow() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.assetClass.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${summary.total} ${summary.inventoryComplete ? 'registered' : 'recorded'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: BafColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      selected
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 16,
                      color: BafColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _tableCount('available', summary.available, BafColors.success),
          _tableCount(
            'unavailable',
            summary.unavailable,
            summary.unavailable > 0
                ? BafColors.danger
                : BafColors.textSecondary,
          ),
          _tableCount(
            'unverified',
            summary.unverifiedAvailability,
            summary.unverifiedWorkflowEvidence > 0
                ? BafColors.warning
                : BafColors.textSecondary,
          ),
        ],
      ),
      if (summary.unverifiedWorkflowEvidence > summary.unverifiedAvailability)
        Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Text(
            '${summary.unverifiedWorkflowEvidence} with incomplete condition evidence',
            style: const TextStyle(fontSize: 11, color: BafColors.warning),
          ),
        ),
      if (!summary.inventoryComplete)
        const Padding(
          padding: EdgeInsets.only(top: BafSpacing.xs),
          child: Text(
            'Inventory incomplete',
            style: TextStyle(fontSize: 11, color: BafColors.warning),
          ),
        ),
    ],
  );

  Widget _tableCount(String label, int count, Color color) => Expanded(
    flex: 2,
    child: Semantics(
      label: '$count $label',
      excludeSemantics: true,
      child: Text(
        '$count',
        key: ValueKey('plant-class-$label-${summary.assetClass.id}'),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    ),
  );

  Widget _count(
    double width,
    String label,
    int count,
    Color color,
    String keyName,
  ) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          key: ValueKey(keyName),
          style: TextStyle(
            fontSize: 22,
            height: 1.15,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: BafColors.textSecondary),
        ),
      ],
    ),
  );
}

class _HomePlantClassDetails extends StatelessWidget {
  const _HomePlantClassDetails({required this.summary, required this.onOpen});
  final PlantAssetClassSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final reasons = <(String, Iterable<PlantAssetState>)>[
      ('Down', summary.assets.where((a) => a.isDown)),
      ('Unfit', summary.assets.where((a) => a.isUnfit)),
      (
        _issueUnavailableLabel,
        summary.assets.where((a) => a.isIssueUnavailable),
      ),
      ('Maintenance', summary.assets.where((a) => a.isUnderMaintenance)),
      ('Stuck-up', summary.assets.where((a) => a.isTemporarilyBlocked)),
      ('Standby', summary.assets.where((a) => a.isStandby)),
      (
        'Out of service',
        summary.assets.where((a) => a.isAdministrativelyOutOfService),
      ),
      (
        'Evidence unverified',
        summary.assets.where((a) => a.hasUnverifiedWorkflowEvidence),
      ),
    ].where((r) => r.$2.isNotEmpty).toList();
    return Container(
      key: ValueKey('plant-class-details-${summary.assetClass.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: const BoxDecoration(
        color: BafColors.surfaceTint,
        border: Border(left: BorderSide(color: BafColors.assets, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${summary.assetClass.name} · condition detail',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          if (reasons.isEmpty && summary.innerCovers.isEmpty)
            Text(
              !summary.inventoryComplete
                  ? 'Inventory incomplete. These records cannot establish the full class position.'
                  : summary.total == 0
                  ? 'No registered equipment in this class.'
                  : 'No recorded restrictions in this class.',
              style: const TextStyle(
                fontSize: 12,
                color: BafColors.textSecondary,
              ),
            ),
          for (final (label, assets) in reasons)
            Padding(
              padding: const EdgeInsets.only(top: BafSpacing.sm),
              child: Text(
                '$label ${assets.length}: ${assets.map((a) => '${summary.assetClass.name} ${a.asset.assetNumber}').join(', ')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: BafColors.textPrimary,
                ),
              ),
            ),
          for (final cover in summary.innerCovers)
            Padding(
              padding: const EdgeInsets.only(top: BafSpacing.sm),
              child: Text(
                [
                  'Inner Cover ${cover.profile.serialNumber}: ${cover.conditionSummary}',
                  ...cover.evidenceWarnings,
                ].join('\n'),
                style: const TextStyle(
                  fontSize: 12,
                  color: BafColors.textPrimary,
                ),
              ),
            ),
          if (reasons.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: BafSpacing.sm),
              child: Text(
                'Reasons may overlap; each asset is counted once above.',
                style: TextStyle(fontSize: 11, color: BafColors.textSecondary),
              ),
            ),
          TextButton(
            key: ValueKey('plant-class-open-${summary.assetClass.id}'),
            onPressed: onOpen,
            child: Text('Open ${summary.assetClass.name} condition'),
          ),
        ],
      ),
    );
  }
}
