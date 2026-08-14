import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

const issueQualityIntentSchemaVersion = 1;

enum IssueQualityAssessment { notSuspected, suspected }

class IssueQualityIntent {
  const IssueQualityIntent({required this.assessment, this.warningReason});

  final IssueQualityAssessment assessment;
  final String? warningReason;

  bool get isSuspected => assessment == IssueQualityAssessment.suspected;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'schemaVersion': issueQualityIntentSchemaVersion,
    'assessment': assessment.name,
    'warningReason': warningReason,
  };

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'qualityIntentSchemaVersion': issueQualityIntentSchemaVersion,
    'qualityImpactAssessment': assessment.name,
    'qualityWarningReason': warningReason,
  };

  String encode() => jsonEncode(<String, dynamic>{'qualityIntent': toMap()});

  factory IssueQualityIntent.fromSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    const fields = <String>{
      'qualityIntentSchemaVersion',
      'qualityImpactAssessment',
      'qualityWarningReason',
    };
    final present = fields.where(map.containsKey).toSet();
    if (present.length != fields.length) {
      throw PersistedDataFormatException(
        field: 'qualityImpactAssessment',
        source: source,
        detail: 'quality-intent fields must be present together',
      );
    }
    final schemaVersion = readRequiredPersistedInt(
      map['qualityIntentSchemaVersion'],
      field: 'qualityIntentSchemaVersion',
      source: source,
    );
    if (schemaVersion != issueQualityIntentSchemaVersion) {
      throw PersistedDataFormatException(
        field: 'qualityIntentSchemaVersion',
        source: source,
        detail: 'unsupported schema version $schemaVersion',
      );
    }
    final assessmentName = readRequiredPersistedString(
      map['qualityImpactAssessment'],
      field: 'qualityImpactAssessment',
      source: source,
    );
    final assessment =
        IssueQualityAssessment.values
            .where((value) => value.name == assessmentName)
            .firstOrNull;
    if (assessment == null) {
      throw PersistedDataFormatException(
        field: 'qualityImpactAssessment',
        source: source,
        detail: 'unsupported value $assessmentName',
      );
    }
    final warningReason = readOptionalPersistedString(
      map['qualityWarningReason'],
      field: 'qualityWarningReason',
      source: source,
    );
    if (assessment == IssueQualityAssessment.suspected &&
        (warningReason == null || warningReason.trim().isEmpty)) {
      throw PersistedDataFormatException(
        field: 'qualityWarningReason',
        source: source,
        detail: 'suspected impact requires a warning reason',
      );
    }
    if (assessment == IssueQualityAssessment.notSuspected &&
        warningReason != null) {
      throw PersistedDataFormatException(
        field: 'qualityWarningReason',
        source: source,
        detail: 'a negative assessment cannot carry a warning reason',
      );
    }
    return IssueQualityIntent(
      assessment: assessment,
      warningReason: warningReason,
    );
  }

  static IssueQualityIntent? tryDecodeLocal(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      // Pre-feature metadata was opaque and was not required to contain JSON.
      return null;
    }
    if (decoded is! Map) return null;
    final root = Map<String, dynamic>.from(decoded);
    if (!root.containsKey('qualityIntent')) return null;
    final raw = root['qualityIntent'];
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'qualityIntent',
        source: 'local maintenance metadata',
        detail: 'expected a quality-intent map',
      );
    }
    final intent = Map<String, dynamic>.from(raw);
    return IssueQualityIntent.fromSynchronizedFields(<String, dynamic>{
      'qualityIntentSchemaVersion': intent['schemaVersion'],
      'qualityImpactAssessment': intent['assessment'],
      'qualityWarningReason': intent['warningReason'],
    }, source: 'local maintenance metadata');
  }

  static IssueQualityIntent? readOptionalSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    const fields = <String>{
      'qualityIntentSchemaVersion',
      'qualityImpactAssessment',
      'qualityWarningReason',
    };
    final present = fields.where(map.containsKey).toSet();
    if (present.isEmpty) return null;
    return IssueQualityIntent.fromSynchronizedFields(map, source: source);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
