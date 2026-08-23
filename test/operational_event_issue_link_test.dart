import 'dart:io';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event_issue_link.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_event_issue_links_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_issue_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

const eventId = '11111111-1111-4111-8111-111111111111';
const issueId = '22222222-2222-4222-8222-222222222222';
const requestId = '33333333-3333-4333-8333-333333333333';
const linkId = 'event_issue_0123456789abcdef0123456789abcdef0123456789abcdef';

Map<String, dynamic> linkRecord({
  Object? linkedAt,
  List<String> classIds = const ['class-furnace'],
  List<String> assetIds = const ['asset-furnace-7'],
}) => <String, dynamic>{
  'schemaVersion': 1,
  'linkId': linkId,
  'requestId': requestId,
  'auditId': 'operational_event_issue_$requestId',
  'eventId': eventId,
  'eventVersionAtLink': 3,
  'eventOccurrenceStartedAt': DateTime.utc(2026, 8, 14, 10),
  'eventType': 'powerTrip',
  'eventTitle': 'Incoming power interruption',
  'eventSeverity': 'critical',
  'eventScope': 'assets',
  'affectedAssetClassIds': classIds,
  'affectedAssetInstanceIds': assetIds,
  'issueId': issueId,
  'issueVersionAtLink': 4,
  'issueStatusAtLink': 'open',
  'issueResolvedAtLink': false,
  'issueAssetType': 'furnace',
  'issueAssetNumber': 7,
  'issueAssetClassId': 'class-furnace',
  'issueAssetInstanceId': 'asset-furnace-7',
  'issueDescription': 'Inspect controls after incoming power interruption.',
  'issueRoutedTo': 'electrical',
  'issueComponent': 'Control panel',
  'issueSubsystem': 'Power distribution',
  'issueTag': 'MCC-07',
  'relationship': 'responseToEvent',
  'reason': 'Electrical inspection verifies a safe restoration.',
  'linkedAt': linkedAt ?? DateTime.utc(2026, 8, 14, 12),
  'linkedByUid': 'ops-1',
  'linkedByName': 'Operations One',
};

OperationalEvent scopedEvent() => OperationalEvent(
  eventId: eventId,
  eventType: OperationalEventType.powerTrip,
  title: 'Incoming power interruption',
  description: 'Incoming power was unavailable across the shop.',
  severity: OperationalEventSeverity.critical,
  scope: OperationalEventScope.assets,
  affectedAssetClassIds: const ['class-furnace'],
  affectedAssetInstanceIds: const ['asset-furnace-7'],
  startedAt: DateTime.utc(2026, 8, 14, 10),
  status: OperationalEventStatus.open,
  createdAt: DateTime.utc(2026, 8, 14, 10, 5),
  createdByUid: 'ops-1',
  createdByName: 'Operations One',
  resolvedAt: null,
  resolvedByUid: null,
  resolvedByName: null,
  resolutionNote: null,
  version: 3,
  updatedAt: DateTime.utc(2026, 8, 14, 10, 5),
  updatedByUid: 'ops-1',
  updatedByName: 'Operations One',
  lastMutationId: requestId,
);

MaintenanceRecord issueForAsset(String assetInstanceId) {
  final reference = AssetHierarchyReference(
    scope: AssetHierarchyReferenceScope.physicalAsset,
    assetClassId: 'class-furnace',
    assetClassCode: 'FURNACE',
    assetClassName: 'Furnace',
    nodeId: assetInstanceId,
    nodeVersion: 2,
    nodeName: 'Furnace 7',
    assetInstanceId: assetInstanceId,
    assetInstanceVersion: 2,
    assetNumber: 7,
    assetInstanceName: 'Furnace 7',
    hierarchyPath: const ['Furnace', 'Furnace 7'],
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Electrical',
    accountableRoleKeys: const ['electrical'],
  );
  return MaintenanceRecord()
    ..firestoreId = issueId
    ..version = 4
    ..assetType = AssetType.furnace
    ..assetNumber = 7
    ..maintenanceType = MaintenanceType.breakdown
    ..description = 'Inspect controls after incoming power interruption.'
    ..routedTo = RoutedTo.electrical
    ..assetHierarchyRefJson = reference.encode()
    ..startDate = DateTime.utc(2026, 8, 14, 10, 10)
    ..createdAt = DateTime.utc(2026, 8, 14, 10, 12)
    ..updatedAt = DateTime.utc(2026, 8, 14, 10, 12);
}

