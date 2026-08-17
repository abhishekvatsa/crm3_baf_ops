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
  bool trim = true,
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
  if (emptyAsNull && cleaned.isEmpty) return null;
  return trim ? cleaned : value;
}

bool readRequiredPersistedBool(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value is bool) return value;
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'required boolean (${value.runtimeType})',
  );
}

bool? readOptionalPersistedBool(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return null;
  return readRequiredPersistedBool(value, field: field, source: source);
}

int readRequiredPersistedInt(
  dynamic value, {
  required String field,
  String? source,
  int? minimum,
}) {
  if (value is int && (minimum == null || value >= minimum)) return value;
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail:
        minimum == null
            ? 'required integer (${value.runtimeType})'
            : 'required integer >= $minimum (${value.runtimeType})',
  );
}

int? readOptionalPersistedInt(
  dynamic value, {
  required String field,
  String? source,
  int? minimum,
}) {
  if (value == null) return null;
  return readRequiredPersistedInt(
    value,
    field: field,
    source: source,
    minimum: minimum,
  );
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

List<String>? readNullablePersistedStringList(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return null;
  return readOptionalPersistedStringList(value, field: field, source: source);
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
  bool allowSerializedTimestampMap = false,
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
  if (allowSerializedTimestampMap && value is Map) {
    final hasPrivateSeconds = value.containsKey('_seconds');
    final hasPrivateNanoseconds = value.containsKey('_nanoseconds');
    final hasPublicSeconds = value.containsKey('seconds');
    final hasPublicNanoseconds = value.containsKey('nanoseconds');
    final hasPrivateShape = hasPrivateSeconds || hasPrivateNanoseconds;
    final hasPublicShape = hasPublicSeconds || hasPublicNanoseconds;

    if (hasPrivateShape != hasPublicShape) {
      final secondsKey = hasPrivateShape ? '_seconds' : 'seconds';
      final nanosecondsKey = hasPrivateShape ? '_nanoseconds' : 'nanoseconds';
      final seconds = value[secondsKey];
      final nanoseconds = value[nanosecondsKey];
      if (value.containsKey(secondsKey) &&
          value.containsKey(nanosecondsKey) &&
          seconds is int &&
          nanoseconds is int) {
        try {
          return Timestamp(seconds, nanoseconds).toDate().toUtc();
        } on ArgumentError {
          // Converted into the stable format exception below.
        }
      }
    }
  }
  throw PersistedDataFormatException(
    field: field,
    source: source,
    detail: 'required timestamp (${value.runtimeType})',
  );
}

DateTime? readOptionalPersistedDateTime(
  dynamic value, {
  required String field,
  String? source,
  bool allowEpochMilliseconds = false,
  bool allowSerializedTimestampMap = false,
}) {
  if (value == null) return null;
  return readRequiredPersistedDateTime(
    value,
    field: field,
    source: source,
    allowEpochMilliseconds: allowEpochMilliseconds,
    allowSerializedTimestampMap: allowSerializedTimestampMap,
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

Map<String, dynamic> readRequiredJsonObject(
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

int readPersistedPayloadSchemaVersion(
  Map<String, dynamic> record, {
  required String field,
  String? source,
  int currentVersion = 1,
  bool allowLegacyAbsent = true,
}) {
  if (!record.containsKey(field)) {
    if (allowLegacyAbsent) return 0;
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'required payload schema version',
    );
  }
  final value = record[field];
  if (value is! int || value != currentVersion) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'supported payload schema version is $currentVersion ($value)',
    );
  }
  return value;
}

dynamic readBoundedPersistedJsonValue(
  dynamic value, {
  required String field,
  String? source,
  int maximumDepth = 6,
  int maximumCollectionEntries = 128,
  int maximumStringLength = 8192,
  int maximumEncodedBytes = 32768,
}) {
  dynamic validate(dynamic current, String path, int depth) {
    if (depth > maximumDepth) {
      throw PersistedDataFormatException(
        field: path,
        source: source,
        detail: 'JSON nesting exceeds $maximumDepth levels',
      );
    }
    if (current == null || current is bool || current is int) return current;
    if (current is double) {
      if (current.isFinite) return current;
      throw PersistedDataFormatException(
        field: path,
        source: source,
        detail: 'JSON number must be finite',
      );
    }
    if (current is String) {
      if (current.length <= maximumStringLength) return current;
      throw PersistedDataFormatException(
        field: path,
        source: source,
        detail: 'JSON string exceeds $maximumStringLength characters',
      );
    }
    if (current is List) {
      if (current.length > maximumCollectionEntries) {
        throw PersistedDataFormatException(
          field: path,
          source: source,
          detail: 'JSON array exceeds $maximumCollectionEntries entries',
        );
      }
      return List<dynamic>.unmodifiable(<dynamic>[
        for (var index = 0; index < current.length; index++)
          validate(current[index], '$path[$index]', depth + 1),
      ]);
    }
    if (current is Map) {
      if (current.length > maximumCollectionEntries) {
        throw PersistedDataFormatException(
          field: path,
          source: source,
          detail: 'JSON object exceeds $maximumCollectionEntries fields',
        );
      }
      final result = <String, dynamic>{};
      for (final entry in current.entries) {
        if (entry.key is! String || (entry.key as String).trim().isEmpty) {
          throw PersistedDataFormatException(
            field: path,
            source: source,
            detail: 'JSON object keys must be non-empty strings',
          );
        }
        final key = entry.key as String;
        if (key.length > 128) {
          throw PersistedDataFormatException(
            field: '$path.$key',
            source: source,
            detail: 'JSON object key exceeds 128 characters',
          );
        }
        result[key] = validate(entry.value, '$path.$key', depth + 1);
      }
      return Map<String, dynamic>.unmodifiable(result);
    }
    throw PersistedDataFormatException(
      field: path,
      source: source,
      detail: 'unsupported JSON value (${current.runtimeType})',
    );
  }

  final validated = validate(value, field, 0);
  final encoded = jsonEncode(validated);
  if (utf8.encode(encoded).length > maximumEncodedBytes) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'encoded JSON exceeds $maximumEncodedBytes bytes',
    );
  }
  return validated;
}

