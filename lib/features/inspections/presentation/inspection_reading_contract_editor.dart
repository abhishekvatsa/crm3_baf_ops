import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/inspection_campaign.dart';

Future<InspectionReadingField?> showInspectionReadingFieldEditor(
  BuildContext context, {
  InspectionReadingField? field,
  List<String> otherLabels = const [],
}) => showDialog<InspectionReadingField>(
  context: context,
  builder: (_) => _ReadingFieldDialog(field: field, otherLabels: otherLabels),
);

/// Preserve the existing scalar contract before appending another reading.
/// A malformed nonempty limit is never silently converted to an absent limit.
InspectionReadingField prepareLegacyInspectionReadingField({
  required String id,
  required String label,
  required InspectionValueType valueType,
  required String unit,
  required List<String> choices,
  required String minimum,
  required String maximum,
}) {
  double? limit(String text) {
    if (text.trim().isEmpty) return null;
    final parsed = double.tryParse(text.trim());
    if (parsed == null || !parsed.isFinite) {
      throw const FormatException('Correct the existing numeric limits first.');
    }
    return parsed;
  }

  return InspectionReadingField.fromMap({
    'id': id,
    'label': label,
    'valueType': valueType.name,
    'unit': valueType == InspectionValueType.number ? unit.trim() : null,
    'choiceValues': valueType == InspectionValueType.choice
        ? choices
        : <String>[],
    'minimumValue': valueType == InspectionValueType.number
        ? limit(minimum)
        : null,
    'maximumValue': valueType == InspectionValueType.number
        ? limit(maximum)
        : null,
  });
}

