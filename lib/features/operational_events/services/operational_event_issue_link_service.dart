import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/operational_event.dart';
import '../data/operational_event_issue_link.dart';
import 'operational_event_service.dart';

const operationalEventIssueLinkOperation = 'LINK_OPERATIONAL_EVENT_ISSUE';
final _operationalEventIssueLinkResultIdPattern = RegExp(
  r'^event_issue_[0-9a-f]{48}$',
);

class OperationalEventIssueLinkCommandResult {
  const OperationalEventIssueLinkCommandResult({
    required this.requestId,
    required this.eventId,
    required this.issueId,
    required this.linkId,
    required this.eventVersion,
    required this.issueVersion,
    required this.auditId,
    required this.committedAt,
    required this.idempotentReplay,
  });

  final String requestId;
  final String eventId;
  final String issueId;
  final String linkId;
  final int eventVersion;
  final int issueVersion;
  final String auditId;
  final DateTime committedAt;
  final bool idempotentReplay;

  factory OperationalEventIssueLinkCommandResult.fromMap(
    Map<String, dynamic> map, {
    required String expectedRequestId,
    required String expectedEventId,
    required String expectedIssueId,
  }) {
    final source = '$operationalEventCallableName/$expectedRequestId';
    if (map['ok'] != true ||
        map['operation'] != operationalEventIssueLinkOperation) {
      throw PersistedDataFormatException(
        field: 'operation',
        source: source,
        detail: 'expected a successful issue-link response',
      );
    }
    final requestId = readRequiredPersistedString(
      map['requestId'],
      field: 'requestId',
      source: source,
    );
    final eventId = readRequiredPersistedString(
      map['eventId'],
      field: 'eventId',
      source: source,
    );
    final issueId = readRequiredPersistedString(
      map['issueId'],
      field: 'issueId',
      source: source,
    );
    if (requestId != expectedRequestId ||
        eventId != expectedEventId ||
        issueId != expectedIssueId) {
      throw PersistedDataFormatException(
        field: 'requestId',
        source: source,
        detail: 'response identity mismatch',
      );
    }
    final committedAtRaw = map['committedAt'];
    final committedAt = readRequiredPersistedDateTime(
      map['committedAt'],
      field: 'committedAt',
      source: source,
    );
    if (committedAtRaw is! String ||
        committedAtRaw.trim() != committedAt.toUtc().toIso8601String()) {
      throw PersistedDataFormatException(
        field: 'committedAt',
        source: source,
        detail: 'must be a canonical UTC ISO instant',
      );
    }
    final auditId = readRequiredPersistedString(
      map['auditId'],
      field: 'auditId',
      source: source,
    );
    if (auditId != 'operational_event_issue_$expectedRequestId') {
      throw PersistedDataFormatException(
        field: 'auditId',
        source: source,
        detail: 'response audit identity mismatch',
      );
    }
    final linkId = readRequiredPersistedString(
      map['linkId'],
      field: 'linkId',
      source: source,
    );
    if (!_operationalEventIssueLinkResultIdPattern.hasMatch(linkId)) {
      throw PersistedDataFormatException(
        field: 'linkId',
        source: source,
        detail: 'must be a canonical operational-event issue-link identity',
      );
    }
    return OperationalEventIssueLinkCommandResult(
      requestId: requestId,
      eventId: eventId,
      issueId: issueId,
      linkId: linkId,
      eventVersion: readRequiredPersistedInt(
        map['eventVersion'],
        field: 'eventVersion',
        source: source,
        minimum: 1,
      ),
      issueVersion: readRequiredPersistedInt(
        map['issueVersion'],
        field: 'issueVersion',
        source: source,
        minimum: 1,
      ),
      auditId: auditId,
      committedAt: committedAt,
      idempotentReplay: readRequiredPersistedBool(
        map['idempotentReplay'],
        field: 'idempotentReplay',
        source: source,
      ),
    );
  }
}

class OperationalEventIssueLinkService {
  OperationalEventIssueLinkService({FirebaseFunctions? functions})
    : _functions = functions;

  final FirebaseFunctions? _functions;
  static const _uuid = Uuid();

  FirebaseFunctions get _client =>
      _functions ??
      FirebaseFunctions.instanceFor(region: operationalEventCallableRegion);

  Future<OperationalEventIssueLinkCommandResult> link({
    required OperationalEvent event,
    required MaintenanceRecord issue,
    required OperationalEventIssueRelationship relationship,
    required String reason,
  }) async {
    final issueId = issue.firestoreId?.trim();
    if (issueId == null || issueId.isEmpty) {
      throw const OperationalEventCommandException(
        'The issue has no cloud identity yet. Sync it before linking.',
        code: 'failed-precondition',
      );
    }
    final requestId = _uuid.v4();
    final request = <String, dynamic>{
      'requestId': requestId,
      'operation': operationalEventIssueLinkOperation,
      'eventId': event.eventId,
      'issueId': issueId,
      'expectedEventVersion': event.version,
      'expectedIssueVersion': issue.version,
      'relationship': relationship.name,
      'reason': reason.trim(),
    };
    try {
      final response = await _client
          .httpsCallable(operationalEventCallableName)
          .call<Map<String, dynamic>>(request);
      return OperationalEventIssueLinkCommandResult.fromMap(
        Map<String, dynamic>.from(response.data),
        expectedRequestId: requestId,
        expectedEventId: event.eventId,
        expectedIssueId: issueId,
      );
    } on FirebaseFunctionsException catch (error) {
      throw OperationalEventCommandException(
        error.message ?? 'The issue could not be linked to this event.',
        code: error.code,
      );
    } on PersistedDataFormatException catch (error) {
      throw OperationalEventCommandException(
        'The server returned invalid issue-link evidence: $error',
        code: 'data-loss',
      );
    }
  }
}
