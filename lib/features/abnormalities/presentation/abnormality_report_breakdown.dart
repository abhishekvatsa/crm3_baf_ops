part of 'abnormality_reports_screen.dart';

class _InsightGrid extends StatelessWidget {
  final List<ChargeAbnormality> records;

  final ValueChanged<AbnormalityCategory> onCategory;
  final ValueChanged<RootReasonCategory> onRootReason;
  final ValueChanged<AssetType> onAssetType;

  const _InsightGrid({
    required this.records,
    required this.onCategory,
    required this.onRootReason,
    required this.onAssetType,
  });

  @override
  Widget build(BuildContext context) {
    final byCategory = _countBy<AbnormalityCategory>(
      records,
      (record) => record.category,
    );

    final byRoot = _countBy<RootReasonCategory>(
      records,
      (record) => record.possibleRootReasonCategory,
    );

    final byAsset = <AssetType, int>{};
    for (final record in records) {
      // A drilldown opens abnormalities, not individual asset references.
      for (final type
          in record.affectedAssets.map((asset) => asset.assetType).toSet()) {
        byAsset[type] = (byAsset[type] ?? 0) + 1;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 760;

        final cards = [
          _BreakdownCard<AbnormalityCategory>(
            title: 'By Category',
            icon: Icons.category_rounded,
            color: BafColors.charges,
            values: byCategory,
            labelBuilder: _categoryLabel,
            keyBuilder: (value) => 'category-${value.name}',
            onSelected: onCategory,
          ),
          _BreakdownCard<RootReasonCategory>(
            title: 'By Root Reason',
            icon: Icons.manage_search_rounded,
            color: BafColors.audit,
            values: byRoot,
            labelBuilder: _rootReasonCategoryLabel,
            keyBuilder: (value) => 'root-${value.name}',
            onSelected: onRootReason,
          ),
          _BreakdownCard<AssetType>(
            title: 'By Asset Type',
            icon: Icons.precision_manufacturing_rounded,
            color: BafColors.assets,
            values: byAsset,
            labelBuilder: _assetTypeLabel,
            keyBuilder: (value) => 'asset-${value.name}',
            onSelected: onAssetType,
            subtitle:
                'Abnormalities by affected type. A record can appear under more than one type.',
          ),
        ];

        if (!useTwoColumns) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: BafSpacing.md),
              cards[1],
              const SizedBox(height: BafSpacing.md),
              cards[2],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: BafSpacing.md),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            cards[2],
          ],
        );
      },
    );
  }

  static Map<T, int> _countBy<T>(
    List<ChargeAbnormality> records,
    T Function(ChargeAbnormality record) selector,
  ) {
    final result = <T, int>{};

    for (final record in records) {
      final key = selector(record);
      result[key] = (result[key] ?? 0) + 1;
    }

    return result;
  }
}

class _BreakdownCard<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Map<T, int> values;
  final String Function(T value) labelBuilder;
  final String Function(T value) keyBuilder;
  final ValueChanged<T> onSelected;
  final String? subtitle;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.values,
    required this.labelBuilder,
    required this.keyBuilder,
    required this.onSelected,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: icon,
            title: title,
            subtitle: entries.isEmpty
                ? 'No records in current filter.'
                : subtitle ?? 'Tap a count to filter the current results.',
            color: color,
          ),
          const SizedBox(height: BafSpacing.md),
          if (entries.isEmpty)
            const Text(
              'No data',
              style: TextStyle(color: BafColors.textSecondary, fontSize: 13),
            )
          else
            ...entries.take(6).map((entry) {
              final label = labelBuilder(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.xs),
                child: Semantics(
                  button: true,
                  label:
                      '$label: ${entry.value} abnormalities. Filter these records',
                  onTap: () => onSelected(entry.key),
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey(
                        'abnormality-breakdown-${keyBuilder(entry.key)}',
                      ),
                      onTap: () => onSelected(entry.key),
                      borderRadius: BorderRadius.circular(BafRadius.small),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: BafSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: BafColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: BafSpacing.sm),
                              StatusBadge(
                                label: '${entry.value}',
                                color: color,
                                icon: Icons.numbers_rounded,
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: color,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
