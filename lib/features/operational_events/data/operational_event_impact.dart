import 'operational_event.dart';

class OperationalEventImpactSummary {
  const OperationalEventImpactSummary({
    required this.startInclusive,
    required this.endExclusive,
    required this.topic,
    required this.eventCount,
    required this.occurrenceCount,
    required this.cumulativeDuration,
    required this.leadingType,
    required this.leadingTypeDuration,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;
  final OperationalEventType? topic;
  final int eventCount;
  final int occurrenceCount;
  final Duration cumulativeDuration;
  final OperationalEventType? leadingType;
  final Duration leadingTypeDuration;
}

OperationalEventImpactSummary summarizeOperationalEventImpact({
  required Iterable<OperationalEvent> events,
  required DateTime month,
  required DateTime asOf,
  OperationalEventType? topic,
}) {
  final startInclusive = _monthBoundary(month);
  final nextMonth = _monthBoundary(month, offset: 1);
  final endExclusive = asOf.isBefore(nextMonth) ? asOf : nextMonth;
  if (!endExclusive.isAfter(startInclusive)) {
    return OperationalEventImpactSummary(
      startInclusive: startInclusive,
      endExclusive: startInclusive,
      topic: topic,
      eventCount: 0,
      occurrenceCount: 0,
      cumulativeDuration: Duration.zero,
      leadingType: null,
      leadingTypeDuration: Duration.zero,
    );
  }

  final matchingEventIds = <String>{};
  final durationByType = <OperationalEventType, Duration>{};
  var occurrenceCount = 0;
  var cumulativeDuration = Duration.zero;

  for (final event in events) {
    for (final occurrence in event.occurrencesUntil(asOf)) {
      if (topic != null && occurrence.eventType != topic) continue;
      if (!occurrence.overlaps(startInclusive, endExclusive)) continue;

      final duration = occurrence.durationWithin(startInclusive, endExclusive);
      matchingEventIds.add(event.eventId);
      occurrenceCount++;
      cumulativeDuration += duration;
      durationByType.update(
        occurrence.eventType,
        (current) => current + duration,
        ifAbsent: () => duration,
      );
    }
  }

  OperationalEventType? leadingType;
  var leadingTypeDuration = Duration.zero;
  for (final candidate in OperationalEventType.values) {
    final duration = durationByType[candidate];
    if (duration == null) continue;
    if (leadingType == null || duration > leadingTypeDuration) {
      leadingType = candidate;
      leadingTypeDuration = duration;
    }
  }

  return OperationalEventImpactSummary(
    startInclusive: startInclusive,
    endExclusive: endExclusive,
    topic: topic,
    eventCount: matchingEventIds.length,
    occurrenceCount: occurrenceCount,
    cumulativeDuration: cumulativeDuration,
    leadingType: leadingType,
    leadingTypeDuration: leadingTypeDuration,
  );
}

DateTime _monthBoundary(DateTime value, {int offset = 0}) =>
    value.isUtc
        ? DateTime.utc(value.year, value.month + offset)
        : DateTime(value.year, value.month + offset);
