import 'package:flutter/services.dart';

import '../serialization/persisted_data_reader.dart';

const int minimumChargeNumber = 10000;
const int maximumChargeNumber = 99999;
const int chargeNumberDigits = 5;

bool isValidChargeNumber(Object? value) =>
    value is int &&
    value >= minimumChargeNumber &&
    value <= maximumChargeNumber;

int readRequiredPersistedChargeNumber(
  dynamic value, {
  required String field,
  String? source,
}) {
  final parsed = readRequiredPersistedInt(
    value,
    field: field,
    source: source,
    minimum: minimumChargeNumber,
  );
  if (!isValidChargeNumber(parsed)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'expected exactly five digits',
    );
  }
  return parsed;
}

int? readOptionalPersistedChargeNumber(
  dynamic value, {
  required String field,
  String? source,
}) {
  if (value == null) return null;
  return readRequiredPersistedChargeNumber(value, field: field, source: source);
}

int? parseOptionalChargeNumber(String? value) {
  final cleaned = value?.trim() ?? '';
  if (cleaned.isEmpty) return null;
  final parsed = int.tryParse(cleaned);
  return isValidChargeNumber(parsed) ? parsed : null;
}

String? validateChargeNumberText(
  String? value, {
  bool required = false,
  String label = 'Charge number',
}) {
  final cleaned = value?.trim() ?? '';
  if (cleaned.isEmpty) return required ? '$label is required' : null;
  if (!RegExp(r'^\d{5}$').hasMatch(cleaned)) {
    return '$label must contain exactly five digits';
  }
  return null;
}

final List<TextInputFormatter> chargeNumberInputFormatters =
    <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(chargeNumberDigits),
    ];
