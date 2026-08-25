part of 'asset_condition_board.dart';

class _PlantMetric extends StatelessWidget {
  final double? width;
  final int value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _PlantMetric({
    this.width,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey<String>('plant-condition-${label.toLowerCase()}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(BafRadius.small),
    child: Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 54),
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
            '$value ${label.toLowerCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ],
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
