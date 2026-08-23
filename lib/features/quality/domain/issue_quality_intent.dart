import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

const issueQualityIntentSchemaVersion = 2;

enum IssueQualityAssessment { notSuspected, suspected }

class IssueQualityIntent {
  const IssueQualityIntent({
    required this.assessment,
    this.warningReason,
    this.abnormalityTypeId,
    this.schemaVersion = issueQualityIntentSchemaVersion,
  });

  final IssueQualityAssessment assessment;
  final String? warningReason;
  final String? abnormalityTypeId;
  final int schemaVersion;

  bool get isSuspected => assessment == IssueQualityAssessment.suspected;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'assessment': assessment.name,
    'warningReason': warningReason,
    if (schemaVersion == issueQualityIntentSchemaVersion)
      'abnormalityTypeId': abnormalityTypeId,
  };

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'qualityIntentSchemaVersion': schemaVersion,
    'qualityImpactAssessment': assessment.name,
    'qualityWarningReason': warningReason,
    if (schemaVersion == issueQualityIntentSchemaVersion)
      'qualityAbnormalityTypeId': abnormalityTypeId,
  };

  String encode() => jsonEncode(<String, dynamic>{'qualityIntent': toMap()});

  factory IssueQualityIntent.fromSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    const baseFields = <String>{
      'qualityIntentSchemaVersion',
      'qualityImpactAssessment',
      'qualityWarningReason',
    };
    final present = baseFields.where(map.containsKey).toSet();
    if (present.length != baseFields.length) {
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
    if (schemaVersion != 1 &&
        schemaVersion != issueQualityIntentSchemaVersion) {
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
    final hasAbnormalityType = map.containsKey('qualityAbnormalityTypeId');
    final abnormalityTypeId =
        hasAbnormalityType
            ? readOptionalPersistedString(
              map['qualityAbnormalityTypeId'],
              field: 'qualityAbnormalityTypeId',
              source: source,
            )
            : null;
    if (schemaVersion == 1 && hasAbnormalityType) {
      throw PersistedDataFormatException(
        field: 'qualityAbnormalityTypeId',
        source: source,
        detail: 'legacy quality intent cannot carry abnormality classification',
      );
    }
    if (schemaVersion == issueQualityIntentSchemaVersion &&
        !hasAbnormalityType) {
      throw PersistedDataFormatException(
        field: 'qualityAbnormalityTypeId',
        source: source,
        detail: 'v2 quality intent requires the classification field',
      );
    }
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
    if (assessment == IssueQualityAssessment.suspected &&
        schemaVersion == issueQualityIntentSchemaVersion &&
        abnormalityTypeId == null) {
      throw PersistedDataFormatException(
        field: 'qualityAbnormalityTypeId',
        source: source,
        detail: 'suspected impact requires governed abnormality classification',
      );
    }
    if (assessment == IssueQualityAssessment.notSuspected &&
        abnormalityTypeId != null) {
      throw PersistedDataFormatException(
        field: 'qualityAbnormalityTypeId',
        source: source,
        detail: 'a negative assessment cannot carry abnormality classification',
      );
    }
    return IssueQualityIntent(
      assessment: assessment,
      warningReason: warningReason,
      abnormalityTypeId: abnormalityTypeId,
      schemaVersion: schemaVersion,
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
      if (intent.containsKey('abnormalityTypeId'))
        'qualityAbnormalityTypeId': intent['abnormalityTypeId'],
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
      'qualityAbnormalityTypeId',
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
