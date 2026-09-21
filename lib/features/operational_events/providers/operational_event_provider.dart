import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/operational_event.dart';
import '../data/operational_event_issue_link.dart';
import '../services/operational_event_issue_link_service.dart';
import '../services/operational_event_service.dart';

final operationalEventFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

const operationalEventLiveWindowLimit = 500;
const operationalEventResolvedHistoryDisclosure =
    'Showing up to $operationalEventLiveWindowLimit most recently updated '
    'events. Older resolved events may not be shown.';

class OperationalEventFeedDiagnostics {
  const OperationalEventFeedDiagnostics({
    this.openMalformedDocumentIds = const <String>{},
    this.recentMalformedDocumentIds = const <String>{},
  });

  final Set<String> openMalformedDocumentIds;
  final Set<String> recentMalformedDocumentIds;

  int get malformedDocumentCount =>
      {...openMalformedDocumentIds, ...recentMalformedDocumentIds}.length;

  bool get isIncomplete => malformedDocumentCount > 0;

  OperationalEventFeedDiagnostics withOpenMalformed(
    Iterable<String> documentIds,
  ) => OperationalEventFeedDiagnostics(
    openMalformedDocumentIds: Set.unmodifiable(documentIds),
    recentMalformedDocumentIds: recentMalformedDocumentIds,
  );

  OperationalEventFeedDiagnostics withRecentMalformed(
    Iterable<String> documentIds,
  ) => OperationalEventFeedDiagnostics(
    openMalformedDocumentIds: openMalformedDocumentIds,
    recentMalformedDocumentIds: Set.unmodifiable(documentIds),
  );
}

final operationalEventFeedDiagnosticsProvider =
    StateProvider.family<OperationalEventFeedDiagnostics, String>(
      (ref, _) => const OperationalEventFeedDiagnostics(),
    );

final operationalEventServiceProvider = Provider<OperationalEventService>(
  (ref) => OperationalEventService(
    actorUidResolver: () {
      final authority = ref.read(currentAppUserProvider);
      if (authority.isLoading || authority.hasError) return null;
      final actor = authority.value;
      return actor != null && actor.isApproved ? actor.uid : null;
    },
  ),
);

final operationalEventIssueLinkServiceProvider =
    Provider<OperationalEventIssueLinkService>(
      (ref) => OperationalEventIssueLinkService(),
    );

typedef OperationalEventIssueLinkScope = ({String actorUid, String eventId});
typedef OperationalIssueEventLinkScope = ({String actorUid, String issueId});

class OperationalEventIssueLinkFeedDiagnostics {
  const OperationalEventIssueLinkFeedDiagnostics({
    this.malformedDocumentIds = const <String>{},
  });

  final Set<String> malformedDocumentIds;

  bool get isIncomplete => malformedDocumentIds.isNotEmpty;

  OperationalEventIssueLinkFeedDiagnostics withMalformed(
    Iterable<String> documentIds,
  ) => OperationalEventIssueLinkFeedDiagnostics(
    malformedDocumentIds: Set.unmodifiable(documentIds),
  );
}

final operationalEventIssueLinkFeedDiagnosticsProvider =
    StateProvider.family<OperationalEventIssueLinkFeedDiagnostics, String>(
      (ref, _) => const OperationalEventIssueLinkFeedDiagnostics(),
    );

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
        ref
            .watch(operationalEventFirestoreProvider)
            .collection('operational_event_issue_links')
            .where('eventId', isEqualTo: scope.eventId)
            .snapshots(includeMetadataChanges: true),
        trust: ref.watch(operationalEventCacheTrustProvider),
        actorUid: scope.actorUid,
        queryKey: 'event-links:event:${scope.eventId}',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(
        (snapshot) => _decodeOperationalEventIssueLinksForLive(
          snapshot,
          source: 'operational-event issue links',
          onMalformed: (documentIds) {
            ref
                .read(
                  operationalEventIssueLinkFeedDiagnosticsProvider(
                    'event:${scope.eventId}',
                  ).notifier,
                )
                .state = OperationalEventIssueLinkFeedDiagnostics(
              malformedDocumentIds: Set.unmodifiable(documentIds),
            );
          },
        ),
      );
    });

