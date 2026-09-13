import 'package:cloud_firestore/cloud_firestore.dart';

/// This immutable audit boundary preserves every supported microsecond. It
/// deliberately refuses nanosecond evidence Dart cannot represent exactly.
DateTime readWorkflowReopenTimestamp(Object? value) {
  if (value is DateTime) return value.toUtc();
  int? seconds;
  int? nanos;
  if (value is Timestamp) {
    seconds = value.seconds;
    nanos = value.nanoseconds;
  } else if (value is Map && value.length == 2) {
    final private =
        value.containsKey('_seconds') && value.containsKey('_nanoseconds');
    final public =
        value.containsKey('seconds') && value.containsKey('nanoseconds');
    if (private != public) {
      final rawSeconds = value[private ? '_seconds' : 'seconds'];
      final rawNanos = value[private ? '_nanoseconds' : 'nanoseconds'];
      if (rawSeconds is int && rawNanos is int) {
        seconds = rawSeconds;
        nanos = rawNanos;
      }
    }
  }
  if (seconds != null &&
      nanos != null &&
      seconds >= -62135596800 &&
      seconds <= 253402300799 &&
      nanos >= 0 &&
      nanos < 1000000000 &&
      nanos % 1000 == 0) {
    return DateTime.fromMicrosecondsSinceEpoch(
      seconds * Duration.microsecondsPerSecond + nanos ~/ 1000,
      isUtc: true,
    );
  }
  if (value is String) {
    // Native Dart snapshots historically contain local or UTC ISO strings;
    // server snapshots use UTC. Accept their exact calendar values only.
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{3}|\d{6}))?(Z)?$',
    ).firstMatch(value);
    if (match != null) {
      final parts = [for (var i = 1; i <= 6; i++) int.parse(match[i]!)];
      final micros = int.parse((match[7] ?? '').padRight(6, '0'));
      final date = match[8] == 'Z'
          ? DateTime.utc(
              parts[0],
              parts[1],
              parts[2],
              parts[3],
              parts[4],
              parts[5],
              micros ~/ 1000,
              micros % 1000,
            )
          : DateTime(
              parts[0],
              parts[1],
              parts[2],
              parts[3],
              parts[4],
              parts[5],
              micros ~/ 1000,
              micros % 1000,
            );
      if (date.year == parts[0] &&
          date.month == parts[1] &&
          date.day == parts[2] &&
          date.hour == parts[3] &&
          date.minute == parts[4] &&
          date.second == parts[5]) {
        return date.toUtc();
      }
    }
  }
  throw StateError(
    'Reopen timestamp evidence is malformed or has unsupported precision. The accepted receipt is retained.',
  );
}

/// Normalize only typed module timestamps on a copy after the original audit
/// before/after equality check. Never rewrite its saved JSON or other values.
Map<String, dynamic> workflowReopenModuleSnapshot(Map<String, dynamic> raw) => {
  ...raw,
  for (final key in const [
    'createdAt',
    'updatedAt',
    'addedAt',
    'submittedAt',
    'acceptedAt',
    'reopenedAt',
    'notApplicableAt',
    'deletedAt',
  ])
    if (raw[key] != null) key: readWorkflowReopenTimestamp(raw[key]),
};
