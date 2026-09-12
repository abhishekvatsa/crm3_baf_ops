import 'dart:convert';

import '../../../core/serialization/command_timestamp.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../data/inner_cover_lifecycle.dart';
import 'inner_cover_acceptance_input.dart';

/// Frozen transport data. Parsing never substitutes the cover's current revision
/// or the current account into an earlier submission.
class InnerCoverAcceptanceSubmission {
  const InnerCoverAcceptanceSubmission._({
    required this.envelopeJson,
    required this.actorUid,
    required this.requestId,
    required this.coverId,
    required this.expectedVersion,
    required this.input,
  });

  final String envelopeJson;
  final String actorUid;
  final String requestId;
  final String coverId;
  final int expectedVersion;
  final InnerCoverAcceptanceInput input;

  String get resourceKey => 'innerCoverAcceptance:$coverId';
  Map<String, dynamic> get envelope =>
      Map<String, dynamic>.from(jsonDecode(envelopeJson) as Map);
  Map<String, dynamic> get request =>
      Map<String, dynamic>.from(envelope['request'] as Map);

  factory InnerCoverAcceptanceSubmission.prepare({
    required InnerCoverProfile cover,
    required InnerCoverAcceptanceInput input,
    required String actorUid,
    required String requestId,
    required DateTime now,
  }) {
    final error = input.validationError(
      now: now,
      receivedOn: cover.receivedOrCompletedOn,
    );
    if (error != null) throw ArgumentError(error);
    String? clean(String? text) {
      final value = text?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    return InnerCoverAcceptanceSubmission.parse(
      jsonEncode({
        'protocolVersion': 2,
        'originActorUid': actorUid,
        'request': {
          'requestId': requestId,
          'operation': 'ACCEPT_INNER_COVER',
          'innerCoverId': cover.id,
          'expectedVersion': cover.version,
          'reason': input.reason.trim(),
          'acceptanceDraft': {
            'inspectedOn': commandUtcMillis(input.inspectedOn),
            'acceptanceReference': input.acceptanceReference.trim(),
            'leakTestReference': clean(input.leakTestReference),
            'ndtReference': clean(input.ndtReference),
            'notes': clean(input.notes),
          },
        },
      }),
    );
  }

  factory InnerCoverAcceptanceSubmission.parse(String raw) {
    const source = 'saved Inner Cover acceptance';
    Never invalid(String field) => throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'saved evidence was retained for review',
    );
    Map<String, dynamic> object(
      Object? value,
      Set<String> fields,
      String field,
    ) {
      if (value is! Map<String, dynamic> ||
          value.length != fields.length ||
          !value.keys.toSet().containsAll(fields)) {
        invalid(field);
      }
      return value;
    }

    final outer = object(jsonDecode(raw), {
      'protocolVersion',
      'originActorUid',
      'request',
    }, 'envelope');
    if (outer['protocolVersion'] != 2) invalid('protocolVersion');
    String requiredText(Map<String, dynamic> map, String field) {
      final value = readRequiredPersistedString(
        map[field],
        field: field,
        source: source,
      );
      if (value != map[field]) invalid(field);
      return value;
    }

    final actorUid = requiredText(outer, 'originActorUid');
    final request = object(outer['request'], {
      'requestId',
      'operation',
      'innerCoverId',
      'expectedVersion',
      'reason',
      'acceptanceDraft',
    }, 'request');
    if (request['operation'] != 'ACCEPT_INNER_COVER') invalid('operation');
    final requestId = requiredText(request, 'requestId');
    final coverId = requiredText(request, 'innerCoverId');
    final expectedVersion = readRequiredPersistedInt(
      request['expectedVersion'],
      field: 'expectedVersion',
      source: source,
      minimum: 1,
    );
    final data = object(request['acceptanceDraft'], {
      'inspectedOn',
      'acceptanceReference',
      'leakTestReference',
      'ndtReference',
      'notes',
    }, 'acceptanceDraft');
    final inspectedOn = readRequiredPersistedDateTime(
      data['inspectedOn'],
      field: 'inspectedOn',
      source: source,
    );
    if (data['inspectedOn'] != commandUtcMillis(inspectedOn)) {
      invalid('inspectedOn');
    }
    String? optionalText(String field) {
      final value = readOptionalPersistedString(
        data[field],
        field: field,
        source: source,
      );
      if (value != data[field]) invalid(field);
      return value;
    }

    final input = InnerCoverAcceptanceInput(
      inspectedOn: inspectedOn,
      acceptanceReference: requiredText(data, 'acceptanceReference'),
      reason: requiredText(request, 'reason'),
      leakTestReference: optionalText('leakTestReference'),
      ndtReference: optionalText('ndtReference'),
      notes: optionalText('notes'),
    );
    if (InnerCoverAcceptanceInput.referenceError(input.acceptanceReference) !=
            null ||
        InnerCoverAcceptanceInput.reasonError(input.reason) != null ||
        InnerCoverAcceptanceInput.optionalReferenceError(
              input.leakTestReference,
            ) !=
            null ||
        InnerCoverAcceptanceInput.optionalReferenceError(input.ndtReference) !=
            null ||
        InnerCoverAcceptanceInput.notesError(input.notes) != null) {
      invalid('acceptanceDraft');
    }
    return InnerCoverAcceptanceSubmission._(
      envelopeJson: raw,
      actorUid: actorUid,
      requestId: requestId,
      coverId: coverId,
      expectedVersion: expectedVersion,
      input: input,
    );
  }
}
