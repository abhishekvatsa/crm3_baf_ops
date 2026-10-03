import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../data/inspection_campaign.dart';

/// Edits the complete frozen reading contract inside the observation's Form.
class InspectionReadingFieldsEditor extends StatefulWidget {
  const InspectionReadingFieldsEditor({
    super.key,
    required this.fields,
    this.initialValues = const [],
  });

  final List<InspectionReadingField> fields;
  final List<InspectionReadingValue> initialValues;

  @override
  State<InspectionReadingFieldsEditor> createState() =>
      InspectionReadingFieldsEditorState();
}

class InspectionReadingFieldsEditorState
    extends State<InspectionReadingFieldsEditor> {
  final _controllers = <String, TextEditingController>{};
  final _selections = <String, Object?>{};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValues.isEmpty
        ? const <InspectionReadingValue>[]
        : validateInspectionReadingValues(widget.fields, widget.initialValues);
    final byId = {for (final value in initial) value.fieldId: value};
    for (final field in widget.fields) {
      final value = byId[field.id]?.value;
      if (field.valueType == InspectionValueType.boolean ||
          field.valueType == InspectionValueType.choice) {
        _selections[field.id] = value;
      } else {
        _controllers[field.id] = TextEditingController(
          text: value == null
              ? ''
              : field.valueType == InspectionValueType.date
              ? formatInspectionDate(value as String)
              : '$value',
        );
      }
    }
  }

  /// Call after the enclosing Form validates. Missing answers never get defaults.
  List<InspectionReadingValue> validatedValues() =>
      validateInspectionReadingValues(widget.fields, [
        for (final field in widget.fields)
          InspectionReadingValue(
            fieldId: field.id,
            valueType: field.valueType,
            value: switch (field.valueType) {
              InspectionValueType.boolean ||
              InspectionValueType.choice => _selections[field.id]!,
              InspectionValueType.number => double.parse(
                _controllers[field.id]!.text.trim(),
              ),
              InspectionValueType.date => parseInspectionDateInput(
                _controllers[field.id]!.text.trim(),
              )!,
              InspectionValueType.text => _controllers[field.id]!.text.trim(),
            },
          ),
      ]);

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Complete each reading',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: BafSpacing.sm),
      for (final field in widget.fields) ...[
        _field(field),
        const SizedBox(height: BafSpacing.md),
      ],
    ],
  );

  Widget _field(InspectionReadingField field) {
    final key = ValueKey('inspection-reading-${field.id}');
    if (field.valueType == InspectionValueType.boolean) {
      return FormField<bool>(
        key: key,
        initialValue: _selections[field.id] as bool?,
        validator: (value) => value == null ? 'Choose Yes or No.' : null,
        builder: (state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              field.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: BafSpacing.sm),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.xs,
              children: [
                for (final answer in const [true, false])
                  ChoiceChip(
                    label: Text(answer ? 'Yes' : 'No'),
                    selected: _selections[field.id] == answer,
                    onSelected: (selected) {
                      setState(
                        () => _selections[field.id] = selected ? answer : null,
                      );
                      state.didChange(selected ? answer : null);
                    },
                  ),
              ],
            ),
            if (state.hasError)
              Text(
                state.errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      );
    }
    if (field.valueType == InspectionValueType.choice) {
      return DropdownButtonFormField<String>(
        key: key,
        initialValue: _selections[field.id] as String?,
        isExpanded: true,
        decoration: InputDecoration(labelText: field.label),
        items: [
          for (final choice in field.choiceValues)
            DropdownMenuItem(value: choice, child: Text(choice)),
        ],
        onChanged: (value) => setState(() => _selections[field.id] = value),
        validator: (value) =>
            value == null ? 'Choose an observed value.' : null,
      );
    }
    final date = field.valueType == InspectionValueType.date;
    final number = field.valueType == InspectionValueType.number;
    return TextFormField(
      key: key,
      controller: _controllers[field.id],
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : date
          ? TextInputType.datetime
          : TextInputType.multiline,
      maxLines: number || date ? 1 : 4,
      decoration: InputDecoration(
        labelText: field.unit == null
            ? field.label
            : '${field.label} (${field.unit})',
        hintText: date ? 'DD-MM-YYYY' : null,
        helperText: date
            ? 'DD-MM-YYYY'
            : number &&
                  (field.minimumValue != null || field.maximumValue != null)
            ? 'Governed range: ${field.minimumValue ?? '−∞'} to ${field.maximumValue ?? '∞'} ${field.unit}'
            : null,
        suffixIcon: date
            ? IconButton(
                tooltip: 'Choose ${field.label} date',
                onPressed: () => _chooseDate(field),
                icon: const Icon(Icons.calendar_month_outlined),
              )
            : null,
      ),
      validator: (input) {
        final text = input?.trim() ?? '';
        if (date) {
          return parseInspectionDateInput(text) == null
              ? 'Enter a valid date as DD-MM-YYYY.'
              : null;
        }
        if (number) {
          return double.tryParse(text)?.isFinite == true
              ? null
              : 'Enter a finite numeric reading.';
        }
        if (text.isEmpty) return 'Record the observed condition.';
        return text.length > 1000 ? 'Use at most 1,000 characters.' : null;
      },
    );
  }

  Future<void> _chooseDate(InspectionReadingField field) async {
    final iso = parseInspectionDateInput(_controllers[field.id]!.text.trim());
    final chosen = await showDatePicker(
      context: context,
      initialDate: iso == null ? DateTime.now() : DateTime.parse(iso),
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      helpText: field.label,
    );
    if (chosen == null || !mounted) return;
    _controllers[field.id]!.text = formatInspectionDate(
      '${chosen.year.toString().padLeft(4, '0')}-'
      '${chosen.month.toString().padLeft(2, '0')}-'
      '${chosen.day.toString().padLeft(2, '0')}',
    );
  }
}
