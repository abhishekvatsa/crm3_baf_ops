// FILE: lib/features/planned_maintenance/presentation/widgets/job_module_response_form.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../data/job_template_model.dart';

/// Dynamic response renderer for one JobModuleInstance.
///
/// It intentionally consumes the lightweight seed/governance-shaped field map
/// stored in JobModuleInstance.fieldDefinitionsJson and writes the app's
/// existing FieldResponse shape back to JobModuleInstance.responsesJson.
class JobModuleResponseForm extends StatefulWidget {
  final List<Map<String, dynamic>> fieldDefinitions;
  final List<FieldResponse> initialResponses;
  final bool isEditable;
  final bool isBusy;
  final String saveButtonLabel;
  final Future<void> Function(List<FieldResponse> responses) onSave;

  const JobModuleResponseForm({
    super.key,
    required this.fieldDefinitions,
    required this.initialResponses,
    required this.isEditable,
    required this.isBusy,
    this.saveButtonLabel = 'Save Structured Responses',
    required this.onSave,
  });

  @override
  State<JobModuleResponseForm> createState() => _JobModuleResponseFormState();
}

class _JobModuleResponseFormState extends State<JobModuleResponseForm> {
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};
  final Map<String, String?> _singleValues = {};
  final Map<String, Set<String>> _multiValues = {};
  final Map<String, String?> _fieldErrors = {};

  late List<_ModuleFieldDefinition> _fields;

  @override
  void initState() {
    super.initState();
    _initialiseState();
  }

  @override
  void didUpdateWidget(covariant JobModuleResponseForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fieldDefinitions != widget.fieldDefinitions ||
        oldWidget.initialResponses != widget.initialResponses) {
      _disposeControllers();
      _initialiseState();
    }
  }

  void _initialiseState() {
    _fields = widget.fieldDefinitions
        .map(_ModuleFieldDefinition.fromMap)
        .where((field) => field.key.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final responsesByKey = <String, FieldResponse>{
      for (final response in widget.initialResponses) response.key: response,
    };

    for (final field in _fields) {
      final existing = responsesByKey[field.key]?.value;
      switch (field.kind) {
        case _ModuleFieldKind.boolean:
          _boolValues[field.key] = _coerceBool(existing);
          break;
        case _ModuleFieldKind.singleSelect:
          _singleValues[field.key] = _cleanOptional(existing?.toString());
          if (field.options.isEmpty) {
            _textControllers[field.key] = TextEditingController(
              text: _cleanOptional(existing?.toString()) ?? '',
            );
          }
          break;
        case _ModuleFieldKind.multiSelect:
          final selected = _coerceStringSet(existing);
          _multiValues[field.key] = selected;
          if (field.options.isEmpty) {
            _textControllers[field.key] = TextEditingController(
              text: selected.join(', '),
            );
          }
          break;
        case _ModuleFieldKind.number:
        case _ModuleFieldKind.text:
        case _ModuleFieldKind.longText:
        case _ModuleFieldKind.dateTime:
          _textControllers[field.key] = TextEditingController(
            text: _valueToText(existing),
          );
          break;
        case _ModuleFieldKind.safetyGate:
        // Safety gates are not ordinary saved responses. They are rendered
        // as non-editable placeholders until the dedicated safety workflow is
        // implemented, so users do not mistake a dropdown for LOTO/gas
        // isolation confirmation.
          break;
      }
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    _textControllers.clear();
    _boolValues.clear();
    _singleValues.clear();
    _multiValues.clear();
    _fieldErrors.clear();
  }

  Future<void> _save() async {
    final errors = <String, String?>{};
    final responses = <FieldResponse>[];

    for (final field in _fields) {
      if (field.kind == _ModuleFieldKind.safetyGate) {
        continue;
      }

      final value = _readFieldValue(field);
      final isEmpty = _isEmptyValue(value);

      if (field.required && isEmpty) {
        errors[field.key] = 'Required';
        continue;
      }

      if (field.kind == _ModuleFieldKind.number && !isEmpty) {
        final raw = value.toString().trim();
        if (num.tryParse(raw) == null) {
          errors[field.key] = 'Enter a valid number';
          continue;
        }
      }

      if (!isEmpty) {
        responses.add(
          FieldResponse(
            key: field.key,
            fieldLabel: field.label,
            fieldType: field.toFieldType(),
            value: field.kind == _ModuleFieldKind.number
                ? num.tryParse(value.toString().trim()) ?? value
                : value,
          ),
        );
      }
    }

    if (errors.values.any((error) => error != null)) {
      setState(() {
        _fieldErrors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(_fieldErrors.clear);
    await widget.onSave(responses);
  }

  dynamic _readFieldValue(_ModuleFieldDefinition field) {
    switch (field.kind) {
      case _ModuleFieldKind.boolean:
        return _boolValues[field.key] ?? false;
      case _ModuleFieldKind.singleSelect:
        if (field.options.isEmpty) {
          return _cleanOptional(_textControllers[field.key]?.text);
        }
        return _cleanOptional(_singleValues[field.key]);
      case _ModuleFieldKind.multiSelect:
        if (field.options.isEmpty) {
          return _splitCsv(_textControllers[field.key]?.text ?? '');
        }
        return (_multiValues[field.key] ?? <String>{}).toList()..sort();
      case _ModuleFieldKind.number:
      case _ModuleFieldKind.text:
      case _ModuleFieldKind.longText:
      case _ModuleFieldKind.dateTime:
        return _cleanOptional(_textControllers[field.key]?.text);
      case _ModuleFieldKind.safetyGate:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fields.isEmpty) {
      return const _ResponseEmptyState(
        text: 'This module snapshot does not contain dynamic field definitions yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isEditable)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: BafSpacing.md),
            padding: const EdgeInsets.all(BafSpacing.md),
            decoration: BoxDecoration(
              color: BafColors.background,
              borderRadius: BorderRadius.circular(BafRadius.medium),
              border: Border.all(color: BafColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_rounded, color: BafColors.textSecondary, size: 18),
                SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    'This module is read-only in its current lifecycle state.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ..._fields.map(_buildField),
        const SizedBox(height: BafSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: widget.isEditable && !widget.isBusy ? _save : null,
            icon: const Icon(Icons.assignment_turned_in_rounded),
            label: Text(widget.saveButtonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: BafColors.sync,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(_ModuleFieldDefinition field) {
    final errorText = _fieldErrors[field.key];

    switch (field.kind) {
      case _ModuleFieldKind.boolean:
        return _FieldShell(
          field: field,
          errorText: errorText,
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _boolValues[field.key] ?? false,
            onChanged: widget.isEditable
                ? (value) => setState(() => _boolValues[field.key] = value ?? false)
                : null,
            title: Text(
              field.label,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      case _ModuleFieldKind.singleSelect:
        if (field.options.isEmpty) return _textInput(field, errorText: errorText);
        final current = field.options.contains(_singleValues[field.key])
            ? _singleValues[field.key]
            : null;
        return _FieldShell(
          field: field,
          errorText: errorText,
          child: DropdownButtonFormField<String>(
            initialValue: current,
            isExpanded: true,
            decoration: _inputDecoration(field.label, field: field).copyWith(
              errorText: errorText,
            ),
            items: field.options
                .map(
                  (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
                .toList(),
            onChanged: widget.isEditable
                ? (value) => setState(() => _singleValues[field.key] = value)
                : null,
          ),
        );
      case _ModuleFieldKind.multiSelect:
        if (field.options.isEmpty) {
          return _textInput(
            field,
            errorText: errorText,
            helperText: 'Enter comma-separated values.',
          );
        }
        final selected = _multiValues[field.key] ?? <String>{};
        return _FieldShell(
          field: field,
          errorText: errorText,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: field.options
                    .map(
                      (option) => FilterChip(
                    label: Text(option),
                    selected: selected.contains(option),
                    onSelected: widget.isEditable
                        ? (isSelected) {
                      setState(() {
                        final next = Set<String>.from(selected);
                        if (isSelected) {
                          next.add(option);
                        } else {
                          next.remove(option);
                        }
                        _multiValues[field.key] = next;
                      });
                    }
                        : null,
                  ),
                )
                    .toList(),
              ),
              if (errorText != null) _ErrorText(errorText),
            ],
          ),
        );
      case _ModuleFieldKind.number:
      case _ModuleFieldKind.text:
      case _ModuleFieldKind.longText:
      case _ModuleFieldKind.dateTime:
        return _textInput(field, errorText: errorText);
      case _ModuleFieldKind.safetyGate:
        return _SafetyGatePlaceholder(field: field);
    }
  }

  Widget _textInput(
      _ModuleFieldDefinition field, {
        String? errorText,
        String? helperText,
      }) {
    final controller = _textControllers.putIfAbsent(
      field.key,
          () => TextEditingController(),
    );

    return _FieldShell(
      field: field,
      errorText: errorText,
      child: TextField(
        controller: controller,
        enabled: widget.isEditable,
        maxLines: field.kind == _ModuleFieldKind.longText ? 4 : 1,
        keyboardType: field.kind == _ModuleFieldKind.number
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : TextInputType.text,
        decoration: _inputDecoration(field.label, field: field).copyWith(
          errorText: errorText,
          helperText: helperText,
          alignLabelWithHint: field.kind == _ModuleFieldKind.longText,
        ),
      ),
    );
  }
}


class _SafetyGatePlaceholder extends StatelessWidget {
  final _ModuleFieldDefinition field;

  const _SafetyGatePlaceholder({required this.field});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BafSpacing.md),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_rounded, color: BafColors.warning, size: 20),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.required ? '${field.label} *' : field.label,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Safety gate fields are handled by a dedicated safety-confirmation workflow. They are intentionally not saved as ordinary form responses.',
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                StatusBadge(label: field.typeLabel, color: BafColors.warning),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldShell extends StatelessWidget {
  final _ModuleFieldDefinition field;
  final Widget child;
  final String? errorText;

  const _FieldShell({
    required this.field,
    required this.child,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: BafSpacing.md),
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(
          color: errorText == null ? BafColors.border : BafColors.danger,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  field.required ? '${field.label} *' : field.label,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusBadge(
                label: field.typeLabel,
                color: BafColors.admin,
              ),
            ],
          ),
          if (field.unit != null) ...[
            const SizedBox(height: 4),
            Text(
              'Unit: ${field.unit}',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.sm),
          child,
          if (errorText != null) _ErrorText(errorText!),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;

  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: BafColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ResponseEmptyState extends StatelessWidget {
  final String text;

  const _ResponseEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.dynamic_form_rounded, color: BafColors.textSecondary, size: 20),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _inputDecoration(
    String label, {
      required _ModuleFieldDefinition field,
    }) {
  final suffix = field.unit == null ? null : ' ${field.unit}';
  return InputDecoration(
    labelText: field.required ? '$label *' : label,
    suffixText: suffix,
    labelStyle: const TextStyle(color: BafColors.textSecondary),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.planned, width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
  );
}

enum _ModuleFieldKind {
  text,
  longText,
  number,
  boolean,
  singleSelect,
  multiSelect,
  dateTime,
  safetyGate,
}

class _ModuleFieldDefinition {
  final String key;
  final String label;
  final String rawType;
  final String? unit;
  final bool required;
  final List<String> options;
  final int order;

  const _ModuleFieldDefinition({
    required this.key,
    required this.label,
    required this.rawType,
    required this.unit,
    required this.required,
    required this.options,
    required this.order,
  });

  factory _ModuleFieldDefinition.fromMap(Map<String, dynamic> map) {
    final key = _cleanOptional(map['fieldId']?.toString()) ??
        _cleanOptional(map['key']?.toString()) ??
        '';
    final label = _cleanOptional(map['label']?.toString()) ?? key;
    final rawType = _cleanOptional(map['type']?.toString()) ?? 'text';
    final options = map['options'] is List
        ? (map['options'] as List)
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList()
        : <String>[];

    return _ModuleFieldDefinition(
      key: key,
      label: label,
      rawType: rawType,
      unit: _cleanOptional(map['unit']?.toString()),
      required: map['required'] == true || map['isRequired'] == true,
      options: options,
      order: _coerceInt(map['order']) ?? 0,
    );
  }

  _ModuleFieldKind get kind {
    final normalized = rawType
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');

    if (normalized == 'longtext' || normalized == 'textarea') {
      return _ModuleFieldKind.longText;
    }
    if (normalized == 'number' || normalized == 'numeric' || normalized == 'numericwithunit') {
      return _ModuleFieldKind.number;
    }
    if (normalized == 'boolean' || normalized == 'yesno' || normalized == 'checkbox') {
      return _ModuleFieldKind.boolean;
    }
    if (normalized == 'multiselect' || normalized == 'multitag') {
      return _ModuleFieldKind.multiSelect;
    }
    if (normalized == 'safetygate') {
      return _ModuleFieldKind.safetyGate;
    }

    if (normalized == 'enum' ||
        normalized == 'dropdown' ||
        normalized == 'devicetagpicklist' ||
        normalized == 'procedureref' ||
        normalized == 'targetrule') {
      return _ModuleFieldKind.singleSelect;
    }
    if (normalized == 'datetime' || normalized == 'date') {
      return _ModuleFieldKind.dateTime;
    }
    return _ModuleFieldKind.text;
  }

  String get typeLabel {
    switch (kind) {
      case _ModuleFieldKind.text:
        return 'Text';
      case _ModuleFieldKind.longText:
        return 'Long text';
      case _ModuleFieldKind.number:
        return unit == null ? 'Number' : 'Number + unit';
      case _ModuleFieldKind.boolean:
        return 'Yes / No';
      case _ModuleFieldKind.singleSelect:
        return options.isEmpty ? 'Text' : 'Select';
      case _ModuleFieldKind.multiSelect:
        return options.isEmpty ? 'Multi text' : 'Multi-select';
      case _ModuleFieldKind.dateTime:
        return 'Date/time';
      case _ModuleFieldKind.safetyGate:
        return 'Safety gate';
    }
  }

  FieldType toFieldType() {
    switch (kind) {
      case _ModuleFieldKind.text:
        return FieldType.text;
      case _ModuleFieldKind.longText:
        return FieldType.longText;
      case _ModuleFieldKind.number:
        return FieldType.number;
      case _ModuleFieldKind.boolean:
        return FieldType.yesNo;
      case _ModuleFieldKind.singleSelect:
        return options.isEmpty ? FieldType.text : FieldType.dropdown;
      case _ModuleFieldKind.multiSelect:
        return FieldType.multiSelect;
      case _ModuleFieldKind.dateTime:
        return FieldType.dateTime;
      case _ModuleFieldKind.safetyGate:
        return FieldType.instruction;
    }
  }
}

String _valueToText(dynamic value) {
  if (value == null) return '';
  if (value is List) return value.join(', ');
  return value.toString();
}

bool _coerceBool(dynamic value) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  return normalized == 'true' || normalized == 'yes' || normalized == 'y' || normalized == '1';
}

Set<String> _coerceStringSet(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }
  return _splitCsv(value?.toString() ?? '').toSet();
}

List<String> _splitCsv(String value) {
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

bool _isEmptyValue(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is List) return value.isEmpty;
  return false;
}

String? _cleanOptional(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

int? _coerceInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
