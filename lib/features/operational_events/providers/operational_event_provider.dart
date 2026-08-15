import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/operational_event.dart';
import '../data/operational_event_issue_link.dart';
import '../services/operational_event_issue_link_service.dart';
import '../services/operational_event_service.dart';

const operationalEventLiveWindowLimit = 500;
const operationalEventResolvedHistoryDisclosure =
    'Showing up to $operationalEventLiveWindowLimit most recently updated '
    'events. Older resolved events may not be shown.';

final operationalEventServiceProvider = Provider<OperationalEventService>(
  (ref) => OperationalEventService(),
);

final operationalEventIssueLinkServiceProvider =
    Provider<OperationalEventIssueLinkService>(
      (ref) => OperationalEventIssueLinkService(),
    );

final operationalEventIssueLinksProvider =
    StreamProvider.family<List<OperationalEventIssueLink>, String>((
      ref,
      eventId,
    ) {
      return FirebaseFirestore.instance
          .collection('operational_event_issue_links')
          .where('eventId', isEqualTo: eventId)
          .snapshots()
          .map(_decodeOperationalEventIssueLinks);
    });

final operationalIssueEventLinksProvider =
    StreamProvider.family<List<OperationalEventIssueLink>, String>((
      ref,
      issueId,
    ) {
      return FirebaseFirestore.instance
          .collection('operational_event_issue_links')
          .where('issueId', isEqualTo: issueId)
          .limit(50)
          .snapshots()
          .map(_decodeOperationalEventIssueLinks);
    });

List<OperationalEventIssueLink> _decodeOperationalEventIssueLinks(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final links = snapshot.docs
      .map((doc) => OperationalEventIssueLink.fromMap(doc.data(), doc.id))
      .toList(growable: false);
  links.sort((left, right) => right.linkedAt.compareTo(left.linkedAt));
  return List<OperationalEventIssueLink>.unmodifiable(links);
}

final operationalEventsProvider = StreamProvider<List<OperationalEvent>>((ref) {
  final events = FirebaseFirestore.instance.collection('operational_events');
  final open = events
      .where('status', isEqualTo: OperationalEventStatus.open.name)
      .snapshots()
      .map(_decodeOperationalEvents);
  final recent = events
      .orderBy('updatedAt', descending: true)
      .limit(operationalEventLiveWindowLimit)
      .snapshots()
      .map(_decodeOperationalEvents);
  return _combineOperationalEventWindows(open, recent);
});

/// Complete event-document history for date-bound operational reports.
///
/// Completed recurrence intervals remain embedded in their parent event, so a
/// server-side date predicate cannot prove complete historical coverage until
/// occurrence projections are introduced. The interactive event list keeps
/// its bounded window; reports deliberately read every event document.
final operationalEventsForReportsProvider =
    StreamProvider<List<OperationalEvent>>((ref) {
      return FirebaseFirestore.instance
          .collection('operational_events')
          .snapshots()
          .map(_decodeOperationalEvents);
    });

List<OperationalEvent> _decodeOperationalEvents(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) => snapshot.docs
    .map((doc) => OperationalEvent.fromMap(doc.data(), doc.id))
    .toList(growable: false);

List<OperationalEvent> mergeOperationalEventWindows(
  List<OperationalEvent> open,
  List<OperationalEvent> recent,
) {
  final byId = <String, OperationalEvent>{
    for (final event in recent) event.eventId: event,
    for (final event in open) event.eventId: event,
  };
  final events = byId.values.toList();
  events.sort((left, right) {
    if (left.isOpen != right.isOpen) return left.isOpen ? -1 : 1;
    final severity = right.severity.index.compareTo(left.severity.index);
    if (severity != 0) return severity;
    return right.startedAt.compareTo(left.startedAt);
  });
  return List<OperationalEvent>.unmodifiable(events);
}

Stream<List<OperationalEvent>> _combineOperationalEventWindows(
  Stream<List<OperationalEvent>> open,
  Stream<List<OperationalEvent>> recent,
) {
  late StreamController<List<OperationalEvent>> controller;
  StreamSubscription<List<OperationalEvent>>? openSubscription;
  StreamSubscription<List<OperationalEvent>>? recentSubscription;
  List<OperationalEvent>? latestOpen;
  List<OperationalEvent>? latestRecent;

  void emitWhenReady() {
    if (latestOpen == null || latestRecent == null) return;
    controller.add(mergeOperationalEventWindows(latestOpen!, latestRecent!));
  }

  controller = StreamController<List<OperationalEvent>>(
    onListen: () {
      openSubscription = open.listen((value) {
        latestOpen = value;
        emitWhenReady();
      }, onError: controller.addError);
      recentSubscription = recent.listen((value) {
        latestRecent = value;
        emitWhenReady();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await openSubscription?.cancel();
      await recentSubscription?.cancel();
    },
  );
  return controller.stream;
}
