import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

const issueAdministrativeClosureSchemaVersion = 1;
const issueAdministrativeClosureStillRelevantMetadataNeedle =
    '"disposition":"stillRelevant"';

const issueAdministrativeClosureSynchronizedFields = <String>{
  'issueClosureSchemaVersion',
  'issueClosureDisposition',
  'issueClosureReason',
  'issueClosureRelevanceEndedAt',
  'issueClosureRelevanceEndedByUid',
  'issueClosureRelevanceEndedByName',
  'issueClosureRelevanceEndReason',
};

const _issueAdministrativeClosureRequiredFields = <String>{
  'issueClosureSchemaVersion',
  'issueClosureDisposition',
  'issueClosureReason',
};

const _issueAdministrativeClosureRelevanceEndFields = <String>{
  'issueClosureRelevanceEndedAt',
  'issueClosureRelevanceEndedByUid',
  'issueClosureRelevanceEndedByName',
  'issueClosureRelevanceEndReason',
};

enum IssueAdministrativeClosureDisposition { stillRelevant, relevanceEnded }

class IssueAdministrativeClosure {
  const IssueAdministrativeClosure({
    required this.disposition,
    required this.reason,
    this.relevanceEndedAt,
    this.relevanceEndedByUid,
    this.relevanceEndedByName,
    this.relevanceEndReason,
  }) : assert(
         (relevanceEndedAt == null &&
                 relevanceEndedByUid == null &&
                 relevanceEndedByName == null &&
                 relevanceEndReason == null) ||
             (disposition ==
                     IssueAdministrativeClosureDisposition.relevanceEnded &&
                 relevanceEndedAt != null &&
                 relevanceEndedByUid != null &&
                 relevanceEndedByName != null &&
                 relevanceEndReason != null),
       );

  final IssueAdministrativeClosureDisposition disposition;
  final String reason;
  final DateTime? relevanceEndedAt;
  final String? relevanceEndedByUid;
  final String? relevanceEndedByName;
  final String? relevanceEndReason;

  bool get relevanceWasEndedAfterClosure => relevanceEndedAt != null;