final operationalIssueEventLinksProvider = StreamProvider.autoDispose
    .family<List<OperationalEventIssueLink>, OperationalIssueEventLinkScope>((
      ref,
      scope,
    ) {
      _requireActorUid(scope.actorUid);
      return admitActorSessionSnapshots(
        ref
            .watch(operationalEventFirestoreProvider)
            .collection('operational_event_issue_links')
            .where('issueId', isEqualTo: scope.issueId)
            .snapshots(includeMetadataChanges: true),
        trust: ref.watch(operationalEventCacheTrustProvider),
        actorUid: scope.actorUid,
        queryKey: 'event-links:issue:${scope.issueId}',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(
        (snapshot) => _decodeOperationalEventIssueLinksForLive(
          snapshot,
          source: 'operational-issue event links',
          onMalformed: (documentIds) {
            ref
                .read(
                  operationalEventIssueLinkFeedDiagnosticsProvider(
                    'issue:${scope.issueId}',
                  ).notifier,
                )
                .state = OperationalEventIssueLinkFeedDiagnostics(
              malformedDocumentIds: Set.unmodifiable(documentIds),
            );
          },
        ),
      );
    });

List<OperationalEventIssueLink> _decodeOperationalEventIssueLinksForLive(
  QuerySnapshot<Map<String, dynamic>> snapshot, {
  required String source,
  required void Function(Iterable<String> documentIds) onMalformed,
}) {
  final decoded = decodeSnapshotBatch(
    snapshot,
    (data, id) => OperationalEventIssueLink.fromMap(data, id),
    source: source,
  );
  onMalformed(decoded.rejectedDocumentIds);
  return sortOperationalEventIssueLinks(decoded.records);
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
      final events = ref
          .watch(operationalEventFirestoreProvider)
          .collection('operational_events');
      final open =
          admitActorSessionSnapshots(
                events
                    .where(
                      'status',
                      isEqualTo: OperationalEventStatus.open.name,
                    )
                    .snapshots(includeMetadataChanges: true),
                trust: cacheTrust,
                actorUid: actorUid,
                queryKey: 'events:open',
                isFromCache: (snapshot) => snapshot.metadata.isFromCache,
                hasPendingWrites: (snapshot) =>
                    snapshot.metadata.hasPendingWrites,
              )
              .map(
                (snapshot) => _decodeOperationalEventsForLive(
                  snapshot,
                  source: 'operational-event open feed',
                  onMalformed: (malformedDocumentIds) {
                    final current = ref.read(
                      operationalEventFeedDiagnosticsProvider(actorUid),
                    );
                    ref
                        .read(
                          operationalEventFeedDiagnosticsProvider(
                            actorUid,
                          ).notifier,
                        )
                        .state = current.withOpenMalformed(
                      malformedDocumentIds,
                    );
                  },
                ),
              )
              .map(
                (events) => events
                    .where((event) => event.isOpen)
                    .toList(growable: false),
              );
      final recent =
          admitActorSessionSnapshots(
            events
                .orderBy('updatedAt', descending: true)
                .limit(operationalEventLiveWindowLimit)
                .snapshots(includeMetadataChanges: true),
            trust: cacheTrust,
            actorUid: actorUid,
            queryKey: 'events:recent',
            isFromCache: (snapshot) => snapshot.metadata.isFromCache,
            hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
          ).map(
            (snapshot) => _decodeOperationalEventsForLive(
              snapshot,
              source: 'operational-event recent feed',
              onMalformed: (malformedDocumentIds) {
                final current = ref.read(
                  operationalEventFeedDiagnosticsProvider(actorUid),
                );
                ref
                    .read(
                      operationalEventFeedDiagnosticsProvider(
                        actorUid,
                      ).notifier,
                    )
                    .state = current.withRecentMalformed(
                  malformedDocumentIds,
                );
              },
            ),
          );
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
        ref
            .watch(operationalEventFirestoreProvider)
            .collection('operational_events')
            .snapshots(includeMetadataChanges: true),
        trust: ref.watch(operationalEventCacheTrustProvider),
        actorUid: actorUid,
        queryKey: 'events:reports',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(_decodeOperationalEvents);
    });

List<OperationalEvent> _decodeOperationalEvents(
  QuerySnapshot<Map<String, dynamic>> snapshot,
) => snapshot.docs
    .map((doc) => OperationalEvent.fromMap(doc.data(), doc.id))
    .toList(growable: false);

List<OperationalEvent> _decodeOperationalEventsForLive(
  QuerySnapshot<Map<String, dynamic>> snapshot, {
  required String source,
  required void Function(Iterable<String> documentIds) onMalformed,
}) {
  final decoded = decodeSnapshotBatch(
    snapshot,
    (data, id) => OperationalEvent.fromMap(data, id),
    source: source,
  );
  onMalformed(decoded.rejectedDocumentIds);
  return List<OperationalEvent>.unmodifiable(decoded.records);
}

List<OperationalEvent> mergeOperationalEventWindows(
  List<OperationalEvent> open,
  List<OperationalEvent> recent,
) {
  final byId = <String, OperationalEvent>{};
  for (final event in recent) {
    byId[event.eventId] = event;
  }
  for (final event in open) {
    final existing = byId[event.eventId];
    if (existing == null || _isNewerOperationalEvent(event, existing)) {
      byId[event.eventId] = event;
    }
  }
  final events = byId.values.toList();
  events.sort((left, right) {
    if (left.isOpen != right.isOpen) return left.isOpen ? -1 : 1;
    final severity = right.severity.index.compareTo(left.severity.index);
    if (severity != 0) return severity;
    final startedAt = right.startedAt.compareTo(left.startedAt);
    if (startedAt != 0) return startedAt;
    return left.eventId.compareTo(right.eventId);
  });
  return List<OperationalEvent>.unmodifiable(events);
}

bool _isNewerOperationalEvent(
  OperationalEvent candidate,
  OperationalEvent existing,
) {
  if (candidate.version != existing.version) {
    return candidate.version > existing.version;
  }
  if (candidate.updatedAt != existing.updatedAt) {
    return candidate.updatedAt.isAfter(existing.updatedAt);
  }
  // Equal revisions with different content are a source contradiction. Keep
  // the already-selected row and let the next complete snapshot/report expose
  // the discrepancy rather than allowing query order to decide silently.
  return false;
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
      openSubscription = open.listen(
        (value) {
          latestOpen = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stackTrace) {
          latestOpen = null;
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
      recentSubscription = recent.listen(
        (value) {
          latestRecent = value;
          emitWhenReady();
        },
        onError: (Object error, StackTrace stackTrace) {
          latestRecent = null;
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
      );
    },
    onCancel: () async {
      await openSubscription?.cancel();
      await recentSubscription?.cancel();
    },
  );
  return controller.stream;
}
