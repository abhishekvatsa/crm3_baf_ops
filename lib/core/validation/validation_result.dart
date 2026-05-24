// FILE: lib/core/validation/validation_result.dart

class ValidationIssue {
  final String field;
  final String message;

  const ValidationIssue({required this.field, required this.message});

  @override
  String toString() => '$field: $message';
}

class ValidationResult {
  final List<ValidationIssue> issues;

  const ValidationResult._(this.issues);

  const ValidationResult.valid() : issues = const <ValidationIssue>[];

  factory ValidationResult.invalid(Iterable<ValidationIssue> issues) {
    return ValidationResult._(List<ValidationIssue>.unmodifiable(issues));
  }

  bool get isValid => issues.isEmpty;

  bool get isInvalid => !isValid;

  String? messageFor(String field) {
    for (final issue in issues) {
      if (issue.field == field) {
        return issue.message;
      }
    }
    return null;
  }

  String get summary {
    if (issues.isEmpty) {
      return 'Valid';
    }
    if (issues.length == 1) {
      return issues.single.message;
    }
    return issues.map((issue) => issue.message).join('\n');
  }

  void requireValid() {
    if (isValid) {
      return;
    }
    throw FormatException(summary);
  }

  static ValidationResult combine(Iterable<ValidationResult> results) {
    final issues = <ValidationIssue>[];
    for (final result in results) {
      issues.addAll(result.issues);
    }
    return issues.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(issues);
  }
}
