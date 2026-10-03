part of 'inspection_campaign.dart';

/// A labelled scalar reading within a version-two inspection contract.
class InspectionReadingField {
  const InspectionReadingField({
    required this.id,
    required this.label,
    required this.valueType,
    this.unit,
    this.choiceValues = const [],
    this.minimumValue,
    this.maximumValue,
  });

  final String id;
  final String label;
  final InspectionValueType valueType;
  final String? unit;
  final List<String> choiceValues;
  final double? minimumValue;
  final double? maximumValue;

  Map<String, Object?> toMap() => {
    'id': id,
    'label': label,
    'valueType': valueType.name,
    'unit': unit,
    'choiceValues': choiceValues,
    'minimumValue': minimumValue,
    'maximumValue': maximumValue,
  };

  factory InspectionReadingField.fromMap(
    Map<String, dynamic> map, {
    String source = 'inspection reading field',
  }) {
    _readingExactKeys(map, const {
      'id',
      'label',
      'valueType',
      'unit',
      'choiceValues',
      'minimumValue',
      'maximumValue',
    }, source);
    final id = _readingText(map['id'], 48, source);
    final label = _readingText(map['label'], 120, source);
    if (!RegExp(r'^[a-z][a-z0-9_]{0,47}$').hasMatch(id)) {
      _readingInvalid(source, 'invalid field identity');
    }
    final type = readRequiredPersistedEnum(
      InspectionValueType.values,
      map['valueType'],
      field: 'valueType',
      source: source,
    );
    final unit = map['unit'] == null
        ? null
        : _readingText(map['unit'], 40, source);
    final rawChoices = map['choiceValues'];
    if (rawChoices is! List || rawChoices.length > 30) {
      _readingInvalid(source, 'invalid choices');
    }
    final choices = rawChoices
        .map((value) => _readingText(value, 120, source))
        .toList(growable: false);
    final minimum = _readingNumber(map['minimumValue'], source);
    final maximum = _readingNumber(map['maximumValue'], source);
    if (choices.toSet().length != choices.length ||
        (type == InspectionValueType.choice) != choices.isNotEmpty ||
        (type == InspectionValueType.number) != (unit != null) ||
        (type != InspectionValueType.number &&
            (minimum != null || maximum != null)) ||
        (minimum != null && maximum != null && minimum > maximum)) {
      _readingInvalid(source, 'inconsistent scalar contract');
    }
    return InspectionReadingField(
      id: id,
      label: label,
      valueType: type,
      unit: unit,
      choiceValues: List.unmodifiable(choices),
      minimumValue: minimum,
      maximumValue: maximum,
    );
  }
}

class InspectionReadingValue {
  const InspectionReadingValue({
    required this.fieldId,
    required this.valueType,
    required this.value,
  });
  final String fieldId;
  final InspectionValueType valueType;
  final Object value;
  Map<String, Object?> toMap() => {
    'fieldId': fieldId,
    'valueType': valueType.name,
    'value': value,
  };
}

List<InspectionReadingField> readInspectionReadingFields(
  Object? value, {
  String source = 'inspection reading contract',
}) {
  if (value is! List || value.isEmpty || value.length > 20) {
    _readingInvalid(source, 'one to twenty reading fields are required');
  }
  final fields = value
      .map(
        (item) => InspectionReadingField.fromMap(
          _object(item, field: 'readingFields', source: source),
          source: source,
        ),
      )
      .toList(growable: false);
  if (fields.map((field) => field.id).toSet().length != fields.length ||
      fields.map((field) => field.label.toLowerCase()).toSet().length !=
          fields.length) {
    _readingInvalid(source, 'reading identities and labels must be unique');
  }
  return List.unmodifiable(fields);
}