  String get label => switch (disposition) {
    IssueAdministrativeClosureDisposition.stillRelevant =>
      'Closed unresolved - still relevant',
    IssueAdministrativeClosureDisposition.relevanceEnded =>
      'Closed unresolved - no longer relevant',
  };

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    'schemaVersion': issueAdministrativeClosureSchemaVersion,
    'disposition': disposition.name,
    'reason': reason,
    if (relevanceEndedAt != null)
      'relevanceEndedAt': relevanceEndedAt!.toUtc().toIso8601String(),
    if (relevanceEndedByUid != null) 'relevanceEndedByUid': relevanceEndedByUid,
    if (relevanceEndedByName != null)
      'relevanceEndedByName': relevanceEndedByName,
    if (relevanceEndReason != null) 'relevanceEndReason': relevanceEndReason,
  };

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'issueClosureSchemaVersion': issueAdministrativeClosureSchemaVersion,
    'issueClosureDisposition': disposition.name,
    'issueClosureReason': reason,
    if (relevanceEndedAt != null)
      'issueClosureRelevanceEndedAt':
          relevanceEndedAt!.toUtc().toIso8601String(),
    if (relevanceEndedByUid != null)
      'issueClosureRelevanceEndedByUid': relevanceEndedByUid,
    if (relevanceEndedByName != null)
      'issueClosureRelevanceEndedByName': relevanceEndedByName,
    if (relevanceEndReason != null)
      'issueClosureRelevanceEndReason': relevanceEndReason,
  };

  factory IssueAdministrativeClosure.fromSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final requiredPresent =
        _issueAdministrativeClosureRequiredFields
            .where(map.containsKey)
            .toSet();
    if (requiredPresent.length !=
        _issueAdministrativeClosureRequiredFields.length) {
      throw PersistedDataFormatException(
        field: 'issueClosureSchemaVersion',
        source: source,
        detail: 'administrative-closure fields must be present together',
      );
    }
    final relevanceEndPresent =
        _issueAdministrativeClosureRelevanceEndFields
            .where(map.containsKey)
            .toSet();
    if (relevanceEndPresent.isNotEmpty &&
        relevanceEndPresent.length !=
            _issueAdministrativeClosureRelevanceEndFields.length) {
      throw PersistedDataFormatException(
        field: 'issueClosureRelevanceEndedAt',
        source: source,
        detail: 'relevance-end evidence must be present together',
      );
    }
    if (map['issueClosureSchemaVersion'] !=
        issueAdministrativeClosureSchemaVersion) {
      throw PersistedDataFormatException(
        field: 'issueClosureSchemaVersion',
        source: source,
        detail: 'unsupported schema version',
      );
    }
    final dispositionName = readRequiredPersistedString(
      map['issueClosureDisposition'],
      field: 'issueClosureDisposition',
      source: source,
    );
    final disposition =
        IssueAdministrativeClosureDisposition.values
            .where((value) => value.name == dispositionName)
            .firstOrNull;
    if (disposition == null) {
      throw PersistedDataFormatException(
        field: 'issueClosureDisposition',
        source: source,
        detail: 'unsupported value $dispositionName',
      );
    }
    final reason = readRequiredPersistedString(
      map['issueClosureReason'],
      field: 'issueClosureReason',
      source: source,
    );
    if (reason.length > 2000) {
      throw PersistedDataFormatException(
        field: 'issueClosureReason',
        source: source,
        detail: 'must not exceed 2000 characters',
      );
    }
    DateTime? relevanceEndedAt;
    String? relevanceEndedByUid;
    String? relevanceEndedByName;
    String? relevanceEndReason;
    if (relevanceEndPresent.isNotEmpty) {
      if (disposition != IssueAdministrativeClosureDisposition.relevanceEnded) {
        throw PersistedDataFormatException(
          field: 'issueClosureRelevanceEndedAt',
          source: source,
          detail: 'relevance-end evidence requires relevanceEnded disposition',
        );
      }
      relevanceEndedAt = readRequiredPersistedDateTime(
        map['issueClosureRelevanceEndedAt'],
        field: 'issueClosureRelevanceEndedAt',
        source: source,
      );
      relevanceEndedByUid = readRequiredPersistedString(
        map['issueClosureRelevanceEndedByUid'],
        field: 'issueClosureRelevanceEndedByUid',
        source: source,
      );
      relevanceEndedByName = readRequiredPersistedString(
        map['issueClosureRelevanceEndedByName'],
        field: 'issueClosureRelevanceEndedByName',
        source: source,
      );
      relevanceEndReason = readRequiredPersistedString(
        map['issueClosureRelevanceEndReason'],
        field: 'issueClosureRelevanceEndReason',
        source: source,
      );
      if (relevanceEndReason.length > 2000) {
        throw PersistedDataFormatException(
          field: 'issueClosureRelevanceEndReason',
          source: source,
          detail: 'must not exceed 2000 characters',
        );
      }
    }
    return IssueAdministrativeClosure(
      disposition: disposition,
      reason: reason,
      relevanceEndedAt: relevanceEndedAt,
      relevanceEndedByUid: relevanceEndedByUid,
      relevanceEndedByName: relevanceEndedByName,
      relevanceEndReason: relevanceEndReason,
    );
  }

  static IssueAdministrativeClosure? readOptionalSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        issueAdministrativeClosureSynchronizedFields
            .where(map.containsKey)
            .toSet();
    if (present.isEmpty) return null;
    return IssueAdministrativeClosure.fromSynchronizedFields(
      map,
      source: source,
    );
  }

  static IssueAdministrativeClosure? tryDecodeLocal(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final raw = Map<String, dynamic>.from(decoded)['administrativeClosure'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'administrativeClosure',
        source: 'local maintenance metadata',
        detail: 'expected an object',
      );
    }
    final closure = Map<String, dynamic>.from(raw);
    return IssueAdministrativeClosure.fromSynchronizedFields(<String, dynamic>{
      'issueClosureSchemaVersion': closure['schemaVersion'],
      'issueClosureDisposition': closure['disposition'],
      'issueClosureReason': closure['reason'],
      if (closure.containsKey('relevanceEndedAt'))
        'issueClosureRelevanceEndedAt': closure['relevanceEndedAt'],
      if (closure.containsKey('relevanceEndedByUid'))
        'issueClosureRelevanceEndedByUid': closure['relevanceEndedByUid'],
      if (closure.containsKey('relevanceEndedByName'))
        'issueClosureRelevanceEndedByName': closure['relevanceEndedByName'],
      if (closure.containsKey('relevanceEndReason'))
        'issueClosureRelevanceEndReason': closure['relevanceEndReason'],
    }, source: 'local maintenance metadata');
  }
}

String mergeIssueAdministrativeClosureIntoMaintenanceMetadata(
  String? existing,
  IssueAdministrativeClosure? value,
) {
  final root = _readMetadataRoot(existing);
  if (value == null) {
    root.remove('administrativeClosure');
  } else {
    root['administrativeClosure'] = value.toLocalMap();
  }
  return jsonEncode(root);
}

Map<String, dynamic> _readMetadataRoot(String? existing) {
  if (existing == null || existing.trim().isEmpty) return <String, dynamic>{};
  dynamic decoded;
  try {
    decoded = jsonDecode(existing);
  } on FormatException {
    return <String, dynamic>{'legacyMetadata': existing};
  }
  if (decoded is! Map) return <String, dynamic>{'legacyMetadata': existing};
  return Map<String, dynamic>.from(decoded);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
