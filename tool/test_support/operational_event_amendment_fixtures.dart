import 'dart:convert';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/operational_events/repositories/operational_event_amendment_repository.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_amendment_service.dart';

const amendmentEventId = '11111111-1111-4111-8111-111111111111';
const amendmentId = '22222222-2222-4222-8222-222222222222';
const previousAmendmentId = '33333333-3333-4333-8333-333333333333';
DateTime amendmentTime(int hour) => DateTime.utc(2025, 8, 14, hour);
AppUser amendmentActor([
  String uid = 'admin-a',
  AppRole role = AppRole.admin,
]) => AppUser(
  uid: uid,
  name: 'Admin A',
  email: '$uid@example.test',
  roles: [role],
  isApproved: true,
  createdAt: DateTime.utc(2025),
);

Map<String, dynamic> amendmentEventRecord({
  bool reopened = false,
  bool amended = false,
}) {
  final interval = <String, dynamic>{
    'eventType': 'powerTrip',
    'title': 'Incoming interruption',
    'description': 'Incoming power was unavailable.',
    'severity': 'critical',
    'scope': 'plantWide',
    'affectedAssetClassIds': <String>[],
    'affectedAssetInstanceIds': <String>[],
    'issueLinkIds': <String>['link-old'],
    'linkedIssueIds': <String>['issue-old'],
    'startedAt': amendmentTime(10),
    'resolvedAt': amendmentTime(12),
    'resolvedByUid': 'ops',
    'resolvedByName': 'Operations',
    'resolutionNote': 'Restored supply.',
  };
  return <String, dynamic>{
    ...interval,
    'schemaVersion': 1,
    'eventId': amendmentEventId,
    'completedIntervals': reopened
        ? [Map<String, dynamic>.from(interval)]
        : <Map<String, dynamic>>[],
    'status': reopened ? 'open' : 'resolved',
    'createdAt': amendmentTime(10),
    'createdByUid': 'ops',
    'createdByName': 'Operations',
    'version': amended ? 4 : 3,
    'updatedAt': amendmentTime(16),
    'updatedByUid': 'admin-a',
    'updatedByName': 'Admin A',
    'lastMutationId': amendmentId,
    if (reopened) ...{
      'startedAt': amendmentTime(15),
      'resolvedAt': null,
      'resolvedByUid': null,
      'resolvedByName': null,
      'resolutionNote': null,
      'issueLinkIds': <String>[],
      'linkedIssueIds': <String>[],
    },
    if (amended)
      'intervalEndAmendments': <String, dynamic>{
        '0': <String, dynamic>{
          'amendmentId': amendmentId,
          'originalResolvedAt': amendmentTime(12),
          'correctedResolvedAt': amendmentTime(11),
          'amendedAt': amendmentTime(16),
          'amendedByUid': 'admin-a',
          'amendedByName': 'Admin A',
          'reason': 'Verified actual restoration.',
          'supersedesAmendmentId': null,
        },
      },
  };
}

OperationalEventAmendmentReview amendmentReview({
  bool reopened = false,
  bool amended = false,
}) => OperationalEventAmendmentRepository.decodeReview(
  amendmentEventRecord(reopened: reopened, amended: amended),
  amendmentEventId,
  0,
);

Map<String, dynamic> amendmentEvidence(
  Map<String, dynamic> request,
  String originalJson,
) {
  final input = request['intervalAmendment'] as Map<String, dynamic>;
  final data = <String, dynamic>{
    'schemaVersion': 1,
    'amendmentId': request['requestId'],
    'eventId': request['eventId'],
    'occurrenceIndex': input['occurrenceIndex'],
    'expectedEventVersion': request['expectedVersion'],
    'resultVersion': (request['expectedVersion'] as int) + 1,
    'originalIntervalJson': originalJson,
    'priorEffectiveResolvedAt': input['expectedEffectiveResolvedAt'],
    'correctedResolvedAt': input['correctedResolvedAt'],
    'supersedesAmendmentId': input['supersedesAmendmentId'],
    'reason': request['reason'],
    'amendedAt': amendmentTime(16).toIso8601String(),
    'amendedByUid': 'admin-a',
    'amendedByName': 'Admin A',
  };
  data['evidenceDigest'] =
      'operational-interval-amendment-v1-sha256:${sha256.convert(utf8.encode(operationalAmendmentCanonicalJson(data)))}';
  return data;
}

Map<String, dynamic> amendmentReceipt(
  Map<String, dynamic> request,
  String originalJson,
) {
  final input = request['intervalAmendment'] as Map<String, dynamic>;
  return {
    'ok': true,
    'requestId': request['requestId'],
    'operation': operationalEventAmendmentOperation,
    'eventId': request['eventId'],
    'status': 'resolved',
    'version': (request['expectedVersion'] as int) + 1,
    'auditId': 'operational_event_${request['requestId']}',
    'committedAt': amendmentTime(16).toIso8601String(),
    'idempotentReplay': false,
    'amendmentId': request['requestId'],
    'occurrenceIndex': input['occurrenceIndex'],
    'correctedResolvedAt': input['correctedResolvedAt'],
    'supersedesAmendmentId': input['supersedesAmendmentId'],
    'amendmentEvidenceDigest': amendmentEvidence(
      request,
      originalJson,
    )['evidenceDigest'],
  };
}
