import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/morning_review/data/morning_review_repository.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_report.dart';

void main() {
  test(
    'server verification grace reports once, then recovers without idle errors',
    () async {
      final snapshots = StreamController<_FeedSnapshot>();
      final values = <_FeedSnapshot>[];
      final errors = <Object>[];
      final subscription = serverVerifiedMorningReviewFeed(
        snapshots.stream,
        isServerVerified: (snapshot) => snapshot.serverVerified,
        source: 'test feed',
        verificationGrace: const Duration(milliseconds: 50),
      ).listen(values.add, onError: errors.add);
      addTearDown(() async {
        await subscription.cancel();
        await snapshots.close();
      });

      snapshots.add(const _FeedSnapshot('cache', serverVerified: false));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(errors, hasLength(1));
      expect(errors.single, isA<MorningReviewFeedUnverifiedException>());

      snapshots.add(const _FeedSnapshot('server', serverVerified: true));
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(values.map((value) => value.label), ['server']);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(errors, hasLength(1));
    },
  );

  group('Morning Review persisted contracts', () {
    test('decodes the exact open-session source snapshot', () {
      final session = MorningReviewSession.fromMap(_sessionMap(), _sessionId);

      expect(session.status, MorningReviewStatus.open);
      expect(session.facilitatorName, 'SI One');
      expect(session.facilitatorHistory, isEmpty);
      expect(
        session.sourceFacts.single.sourceCollection,
        'maintenance_records',
      );
      expect(
        session.sourceCaptureState,
        MorningReviewSourceCaptureState.complete,
      );
    });

    test('rejects unknown fields and incomplete asset identity', () {
      expect(
        () => MorningReviewSession.fromMap({
          ..._sessionMap(),
          'clientOnly': true,
        }, _sessionId),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => MorningReviewEntry.fromMap({
          ..._entryMap(),
          'assetClassName': null,
        }, _entryId),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => MorningReviewSourceFact.fromMap({
          ..._sourceFactMap(),
          'factId': 'maintenance_records:ticket-1',
        }, source: 'test/sourceFact'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test(
      'keeps active action ownership strict and independent of attendance',
      () {
        final action = MorningReviewAction.fromMap(_actionMap(), _actionId);

        expect(action.status, MorningReviewActionStatus.open);
        expect(action.assigneeRole, 'seniorMechanical');
        expect(action.sessionId, _sessionId);

        expect(
          () => MorningReviewAction.fromMap({
            ..._actionMap(),
            'assigneeRole': 'inventedSupervisor',
          }, _actionId),
          throwsA(isA<PersistedDataFormatException>()),
        );
        expect(
          () => MorningReviewAction.fromMap({
            ..._actionMap(),
            'expiresAt': _expiresAt,
          }, _actionId),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test(
      'decodes a frozen meeting and builds the branded report structure',
      () {
        final document = MorningReviewDocument.fromMap(
          _documentMap(),
          _sessionId,
        );
        final report = buildMorningReviewReport(document: document);

        expect(document.entries.single.authorName, 'Contract One');
        expect(document.participants.single.userName, 'SI One');
        expect(document.standingConcerns.single.title, 'Sheath purge valves');
        expect(document.facilitatorHistory, isEmpty);
        expect(report.reportId, 'MR-$_sessionId');
        final actions = report.sections.singleWhere(
          (section) => section.title == 'Actions and ownership',
        );
        expect(actions.tables.single.headers, contains('Completion evidence'));
        expect(actions.tables.single.rows.single.last, 'Pending');
        expect(
          report.sections.map((section) => section.title),
          containsAllInOrder([
            'Meeting record',
            'Furnaces',
            'Actions and ownership',
            'Attendance',
          ]),
        );
        expect(
          () => MorningReviewDocument.fromMap({
            ..._documentMap(),
            'entries': [
              <String, dynamic>{
                'documentId': _entryId,
                ..._entryMap(),
                'sourceReferences': ['maintenance_records/not-captured'],
              },
            ],
          }, _sessionId),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );

    test(
      'decodes the governed not-held record without inventing attendance',
      () {
        final document = MorningReviewDocument.fromMap(
          _notHeldDocumentMap(),
          _sessionId,
        );

        expect(document.status, MorningReviewStatus.notHeld);
        expect(document.participants, isEmpty);
        expect(document.sourceFacts, isEmpty);
        expect(
          document.sourceCaptureState,
          MorningReviewSourceCaptureState.notApplicable,
        );
      },
    );
  });

  group('Morning Review source boundaries', () {
    test('routes the workspace and keeps all client writes denied', () {
      final home = File('lib/home_screen.dart').readAsStringSync();
      final homeCommands =
          File('lib/home_insight_widgets.dart').readAsStringSync();
      final rules = File('firestore.rules').readAsStringSync();

      expect(home, contains("title: 'Morning Review'"));
      expect(home, contains('const MorningReviewScreen()'));
      expect(homeCommands, contains("ValueKey('home-morning-review')"));
      for (final collection in _temporaryCollections) {
        expect(rules, contains('match /$collection/{docId}'));
      }
      expect(
        rules,
        contains('match /morning_review_mutation_receipts/{docId}'),
      );
    });

    test('declares TTL for every temporary Morning Review collection', () {
      final indexes = File('firestore.indexes.json').readAsStringSync();
      for (final collection in _temporaryCollections) {
        expect(indexes, contains('"collectionGroup": "$collection"'));
      }
      expect(indexes, contains('"ttl": true'));
    });

    test('does not silently cap active actions across meeting days', () {
      final source =
          File(
            'lib/features/morning_review/data/morning_review_repository.dart',
          ).readAsStringSync();
      final start = source.indexOf('watchActiveActions()');
      final end = source.indexOf('watchStandingConcerns()', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      expect(source.substring(start, end), isNot(contains('.limit(')));
    });

    test('filters standing-concern lifecycle before presenting the agenda', () {
      final source =
          File(
            'lib/features/morning_review/data/morning_review_repository.dart',
          ).readAsStringSync();
      final start = source.indexOf('watchStandingConcerns()');
      final end = source.indexOf('watchConcernChecks(', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final query = source.substring(start, end);
      expect(query, contains("where('status', whereIn:"));
      expect(query, isNot(contains('.limit(')));
    });

    test('retains retry IDs and waits through initial unverified snapshots', () {
      final providers =
          File(
            'lib/features/morning_review/providers/morning_review_providers.dart',
          ).readAsStringSync();
      final repository =
          File(
            'lib/features/morning_review/data/morning_review_repository.dart',
          ).readAsStringSync();
      expect(
        providers,
        contains('Provider.family<MorningReviewCommandService, String>'),
      );
      expect(providers, contains('currentAppUserProvider.select('));
      expect(
        providers,
        contains('_morningReviewCommandServiceByActorProvider'),
      );
      expect(repository, contains('MorningReviewFeedUnverifiedException'));
      expect(repository, contains('_serverVerificationGrace'));
      expect(repository, contains('serverVerifiedMorningReviewFeed'));
      expect(repository, contains('Timer(verificationGrace'));
      expect(repository, isNot(contains('.timeout(')));
      expect(repository, isNot(contains('yield* Stream<T>.error(')));
      expect(
        repository,
        isNot(contains('_isServerVerified(snapshot)) continue')),
      );
    });
  });
}

class _FeedSnapshot {
  const _FeedSnapshot(this.label, {required this.serverVerified});

  final String label;
  final bool serverVerified;
}

const _sessionId = '2026-08-31';
const _entryId = '33333333-3333-4333-8333-333333333333';
const _actionId = '44444444-4444-4444-8444-444444444444';
const _concernId = '77777777-7777-4777-8777-777777777777';
const _sourceDigest =
    'morningreviewsource1-sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _documentDigest =
    'morningreviewdocument1-sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
final _openedAt = DateTime.utc(2026, 8, 31, 3);
final _expiresAt = DateTime.utc(2026, 9, 14, 3);

const _temporaryCollections = <String>[
  'morning_review_sessions',
  'morning_review_participants',
  'morning_review_entries',
  'morning_review_actions',
  'morning_review_standing_concerns',
  'morning_review_concern_checks',
  'morning_review_documents',
  'morning_review_mutation_receipts',
];

Map<String, dynamic> _sourceFactMap() => {
  'factId': 'maintenance_records/ticket-1',
  'section': 'furnace',
  'sourceType': 'maintenanceIssue',
  'sourceCollection': 'maintenance_records',
  'sourceDocumentId': 'ticket-1',
  'title': 'Furnace 12',
  'summary': 'Draft seal requires inspection.',
  'status': 'open',
  'assetClassId': 'furnace-class',
  'assetClassName': 'Furnace',
  'assetInstanceId': 'furnace-12',
  'assetNumber': '12',
  'observedAtIso': '2026-08-30T06:00:00.000Z',
};

Map<String, dynamic> _sessionMap() => {
  'schemaVersion': 1,
  'sessionId': _sessionId,
  'plantDay': _sessionId,
  'status': 'open',
  'version': 3,
  'openedAt': _openedAt,
  'openedByUid': 'si-1',
  'openedByName': 'SI One',
  'facilitatorUid': 'si-1',
  'facilitatorName': 'SI One',
  'facilitatorRoleKeys': ['si'],
  'facilitatorHistory': <Map<String, dynamic>>[],
  'sourceCapturedAt': _openedAt,
  'sourceFacts': [_sourceFactMap()],
  'sourceFactDigest': _sourceDigest,
  'sourceFactCount': 1,
  'sourceCaptureState': 'complete',
  'sourceCollectionsAtLimit': <String>[],
  'finalizedAt': null,
  'finalizedByUid': null,
  'finalizedByName': null,
  'finalSummary': null,
  'documentDigest': null,
  'updatedAt': _openedAt,
  'updatedByUid': 'si-1',
  'updatedByName': 'SI One',
  'expiresAt': _expiresAt,
  'lastMutationId': '11111111-1111-4111-8111-111111111111',
};

Map<String, dynamic> _entryMap() => {
  'schemaVersion': 1,
  'entryId': _entryId,
  'sessionId': _sessionId,
  'plantDay': _sessionId,
  'section': 'furnace',
  'kind': 'maintenanceUpdate',
  'text': 'Draft seal inspection will precede the next charging plan.',
  'assetClassId': 'furnace-class',
  'assetClassName': 'Furnace',
  'assetInstanceId': 'furnace-12',
  'assetNumber': '12',
  'sourceReferences': ['maintenance_records/ticket-1'],
  'authorUid': 'contract-1',
  'authorName': 'Contract One',
  'authorRoleKeys': ['contractSupervisor'],
  'createdAt': _openedAt.add(const Duration(minutes: 10)),
  'addendumReason': null,
  'expiresAt': _expiresAt,
};

Map<String, dynamic> _participantMap() => {
  'schemaVersion': 1,
  'participantId': '${_sessionId}_si-1',
  'sessionId': _sessionId,
  'userUid': 'si-1',
  'userName': 'SI One',
  'roleKeys': ['si'],
  'state': 'joined',
  'joinedAt': _openedAt,
  'joinedByRequestId': '11111111-1111-4111-8111-111111111111',
  'expiresAt': _expiresAt,
};

Map<String, dynamic> _actionMap() => {
  'schemaVersion': 1,
  'actionId': _actionId,
  'sessionId': _sessionId,
  'originPlantDay': _sessionId,
  'section': 'furnace',
  'text': 'Inspect Furnace 12 draft seal before charging.',
  'assetClassId': 'furnace-class',
  'assetClassName': 'Furnace',
  'assetInstanceId': 'furnace-12',
  'assetNumber': '12',
  'assigneeUid': null,
  'assigneeName': null,
  'assigneeRole': 'seniorMechanical',
  'dueAt': DateTime.utc(2026, 8, 31, 12, 30),
  'status': 'open',
  'version': 1,
  'acceptedAt': null,
  'acceptedByUid': null,
  'acceptedByName': null,
  'completedAt': null,
  'completedByUid': null,
  'completedByName': null,
  'completionNote': null,
  'createdAt': _openedAt.add(const Duration(minutes: 15)),
  'createdByUid': 'si-1',
  'createdByName': 'SI One',
  'updatedAt': _openedAt.add(const Duration(minutes: 15)),
  'updatedByUid': 'si-1',
  'updatedByName': 'SI One',
  'expiresAt': null,
  'lastMutationId': _actionId,
};

Map<String, dynamic> _checkMap() => {
  'schemaVersion': 1,
  'checkId': '${_sessionId}_$_concernId',
  'sessionId': _sessionId,
  'concernId': _concernId,
  'concernTitle': 'Sheath purge valves',
  'state': 'complied',
  'note': 'Verified open on all operating bases.',
  'checkedAt': _openedAt.add(const Duration(minutes: 20)),
  'checkedByUid': 'si-1',
  'checkedByName': 'SI One',
  'expiresAt': _expiresAt,
};

Map<String, dynamic> _concernMap() => {
  'schemaVersion': 1,
  'concernId': _concernId,
  'originSessionId': _sessionId,
  'title': 'Sheath purge valves',
  'detail': 'Confirm that sheath purge valves remain open on all bases.',
  'criticality': 'safety',
  'status': 'active',
  'version': 1,
  'createdAt': _openedAt.add(const Duration(minutes: 5)),
  'createdByUid': 'si-1',
  'createdByName': 'SI One',
  'resolvedAt': null,
  'resolvedByUid': null,
  'resolvedByName': null,
  'resolutionReason': null,
  'updatedAt': _openedAt.add(const Duration(minutes: 5)),
  'updatedByUid': 'si-1',
  'updatedByName': 'SI One',
  'expiresAt': null,
  'lastMutationId': _concernId,
};

Map<String, dynamic> _documentMap() => {
  'schemaVersion': 1,
  'sessionId': _sessionId,
  'plantDay': _sessionId,
  'status': 'finalized',
  'title': 'BAF Morning Review',
  'facilitatorUid': 'si-1',
  'facilitatorName': 'SI One',
  'facilitatorHistory': <Map<String, dynamic>>[],
  'sourceCapturedAt': _openedAt,
  'sourceCaptureState': 'complete',
  'sourceCollectionsAtLimit': <String>[],
  'sourceFactDigest': _sourceDigest,
  'documentDigest': _documentDigest,
  'sourceFacts': [_sourceFactMap()],
  'entries': [
    <String, dynamic>{'documentId': _entryId, ..._entryMap()},
  ],
  'actions': [
    <String, dynamic>{'documentId': _actionId, ..._actionMap()},
  ],
  'participants': [
    <String, dynamic>{'documentId': '${_sessionId}_si-1', ..._participantMap()},
  ],
  'standingConcerns': [
    <String, dynamic>{'documentId': _concernId, ..._concernMap()},
  ],
  'standingConcernChecks': [
    <String, dynamic>{
      'documentId': '${_sessionId}_$_concernId',
      ..._checkMap(),
    },
  ],
  'finalSummary': 'Furnace 12 inspection remains in the forward plan.',
  'finalizedAt': _openedAt.add(const Duration(hours: 1)),
  'finalizedByUid': 'si-1',
  'finalizedByName': 'SI One',
  'expiresAt': _expiresAt,
};

Map<String, dynamic> _notHeldDocumentMap() => {
  'schemaVersion': 1,
  'sessionId': _sessionId,
  'plantDay': _sessionId,
  'status': 'notHeld',
  'title': 'BAF Morning Review',
  'facilitatorUid': 'admin-1',
  'facilitatorName': 'Admin One',
  'facilitatorHistory': <Map<String, dynamic>>[],
  'sourceCapturedAt': null,
  'sourceCaptureState': 'notApplicable',
  'sourceCollectionsAtLimit': <String>[],
  'sourceFactDigest': null,
  'documentDigest': null,
  'sourceFacts': <Map<String, dynamic>>[],
  'entries': <Map<String, dynamic>>[],
  'actions': <Map<String, dynamic>>[],
  'participants': <Map<String, dynamic>>[],
  'standingConcerns': <Map<String, dynamic>>[],
  'standingConcernChecks': <Map<String, dynamic>>[],
  'finalSummary': 'Plant shutdown.',
  'finalizedAt': _openedAt,
  'finalizedByUid': 'admin-1',
  'finalizedByName': 'Admin One',
  'expiresAt': _expiresAt,
};
