// FILE: lib/features/planned_maintenance/presentation/widgets/job_module_response_summary.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../data/job_template_model.dart';

/// Read-only renderer for saved structured module responses.
///
/// This widget is deliberately small and reusable: it is used first inside the
/// module workspace and can later be reused by the final closed-job dossier.
///
/// Callers validate and decode the persisted field-definition payload before
/// constructing this presentation-only widget.
class JobModuleResponseSummary extends StatelessWidget {
  final List<FieldResponse> responses;
  final List<Map<String, dynamic>> fieldDefinitions;
  final String emptyText;

  const JobModuleResponseSummary({
    super.key,
    required this.responses,
    this.fieldDefinitions = const [],
    this.emptyText = 'No structured responses have been saved yet.',
  });

  @override
  Widget build(BuildContext context) {
    final metadataByKey = _metadataByFieldKey(
      fieldDefinitions: fieldDefinitions,
    );

    final visibleResponses = responses
        .where((response) => response.key.trim().isNotEmpty)
        .toList()
      ..sort((a, b) {
        final aMeta = metadataByKey[a.key.trim()];
        final bMeta = metadataByKey[b.key.trim()];
        final orderCompare = (aMeta?.order ?? 999999).compareTo(
          bMeta?.order ?? 999999,
        );
        if (orderCompare != 0) return orderCompare;
        return _labelFor(a, aMeta).compareTo(_labelFor(b, bMeta));
      });

    if (visibleResponses.isEmpty) {
      return _SummaryEmptyState(text: emptyText);
    }

    final requiredCount = visibleResponses.where((response) {
      return metadataByKey[response.key.trim()]?.required == true;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.fact_check_rounded,
              size: 18,
              color: BafColors.sync,
            ),
            const SizedBox(width: BafSpacing.sm),
            Expanded(
              child: Text(
                '${visibleResponses.length} structured response${visibleResponses.length == 1 ? '' : 's'} saved',
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (requiredCount > 0)
              StatusBadge(
                label: '$requiredCount required',
                color: BafColors.danger,
                icon: Icons.lock_rounded,
              ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        ...visibleResponses.map(
              (response) => Padding(
            padding: const EdgeInsets.only(bottom: BafSpacing.sm),
            child: _ResponseSummaryTile(
              response: response,
              metadata: metadataByKey[response.key.trim()],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResponseSummaryTile extends StatelessWidget {
  final FieldResponse response;
  final _FieldMetadata? metadata;

  const _ResponseSummaryTile({
    required this.response,
    required this.metadata,
  });

  @override
  Widget build(BuildContext context) {
    final valueText = _formatValue(
      response.value,
      unit: metadata?.unit,
      fieldType: response.fieldType,
    );
    final label = _labelFor(response, metadata);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.end,
                children: [
                  if (metadata?.required == true)
                    const StatusBadge(
                      label: 'Required',
                      color: BafColors.danger,
                      icon: Icons.lock_rounded,
                    ),
                  StatusBadge(
                    label: _fieldTypeLabel(response.fieldType),
                    color: BafColors.planned,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            valueText,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          if (_hasText(metadata?.unit)) ...[
            const SizedBox(height: 6),
            StatusBadge(
              label: 'Unit: ${metadata!.unit!.trim()}',
              color: BafColors.assets,
              icon: Icons.straighten_rounded,
            ),
          ],
          if (response.key.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              response.key.trim(),
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryEmptyState extends StatelessWidget {
  final String text;

  const _SummaryEmptyState({required this.text});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_outlined,
            color: BafColors.textSecondary,
            size: 18,
          ),
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

class _FieldMetadata {
  final String key;
  final String? label;
  final String? unit;
  final bool required;
  final int order;

  const _FieldMetadata({
    required this.key,
    required this.label,
    required this.unit,
    required this.required,
    required this.order,
  });
}

Map<String, _FieldMetadata> _metadataByFieldKey({
  required List<Map<String, dynamic>> fieldDefinitions,
}) {
  final result = <String, _FieldMetadata>{};

  // Keep the existing live-workspace API first.
  for (var i = 0; i < fieldDefinitions.length; i++) {
    final metadata = _metadataFromMap(fieldDefinitions[i], fallbackOrder: i);
    if (metadata != null) {
      result[metadata.key] = metadata;
    }
  }

  return result;
}

_FieldMetadata? _metadataFromMap(
    Map<String, dynamic> map, {
      required int fallbackOrder,
    }) {
  final key = _cleanOptional(map['fieldId']?.toString()) ??
      _cleanOptional(map['key']?.toString());
  if (key == null) return null;

  return _FieldMetadata(
    key: key,
    label: _cleanOptional(map['label']?.toString()) ??
        _cleanOptional(map['fieldLabel']?.toString()),
    unit: _cleanOptional(map['unit']?.toString()),
    required: map['required'] == true || map['isRequired'] == true,
    order: _intOr(map['order'], fallbackOrder),
  );
}

String _labelFor(FieldResponse response, [_FieldMetadata? metadata]) {
  final metaLabel = metadata?.label?.trim();
  if (metaLabel != null && metaLabel.isNotEmpty) return metaLabel;
  final label = response.fieldLabel.trim();
  if (label.isNotEmpty) return label;
  return response.key.trim().isEmpty ? 'Response' : response.key.trim();
}

String _formatValue(
    dynamic value, {
      String? unit,
      required FieldType fieldType,
    }) {
  if (value == null) return '—';

  final formatted = _formatRawValue(value);
  final cleanedUnit = _cleanOptional(unit);
  if (formatted == '—' || cleanedUnit == null) return formatted;

  // The old widget appended units only when present. Keeping that behavior for
  // numeric fields prevents odd strings like "Yes bar" for non-measurement
  // answers while still showing a separate Unit badge when metadata contains it.
  if (fieldType == FieldType.number) return '$formatted $cleanedUnit';
  return formatted;
}

String _formatRawValue(dynamic value) {
  if (value == null) return '—';

  if (value is bool) return value ? 'Yes' : 'No';

  if (value is DateTime) {
    return '${value.day.toString().padLeft(2, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  if (value is Iterable) {
    final items = value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return items.isEmpty ? '—' : items.join(', ');
  }

  if (value is Map) {
    final parts = value.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    return parts.isEmpty ? '—' : parts.join('\n');
  }

  final text = value.toString().trim();
  return text.isEmpty ? '—' : text;
}

String? _cleanOptional(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String _fieldTypeLabel(FieldType type) {
  switch (type) {
    case FieldType.text:
      return 'Text';
    case FieldType.longText:
      return 'Long text';
    case FieldType.number:
      return 'Number';
    case FieldType.yesNo:
      return 'Yes/No';
    case FieldType.checkbox:
      return 'Check';
    case FieldType.dropdown:
      return 'Select';
    case FieldType.multiSelect:
      return 'Multi-select';
    case FieldType.dateTime:
      return 'Date/Time';
    case FieldType.sectionHeader:
      return 'Section';
    case FieldType.instruction:
      return 'Instruction';
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

int _intOr(dynamic value, int fallback) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
