import '../../../core/serialization/persisted_data_reader.dart';

enum AbnormalityObservationKind {
  resultFinding,
  processEquipment,
  legacyUnknown,
}

enum CauseAssessment { suspected, confirmed, ruledOut }

enum PostRaResult { notAssessed, acceptable, abnormal }

/// A reviewed hypothesis, not a causal conclusion inferred from charge membership.
class CandidateProcessCause {
  const CandidateProcessCause({
    required this.id,
    required this.description,
    required this.assessment,
    required this.evidence,
    this.maintenanceTicketId,
    this.processAbnormalityId,
  });

  final String id;
  final String description;
  final CauseAssessment assessment;
  final String? evidence;
  final String? maintenanceTicketId;

  /// ID of a separately recorded process/equipment abnormality on this charge.
  final String? processAbnormalityId;

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'assessment': assessment.name,
    'evidence': evidence,
    'maintenanceTicketId': maintenanceTicketId,
    'processAbnormalityId': processAbnormalityId,
  };

  factory CandidateProcessCause.fromMap(Map<String, dynamic> map) {
    _keys(map, const {
      'id',
      'description',
      'assessment',
      'evidence',
      'maintenanceTicketId',
      'processAbnormalityId',
    }, 'candidateCause');
    final status = readRequiredPersistedEnum(
      CauseAssessment.values,
      map['assessment'],
      field: 'candidateCause.assessment',
    );
    final evidence = _text(map['evidence'], 'candidateCause.evidence', 2000);
    if (status != CauseAssessment.suspected && evidence == null) {
      _bad(
        'candidateCause.evidence',
        'Confirmed or ruled-out causes need evidence.',
      );
    }
    return CandidateProcessCause(
      id: _text(map['id'], 'candidateCause.id', 128, required: true)!,
      description: _text(
        map['description'],
        'candidateCause.description',
        1000,
        required: true,
      )!,
      assessment: status,
      evidence: evidence,
      maintenanceTicketId: _text(
        map['maintenanceTicketId'],
        'candidateCause.maintenanceTicketId',
        512,
      ),
      processAbnormalityId: _text(
        map['processAbnormalityId'],
        'candidateCause.processAbnormalityId',
        512,
      ),
    );
  }
}

/// Additive evidence. Absence is legacy unknown; dates are never synthesized.
class AbnormalityAssessment {
  const AbnormalityAssessment({
    required this.observationKind,
    this.candidateCauses = const [],
    this.raPerformedAt,
    this.postRaResult = PostRaResult.notAssessed,
    this.postRaObservation,
  });
  final AbnormalityObservationKind observationKind;
  final List<CandidateProcessCause> candidateCauses;
  final DateTime? raPerformedAt;
  final PostRaResult postRaResult;
  final String? postRaObservation;

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'observationKind': observationKind.name,
    'candidateCauses': candidateCauses.map((cause) => cause.toMap()).toList(),
    'raPerformedAt': raPerformedAt?.toUtc().toIso8601String(),
    'postRaResult': postRaResult.name,
    'postRaObservation': postRaObservation,
  };

  factory AbnormalityAssessment.fromMap(Map<String, dynamic> map) {
    _keys(map, const {
      'schemaVersion',
      'observationKind',
      'candidateCauses',
      'raPerformedAt',
      'postRaResult',
      'postRaObservation',
    }, 'assessment');
    if (map['schemaVersion'] != 1) {
      _bad('assessment.schemaVersion', 'Unsupported version.');
    }
    final raw = map['candidateCauses'];
    if (raw is! List || raw.length > 20) {
      _bad('assessment.candidateCauses', 'Expected at most 20 causes.');
    }
    final causes = <CandidateProcessCause>[];
    final ids = <String>{};
    for (final value in raw) {
      if (value is! Map) {
        _bad('assessment.candidateCauses', 'Expected cause objects.');
      }
      final cause = CandidateProcessCause.fromMap(
        Map<String, dynamic>.from(value),
      );
      if (!ids.add(cause.id)) {
        _bad('assessment.candidateCauses', 'Duplicate cause identity.');
      }
      causes.add(cause);
    }
    final performed = readOptionalPersistedDateTime(
      map['raPerformedAt'],
      field: 'assessment.raPerformedAt',
    );
    final result = readRequiredPersistedEnum(
      PostRaResult.values,
      map['postRaResult'],
      field: 'assessment.postRaResult',
    );
    final observation = _text(
      map['postRaObservation'],
      'assessment.postRaObservation',
      2000,
    );
    if (result != PostRaResult.notAssessed && observation == null) {
      _bad('assessment.postRaResult', 'An assessed result needs observations.');
    }
    return AbnormalityAssessment(
      observationKind: readRequiredPersistedEnum(
        AbnormalityObservationKind.values,
        map['observationKind'],
        field: 'assessment.observationKind',
      ),
      candidateCauses: List.unmodifiable(causes),
      raPerformedAt: performed,
      postRaResult: result,
      postRaObservation: observation,
    );
  }
}

void _keys(Map<String, dynamic> map, Set<String> keys, String field) {
  if (map.keys.any((key) => !keys.contains(key))) {
    _bad(field, 'Unexpected evidence field.');
  }
}

String? _text(
  dynamic value,
  String field,
  int maximum, {
  bool required = false,
}) {
  if (value == null && !required) return null;
  if (value is! String || value.trim().isEmpty || value.length > maximum) {
    _bad(field, 'Expected ${required ? "required" : "optional"} bounded text.');
  }
  return value.trim();
}

Never _bad(String field, String detail) =>
    throw PersistedDataFormatException(field: field, detail: detail);