/// Edits descriptors only. Recording values is a separate inspection action.
class InspectionReadingContractEditor extends StatelessWidget {
  const InspectionReadingContractEditor({
    required this.fields,
    required this.onChanged,
    super.key,
  });
  final List<InspectionReadingField> fields;
  final ValueChanged<List<InspectionReadingField>> onChanged;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final changed = await showInspectionReadingFieldEditor(
      context,
      field: index == null ? null : fields[index],
      otherLabels: [
        for (var i = 0; i < fields.length; i++)
          if (i != index) fields[i].label,
      ],
    );
    if (changed == null || !context.mounted) return;
    final next = fields.toList();
    if (index == null) {
      next.add(changed);
    } else {
      next[index] = changed;
    }
    onChanged(List.unmodifiable(next));
  }

  void _move(int index, int delta) {
    final next = fields.toList();
    final field = next.removeAt(index);
    next.insert(index + delta, field);
    onChanged(List.unmodifiable(next));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('All readings below are required at each inspection point.'),
      for (var i = 0; i < fields.length; i++)
        Card(
          key: ValueKey('inspection-contract-field-${fields[i].id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fields[i].label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(inspectionReadingTypeLabel(fields[i].valueType)),
                if (fields[i].unit != null) Text('Unit: ${fields[i].unit}'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      key: ValueKey('inspection-contract-edit-${fields[i].id}'),
                      onPressed: () => _edit(context, i),
                      child: const Text('Edit reading'),
                    ),
                    if (i > 0)
                      TextButton(
                        key: ValueKey('inspection-contract-up-${fields[i].id}'),
                        onPressed: () => _move(i, -1),
                        child: const Text('Move up'),
                      ),
                    if (i + 1 < fields.length)
                      TextButton(
                        onPressed: () => _move(i, 1),
                        child: const Text('Move down'),
                      ),
                    if (fields.length > 1)
                      TextButton(
                        onPressed: () => onChanged(
                          List.unmodifiable([
                            for (var j = 0; j < fields.length; j++)
                              if (j != i) fields[j],
                          ]),
                        ),
                        child: const Text('Remove reading'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      OutlinedButton.icon(
        key: const ValueKey('inspection-contract-add-reading'),
        onPressed: fields.length < 20 ? () => _edit(context) : null,
        icon: const Icon(Icons.add),
        label: const Text('Add reading'),
      ),
    ],
  );
}

String inspectionReadingTypeLabel(InspectionValueType value) => switch (value) {
  InspectionValueType.number => 'Number',
  InspectionValueType.boolean => 'Yes/No',
  InspectionValueType.text => 'Text',
  InspectionValueType.choice => 'Choice',
  InspectionValueType.date => 'Date (dd-mm-yyyy)',
};

class _ReadingFieldDialog extends StatefulWidget {
  const _ReadingFieldDialog({required this.field, required this.otherLabels});
  final InspectionReadingField? field;
  final List<String> otherLabels;
  @override
  State<_ReadingFieldDialog> createState() => _ReadingFieldDialogState();
}

class _ReadingFieldDialogState extends State<_ReadingFieldDialog> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _label;
  late final TextEditingController _unit;
  late final TextEditingController _choices;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late InspectionValueType _type;

  @override
  void initState() {
    super.initState();
    final field = widget.field;
    _id = field?.id ?? 'reading_${const Uuid().v4().replaceAll('-', '')}';
    _label = TextEditingController(text: field?.label ?? '');
    _unit = TextEditingController(text: field?.unit ?? '');
    _choices = TextEditingController(
      text: field?.choiceValues.join('\n') ?? '',
    );
    _minimum = TextEditingController(text: '${field?.minimumValue ?? ''}');
    _maximum = TextEditingController(text: '${field?.maximumValue ?? ''}');
    _type = field?.valueType ?? InspectionValueType.boolean;
  }

  @override
  void dispose() {
    for (final value in [_label, _unit, _choices, _minimum, _maximum]) {
      value.dispose();
    }
    super.dispose();
  }

  String? _number(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    return parsed == null || !parsed.isFinite ? 'Enter a finite number.' : null;
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.field == null ? 'Add reading' : 'Edit reading',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextFormField(
                key: const ValueKey('inspection-reading-label'),
                controller: _label,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Reading label'),
                validator: (value) {
                  final label = value?.trim() ?? '';
                  if (label.isEmpty) return 'Name this reading.';
                  if (widget.otherLabels.any(
                    (other) => other.toLowerCase() == label.toLowerCase(),
                  )) {
                    return 'Each reading needs a different label.';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<InspectionValueType>(
                key: const ValueKey('inspection-reading-type'),
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Reading type'),
                items: [
                  for (final type in InspectionValueType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(inspectionReadingTypeLabel(type)),
                    ),
                ],
                onChanged: (type) {
                  if (type != null) setState(() => _type = type);
                },
              ),
              if (_type == InspectionValueType.date)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Enter or choose a calendar date as dd-mm-yyyy. This is separate from the inspection time.',
                  ),
                ),
              if (_type == InspectionValueType.number) ...[
                TextFormField(
                  controller: _unit,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Engineering unit',
                  ),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : 'Numeric readings require a unit.',
                ),
                TextFormField(
                  controller: _minimum,
                  decoration: const InputDecoration(
                    labelText: 'Minimum (optional)',
                  ),
                  validator: _number,
                ),
                TextFormField(
                  controller: _maximum,
                  decoration: const InputDecoration(
                    labelText: 'Maximum (optional)',
                  ),
                  validator: (value) {
                    final error = _number(value);
                    if (error != null) return error;
                    final minimum = double.tryParse(_minimum.text.trim());
                    final maximum = double.tryParse(value?.trim() ?? '');
                    return minimum != null &&
                            maximum != null &&
                            minimum > maximum
                        ? 'Minimum cannot exceed maximum.'
                        : null;
                  },
                ),
              ],
              if (_type == InspectionValueType.choice)
                TextFormField(
                  controller: _choices,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Choices · one per line',
                  ),
                  validator: (value) {
                    final choices = _choiceLines();
                    if (choices.isEmpty ||
                        choices.length > 30 ||
                        choices.any((choice) => choice.length > 120) ||
                        choices.toSet().length != choices.length) {
                      return 'Enter 1–30 different choices, up to 120 characters each.';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    key: const ValueKey('inspection-reading-save'),
                    onPressed: _save,
                    child: const Text('Save reading'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  List<String> _choiceLines() => _choices.text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      InspectionReadingField(
        id: _id,
        label: _label.text.trim(),
        valueType: _type,
        unit: _type == InspectionValueType.number ? _unit.text.trim() : null,
        choiceValues: _type == InspectionValueType.choice
            ? _choiceLines()
            : const [],
        minimumValue: _type == InspectionValueType.number
            ? double.tryParse(_minimum.text.trim())
            : null,
        maximumValue: _type == InspectionValueType.number
            ? double.tryParse(_maximum.text.trim())
            : null,
      ),
    );
  }
}
