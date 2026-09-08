import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_agenda.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Morning Review agenda compiler', () {
    test('native completion command contract settles its captured action', () {
      final contract =
          jsonDecode(
                File(
                  'test/fixtures/morning_review_native_completion_v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final fact = MorningReviewSourceFact.fromMap(
        Map<String, dynamic>.from(contract['fact'] as Map),
        source: 'native command contract',
      );
      final entryMap = Map<String, dynamic>.from(contract['entry'] as Map);
      final entry = MorningReviewEntry.fromMap(
        entryMap,
        entryMap['entryId'] as String,
      );
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [fact],
        entries: [entry],
      );
      expect(agenda.countFor(MorningReviewAgendaFilter.open), 0);
      expect(agenda.countFor(MorningReviewAgendaFilter.resolved), 1);
      expect(
        fact.status,
        'accepted',
        reason: 'The captured source remains unchanged.',
      );

      for (final invalid in <Map<String, dynamic>>[
        {
          ...entryMap,
          'sourceReferences': ['maintenance_records/prior-action'],
        },
        {...entryMap, 'sourceReferences': <String>[]},
        {
          ...entryMap,
          'sourceReferences': [
            'morning_review_actions/prior-action',
            'morning_review_actions/other',
          ],
        },
        {...entryMap, 'kind': 'observation'},
        {
          ...entryMap,
          'entryId': (entryMap['entryId'] as String).replaceFirst(
            '-v2-',
            '-v1-',
          ),
        },
        {
          ...entryMap,
          'entryId': (entryMap['entryId'] as String).replaceFirst(
            '-v2-',
            '-v9007199254740992-',
          ),
        },
      ]) {
        expect(
          () =>
              MorningReviewEntry.fromMap(invalid, invalid['entryId'] as String),
          throwsFormatException,
        );
      }
      final otherFact = _fact(
        id: 'morning_review_actions/other',
        sourceType: 'carriedAction',
        title: 'A different action',
        status: 'accepted',
        observedAt: DateTime.utc(2026, 8, 30),
      );
      final otherAgenda = compileMorningReviewAgenda(
        sourceFacts: [otherFact],
        entries: [entry],
      );
      expect(otherAgenda.countFor(MorningReviewAgendaFilter.resolved), 0);
    });
    test('keeps distinct matters under one governed asset', () {
      final burner = _fact(
        id: 'maintenance_records/burner',
        title: 'Burner lockout',
        status: 'open',
      );
      final seal = _fact(
        id: 'maintenance_records/seal',
        title: 'Draft seal restored',
        status: 'resolved',
      );
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [burner, seal],
        entries: [
          _entry(
            id: 'entry-current',
            kind: MorningReviewEntryKind.currentCompliance,
            text: 'Burner investigation is in progress.',
            references: [burner.factId],
          ),
          _entry(
            id: 'entry-resolved',
            kind: MorningReviewEntryKind.conclusion,
            text: 'Seal repair was verified yesterday.',
            references: [seal.factId],
          ),
        ],
      );

      expect(agenda.subjects, hasLength(1));
      expect(agenda.subjects.single.label, 'Furnace 7');
      expect(agenda.subjects.single.matters, hasLength(2));
      expect(
        agenda.subjects.single.matters.map((matter) => matter.title),
        containsAll(['Burner lockout', 'Draft seal restored']),
      );
      expect(agenda.countFor(MorningReviewAgendaFilter.open), 1);
      expect(agenda.countFor(MorningReviewAgendaFilter.resolved), 1);
    });

    test('keeps condition filters overlapping and explicit', () {
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [
          _fact(
            id: 'asset_operational_conditions/down',
            title: 'Base unavailable',
            status: 'down',
            section: MorningReviewSection.base,
            classId: 'base-class',
            className: 'Base',
            instanceId: 'base-113',
            number: '113',
          ),
          _fact(
            id: 'asset_availability_current/stuck',
            title: 'Furnace stuck-up',
            status: 'temporarilyBlocked',
          ),
        ],
        entries: const [],
      );

      expect(agenda.countFor(MorningReviewAgendaFilter.all), 2);
      expect(agenda.countFor(MorningReviewAgendaFilter.down), 1);
      expect(agenda.countFor(MorningReviewAgendaFilter.stuckUp), 1);
      expect(agenda.countFor(MorningReviewAgendaFilter.open), 2);
    });

    test('represents a cross-asset source discussion only once', () {
      final furnace = _fact(
        id: 'directives/furnace-crane',
        title: 'Crane constraint',
        status: 'open',
      );
      final base = _fact(
        id: 'operational_events/base-crane',
        title: 'Crane constraint',
        status: 'open',
        section: MorningReviewSection.base,
        classId: 'base-class',
        className: 'Base',
        instanceId: 'base-113',
        number: '113',
      );
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [furnace, base],
        entries: [
          _entry(
            id: 'shared-entry',
            kind: MorningReviewEntryKind.blocker,
            text: 'The same crane blocks both work fronts.',
            references: [furnace.factId, base.factId],
          ),
          _entry(
            id: 'follow-up-entry',
            kind: MorningReviewEntryKind.currentCompliance,
            text: 'The furnace workfront has been made safe.',
            references: [furnace.factId],
          ),
        ],
      );

      expect(agenda.subjects, hasLength(1));
      expect(agenda.subjects.single.isShared, isTrue);
      expect(agenda.subjects.single.section, MorningReviewSection.plantWide);
      expect(agenda.subjects.single.matters.single.sourceFacts, hasLength(2));
      expect(agenda.subjects.single.matters.single.entries, hasLength(2));
      expect(agenda.subjects.single.matters.single.linkedAssetLabels, [
        'Furnace 7',
        'Base 113',
      ]);
    });

    test('completion-looking prose cannot settle a carried action', () {
      final createdYesterday = DateTime.utc(2026, 9, 4, 3);
      final carriedAction = _fact(
        id: 'morning_review_actions/action-17',
        sourceType: 'carriedAction',
        title: 'Confirm spare Inner Cover',
        status: 'accepted',
        observedAt: createdYesterday,
      );
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [carriedAction],
        entries: [
          _entry(
            id: 'completed-today',
            kind: MorningReviewEntryKind.currentCompliance,
            text: 'Action action-17 completed: spare Inner Cover confirmed.',
            references: [carriedAction.factId],
          ),
        ],
      );

      final matter = agenda.subjects.single.matters.single;
      expect(matter.primaryFact?.factId, carriedAction.factId);
      expect(matter.primaryFact?.observedAt, createdYesterday);
      expect(matter.currentCompliance.single.entryId, 'completed-today');
      expect(matter.categories, contains(MorningReviewAgendaFilter.open));
      expect(
        matter.categories,
        isNot(contains(MorningReviewAgendaFilter.resolved)),
      );
    });

    test('does not treat an ordinary carried-action note as completion', () {
      final carriedAction = _fact(
        id: 'morning_review_actions/action-18',
        sourceType: 'carriedAction',
        title: 'Confirm burner inspection',
        status: 'accepted',
      );
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [carriedAction],
        entries: [
          _entry(
            id: 'progress-today',
            kind: MorningReviewEntryKind.currentCompliance,
            text: 'Inspection is continuing on the morning shift.',
            references: [carriedAction.factId],
          ),
        ],
      );

      final matter = agenda.subjects.single.matters.single;
      expect(matter.categories, contains(MorningReviewAgendaFilter.open));
      expect(
        matter.categories,
        isNot(contains(MorningReviewAgendaFilter.resolved)),
      );
    });

    test('a withdrawn-in-error alarm is not a technical resolution', () {
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [
          _fact(
            id: 'critical_alarms/withdrawn',
            title: 'Alarm withdrawn after verification',
            status: 'withdrawnInError',
            section: MorningReviewSection.safety,
          ),
        ],
        entries: const [],
      );

      expect(agenda.countFor(MorningReviewAgendaFilter.open), 0);
      expect(agenda.countFor(MorningReviewAgendaFilter.resolved), 0);
    });

    test('classifies native quality and inspection lifecycle states', () {
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [
          _fact(
            id: 'quality_warnings/requested',
            sourceType: 'qualityWarning',
            title: 'Quality warning',
            status: 'closureRequested',
            number: '7',
          ),
          _fact(
            id: 'inspection_findings/awaiting',
            sourceType: 'inspectionFinding',
            title: 'Inspection awaiting verification',
            status: 'awaitingVerification',
            instanceId: 'furnace-8',
            number: '8',
          ),
          _fact(
            id: 'inspection_findings/verified',
            sourceType: 'inspectionFinding',
            title: 'Inspection verified',
            status: 'verifiedResolved',
            instanceId: 'furnace-9',
            number: '9',
          ),
          _fact(
            id: 'inspection_findings/accepted',
            sourceType: 'inspectionFinding',
            title: 'Condition accepted',
            status: 'acceptedCondition',
            instanceId: 'furnace-10',
            number: '10',
          ),
        ],
        entries: const [],
      );

      expect(agenda.countFor(MorningReviewAgendaFilter.open), 2);
      expect(agenda.countFor(MorningReviewAgendaFilter.resolved), 1);
    });

    test(
      'validated server completion settles a carried action without matching prose',
      () {
        final fact = _fact(
          id: 'morning_review_actions/action-17',
          sourceType: 'carriedAction',
          title: 'Confirm spare Inner Cover',
          status: 'accepted',
        );
        final entry = MorningReviewEntry.fromMap({
          'schemaVersion': 1,
          'entryId': 'action-completed-v2-66666666-6666-4666-8666-666666666666',
          'sessionId': '2026-09-05',
          'plantDay': '2026-09-05',
          'section': 'furnace',
          'kind': 'currentCompliance',
          'text': 'The assigned follow-up was verified.',
          'assetClassId': 'furnace-class',
          'assetClassName': 'Furnace',
          'assetInstanceId': 'furnace-7',
          'assetNumber': '7',
          'sourceReferences': [fact.factId],
          'authorUid': 'operator-1',
          'authorName': 'Operator One',
          'authorRoleKeys': ['operations'],
          'createdAt': '2026-09-05T03:00:00.000Z',
          'addendumReason': null,
          'expiresAt': '2026-09-19T03:00:00.000Z',
        }, 'action-completed-v2-66666666-6666-4666-8666-666666666666');
        final agenda = compileMorningReviewAgenda(
          sourceFacts: [fact],
          entries: [entry],
        );
        expect(agenda.countFor(MorningReviewAgendaFilter.open), 0);
        expect(agenda.countFor(MorningReviewAgendaFilter.resolved), 1);
      },
    );

    test('issue condition is independent of its open lifecycle', () {
      final fact = MorningReviewSourceFact.fromMap({
        'factId': 'maintenance_records/unfit-issue',
        'section': 'furnace',
        'sourceType': 'maintenanceIssue:unfit',
        'sourceCollection': 'maintenance_records',
        'sourceDocumentId': 'unfit-issue',
        'title': 'Furnace requires repair',
        'summary': 'Independent Unfit contribution',
        'status': 'open',
        'assetClassId': 'furnace-class',
        'assetClassName': 'Furnace',
        'assetInstanceId': 'furnace-7',
        'assetNumber': '7',
        'observedAtIso': '2026-09-05T03:00:00.000Z',
      }, source: 'captured issue');
      final agenda = compileMorningReviewAgenda(
        sourceFacts: [fact],
        entries: const [],
      );
      expect(agenda.countFor(MorningReviewAgendaFilter.open), 1);
      expect(agenda.countFor(MorningReviewAgendaFilter.unfit), 1);
    });
  });
}

