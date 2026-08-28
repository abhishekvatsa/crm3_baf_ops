import '../../../core/serialization/persisted_data_reader.dart';
import 'operational_event.dart';

final _operationalEventIssueLinkIdPattern = RegExp(
  r'^event_issue_[0-9a-f]{48}$',
);
final _operationalEventIssueUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

enum OperationalEventIssueRelationship {
  causedByEvent,
  responseToEvent,
  affectedByEvent;

  String get label => switch (this) {
    causedByEvent => 'Caused by disruption',
    responseToEvent => 'Restoration work',
    affectedByEvent => 'Work affected by disruption',
  };
}

class OperationalEventIssueLink {
  const OperationalEventIssueLink({
    required this.linkId,
    required this.requestId,
    required this.auditId,
    required this.eventId,
    required this.eventVersionAtLink,
    required this.eventOccurrenceStartedAt,
    required this.eventType,
    required this.eventTitle,
    required this.eventSeverity,
    required this.eventScope,
    required this.affectedAssetClassIds,
    required this.affectedAssetInstanceIds,
    required this.issueId,
    required this.issueVersionAtLink,
    required this.issueStatusAtLink,
    required this.issueResolvedAtLink,
    required this.issueAssetType,
    required this.issueAssetNumber,
    required this.issueAssetClassId,
    required this.issueAssetInstanceId,
    required this.issueDescription,
    required this.issueRoutedTo,
    required this.issueComponent,
    required this.issueSubsystem,
    required this.issueTag,
    required this.relationship,
    required this.reason,
    required this.linkedAt,
    required this.linkedByUid,
    required this.linkedByName,
  });

  final String linkId;
  final String requestId;
  final String auditId;
  final String eventId;
  final int eventVersionAtLink;
  final DateTime eventOccurrenceStartedAt;
  final OperationalEventType eventType;
  final String eventTitle;
  final OperationalEventSeverity eventSeverity;
  final OperationalEventScope eventScope;
  final List<String> affectedAssetClassIds;
  final List<String> affectedAssetInstanceIds;
  final String issueId;
  final int issueVersionAtLink;
  final String issueStatusAtLink;
  final bool issueResolvedAtLink;
  final String issueAssetType;
  final int issueAssetNumber;
  final String? issueAssetClassId;
  final String? issueAssetInstanceId;
  final String issueDescription;
  final String issueRoutedTo;
  final String? issueComponent;
  final String? issueSubsystem;
  final String? issueTag;
  final OperationalEventIssueRelationship relationship;
  final String reason;
  final DateTime linkedAt;
  final String linkedByUid;
  final String linkedByName;

