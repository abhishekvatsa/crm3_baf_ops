part of 'asset_condition_board.dart';

class _PlantClassConditionSummary extends StatelessWidget {
  const _PlantClassConditionSummary(this.summary);

  final PlantAssetClassSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = <Widget?>[
      _statusMetric(
        label: 'Maintenance',
        color: BafColors.maintenance,
        assets: summary.assets.where((asset) => asset.isUnderMaintenance),
      ),
      _statusMetric(
        label: 'Stuck-up',
        color: BafColors.instrument,
        assets: summary.assets.where((asset) => asset.isTemporarilyBlocked),
      ),
      _statusMetric(
        label: 'Unavailable',
        color: BafColors.cobalt,
        assets: summary.assets.where((asset) => asset.isIssueUnavailable),
      ),
      _statusMetric(
        label: 'Down',
        color: BafColors.danger,
        assets: summary.assets.where((asset) => asset.isDown),
      ),
      _statusMetric(
        label: 'Unfit',
        color: BafColors.warning,
        assets: summary.assets.where((asset) => asset.isUnfit),
      ),
      _statusMetric(
        label: 'Standby',
        color: BafColors.steel,
        assets: summary.assets.where((asset) => asset.isStandby),
      ),
      _statusMetric(
        label: 'Out of service',
        color: BafColors.admin,
        assets: summary.assets.where(
          (asset) => asset.isAdministrativelyOutOfService,
        ),
      ),
    ].whereType<Widget>().toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(top: BafSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final name = Text(
                summary.assetClass.name,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              );
              final registered = Text(
                '${summary.total} registered',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              );
              final labels = [
                _classCount('Down', summary.down, BafColors.danger),
                _classCount('Unfit', summary.unfit, BafColors.warning),
                _classCount(
                  'Stuck-up',
                  summary.temporarilyBlocked,
                  BafColors.instrument,
                ),
              ];
              final counts = Wrap(
                key: ValueKey('plant-class-counts-${summary.assetClass.id}'),
                spacing: BafSpacing.sm,
                runSpacing: BafSpacing.xs,
                children: labels,
              );
              var requiredWidth = 4 * BafSpacing.sm;
              for (final text in [name, ...labels, registered]) {
                final painter = TextPainter(
                  text: TextSpan(
                    text: text.data,
                    style: DefaultTextStyle.of(context).style.merge(text.style),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 1,
                )..layout();
                requiredWidth += painter.width;
                painter.dispose();
              }
              final inline = constraints.maxWidth >= requiredWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (inline) ...[
                        name,
                        const SizedBox(width: BafSpacing.sm),
                        Expanded(child: Center(child: counts)),
                        const SizedBox(width: BafSpacing.sm),
                        registered,
                      ] else ...[
                        Expanded(child: name),
                        const SizedBox(width: BafSpacing.sm),
                        Flexible(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: registered,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!inline) ...[
                    const SizedBox(height: BafSpacing.xs),
                    counts,
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: BafSpacing.xs),
          if (metrics.isEmpty)
            const Text(
              'All registered assets are in the available state.',
              style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
            )
          else
            Wrap(
              spacing: BafSpacing.xs,
              runSpacing: BafSpacing.xs,
              children: metrics,
            ),
        ],
      ),
    );
  }

  Text _classCount(String label, int count, Color color) => Text(
    '$label $count',
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
  );

  Widget? _statusMetric({
    required String label,
    required Color color,
    required Iterable<PlantAssetState> assets,
  }) {
    final rows = assets.toList(growable: false)..sort(
      (left, right) =>
          left.asset.assetNumber.compareTo(right.asset.assetNumber),
    );
    if (rows.isEmpty) return null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: Text(
        '$label ${rows.length}: ${rows.map(_assetIdentity).join(', ')}',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _assetIdentity(PlantAssetState row) {
    final asset = row.asset;
    return '${summary.assetClass.name} ${asset.assetNumber}';
  }
}
