part of 'module_composer_screen.dart';

extension _ModuleComposerHelpers on _ModuleComposerScreenState {
  String _uniqueModuleCode(String base) {
    final existing =
        _draft.modules.map((module) => module.moduleCode.toLowerCase()).toSet();
    var code =
        base.trim().isEmpty ? 'M-${_draft.modules.length + 1}' : base.trim();
    if (!existing.contains(code.toLowerCase())) {
      return code;
    }
    var suffix = 2;
    while (existing.contains('$code-$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '$code-$suffix';
  }

  String _uniqueFieldKey(ComposerModuleDraft module, String base) {
    final existing =
        module.fields.map((field) => field.key.toLowerCase()).toSet();
    var key = _slugKey(base);
    if (key.isEmpty) {
      key = 'field_${module.fields.length + 1}';
    }
    if (!existing.contains(key.toLowerCase())) {
      return key;
    }
    var suffix = 2;
    while (existing.contains('${key}_$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '${key}_$suffix';
  }

  String _uniqueChecklistId(ComposerModuleDraft module, String base) {
    final existing =
        module.checklistItems.map((item) => item.id.toLowerCase()).toSet();
    var id =
        base.trim().isEmpty
            ? '${module.moduleCode}-item-${module.checklistItems.length + 1}'
            : base.trim();
    if (!existing.contains(id.toLowerCase())) {
      return id;
    }
    var suffix = 2;
    while (existing.contains('$id-$suffix'.toLowerCase())) {
      suffix += 1;
    }
    return '$id-$suffix';
  }

  void _showSnack(String message, Color color) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

InputDecoration _inputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: BafColors.textSecondary),
    filled: true,
    fillColor: BafColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
  );
}

List<String> _splitComma(String value) {
  return value
      .split(RegExp(r'[,;|]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
}

String _slugKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _ownerFromDiscipline(JobModuleDiscipline discipline) {
  switch (discipline) {
    case JobModuleDiscipline.mechanical:
      return 'mechanical';
    case JobModuleDiscipline.electrical:
      return 'electrical';
    case JobModuleDiscipline.instrumentation:
      return 'instrumentation';
    case JobModuleDiscipline.operations:
      return 'operations';
    case JobModuleDiscipline.emd:
      return 'emd';
    case JobModuleDiscipline.refractory:
      return 'refractory';
    case JobModuleDiscipline.shared:
      return 'shared';
    default:
      return 'others';
  }
}

String _normaliseSafetyText(String value) =>
    _slugKey(value).replaceAll('_', '');

bool _moduleLooksSafetyCritical(ComposerModuleDraft module) {
  final text = module.safetyClasses.join(' ').toLowerCase();
  return text.contains('gas') ||
      text.contains('hydrogen') ||
      text.contains('explosion') ||
      text.contains('loto') ||
      text.contains('interlock') ||
      text.contains('hydraulic') ||
      text.contains('water') ||
      text.contains('combustion');
}

bool _seedSuggestsClosureCritical(BafModuleSeed seed) {
  final text =
      [
        seed.defaultSafetyClass.name,
        seed.componentGroup,
        seed.functionalSection,
        ...seed.safetyConfirmations,
      ].join(' ').toLowerCase();
  return text.contains('gas') ||
      text.contains('hydrogen') ||
      text.contains('pressure') ||
      text.contains('loto') ||
      text.contains('safety') ||
      text.contains('clamp') ||
      text.contains('water') ||
      text.contains('combustion');
}

List<String> _extractTagsFromSeed(BafModuleSeed seed) {
  final tags = <String>{};
  final pattern = RegExp(r'\b[A-Z]{1,5}\d{1,3}[A-Z]?\b');
  for (final text in [
    seed.moduleTitle,
    seed.functionalSection,
    seed.componentGroup,
    ...seed.fields.map((field) => field.fieldId),
    ...seed.fields.map((field) => field.label),
    ...seed.standardItems.map((item) => item.title),
  ]) {
    for (final match in pattern.allMatches(text.toUpperCase())) {
      tags.add(match.group(0)!);
    }
  }
  return tags.toList()..sort();
}

ComposerFieldDraft _fieldFromSeed(
  BafModuleFieldSeed seedField,
  int order,
  BafModuleSeed parent,
) {
  final type = switch (seedField.type.toLowerCase()) {
    'boolean' || 'bool' => ComposerFieldType.yesNo,
    'enum' => ComposerFieldType.dropdown,
    'numeric' => ComposerFieldType.number,
    'numericwithunit' => ComposerFieldType.numericWithUnit,
    'multiselect' => ComposerFieldType.multiSelect,
    'longtext' => ComposerFieldType.longText,
    _ => ComposerFieldType.text,
  };
  final safety = _seedSuggestsClosureCritical(parent);
  return ComposerFieldDraft(
    key: _slugKey(seedField.fieldId),
    label: seedField.label,
    type: type,
    isRequired: seedField.required || safety,
    order: order,
    unit: seedField.unit,
    options: List<String>.from(seedField.options),
    instructionText: 'Cloned from seed catalogue ${parent.moduleCode}.',
    isSafetyCriticalPreset: safety,
    sourcePresetId: '${parent.moduleCode}:${seedField.fieldId}',
    meta: <String, dynamic>{
      'sourceSeedCode': parent.moduleCode,
      'sourceFieldId': seedField.fieldId,
      'isSafetyCriticalPreset': safety,
    },
  );
}

String _assetLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'Base';
    case AssetType.furnace:
      return 'Furnace';
    case AssetType.forceCooler:
      return 'Forced Cooler';
    case AssetType.innerCover:
      return 'Inner Cover';
    case AssetType.governedCustom:
      return 'Governed Asset';
  }
}

String _disciplineLabel(JobModuleDiscipline discipline) =>
    _enumLabel(discipline.name);

String _enumLabel(String value) {
  final spaced = value.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => ' ${match.group(0)}',
  );
  return spaced
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            part.length == 1
                ? part.toUpperCase()
                : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

String _readinessLabel(ComposerReadiness readiness) =>
    _enumLabel(readiness.name);

Color _readinessColor(ComposerReadiness readiness) {
  switch (readiness) {
    case ComposerReadiness.readyPreset:
      return BafColors.success;
    case ComposerReadiness.needsReview:
      return BafColors.warning;
    case ComposerReadiness.consultRequired:
      return BafColors.danger;
    case ComposerReadiness.tagOnly:
      return BafColors.sync;
    case ComposerReadiness.troubleshootingOnly:
      return BafColors.maintenance;
    case ComposerReadiness.futureIntegration:
      return BafColors.planned;
    case ComposerReadiness.referenceOnly:
      return BafColors.textSecondary;
  }
}

String _compactPreview(String jsonText) {
  try {
    final decoded = jsonDecode(jsonText);
    final compact = const JsonEncoder.withIndent('  ').convert(decoded);
    return compact.length > _jsonPreviewMaxChars
        ? '${compact.substring(0, _jsonPreviewMaxChars)}\n…'
        : compact;
  } catch (_) {
    return jsonText.length > _jsonPreviewMaxChars
        ? '${jsonText.substring(0, _jsonPreviewMaxChars)}\n…'
        : jsonText;
  }
}
