import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../domain/critical_alarm_models.dart';

class CriticalAlarmRepository {
  const CriticalAlarmRepository(this.firestore);

  final FirebaseFirestore firestore;

  Stream<List<CriticalAlarm>> watchActiveAlarms() async* {
    await for (final snapshot in firestore
        .collection('critical_alarms')
        .where('status', whereIn: const ['raised', 'supportConfirmed'])
        .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
      yield List.unmodifiable(
        snapshot.docs.map(
          (document) =>
              CriticalAlarm.fromFirestore(document.data(), document.id),
        ),
      );
    }
  }

  Stream<List<CriticalAlarm>> watchAlarms() async* {
    await for (final snapshot in firestore
        .collection('critical_alarms')
        .orderBy('raisedAt', descending: true)
        .limit(250)
        .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
      yield List.unmodifiable(
        snapshot.docs.map(
          (document) =>
              CriticalAlarm.fromFirestore(document.data(), document.id),
        ),
      );
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
      final alarms = snapshot.docs
          .map(
            (document) =>
                CriticalAlarm.fromFirestore(document.data(), document.id),
          )
          .toList(growable: false)
        ..sort((left, right) => right.raisedAt.compareTo(left.raisedAt));
      return List.unmodifiable(alarms);
    });
  }

  Stream<List<CriticalAlarmContact>> watchContacts() async* {
    await for (final snapshot in firestore
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
    await for (final snapshot in firestore
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
