part of 'asset_condition_board.dart';

double _metricWidth(BuildContext context, BoxConstraints constraints) {
  final availableWidth = constraints.maxWidth;
  // Three columns fit normal phone widths; larger text gets fewer columns.
  final minimumWidth = 92 * MediaQuery.textScalerOf(context).scale(11) / 11;
  final columns =
      ((availableWidth + BafSpacing.xs) / (minimumWidth + BafSpacing.xs))
          .floor()
          .clamp(1, 3);
  return (availableWidth - BafSpacing.xs * (columns - 1)) / columns;
}

class _PlantMetric extends StatelessWidget {
  final double? width;
  final int value;
  final String label;
  final String? keyLabel;
  final Color color;
  final VoidCallback? onTap;

  const _PlantMetric({
    this.width,
    required this.value,
    required this.label,
    this.keyLabel,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey<String>('plant-condition-${keyLabel ?? label.toLowerCase()}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(BafRadius.small),
    child: Semantics(
      label: '$value ${label.toLowerCase()}',
      excludeSemantics: true,
      child: Container(
        width: width,
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.xs,
          vertical: BafSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(BafRadius.small),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$value',
              key: ValueKey(
                'plant-condition-${keyLabel ?? label.toLowerCase()}-value',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(11) * 1.15 * 2,
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConditionFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  const _ConditionFilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    selectedColor: color.withValues(alpha: 0.16),
    labelStyle: TextStyle(
      color: selected ? color : BafColors.textSecondary,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
    ),
    onSelected: (_) => onSelected(),
  );
}