Map<String, dynamic>? readOptionalBoundedJsonObject(
  dynamic value, {
  required String field,
  String? source,
  int maximumDepth = 6,
  int maximumCollectionEntries = 128,
  int maximumStringLength = 8192,
  int maximumEncodedBytes = 32768,
}) {
  final object = readOptionalJsonObject(value, field: field, source: source);
  if (object == null) return null;
  return readBoundedPersistedJsonValue(
        object,
        field: field,
        source: source,
        maximumDepth: maximumDepth,
        maximumCollectionEntries: maximumCollectionEntries,
        maximumStringLength: maximumStringLength,
        maximumEncodedBytes: maximumEncodedBytes,
      )
      as Map<String, dynamic>;
}

Map<String, dynamic> readBoundedPersistedExtensionBag(
  Map<String, dynamic> record, {
  required Set<String> knownFields,
  required Map<String, PersistedExtensionValueKind> allowedFields,
  required String field,
  String? source,
  int maximumEntries = 8,
  int maximumEncodedBytes = 8192,
}) {
  final extensions = <String, dynamic>{
    for (final entry in record.entries)
      if (!knownFields.contains(entry.key)) entry.key: entry.value,
  };
  return validateBoundedPersistedExtensionBag(
    extensions,
    allowedFields: allowedFields,
    field: field,
    source: source,
    maximumEntries: maximumEntries,
    maximumEncodedBytes: maximumEncodedBytes,
  );
}

enum PersistedExtensionValueKind {
  string,
  boolean,
  integer,
  finiteNumber,
  stringList,
}

Map<String, dynamic> validateBoundedPersistedExtensionBag(
  Map<String, dynamic> extensions, {
  required Map<String, PersistedExtensionValueKind> allowedFields,
  required String field,
  String? source,
  int maximumEntries = 8,
  int maximumEncodedBytes = 8192,
}) {
  if (extensions.length > maximumEntries) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'at most $maximumEntries registered extension fields are allowed',
    );
  }

  for (final entry in extensions.entries) {
    final expected = allowedFields[entry.key];
    if (expected == null) {
      throw PersistedDataFormatException(
        field: '$field.${entry.key}',
        source: source,
        detail: 'unregistered extension field',
      );
    }
    _validatePersistedExtensionValue(
      entry.value,
      expected: expected,
      field: '$field.${entry.key}',
      source: source,
    );
  }

  late final String encoded;
  try {
    encoded = jsonEncode(extensions);
  } on JsonUnsupportedObjectError {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'extension bag must be JSON serializable',
    );
  }
  if (utf8.encode(encoded).length > maximumEncodedBytes) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'encoded extension bag exceeds $maximumEncodedBytes bytes',
    );
  }
  return Map<String, dynamic>.unmodifiable(extensions);
}

void _validatePersistedExtensionValue(
  dynamic value, {
  required PersistedExtensionValueKind expected,
  required String field,
  String? source,
}) {
  final valid = switch (expected) {
    PersistedExtensionValueKind.string => value is String,
    PersistedExtensionValueKind.boolean => value is bool,
    PersistedExtensionValueKind.integer => value is int,
    PersistedExtensionValueKind.finiteNumber => value is num && value.isFinite,
    PersistedExtensionValueKind.stringList =>
      value is List && value.every((entry) => entry is String),
  };
  if (!valid) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected registered ${expected.name} extension value',
    );
  }
}
