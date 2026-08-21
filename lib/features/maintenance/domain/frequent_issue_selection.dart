import 'dart:convert';

import '../../../core/serialization/persisted_data_reader.dart';
import '../data/frequent_issue_definition.dart';

enum FrequentIssueSelectionType { definition, unlisted }

class FrequentIssueSelection {
  const FrequentIssueSelection._({
    required this.type,
    this.definitionId,
    this.definitionVersion,
    this.definitionCode,
    this.definitionTitle,
    this.codeOwnedWorkflowProfile,
    this.unlistedReason,
  });

  factory FrequentIssueSelection.definition(FrequentIssueDefinition value) =>
      FrequentIssueSelection._(
        type: FrequentIssueSelectionType.definition,
        definitionId: value.id,
        definitionVersion: value.version,
        definitionCode: value.code,
        definitionTitle: value.title,
        codeOwnedWorkflowProfile: value.codeOwnedWorkflowProfile,
      );

  factory FrequentIssueSelection.unlisted(String reason) {
    final cleaned = reason.trim();
    if (cleaned.length < 5 || cleaned.length > 500) {
      throw const FormatException(
        'Describe the unlisted issue in 5-500 characters.',
      );
    }
    return FrequentIssueSelection._(
      type: FrequentIssueSelectionType.unlisted,
      unlistedReason: cleaned,
    );
  }

  final FrequentIssueSelectionType type;
  final String? definitionId;
  final int? definitionVersion;
  final String? definitionCode;
  final String? definitionTitle;
  final String? codeOwnedWorkflowProfile;
  final String? unlistedReason;

  bool get isUnlisted => type == FrequentIssueSelectionType.unlisted;

  Map<String, dynamic> toCommandMap() => <String, dynamic>{
    'schemaVersion': 1,
    'selectionType': type.name,
    'definitionId': definitionId,
    'definitionVersion': definitionVersion,
    'unlistedReason': unlistedReason,
  };

  Map<String, dynamic> toLocalMap() => <String, dynamic>{
    ...toCommandMap(),
    'definitionCode': definitionCode,
    'definitionTitle': definitionTitle,
    'codeOwnedWorkflowProfile': codeOwnedWorkflowProfile,
  };

  factory FrequentIssueSelection.fromMap(
    Map<String, dynamic> map, {
    required String source,
  }) {
    if (readRequiredPersistedInt(
          map['schemaVersion'],
          field: 'frequentIssueSelection.schemaVersion',
          source: source,
        ) !=
        1) {
      throw PersistedDataFormatException(
        field: 'frequentIssueSelection.schemaVersion',
        source: source,
        detail: 'unsupported selection schema',
      );
    }
    final type = readRequiredPersistedEnum(
      FrequentIssueSelectionType.values,
      map['selectionType'],
      field: 'frequentIssueSelection.selectionType',
      source: source,
    );
    final id = readOptionalPersistedString(
      map['definitionId'],
      field: 'frequentIssueSelection.definitionId',
      source: source,
    );
    final version = readOptionalPersistedInt(
      map['definitionVersion'],
      field: 'frequentIssueSelection.definitionVersion',
      source: source,
      minimum: 1,
    );
    final code = readOptionalPersistedString(
      map['definitionCode'],
      field: 'frequentIssueSelection.definitionCode',
      source: source,
    );
    final title = readOptionalPersistedString(
      map['definitionTitle'],
      field: 'frequentIssueSelection.definitionTitle',
      source: source,
    );
    final profile = readOptionalPersistedString(
      map['codeOwnedWorkflowProfile'],
      field: 'frequentIssueSelection.codeOwnedWorkflowProfile',
      source: source,
    );
    final reason = readOptionalPersistedString(
      map['unlistedReason'],
      field: 'frequentIssueSelection.unlistedReason',
      source: source,
    );
    final definitionComplete =
        id != null && version != null && code != null && title != null;
    final definitionAbsent =
        id == null && version == null && code == null && title == null;
    if ((type == FrequentIssueSelectionType.definition &&
            (!definitionComplete || reason != null)) ||
        (type == FrequentIssueSelectionType.unlisted &&
            (!definitionAbsent || reason == null || reason.length < 5))) {
      throw PersistedDataFormatException(
        field: 'frequentIssueSelection',
        source: source,
        detail: 'definition and unlisted identities must be mutually exclusive',
      );
    }
    return FrequentIssueSelection._(
      type: type,
      definitionId: id,
      definitionVersion: version,
      definitionCode: code,
      definitionTitle: title,
      codeOwnedWorkflowProfile: profile,
      unlistedReason: reason,
    );
  }

  static FrequentIssueSelection? readOptionalSynchronizedFields(
    Map<String, dynamic> map, {
    required String source,
  }) {
    if (!map.containsKey('frequentIssueSelection')) return null;
    final raw = map['frequentIssueSelection'];
    if (raw is! Map) {
      throw PersistedDataFormatException(
        field: 'frequentIssueSelection',
        source: source,
        detail: 'expected an object',
      );
    }
    return FrequentIssueSelection.fromMap(
      Map<String, dynamic>.from(raw),
      source: source,
    );
  }

  static FrequentIssueSelection? tryDecodeLocal(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return null;
    dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final raw = Map<String, dynamic>.from(decoded)['frequentIssueSelection'];
    if (raw == null) return null;
    if (raw is! Map) {
      throw const FormatException('Frequent issue metadata is malformed.');
    }
    return FrequentIssueSelection.fromMap(
      Map<String, dynamic>.from(raw),
      source: 'local maintenance metadata',
    );
  }
}

String mergeFrequentIssueSelectionIntoMaintenanceMetadata(
  String? existing,
  FrequentIssueSelection? selection,
) {
  final root = <String, dynamic>{};
  if (existing != null && existing.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(existing);
      if (decoded is Map) root.addAll(Map<String, dynamic>.from(decoded));
    } on FormatException {
      root['legacyMetadata'] = existing;
    }
  }
  if (selection == null) {
    root.remove('frequentIssueSelection');
  } else {
    root['frequentIssueSelection'] = selection.toLocalMap();
  }
  return jsonEncode(root);
}
