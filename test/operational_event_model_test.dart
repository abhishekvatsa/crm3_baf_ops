import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> record({
  String status = 'open',
  Object? resolvedAt,
  String? resolvedByUid,
  String? resolvedByName,
  String? resolutionNote,
}) => <String, dynamic>{
  'schemaVersion': 1,
  'eventId': 'event-1',
  'eventType': 'powerTrip',
  'title': 'Incoming power interruption',
  'description': 'Incoming power was unavailable across the shop.',
  'severity': 'critical',
  'scope': 'plantWide',
  'affectedAssetClassIds': <String>[],
  'affectedAssetInstanceIds': <String>[],
  'completedIntervals': <Map<String, dynamic>>[],
  'startedAt': DateTime.utc(2026, 8, 14, 10),
  'status': status,
  'createdAt': DateTime.utc(2026, 8, 14, 10, 5),
  'createdByUid': 'ops-1',
  'createdByName': 'Operations One',
  'resolvedAt': resolvedAt,
  'resolvedByUid': resolvedByUid,
  'resolvedByName': resolvedByName,
  'resolutionNote': resolutionNote,
  'version': 1,
  'updatedAt': DateTime.utc(2026, 8, 14, 10, 5),
  'updatedByUid': 'ops-1',
  'updatedByName': 'Operations One',
  'lastMutationId': 'request-1',
};

void main() {
  test('command timestamps are normalized to UTC milliseconds', () {
    final draft = OperationalEventDraft(
      eventType: OperationalEventType.water,
      title: 'Cooling-water pressure variation',
      description: 'Pressure varied during the active operating cycle.',
      severity: OperationalEventSeverity.significant,
      scope: OperationalEventScope.plantWide,
      affectedAssetClassIds: const [],
      affectedAssetInstanceIds: const [],
      startedAt: DateTime.utc(2026, 8, 14, 10, 0, 0, 123, 456),
    );

    expect(draft.toCommandMap()['startedAt'], '2026-08-14T10:00:00.123Z');
  });

  test('resolved history disclosure states the bounded source window', () {
    expect(
      operationalEventResolvedHistoryDisclosure,
      contains('$operationalEventLiveWindowLimit'),
    );
    expect(operationalEventResolvedHistoryDisclosure, contains('resolved'));
  });

  test('strictly decodes a complete open operational event', () {
    final event = OperationalEvent.fromMap(record(), 'event-1');
    expect(event.isOpen, isTrue);
    expect(event.eventType, OperationalEventType.powerTrip);
    expect(event.durationUntil(DateTime.utc(2026, 8, 14, 12)).inHours, 2);
  });

  test('requires complete scope arrays', () {
    final malformed = record()..remove('affectedAssetClassIds');
    expect(
      () => OperationalEvent.fromMap(malformed, 'event-1'),
      throwsFormatException,
    );
    for (final field in [
      'affectedAssetClassIds',
      'affectedAssetInstanceIds',
      'completedIntervals',
    ]) {
      expect(
        () => OperationalEvent.fromMap(record()..[field] = null, 'event-1'),
        throwsFormatException,
      );
    }
  });

  test('rejects partial resolution evidence', () {
    expect(
      () => OperationalEvent.fromMap(
        record(status: 'resolved', resolvedAt: DateTime.utc(2026, 8, 14, 11)),
        'event-1',
      ),
      throwsFormatException,
    );
  });

  test('requires complete closure evidence for every prior occurrence', () {
    final malformed =
        record()
          ..['completedIntervals'] = [
            {
              'startedAt': DateTime.utc(2026, 8, 14, 8),
              'resolvedAt': DateTime.utc(2026, 8, 14, 9),
              'scope': 'plantWide',
              'affectedAssetClassIds': <String>[],
              'affectedAssetInstanceIds': <String>[],
            },
          ];
    expect(
      () => OperationalEvent.fromMap(malformed, 'event-1'),
      throwsFormatException,
    );
  });

  test('decodes complete resolved evidence', () {
    final event = OperationalEvent.fromMap(
      record(
        status: 'resolved',
        resolvedAt: DateTime.utc(2026, 8, 14, 11),
        resolvedByUid: 'shift-1',
        resolvedByName: 'Shift One',
        resolutionNote: 'Supply remained stable after restoration checks.',
      ),
      'event-1',
    );
    expect(event.status, OperationalEventStatus.resolved);
    expect(event.durationUntil(DateTime.utc(2026, 8, 15)).inHours, 1);
  });

  test('clips event duration to the selected report interval', () {
    final event = OperationalEvent.fromMap(
      record(
        status: 'resolved',
        resolvedAt: DateTime.utc(2026, 8, 14, 11),
        resolvedByUid: 'shift-1',
        resolvedByName: 'Shift One',
        resolutionNote: 'Supply remained stable after restoration checks.',
      ),
      'event-1',
    );
    expect(
      event
          .durationWithin(
            DateTime.utc(2026, 8, 14, 10, 30),
            DateTime.utc(2026, 8, 14, 10, 45),
            DateTime.utc(2026, 8, 14, 12),
          )
          .inMinutes,
      15,
    );
  });

  test('keeps reopened disruption occurrences separate', () {
    final recurring =
        record(
            status: 'resolved',
            resolvedAt: DateTime.utc(2026, 8, 14, 14),
            resolvedByUid: 'shift-1',
            resolvedByName: 'Shift One',
            resolutionNote:
                'Supply remained stable after the second restoration.',
          )
          ..['startedAt'] = DateTime.utc(2026, 8, 14, 13)
          ..['completedIntervals'] = [
            {
              'startedAt': DateTime.utc(2026, 8, 14, 10),
              'resolvedAt': DateTime.utc(2026, 8, 14, 12),
              'scope': 'plantWide',
              'affectedAssetClassIds': <String>[],
              'affectedAssetInstanceIds': <String>[],
              'resolvedByUid': 'shift-1',
              'resolvedByName': 'Shift One',
              'resolutionNote':
                  'Supply remained stable after the first restoration.',
            },
          ];
    final event = OperationalEvent.fromMap(recurring, 'event-1');
    final start = DateTime.utc(2026, 8, 14, 9);
    final end = DateTime.utc(2026, 8, 14, 15);

    expect(event.occurrenceCountWithin(start, end, end), 2);
    expect(event.durationWithin(start, end, end), const Duration(hours: 3));
    expect(event.completedIntervals.single.resolvedByName, 'Shift One');
    expect(
      event.completedIntervals.single.resolutionNote,
      'Supply remained stable after the first restoration.',
    );
  });

  test(
    'open-event window preserves old active events and removes duplicates',
    () {
      final open = OperationalEvent.fromMap(record(), 'event-1');
      final resolved = OperationalEvent.fromMap(
        record(
          status: 'resolved',
          resolvedAt: DateTime.utc(2026, 8, 14, 11),
          resolvedByUid: 'shift-1',
          resolvedByName: 'Shift One',
          resolutionNote: 'Supply remained stable after restoration checks.',
        )..['eventId'] = 'event-2',
        'event-2',
      );
      final merged = mergeOperationalEventWindows([open], [resolved, open]);
      expect(merged.map((event) => event.eventId), ['event-1', 'event-2']);
    },
  );
}
