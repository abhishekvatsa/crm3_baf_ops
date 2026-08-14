import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
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
}