MorningReviewSourceFact _fact({
  required String id,
  String? sourceType,
  required String title,
  required String status,
  MorningReviewSection section = MorningReviewSection.furnace,
  String classId = 'furnace-class',
  String className = 'Furnace',
  String instanceId = 'furnace-7',
  String number = '7',
  DateTime? observedAt,
}) => MorningReviewSourceFact(
  factId: id,
  section: section,
  sourceType: sourceType ?? id.split('/').first,
  sourceCollection: id.split('/').first,
  sourceDocumentId: id.split('/').last,
  title: title,
  summary: '$title evidence',
  status: status,
  assetClassId: classId,
  assetClassName: className,
  assetInstanceId: instanceId,
  assetNumber: number,
  observedAt: observedAt ?? DateTime.utc(2026, 9, 5, 3),
);

MorningReviewEntry _entry({
  required String id,
  required MorningReviewEntryKind kind,
  required String text,
  required List<String> references,
}) => MorningReviewEntry(
  entryId: id,
  sessionId: '2026-09-05',
  section: MorningReviewSection.furnace,
  kind: kind,
  text: text,
  assetClassId: 'furnace-class',
  assetClassName: 'Furnace',
  assetInstanceId: 'furnace-7',
  assetNumber: '7',
  sourceReferences: references,
  authorUid: 'operator-1',
  authorName: 'Operator One',
  authorRoleKeys: const ['operations'],
  createdAt: DateTime.utc(2026, 9, 5, 3, 30),
  addendumReason: null,
);
