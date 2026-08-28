import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/uv_detector_lifecycle_event.dart';
import 'burner_condition_round_provider.dart';

const uvDetectorLifecycleReportLimit = 1000;

final uvDetectorLifecycleEventsProvider = StreamProvider.autoDispose
    .family<List<UvDetectorLifecycleEvent>, String>((ref, actorUid) {
      final actorAsync = ref.watch(currentAppUserProvider);
      if (actorAsync.isLoading) {
        throw StateError('UV lifecycle access is still being verified.');
      }
      if (actorAsync.hasError) {
        throw StateError('UV lifecycle access could not be verified.');
      }
      final actor = actorAsync.value;
      if (actor == null ||
          !actor.isApproved ||
          actor.uid != actorUid ||
          actorUid.trim().isEmpty) {
        throw StateError('Approved UV lifecycle access is required.');
      }
      final ActorSessionCacheTrust cacheTrust = ref.watch(
        burnerConditionRoundCacheTrustProvider,
      )..observeActor(actorUid);
      final snapshots = FirebaseFirestore.instance
          .collection('uv_detector_lifecycle_events')
          .orderBy('actionPerformedAt', descending: true)
          .limit(uvDetectorLifecycleReportLimit)
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: cacheTrust,
        actorUid: actorUid,
        queryKey: 'uv-detector-lifecycle-events',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(
        (snapshot) => List<UvDetectorLifecycleEvent>.unmodifiable(
          snapshot.docs.map(
            (document) =>
                UvDetectorLifecycleEvent.fromMap(document.data(), document.id),
          ),
        ),
      );
    });

final uvDetectorLifecycleCurrentProvider = StreamProvider.autoDispose
    .family<List<UvDetectorLifecycleEvent>, String>((ref, actorUid) {
      final actorAsync = ref.watch(currentAppUserProvider);
      if (actorAsync.isLoading) {
        throw StateError('UV lifecycle access is still being verified.');
      }
      if (actorAsync.hasError) {
        throw StateError('UV lifecycle access could not be verified.');
      }
      final actor = actorAsync.value;
      if (actor == null ||
          !actor.isApproved ||
          actor.uid != actorUid ||
          actorUid.trim().isEmpty) {
        throw StateError('Approved UV lifecycle access is required.');
      }
      final ActorSessionCacheTrust cacheTrust = ref.watch(
        burnerConditionRoundCacheTrustProvider,
      )..observeActor(actorUid);
      final snapshots = FirebaseFirestore.instance
          .collection('uv_detector_lifecycle_current')
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: cacheTrust,
        actorUid: actorUid,
        queryKey: 'uv-detector-lifecycle-current',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(
        (snapshot) => List<UvDetectorLifecycleEvent>.unmodifiable(
          snapshot.docs.map(
            (document) => UvDetectorLifecycleEvent.fromCurrentMap(
              document.data(),
              document.id,
            ),
          ),
        ),
      );
    });
