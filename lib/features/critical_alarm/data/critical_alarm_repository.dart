import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../domain/critical_alarm_models.dart';

class _AlarmDecodeResult {
  const _AlarmDecodeResult({
    required this.alarms,
    required this.malformedDocumentCount,
  });

  final List<CriticalAlarm> alarms;
  final int malformedDocumentCount;
  bool get hasMalformed => malformedDocumentCount > 0;
}

class CriticalAlarmFeedIncompleteException implements Exception {
  const CriticalAlarmFeedIncompleteException({
    required this.malformedDocumentCount,
  });

  final int malformedDocumentCount;

  @override
  String toString() =>
      'Critical alarm feed is incomplete: '
      '$malformedDocumentCount malformed document(s) could not be read.';
}

_AlarmDecodeResult _decodeAlarms(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
) {
  final alarms = <CriticalAlarm>[];
  var malformedDocumentCount = 0;
  for (final document in documents) {
    try {
      alarms.add(CriticalAlarm.fromFirestore(document.data(), document.id));
    } on Object {
      // A single damaged document must not terminate the live safety feed.
      // The caller treats the whole snapshot as unverified so the malformed
      // row cannot be mistaken for an empty active set.
      malformedDocumentCount += 1;
    }
  }
  return _AlarmDecodeResult(
    alarms: List.unmodifiable(alarms),
    malformedDocumentCount: malformedDocumentCount,
  );
}

class CriticalAlarmRepository {
  const CriticalAlarmRepository(this.firestore);

  final FirebaseFirestore firestore;

  Stream<CriticalAlarmLiveSnapshot> watchActiveAlarms() async* {
    List<CriticalAlarm> lastVerifiedAlarms = const <CriticalAlarm>[];
    DateTime? lastVerifiedAt;
    await for (final snapshot
        in firestore
            .collection('critical_alarms')
            .where('status', whereIn: const ['raised', 'supportConfirmed'])
            .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        yield lastVerifiedAt == null
            ? CriticalAlarmLiveSnapshot.unavailable()
            : CriticalAlarmLiveSnapshot.staleLastKnown(
                alarms: lastVerifiedAlarms,
                lastVerifiedAt: lastVerifiedAt,
              );
        continue;
      }
      final decoded = _decodeAlarms(snapshot.docs);
      if (decoded.hasMalformed) {
        // Keep valid new alarms visible, but mark the whole snapshot as
        // unverified. Replacing it with an older verified set hides newly
        // raised alarms and can make an operator act on the wrong picture.
        yield CriticalAlarmLiveSnapshot.partiallyVerified(
          alarms: decoded.alarms,
          malformedDocumentCount: decoded.malformedDocumentCount,
          lastVerifiedAt: lastVerifiedAt,
        );
        continue;
      }
      lastVerifiedAlarms = decoded.alarms;
      lastVerifiedAt = DateTime.now().toUtc();
      yield CriticalAlarmLiveSnapshot.serverVerified(
        alarms: lastVerifiedAlarms,
        verifiedAt: lastVerifiedAt,
      );
    }
  }

  Stream<List<CriticalAlarm>> watchAlarms() async* {
    await for (final snapshot
        in firestore
            .collection('critical_alarms')
            .orderBy('raisedAt', descending: true)
            .limit(250)
            .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
      final decoded = _decodeAlarms(snapshot.docs);
      if (decoded.hasMalformed) {
        throw CriticalAlarmFeedIncompleteException(
          malformedDocumentCount: decoded.malformedDocumentCount,
        );
      }
      yield decoded.alarms;
    }
  }

  /// Complete alarm population for explicit period-bound reporting.
  ///
  /// The operational alarm feed remains capped for screen performance. A
  /// report must not silently inherit that cap.
  Stream<List<CriticalAlarm>> watchAlarmsForReports({
    required ActorSessionCacheTrust trust,
    required String actorUid,
  }) {
    final snapshots = firestore
        .collection('critical_alarms')
        .snapshots(includeMetadataChanges: true);
    return admitActorSessionSnapshots(
      snapshots,
      trust: trust,
      actorUid: actorUid,
      queryKey: 'critical-alarms:reports',
      isFromCache: (snapshot) => snapshot.metadata.isFromCache,
      hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
    ).map((snapshot) {
      final decoded = _decodeAlarms(snapshot.docs);
      if (decoded.hasMalformed) {
        throw CriticalAlarmFeedIncompleteException(
          malformedDocumentCount: decoded.malformedDocumentCount,
        );
      }
      final alarms = decoded.alarms.toList(growable: false)
        ..sort((left, right) => right.raisedAt.compareTo(left.raisedAt));
      return List.unmodifiable(alarms);
    });
  }

  Stream<List<CriticalAlarmContact>> watchContacts() async* {
    await for (final snapshot
        in firestore
            .collection('critical_alarm_contacts')
            .orderBy('priority')
            .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
      yield List.unmodifiable(
        snapshot.docs.map(
          (document) =>
              CriticalAlarmContact.fromFirestore(document.data(), document.id),
        ),
      );
    }
  }

  Stream<List<CriticalAlarmDefinition>> watchDefinitions() async* {
    await for (final snapshot
        in firestore
            .collection('critical_alarm_definitions')
            .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
      final overrides = snapshot.docs.map(
        (document) =>
            CriticalAlarmDefinition.fromFirestore(document.data(), document.id),
      );
      yield CriticalAlarmDefinition.mergeOverrides(overrides);
    }
  }
}
