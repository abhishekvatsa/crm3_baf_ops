import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/security/actor_session_cache_trust.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event_impact.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event_issue_link.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/test_support/operational_event_amendment_fixtures.dart';
import 'operational_event_issue_link_test.dart' as links;

void main() {
  test(
    'raw closure stays immutable while summary and report builder use amended end',
    () {
      final event = amendmentReview(amended: true).event;
      expect(event.resolvedAt, amendmentTime(12));
      expect(
        event.occurrencesUntil(amendmentTime(18)).single.resolvedAt,
        amendmentTime(12),
      );
      expect(
        event.effectiveOccurrencesUntil(amendmentTime(18)).single.resolvedAt,
        amendmentTime(11),
      );
      final summary = summarizeOperationalEventImpact(
        events: [event],
        month: DateTime.utc(2025, 8),
        asOf: amendmentTime(18),
      );
      expect(summary.cumulativeDuration, const Duration(hours: 1));
      expect(summary.occurrenceCount, 1);
      final report = buildOperationsReport(
        filter: OperationsReportFilter(
          startDate: DateTime(2025, 8, 14),
          endDate: DateTime(2025, 8, 14),
        ),
        tickets: [],
        executions: [],
        events: [event],
        assetClasses: [],
        assetInstances: [],
        overview: const PlantAssetOverview(classes: [], assets: []),
        asOf: amendmentTime(18),
      );
      expect(
        report.eventOccurrences.single.interval.resolvedAt,
        amendmentTime(11),
      );
      expect(
        report.eventOccurrences.single.event.resolvedAt,
        amendmentTime(12),
      );
    },
  );

  test(
    'archived ordinal and effective end survive reopening without changing raw history',
    () {
      final event = amendmentReview(reopened: true, amended: true).event;
      expect(event.currentOccurrenceIndex, 1);
      expect(event.isOpen, isTrue);
      expect(event.completedIntervals.single.resolvedAt, amendmentTime(12));
      expect(
        event
            .effectiveOccurrencesUntil(amendmentTime(16))
            .map((e) => e.occurrenceIndex),
        [0, 1],
      );
      expect(event.durationUntil(amendmentTime(16)), const Duration(hours: 2));
      expect(
        event.occurrenceCountWithin(
          amendmentTime(11),
          amendmentTime(12),
          amendmentTime(16),
        ),
        0,
      );
    },
  );

  final malformed =
      <String, void Function(Map<String, dynamic>, Map<String, dynamic>)>{
        'unknown head field': (_, head) => head['unrecognized'] = true,
        'missing chain field': (_, head) =>
            head.remove('supersedesAmendmentId'),
        'wrong reviewer type': (_, head) => head['amendedByName'] = 3,
        'empty reason': (_, head) => head['reason'] = '',
        'self predecessor': (_, head) =>
            head['supersedesAmendmentId'] = amendmentId,
        'original end drift': (_, head) =>
            head['originalResolvedAt'] = amendmentTime(13),
        'before start': (_, head) =>
            head['correctedResolvedAt'] = amendmentTime(9),
        'past next recurrence': (_, head) =>
            head['correctedResolvedAt'] = amendmentTime(16),
        'future corrected': (_, head) =>
            head['correctedResolvedAt'] = amendmentTime(17),
        'future amendment': (_, head) => head['amendedAt'] = amendmentTime(17),
        'fractional millisecond native': (_, head) =>
            head['correctedResolvedAt'] = Timestamp(
              amendmentTime(11).millisecondsSinceEpoch ~/ 1000,
              1,
            ),
        'fractional millisecond ISO': (_, head) =>
            head['amendedAt'] = '2025-08-14T16:00:00.000001Z',
        'noncanonical ordinal': (event, head) =>
            event['intervalEndAmendments'] = {'00': head},
        'open occurrence ordinal': (event, head) =>
            event['intervalEndAmendments'] = {'1': head},
        'ordinal out of bounds': (event, head) =>
            event['intervalEndAmendments'] = {'101': head},
      };
  for (final entry in malformed.entries) {
    test('rejects ${entry.key}', () {
      final raw = amendmentEventRecord(reopened: true, amended: true);
      final head =
          (raw['intervalEndAmendments'] as Map)['0'] as Map<String, dynamic>;
      entry.value(raw, head);
      expect(
        () => OperationalEvent.fromMap(raw, amendmentEventId),
        throwsFormatException,
      );
    });
  }

  test(
    'issue membership follows immutable link ID even when start label differs',
    () {
      final record = amendmentEventRecord(reopened: true, amended: true);
      (record['completedIntervals'] as List).single['issueLinkIds'] = [
        links.linkId,
      ];
      final event = OperationalEvent.fromMap(record, amendmentEventId);
      final rawLink = links.linkRecord()
        ..['eventOccurrenceStartedAt'] = amendmentTime(9);
      final link = OperationalEventIssueLink.fromMap(rawLink, links.linkId);
      expect(operationalEventLinkOccurrenceIndex(event, link), 0);
      expect(
        operationalEventLinkOccurrenceIndex(
          event,
          OperationalEventIssueLink.fromMap({
            ...rawLink,
            'eventOccurrenceIndex': 0,
          }, links.linkId),
        ),
        0,
      );
      expect(
        operationalEventLinkOccurrenceIndex(
          event,
          OperationalEventIssueLink.fromMap({
            ...rawLink,
            'eventOccurrenceIndex': 1,
          }, links.linkId),
        ),
        isNull,
      );
      expect(
        () => OperationalEventIssueLink.fromMap({
          ...rawLink,
          'eventOccurrenceIndex': 1.5,
        }, links.linkId),
        throwsFormatException,
      );
      record['issueLinkIds'] = [links.linkId];
      record['linkedIssueIds'] = ['issue-old'];
      expect(
        operationalEventLinkOccurrenceIndex(
          OperationalEvent.fromMap(record, amendmentEventId),
          link,
        ),
        isNull,
      );
    },
  );

  test(
    'actual complete report provider decodes and propagates effective amendment',
    () async {
      final trust = ActorSessionCacheTrust()..observeActor('admin-a');
      final container = ProviderContainer(
        overrides: [
          operationalEventFirestoreProvider.overrideWithValue(
            _Firestore(amendmentEventRecord(amended: true)),
          ),
          operationalEventCacheTrustProvider.overrideWithValue(trust),
        ],
      );
      addTearDown(container.dispose);
      final events = await container.read(
        operationalEventsForReportsProvider('admin-a').future,
      );
      expect(events.single.resolvedAt, amendmentTime(12));
      expect(
        events.single.durationUntil(amendmentTime(18)),
        const Duration(hours: 1),
      );
    },
  );

  test(
    'actual complete report provider rejects malformed overlay instead of falling back to raw',
    () async {
      final raw = amendmentEventRecord(amended: true);
      (raw['intervalEndAmendments'] as Map)['0']['correctedResolvedAt'] = 'bad';
      final container = ProviderContainer(
        overrides: [
          operationalEventFirestoreProvider.overrideWithValue(_Firestore(raw)),
          operationalEventCacheTrustProvider.overrideWithValue(
            ActorSessionCacheTrust()..observeActor('admin-a'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(operationalEventsForReportsProvider('admin-a').future),
        throwsFormatException,
      );
    },
  );
}

class _Firestore implements FirebaseFirestore {
  _Firestore(this.raw);
  final Map<String, dynamic> raw;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(raw);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Firestore snapshot test doubles exercise the actual provider admission path.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.raw);
  final Map<String, dynamic> raw;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => Stream.value(_Snapshot(raw));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.raw);
  final Map<String, dynamic> raw;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    _Document(raw),
  ];
  @override
  SnapshotMetadata get metadata => _Metadata();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Immutable snapshot test double; no production Firestore subclasses.
// ignore: subtype_of_sealed_class
class _Document implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.raw);
  final Map<String, dynamic> raw;
  @override
  String get id => amendmentEventId;
  @override
  Map<String, dynamic> data() => raw;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Metadata implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
