import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class PersistedDataFormatException extends FormatException {
  final String fieldName;

  PersistedDataFormatException({
    required String field,
    String? source,
    String? detail,
  }) : fieldName = field,
       super(
         'Invalid persisted field "$field"'
         '${source == null ? '' : ' in $source'}'
         '${detail == null ? '' : ': $detail'}.',
       );
}

String readRequiredPersistedString(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'required non-empty string (${value.runtimeType})',
  );
}

String? readOptionalPersistedString(
  dynamic value, {
  required String field,
  String? source,
  bool emptyAsNull = true,
}) {
  if (value == null) return null;
  if (value is! String) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a string (${value.runtimeType})',
    );
  }
  final cleaned = value.trim();
  return emptyAsNull && cleaned.isEmpty ? null : cleaned;
}

double? readOptionalPersistedDouble(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'expected a finite number (${value.runtimeType})',
  );
}

List<String> readOptionalPersistedStringList(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return const <String>[];
  if (value is! List) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected an array (${value.runtimeType})',
    );
  }
  final result = <String>[];
  for (var index = 0; index < value.length; index++) {
    final entry = value[index];
    if (entry is! String || entry.trim().isEmpty) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'expected a non-empty string (${entry.runtimeType})',
      );
    }
    result.add(entry.trim());
  }
  return result;
}

T readRequiredPersistedEnum<T extends Enum>(
  List<T> values,
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value is String) {
    for (final item in values) {
      if (item.name == value) return item;
    }
  }
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'unknown enum value "$value"',
  );
}

T? readOptionalPersistedEnum<T extends Enum>(
  List<T> values,
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return null;
  return readRequiredPersistedEnum(values, value, field: field, source: source);
}

DateTime readRequiredPersistedDateTime(
  dynamic value, {
  required String field,
  String? source,
  bool allowEpochMilliseconds = false,
}) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  if (allowEpochMilliseconds && value is int) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } on RangeError {
      // Converted into the stable format exception below.
    }
  }
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'required timestamp (${value.runtimeType})',
  );
}

List<Map<String, dynamic>> readRequiredJsonObjectList(
  String value, {
  required String field,
  String? source,
}) {
  dynamic decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'malformed JSON',
    );
  }
  if (decoded is! List) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a JSON array',
    );
  }

  final result = <Map<String, dynamic>>[];
  for (var index = 0; index < decoded.length; index++) {
    final entry = decoded[index];
    if (entry is! Map) {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'expected a JSON object',
      );
    }
    try {
      result.add(Map<String, dynamic>.from(entry));
    } on TypeError {
      throw PersistedDataFormatException(
        field: '$field[$index]',
        source: source,
        detail: 'object keys must be strings',
      );
    }
  }
  return result;
}

Map<String, dynamic>? readOptionalJsonObject(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null || (value is String && value.trim().isEmpty)) return null;

  dynamic decoded = value;
  if (value is String) {
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw PersistedDataFormatException(
        field: field,
        source: source,
        detail: 'malformed JSON',
      );
    }
  }
  if (decoded is! Map) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected a JSON object',
    );
  }
  try {
    return Map<String, dynamic>.from(decoded);
  } on TypeError {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'object keys must be strings',
    );
  }
}