  factory OperationalEventIssueLink.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final source = 'operational_event_issue_links/$documentId';
    final schemaVersion = readRequiredPersistedInt(
      map['schemaVersion'],
      field: 'schemaVersion',
      source: source,
      minimum: 1,
    );
    if (schemaVersion != 1) {
      throw PersistedDataFormatException(
        field: 'schemaVersion',
        source: source,
        detail: 'unsupported issue-link schema $schemaVersion',
      );
    }
    final linkId = readRequiredPersistedString(
      map['linkId'],
      field: 'linkId',
      source: source,
    );
    if (linkId != documentId ||
        !_operationalEventIssueLinkIdPattern.hasMatch(linkId)) {
      throw PersistedDataFormatException(
        field: 'linkId',
        source: source,
        detail: 'must be the canonical link identity and match the document ID',
      );
    }
    final requestId = _uuidIdentity(map, 'requestId', source);
    final auditId = readRequiredPersistedString(
      map['auditId'],
      field: 'auditId',
      source: source,
    );
    if (auditId != 'operational_event_issue_$requestId') {
      throw PersistedDataFormatException(
        field: 'auditId',
        source: source,
        detail: 'must derive from the request identity',
      );
    }
    final eventId = _uuidIdentity(map, 'eventId', source);
    final issueId = _documentIdentity(map, 'issueId', source);
    final classIds = readRequiredStringList(
      map,
      'affectedAssetClassIds',
      source,
      maximum: 20,
    );
    final assetIds = readRequiredStringList(
      map,
      'affectedAssetInstanceIds',
      source,
      maximum: 50,
    );
    final eventScope = readRequiredPersistedEnum(
      OperationalEventScope.values,
      map['eventScope'],
      field: 'eventScope',
      source: source,
    );
    if (!_validScope(eventScope, classIds, assetIds)) {
      throw PersistedDataFormatException(
        field: 'eventScope',
        source: source,
        detail: 'does not agree with the frozen event asset scope',
      );
    }
    final occurrenceStartedAt = readRequiredPersistedDateTime(
      map['eventOccurrenceStartedAt'],
      field: 'eventOccurrenceStartedAt',
      source: source,
    );
    final linkedAt = readRequiredPersistedDateTime(
      map['linkedAt'],
      field: 'linkedAt',
      source: source,
    );
    if (linkedAt.isBefore(occurrenceStartedAt)) {
      throw PersistedDataFormatException(
        field: 'linkedAt',
        source: source,
        detail: 'cannot precede the linked event occurrence',
      );
    }
    final status = readRequiredPersistedString(
      map['issueStatusAtLink'],
      field: 'issueStatusAtLink',
      source: source,
    );
    const statuses = <String>{'open', 'acknowledged', 'inProgress', 'resolved'};
    if (!statuses.contains(status)) {
      throw PersistedDataFormatException(
        field: 'issueStatusAtLink',
        source: source,
        detail: 'is not a supported maintenance lifecycle state',
      );
    }
    final resolved = readRequiredPersistedBool(
      map['issueResolvedAtLink'],
      field: 'issueResolvedAtLink',
      source: source,
    );
    if ((status == 'resolved') != resolved) {
      throw PersistedDataFormatException(
        field: 'issueResolvedAtLink',
        source: source,
        detail: 'must agree with issueStatusAtLink',
      );
    }
    final issueAssetClassId = _boundedOptionalText(
      map,
      'issueAssetClassId',
      source,
      128,
    );
    final issueAssetInstanceId = _boundedOptionalText(
      map,
      'issueAssetInstanceId',
      source,
      128,
    );
    final issueIdentityMatchesScope = switch (eventScope) {
      OperationalEventScope.plantWide =>
        issueAssetInstanceId == null || issueAssetClassId != null,
      OperationalEventScope.assetClasses =>
        issueAssetClassId != null && classIds.contains(issueAssetClassId),
      OperationalEventScope.assets =>
        issueAssetClassId != null &&
            issueAssetInstanceId != null &&
            assetIds.contains(issueAssetInstanceId),
    };
    if (!issueIdentityMatchesScope) {
      throw PersistedDataFormatException(
        field: 'issueAssetInstanceId',
        source: source,
        detail: 'does not belong to the frozen event scope',
      );
    }
    final reason = readRequiredPersistedString(
      map['reason'],
      field: 'reason',
      source: source,
    );
    if (reason.length > 1000) {
      throw PersistedDataFormatException(
        field: 'reason',
        source: source,
        detail: 'must not exceed 1000 characters',
      );
    }
    return OperationalEventIssueLink(
      linkId: linkId,
      requestId: requestId,
      auditId: auditId,
      eventId: eventId,
      eventVersionAtLink: readRequiredPersistedInt(
        map['eventVersionAtLink'],
        field: 'eventVersionAtLink',
        source: source,
        minimum: 1,
      ),
      eventOccurrenceStartedAt: occurrenceStartedAt,
      eventType: readRequiredPersistedEnum(
        OperationalEventType.values,
        map['eventType'],
        field: 'eventType',
        source: source,
      ),
      eventTitle: _boundedText(map, 'eventTitle', source, 120),
      eventSeverity: readRequiredPersistedEnum(
        OperationalEventSeverity.values,
        map['eventSeverity'],
        field: 'eventSeverity',
        source: source,
      ),
      eventScope: eventScope,
      affectedAssetClassIds: classIds,
      affectedAssetInstanceIds: assetIds,
      issueId: issueId,
      issueVersionAtLink: readRequiredPersistedInt(
        map['issueVersionAtLink'],
        field: 'issueVersionAtLink',
        source: source,
        minimum: 1,
      ),
      issueStatusAtLink: status,
      issueResolvedAtLink: resolved,
      issueAssetType: _boundedText(map, 'issueAssetType', source, 64),
      issueAssetNumber: readRequiredPersistedInt(
        map['issueAssetNumber'],
        field: 'issueAssetNumber',
        source: source,
        minimum: 1,
      ),
      issueAssetClassId: issueAssetClassId,
      issueAssetInstanceId: issueAssetInstanceId,
      issueDescription: _boundedText(map, 'issueDescription', source, 4000),
      issueRoutedTo: _boundedText(map, 'issueRoutedTo', source, 64),
      issueComponent: _boundedOptionalText(map, 'issueComponent', source, 500),
      issueSubsystem: _boundedOptionalText(map, 'issueSubsystem', source, 500),
      issueTag: _boundedOptionalText(map, 'issueTag', source, 200),
      relationship: readRequiredPersistedEnum(
        OperationalEventIssueRelationship.values,
        map['relationship'],
        field: 'relationship',
        source: source,
      ),
      reason: reason,
      linkedAt: linkedAt,
      linkedByUid: _boundedText(map, 'linkedByUid', source, 128),
      linkedByName: _boundedText(map, 'linkedByName', source, 200),
    );
  }
}

