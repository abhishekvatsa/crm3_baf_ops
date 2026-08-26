import 'package:cloud_firestore/cloud_firestore.dart';

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
}
