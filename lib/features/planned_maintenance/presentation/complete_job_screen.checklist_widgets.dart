part of 'complete_job_screen.dart';

class _FieldPadding extends StatelessWidget {
  final Widget child;

  const _FieldPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }
}

class _ToggleCard extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: SwitchListTile(
        title: Text(
          label,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        value: value,
        activeThumbColor: BafColors.planned,
        onChanged: onChanged,
      ),
    );
  }
}

class _CheckboxCard extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckboxCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        value: value,
        activeColor: BafColors.planned,
        onChanged: onChanged,
      ),
    );
  }
}

class _MultiSelectField extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final bool requiredField;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectField({
    required this.label,
    required this.options,
    required this.selected,
    required this.requiredField,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((option) {
                final isSelected = selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: BafColors.planned.withValues(alpha: 0.14),
                  checkmarkColor: BafColors.planned,
                  side: BorderSide(
                    color:
                        isSelected
                            ? BafColors.planned.withValues(alpha: 0.35)
                            : BafColors.border,
                  ),
                  onSelected: (value) {
                    final updated = List<String>.from(selected);
                    value ? updated.add(option) : updated.remove(option);
                    onChanged(updated);
                  },
                );
              }).toList(),
        ),
        if (requiredField && selected.isEmpty) ...[
          const SizedBox(height: BafSpacing.xs),
          const Text(
            'Required',
            style: TextStyle(
              color: BafColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