String _uuidIdentity(Map<String, dynamic> map, String field, String source) {
  final value = readRequiredPersistedString(
    map[field],
    field: field,
    source: source,
  );
  if (!_operationalEventIssueUuidPattern.hasMatch(value)) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be a canonical UUID',
    );
  }
  return value;
}

String _documentIdentity(
  Map<String, dynamic> map,
  String field,
  String source,
) {
  final value = _boundedText(map, field, source, 128);
  if (value == '.' || value == '..' || value.contains('/')) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be a valid document identity',
    );
  }
  return value;
}

List<String> readRequiredStringList(
  Map<String, dynamic> map,
  String field,
  String source, {
  required int maximum,
}) {
  if (map[field] is! List) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must be a complete list',
    );
  }
  final values = readOptionalPersistedStringList(
    map[field],
    field: field,
    source: source,
  );
  if (values.length > maximum || values.toSet().length != values.length) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'exceeds its bound or contains duplicates',
    );
  }
  return List<String>.unmodifiable(values);
}

String _boundedText(
  Map<String, dynamic> map,
  String field,
  String source,
  int maximum,
) {
  final value = readRequiredPersistedString(
    map[field],
    field: field,
    source: source,
  );
  if (value.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain at most $maximum characters',
    );
  }
  return value;
}

String? _boundedOptionalText(
  Map<String, dynamic> map,
  String field,
  String source,
  int maximum,
) {
  final value = readOptionalPersistedString(
    map[field],
    field: field,
    source: source,
  );
  if (value != null && value.length > maximum) {
    throw PersistedDataFormatException(
      field: field,
      source: source,
      detail: 'must contain at most $maximum characters',
    );
  }
  return value;
}

bool _validScope(
  OperationalEventScope scope,
  List<String> classIds,
  List<String> assetIds,
) => switch (scope) {
  OperationalEventScope.plantWide => classIds.isEmpty && assetIds.isEmpty,
  OperationalEventScope.assetClasses => classIds.isNotEmpty && assetIds.isEmpty,
  OperationalEventScope.assets => assetIds.isNotEmpty,
};