/// Order and every field identity are bound to the frozen contract.
List<InspectionReadingValue> validateInspectionReadingValues(
  List<InspectionReadingField> fields,
  Object? values, {
  String source = 'inspection readings',
}) {
  if (values is! List || values.length != fields.length || fields.isEmpty) {
    _readingInvalid(source, 'every frozen reading is required');
  }
  final result = <InspectionReadingValue>[];
  for (var index = 0; index < fields.length; index++) {
    final field = fields[index];
    final raw = values[index];
    final row = raw is InspectionReadingValue
        ? raw.toMap()
        : _object(raw, field: 'readings', source: source);
    _readingExactKeys(row, const {'fieldId', 'valueType', 'value'}, source);
    if (row['fieldId'] != field.id ||
        row['valueType'] != field.valueType.name) {
      _readingInvalid(source, 'reading identity or type differs from contract');
    }
    final value = row['value'];
    final valid = switch (field.valueType) {
      InspectionValueType.number => value is num && value.isFinite,
      InspectionValueType.boolean => value is bool,
      InspectionValueType.text =>
        value is String &&
            value.trim() == value &&
            value.isNotEmpty &&
            value.length <= 1000,
      InspectionValueType.choice =>
        value is String && field.choiceValues.contains(value),
      InspectionValueType.date =>
        value is String && isValidInspectionDate(value),
    };
    if (!valid || value == null) {
      _readingInvalid(source, 'invalid reading value');
    }
    result.add(
      InspectionReadingValue(
        fieldId: field.id,
        valueType: field.valueType,
        value: value,
      ),
    );
  }
  return List.unmodifiable(result);
}

List<InspectionReadingValue> readInspectionReadingEnvelope(
  List<InspectionReadingField> fields,
  Object? value, {
  String source = 'inspection reading envelope',
}) {
  final map = _object(value, field: 'value', source: source);
  _readingExactKeys(map, const {'schemaVersion', 'readings'}, source);
  if (map['schemaVersion'] != 2) {
    _readingInvalid(source, 'unsupported reading envelope');
  }
  return validateInspectionReadingValues(
    fields,
    map['readings'],
    source: source,
  );
}

/// Calendar dates carry no instant or timezone. Reject normalization/rollover.
bool isValidInspectionDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  if (year < 1 || month < 1 || month > 12 || day < 1) return false;
  final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
  final days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return day <= days[month - 1];
}

String? parseInspectionDateInput(String value) {
  if (!RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(value)) return null;
  final canonical =
      '${value.substring(6)}-${value.substring(3, 5)}-${value.substring(0, 2)}';
  return isValidInspectionDate(canonical) ? canonical : null;
}

String formatInspectionDate(String value) {
  if (!isValidInspectionDate(value)) {
    throw const FormatException('Invalid inspection calendar date.');
  }
  return '${value.substring(8)}-${value.substring(5, 7)}-${value.substring(0, 4)}';
}

String displayInspectionReading(
  InspectionReadingField field,
  InspectionReadingValue reading,
) => switch (field.valueType) {
  InspectionValueType.number => '${reading.value} ${field.unit}',
  InspectionValueType.boolean => reading.value == true ? 'Yes' : 'No',
  InspectionValueType.date => formatInspectionDate(reading.value as String),
  InspectionValueType.text || InspectionValueType.choice => '${reading.value}',
};

bool inspectionReadingsOutOfRange(
  List<InspectionReadingField> fields,
  List<InspectionReadingValue> readings,
) {
  final checked = validateInspectionReadingValues(fields, readings);
  for (var index = 0; index < fields.length; index++) {
    final field = fields[index];
    if (field.valueType != InspectionValueType.number) continue;
    final value = checked[index].value as num;
    if ((field.minimumValue != null && value < field.minimumValue!) ||
        (field.maximumValue != null && value > field.maximumValue!)) {
      return true;
    }
  }
  return false;
}

void _readingExactKeys(
  Map<Object?, Object?> map,
  Set<String> keys,
  String source,
) {
  if (map.length != keys.length || !map.keys.every(keys.contains)) {
    _readingInvalid(source, 'unexpected or missing reading fields');
  }
}

String _readingText(Object? value, int maximum, String source) {
  if (value is! String ||
      value.isEmpty ||
      value.trim() != value ||
      value.length > maximum) {
    _readingInvalid(source, 'invalid reading text');
  }
  return value;
}

double? _readingNumber(Object? value, String source) {
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    _readingInvalid(source, 'invalid number');
  }
  return value.toDouble();
}

Never _readingInvalid(String source, String detail) =>
    throw PersistedDataFormatException(
      field: 'readingContract',
      source: source,
      detail: detail,
    );
