// FILE: lib/core/validation/field_validators.dart

import 'validation_result.dart';

class FieldValidators {
  static final RegExp _controlCharacters = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  const FieldValidators._();

  static String clean(String? value) => value?.trim() ?? '';

  static ValidationResult requiredText(
    String? value, {
    required String field,
    required String label,
    int minLength = 1,
    int maxLength = 255,
  }) {
    final text = clean(value);
    final issues = <ValidationIssue>[];

    if (text.isEmpty) {
      issues.add(ValidationIssue(field: field, message: '$label is required.'));
    } else if (text.length < minLength) {
      issues.add(
        ValidationIssue(
          field: field,
          message: '$label must be at least $minLength characters.',
        ),
      );
    }

    issues.addAll(
      _lengthAndCharacterIssues(
        text,
        field: field,
        label: label,
        maxLength: maxLength,
      ),
    );

    return issues.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(issues);
  }

  static ValidationResult optionalText(
    String? value, {
    required String field,
    required String label,
    int maxLength = 255,
  }) {
    final text = clean(value);
    if (text.isEmpty) {
      return const ValidationResult.valid();
    }

    final issues = _lengthAndCharacterIssues(
      text,
      field: field,
      label: label,
      maxLength: maxLength,
    );

    return issues.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(issues);
  }

  static ValidationResult integerText(
    String? value, {
    required String field,
    required String label,
    bool isRequired = true,
    int? min,
    int? max,
  }) {
    final text = clean(value);
    if (text.isEmpty) {
      return isRequired
          ? ValidationResult.invalid([
            ValidationIssue(field: field, message: '$label is required.'),
          ])
          : const ValidationResult.valid();
    }

    if (_controlCharacters.hasMatch(text)) {
      return ValidationResult.invalid([
        ValidationIssue(
          field: field,
          message: '$label contains unsupported control characters.',
        ),
      ]);
    }

    final parsed = int.tryParse(text);
    if (parsed == null) {
      return ValidationResult.invalid([
        ValidationIssue(
          field: field,
          message: '$label must be a whole number.',
        ),
      ]);
    }

    final issues = <ValidationIssue>[];
    if (min != null && parsed < min) {
      issues.add(
        ValidationIssue(field: field, message: '$label must be at least $min.'),
      );
    }
    if (max != null && parsed > max) {
      issues.add(
        ValidationIssue(field: field, message: '$label must be at most $max.'),
      );
    }

    return issues.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(issues);
  }

  static ValidationResult email(
    String? value, {
    required String field,
    required String label,
    bool isRequired = true,
    int maxLength = 320,
  }) {
    final text = clean(value);
    if (text.isEmpty) {
      return isRequired
          ? ValidationResult.invalid([
            ValidationIssue(field: field, message: '$label is required.'),
          ])
          : const ValidationResult.valid();
    }

    final issues = <ValidationIssue>[];
    issues.addAll(
      _lengthAndCharacterIssues(
        text,
        field: field,
        label: label,
        maxLength: maxLength,
      ),
    );
    if (!_emailPattern.hasMatch(text)) {
      issues.add(
        ValidationIssue(field: field, message: '$label must be a valid email.'),
      );
    }

    return issues.isEmpty
        ? const ValidationResult.valid()
        : ValidationResult.invalid(issues);
  }

  static ValidationResult dateNotFuture(
    DateTime value, {
    required String field,
    required String label,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (value.isAfter(current)) {
      return ValidationResult.invalid([
        ValidationIssue(
          field: field,
          message: '$label cannot be in the future.',
        ),
      ]);
    }
    return const ValidationResult.valid();
  }

  static ValidationResult dateNotBefore(
    DateTime value, {
    required String field,
    required String label,
    required DateTime minimum,
    required String minimumLabel,
  }) {
    if (value.isBefore(minimum)) {
      return ValidationResult.invalid([
        ValidationIssue(
          field: field,
          message: '$label cannot be before $minimumLabel.',
        ),
      ]);
    }
    return const ValidationResult.valid();
  }

  static List<ValidationIssue> _lengthAndCharacterIssues(
    String text, {
    required String field,
    required String label,
    required int maxLength,
  }) {
    final issues = <ValidationIssue>[];
    if (text.length > maxLength) {
      issues.add(
        ValidationIssue(
          field: field,
          message: '$label must be $maxLength characters or fewer.',
        ),
      );
    }
    if (_controlCharacters.hasMatch(text)) {
      issues.add(
        ValidationIssue(
          field: field,
          message: '$label contains unsupported control characters.',
        ),
      );
    }
    return issues;
  }
}
