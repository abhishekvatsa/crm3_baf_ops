part of 'furnace_component_condition_audit_screen.dart';

Future<bool> _confirmFurnaceChecks(
  BuildContext context,
  String furnaceName,
  String confirmation,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $furnaceName checks'),
        content: Text(confirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Checked now'),
          ),
        ],
      ),
    ) ??
    false;

class _ConditionCell extends StatelessWidget {
  const _ConditionCell({
    super.key,
    required this.selected,
    required this.color,
    required this.tooltip,
    required this.onChanged,
    this.evidenceIcon,
    this.unknown = false,
  });

  final bool selected;
  final Color color;
  final String tooltip;
  final ValueChanged<bool>? onChanged;
  final IconData? evidenceIcon;
  final bool unknown;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Checkbox(
              value: selected,
              activeColor: color,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value == true),
            ),
            if (unknown || evidenceIcon != null)
              Positioned(
                right: -1,
                bottom: -1,
                child: Icon(
                  unknown ? Icons.help_outline : evidenceIcon,
                  size: 13,
                  color: unknown ? BafColors.warning : BafColors.success,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Color _uvColor(BurnerUvCondition condition) => switch (condition) {
  BurnerUvCondition.serviceable => BafColors.success,
  BurnerUvCondition.melted => BafColors.danger,
  BurnerUvCondition.missing => BafColors.warning,
  BurnerUvCondition.hanging => BafColors.instrument,
};
