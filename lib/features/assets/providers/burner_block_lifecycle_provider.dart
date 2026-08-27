import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/burner_block_lifecycle_event.dart';
import 'burner_condition_round_provider.dart';

const burnerBlockLifecycleReportLimit = 1000;

final burnerBlockLifecycleEventsProvider = StreamProvider.autoDispose
    .family<List<BurnerBlockLifecycleEvent>, String>((ref, actorUid) {
      final actorAsync = ref.watch(currentAppUserProvider);
      if (actorAsync.isLoading) {
        throw StateError('Burner lifecycle access is still being verified.');
      }
      if (actorAsync.hasError) {
        throw StateError('Burner lifecycle access could not be verified.');
      }
      final actor = actorAsync.value;
      if (actor == null ||
          !actor.isApproved ||
          actor.uid != actorUid ||
          actorUid.trim().isEmpty) {
        throw StateError('Approved burner lifecycle access is required.');
      }
      final ActorSessionCacheTrust cacheTrust = ref.watch(
        burnerConditionRoundCacheTrustProvider,
      )..observeActor(actorUid);
      final snapshots = FirebaseFirestore.instance
          .collection('burner_block_lifecycle_events')
          .orderBy('actionPerformedAt', descending: true)
          .limit(burnerBlockLifecycleReportLimit)
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: cacheTrust,
        actorUid: actorUid,
        queryKey: 'burner-block-lifecycle-events',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(
        (snapshot) => List<BurnerBlockLifecycleEvent>.unmodifiable(
          snapshot.docs.map(
            (document) =>
                BurnerBlockLifecycleEvent.fromMap(document.data(), document.id),
          ),
        ),
      );
    });

final burnerBlockLifecycleCurrentProvider = StreamProvider.autoDispose
    .family<List<BurnerBlockLifecycleEvent>, String>((ref, actorUid) {
      final actorAsync = ref.watch(currentAppUserProvider);
      if (actorAsync.isLoading) {
        throw StateError('Burner lifecycle access is still being verified.');
      }
      if (actorAsync.hasError) {
        throw StateError('Burner lifecycle access could not be verified.');
      }
      final actor = actorAsync.value;
      if (actor == null ||
          !actor.isApproved ||
          actor.uid != actorUid ||
          actorUid.trim().isEmpty) {
        throw StateError('Approved burner lifecycle access is required.');
      }
      final ActorSessionCacheTrust cacheTrust = ref.watch(
        burnerConditionRoundCacheTrustProvider,
      )..observeActor(actorUid);
      final snapshots = FirebaseFirestore.instance
          .collection('burner_block_lifecycle_current')
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: cacheTrust,
        actorUid: actorUid,
        queryKey: 'burner-block-lifecycle-current',
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(
        (snapshot) => List<BurnerBlockLifecycleEvent>.unmodifiable(
          snapshot.docs.map(
            (document) => BurnerBlockLifecycleEvent.fromCurrentMap(
              document.data(),
              document.id,
            ),
          ),
        ),
      );
    });
