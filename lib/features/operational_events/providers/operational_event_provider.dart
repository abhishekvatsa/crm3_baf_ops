import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/operational_event.dart';
import '../services/operational_event_service.dart';

const operationalEventLiveWindowLimit = 500;

final operationalEventServiceProvider = Provider<OperationalEventService>(
  (ref) => OperationalEventService(),
);

final operationalEventsProvider = StreamProvider<List<OperationalEvent>>((ref) {
  return FirebaseFirestore.instance
      .collection('operational_events')
      .orderBy('updatedAt', descending: true)
      .limit(operationalEventLiveWindowLimit)
      .snapshots()
      .map((snapshot) {
        final events =
            snapshot.docs
                .map((doc) => OperationalEvent.fromMap(doc.data(), doc.id))
                .toList();
        events.sort((left, right) {
          if (left.isOpen != right.isOpen) return left.isOpen ? -1 : 1;
          final severity = right.severity.index.compareTo(left.severity.index);
          if (severity != 0) return severity;
          return right.startedAt.compareTo(left.startedAt);
        });
        return List<OperationalEvent>.unmodifiable(events);
      });
});
