import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
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

typedef OperationalEventIssueLinkScope = ({String actorUid, String eventId});
typedef OperationalIssueEventLinkScope = ({String actorUid, String issueId});

final operationalEventCacheTrustProvider = Provider<ActorSessionCacheTrust>((
  ref,
) {
  final trust = ActorSessionCacheTrust();

  void observeAuthority(AsyncValue<AppUser?> authority) {
    if (authority.isLoading || authority.hasError) {
      trust.observeActor(null);
      return;
    }
    final actor = authority.value;
    trust.observeActor(actor != null && actor.isApproved ? actor.uid : null);
  }

  observeAuthority(ref.read(currentAppUserProvider));
  ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (_, next) {
    observeAuthority(next);
  });
  return trust;
});

final operationalEventIssueLinksProvider = StreamProvider.autoDispose
    .family<List<OperationalEventIssueLink>, OperationalEventIssueLinkScope>((
      ref,
      scope,
    ) {
      _requireActorUid(scope.actorUid);
      return admitActorSessionSnapshots(
        FirebaseFirestore.instance
            .collection('operational_event_issue_links')
            .where('eventId', isEqualTo: scope.eventId)
            .snapshots(includeMetadataChanges: true),
        trust: ref.watch(operationalEventCacheTrustProvider),
        actorUid: scope.actorUid,
        queryKey: 'event-links:event:${scope.eventId}',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
      ).map(_decodeOperationalEventIssueLinks);
    });

final operationalIssueEventLinksProvider = StreamProvider.autoDispose
    .family<List<OperationalEventIssueLink>, OperationalIssueEventLinkScope>((
      ref,
      scope,
    ) {
      _requireActorUid(scope.actorUid);
      return admitActorSessionSnapshots(
        FirebaseFirestore.instance
            .collection('operational_event_issue_links')
            .where('issueId', isEqualTo: scope.issueId)
            .snapshots(includeMetadataChanges: true),
        trust: ref.watch(operationalEventCacheTrustProvider),
        actorUid: scope.actorUid,
        queryKey: 'event-links:issue:${scope.issueId}',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
      ).map(_decodeOperationalEventIssueLinks);
    });

List<OperationalEventIssueLink> _decodeOperationalEventIssueLinks(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) {
  final links = snapshot.docs
      .map((doc) => OperationalEventIssueLink.fromMap(doc.data(), doc.id))
      .toList(growable: false);
  return sortOperationalEventIssueLinks(links);
}

List<OperationalEventIssueLink> sortOperationalEventIssueLinks(
  Iterable<OperationalEventIssueLink> source,
) {
  final links = source.toList();
  links.sort((left, right) => right.linkedAt.compareTo(left.linkedAt));
  return List<OperationalEventIssueLink>.unmodifiable(links);
}

final operationalEventsProvider = StreamProvider.autoDispose
    .family<List<OperationalEvent>, String>((ref, actorUid) {
      _requireActorUid(actorUid);
      final cacheTrust = ref.watch(operationalEventCacheTrustProvider);
      final events = FirebaseFirestore.instance.collection(
        'operational_events',
      );
      final open = admitActorSessionSnapshots(
        events
            .where('status', isEqualTo: OperationalEventStatus.open.name)
            .snapshots(includeMetadataChanges: true),
        trust: cacheTrust,
        actorUid: actorUid,
        queryKey: 'events:open',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
      ).map(_decodeOperationalEvents);
      final recent = admitActorSessionSnapshots(
        events
            .orderBy('updatedAt', descending: true)
            .limit(operationalEventLiveWindowLimit)
            .snapshots(includeMetadataChanges: true),
        trust: cacheTrust,
        actorUid: actorUid,
        queryKey: 'events:recent',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
      ).map(_decodeOperationalEvents);
      return _combineOperationalEventWindows(open, recent);
    });

void _requireActorUid(String actorUid) {
  if (actorUid.trim().isEmpty) {
    throw StateError('An approved actor UID is required for event reads.');
  }
}

/// Complete event-document history for date-bound operational reports.
///
/// Completed recurrence intervals remain embedded in their parent event, so a
/// server-side date predicate cannot prove complete historical coverage until
/// occurrence projections are introduced. The interactive event list keeps
/// its bounded window; reports deliberately read every event document.
final operationalEventsForReportsProvider = StreamProvider.autoDispose
    .family<List<OperationalEvent>, String>((ref, actorUid) {
      _requireActorUid(actorUid);
      return admitActorSessionSnapshots(
        FirebaseFirestore.instance
            .collection('operational_events')
            .snapshots(includeMetadataChanges: true),
        trust: ref.watch(operationalEventCacheTrustProvider),
        actorUid: actorUid,
        queryKey: 'events:reports',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
      ).map(_decodeOperationalEvents);
    });

@visibleForTesting
final class ActorSessionCacheTrust {
  String? _actorUid;
  final Set<String> _serverConfirmedQueries = <String>{};

  void observeActor(String? actorUid) {
    final normalized = actorUid?.trim();
    final nextActor =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (nextActor == _actorUid) return;
    _actorUid = nextActor;
    _serverConfirmedQueries.clear();
  }

  bool acceptSnapshot({
    required String actorUid,
    required String queryKey,
    required bool isFromCache,
  }) {
    final normalizedActor = actorUid.trim();
    final normalizedQuery = queryKey.trim();
    if (normalizedActor.isEmpty ||
        normalizedQuery.isEmpty ||
        normalizedActor != _actorUid) {
      return false;
    }
    if (!isFromCache) {
      _serverConfirmedQueries.add(normalizedQuery);
      return true;
    }
    return _serverConfirmedQueries.contains(normalizedQuery);
  }
}

@visibleForTesting
Stream<T> admitActorSessionSnapshots<T>(
  Stream<T> snapshots, {
  required ActorSessionCacheTrust trust,
  required String actorUid,
  required String queryKey,
  required bool Function(T snapshot) isFromCache,
}) {
  return snapshots.where(
    (snapshot) => trust.acceptSnapshot(
      actorUid: actorUid,
      queryKey: queryKey,
      isFromCache: isFromCache(snapshot),
    ),
  );
}

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
