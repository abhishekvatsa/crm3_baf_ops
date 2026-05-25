part of 'template_publisher_screen.dart';

class _PublisherPayloadSemanticResult {
  final List<String> errors;
  final List<String> warnings;

  const _PublisherPayloadSemanticResult({
    this.errors = const <String>[],
    this.warnings = const <String>[],
  });
}

class _ValidationResult {
  final List<String> errors;
  final List<String> warnings;
  final String? contentHash;
  final int moduleCount;
  final int fieldCount;
  final int checklistCount;
  final bool? canSaveDraftOverride;

  const _ValidationResult({
    required this.errors,
    required this.warnings,
    required this.contentHash,
    required this.moduleCount,
    required this.fieldCount,
    required this.checklistCount,
    this.canSaveDraftOverride,
  });

  bool get canSaveDraft => canSaveDraftOverride ?? errors.isEmpty;
  bool get canPublish => errors.isEmpty;
}

class _JsonCheck {
  final String? error;
  final String? warning;
  final int itemCount;
  final String? normalizedJson;

  const _JsonCheck({
    this.error,
    this.warning,
    this.itemCount = 0,
    this.normalizedJson,
  });
}

class _CachedJsonCheck {
  final String raw;
  final _JsonRoot expectedRoot;
  final bool allowEmpty;
  final _JsonCheck result;

  const _CachedJsonCheck({
    required this.raw,
    required this.expectedRoot,
    required this.allowEmpty,
    required this.result,
  });
}

enum _JsonRoot { object, list }

class _DisciplineOption {
  final String value;
  final String label;
  final IconData icon;

  const _DisciplineOption(this.value, this.label, this.icon);
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