void main() {
  test('strictly decodes immutable issue-link evidence', () {
    final link = OperationalEventIssueLink.fromMap(linkRecord(), linkId);
    expect(
      link.relationship,
      OperationalEventIssueRelationship.responseToEvent,
    );
    expect(link.eventType, OperationalEventType.powerTrip);
    expect(link.issueAssetInstanceId, 'asset-furnace-7');
    expect(link.linkedByName, 'Operations One');
  });

  test('rejects reversed chronology and malformed frozen scope', () {
    expect(
      () => OperationalEventIssueLink.fromMap(
        linkRecord(linkedAt: DateTime.utc(2026, 8, 14, 9)),
        linkId,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationalEventIssueLink.fromMap(
        linkRecord(classIds: const [], assetIds: const []),
        linkId,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationalEventIssueLink.fromMap(
        linkRecord()..['issueAssetInstanceId'] = 'asset-furnace-8',
        linkId,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationalEventIssueLink.fromMap(
        linkRecord()..['issueTag'] = List.filled(201, 'x').join(),
        linkId,
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed immutable and response identities', () {
    expect(
      () => OperationalEventIssueLink.fromMap(
        linkRecord()..['requestId'] = 'not-a-request-uuid',
        linkId,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationalEventIssueLink.fromMap(
        linkRecord()..['auditId'] = 'unbound-audit',
        linkId,
      ),
      throwsFormatException,
    );
    expect(
      () => OperationalEventIssueLink.fromMap(
        linkRecord()..['linkId'] = 'event_issue_short',
        'event_issue_short',
      ),
      throwsFormatException,
    );

    expect(
      () => OperationalEventIssueLinkCommandResult.fromMap(
        {
          'ok': true,
          'requestId': requestId,
          'operation': operationalEventIssueLinkOperation,
          'eventId': eventId,
          'issueId': issueId,
          'linkId': 'event_issue_short',
          'eventVersion': 4,
          'issueVersion': 5,
          'auditId': 'operational_event_issue_$requestId',
          'committedAt': '2026-08-14T12:00:00.000Z',
          'idempotentReplay': false,
        },
        expectedRequestId: requestId,
        expectedEventId: eventId,
        expectedIssueId: issueId,
      ),
      throwsFormatException,
    );
  });

  test('event scope accepts only governed issue identity inside it', () {
    expect(
      operationalEventCoversIssue(
        scopedEvent(),
        issueForAsset('asset-furnace-7'),
      ),
      isTrue,
    );
    expect(
      operationalEventCoversIssue(
        scopedEvent(),
        issueForAsset('asset-furnace-8'),
      ),
      isFalse,
    );
  });

  test('issue dossier retains and orders more than fifty event links', () {
    final links = List<OperationalEventIssueLink>.generate(51, (index) {
      final currentLinkId =
          'event_issue_${index.toRadixString(16).padLeft(48, '0')}';
      return OperationalEventIssueLink.fromMap(
        linkRecord(
          linkedAt: DateTime.utc(2026, 8, 14, 12).add(Duration(hours: index)),
        )..['linkId'] = currentLinkId,
        currentLinkId,
      );
    });

    final sorted = sortOperationalEventIssueLinks(links.reversed);
    expect(sorted, hasLength(51));
    expect(sorted.first.linkedAt, DateTime.utc(2026, 8, 16, 14));
    expect(sorted.last.linkedAt, DateTime.utc(2026, 8, 14, 12));

    final providerSource =
        File(
          'lib/features/operational_events/providers/operational_event_provider.dart',
        ).readAsStringSync();
    final issueProvider = RegExp(
      r'operationalIssueEventLinksProvider[\s\S]*?'
      r'_decodeOperationalEventIssueLinks\);',
    ).firstMatch(providerSource);
    expect(issueProvider, isNotNull);
    expect(issueProvider!.group(0), isNot(contains('.limit(')));
  });

  test(
    'strict command response binds request, records, and audit identity',
    () {
      final result = OperationalEventIssueLinkCommandResult.fromMap(
        {
          'ok': true,
          'requestId': requestId,
          'operation': operationalEventIssueLinkOperation,
          'eventId': eventId,
          'issueId': issueId,
          'linkId': linkId,
          'eventVersion': 4,
          'issueVersion': 5,
          'auditId': 'operational_event_issue_$requestId',
          'committedAt': '2026-08-14T12:00:00.000Z',
          'idempotentReplay': false,
        },
        expectedRequestId: requestId,
        expectedEventId: eventId,
        expectedIssueId: issueId,
      );
      expect(result.linkId, linkId);
      expect(result.eventVersion, 4);

      expect(
        () => OperationalEventIssueLinkCommandResult.fromMap(
          {
            'ok': true,
            'requestId': requestId,
            'operation': operationalEventIssueLinkOperation,
            'eventId': eventId,
            'issueId': 'wrong-issue',
            'linkId': linkId,
            'eventVersion': 4,
            'issueVersion': 5,
            'auditId': 'operational_event_issue_$requestId',
            'committedAt': '2026-08-14T12:00:00.000Z',
            'idempotentReplay': false,
          },
          expectedRequestId: requestId,
          expectedEventId: eventId,
          expectedIssueId: issueId,
        ),
        throwsFormatException,
      );
    },
  );
}
