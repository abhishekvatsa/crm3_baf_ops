import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';

const issueAdministrativeClosureSchemaVersion = 1;

const issueAdministrativeClosureSynchronizedFields = <String>{
  'issueClosureSchemaVersion',
  'issueClosureDisposition',
  'issueClosureReason',
};

enum IssueAdministrativeClosureDisposition { stillRelevant, relevanceEnded }

class IssueAdministrativeClosure {
  const IssueAdministrativeClosure({
    required this.disposition,
    required this.reason,
  });

  final IssueAdministrativeClosureDisposition disposition;
  final String reason;

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
  };

  Map<String, dynamic> toSynchronizedFields() => <String, dynamic>{
    'issueClosureSchemaVersion': issueAdministrativeClosureSchemaVersion,
    'issueClosureDisposition': disposition.name,
    'issueClosureReason': reason,
  };

  factory IssueAdministrativeClosure.fromSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    final present =
        issueAdministrativeClosureSynchronizedFields
            .where(map.containsKey)
            .toSet();
    if (present.length != issueAdministrativeClosureSynchronizedFields.length) {
      throw PersistedDataFormatException(
        field: 'issueClosureSchemaVersion',
        source: source,
        detail: 'administrative-closure fields must be present together',
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
    return IssueAdministrativeClosure(disposition: disposition, reason: reason);
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
