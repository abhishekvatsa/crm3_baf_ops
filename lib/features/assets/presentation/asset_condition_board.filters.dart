part of 'asset_condition_board.dart';

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
