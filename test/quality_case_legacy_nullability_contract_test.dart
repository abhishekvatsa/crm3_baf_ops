import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The backend accepts a stored quality record whose optional keys are absent,
/// treating absence as null. That tolerance is only safe where the shipped
/// client reader already reads absence and an explicit null as the same value:
/// `map['x']` is null for both. These tests pin the two sides to each other, so
/// neither can widen its tolerance, or tighten it into a refusal the other side
/// never sees, without the other being changed in the same commit.
String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('missing $path');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

/// The quoted entries of a `new Set([...])` constant in a TypeScript source.
Set<String> _backendNullableFields(String source, String constant) {
  final declaration = RegExp('const $constant = new Set\\(\\[(.*?)\\]\\);',
      dotAll: true);
  final match = declaration.firstMatch(source);
  expect(match, isNotNull, reason: 'no declaration of $constant');
  return RegExp("\"(\\w+)\"")
      .allMatches(match!.group(1)!)
      .map((entry) => entry.group(1)!)
      .toSet();
}

/// The body of one function or factory, from its signature to the closing brace
/// at [closing] indentation.
String _body(String source, String signature, {String closing = '\n}\n'}) {
  final start = source.indexOf(signature);
  expect(start, isNot(-1), reason: 'no declaration of $signature');
  // Past the signature itself, so a named-parameter block closing at the same
  // indentation is not mistaken for the end of the body.
  final end = source.indexOf(closing, start + signature.length);
  expect(end, isNot(-1), reason: 'unterminated $signature');
  return source.substring(start, end);
}

/// The record keys a reader accepts as absent: every `map['x']` handed to an
/// optional accessor.
Set<String> _clientOptionalFields(String body) {
  return RegExp(r"_?readOptional\w*\(\s*(?:[\w.]+,\s*)?map\['(\w+)'\]")
      .allMatches(body)
      .map((entry) => entry.group(1)!)
      .toSet();
}

void main() {
  final abnormalityMutation = _read('functions/src/chargeAbnormalityMutation.ts');
  final qualityMutation = _read('functions/src/qualityMutation.ts');
  final abnormalityReader =
      _read('lib/features/abnormalities/data/remote_abnormality_reader.dart');
  final abnormalityTimestamps =
      _read('lib/features/abnormalities/data/remote_abnormality_timestamps.dart');
  final warningReader = _read('lib/features/quality/data/quality_warning.dart');

  test('both backend modules read one charge-abnormality record', () {
    expect(
      _backendNullableFields(
        abnormalityMutation,
        'LEGACY_NULLABLE_ABNORMALITY_FIELDS',
      ),
      _backendNullableFields(qualityMutation, 'LEGACY_NULLABLE_CASE_FIELDS'),
    );
  });

  test('a charge abnormality tolerates the keys the shipped reader does', () {
    final client = _clientOptionalFields(
      _body(abnormalityReader, 'ChargeAbnormality readRemoteChargeAbnormality('),
    )
      ..addAll(_clientOptionalFields(_body(
        abnormalityTimestamps,
        'RemoteChargeAbnormalityTimestamps readRemoteChargeAbnormalityTimestamps(',
      )));

    expect(
      _backendNullableFields(
        abnormalityMutation,
        'LEGACY_NULLABLE_ABNORMALITY_FIELDS',
      ),
      client,
    );
  });

  test('a quality warning tolerates the keys the shipped reader does', () {
    expect(
      _backendNullableFields(qualityMutation, 'LEGACY_NULLABLE_WARNING_FIELDS'),
      _clientOptionalFields(_body(
        warningReader,
        'factory QualityWarning.fromMap(',
        closing: '\n  }\n',
      )),
    );
  });

  test('evidence a decision rests on is never inferred from absence', () {
    for (final constant in const <String>[
      'LEGACY_NULLABLE_ABNORMALITY_FIELDS',
      'LEGACY_NULLABLE_CASE_FIELDS',
      'LEGACY_NULLABLE_WARNING_FIELDS',
    ]) {
      final source =
          constant == 'LEGACY_NULLABLE_ABNORMALITY_FIELDS' ?
              abnormalityMutation : qualityMutation;
      expect(
        _backendNullableFields(source, constant).intersection(const <String>{
          'firestoreId', 'warningId', 'sourceChargeNo', 'sourceId',
          'sourceType', 'severity', 'sourceSeverity', 'status',
          'abnormalityTypeId', 'observedReason', 'warningReason',
          'affectedAssets', 'reannealingStatus', 'loggedAt', 'loggedByUid',
          'createdAt', 'createdByUid', 'updatedAt', 'updatedByUid',
          'isDeleted', 'version', 'schemaVersion',
        }),
        isEmpty,
        reason: '$constant must not make required evidence optional',
      );
    }
  });
}
