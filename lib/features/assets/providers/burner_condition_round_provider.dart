import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/serialization/persisted_data_reader.dart';
import '../../../core/security/actor_session_cache_trust.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_service.dart';
import '../data/burner_condition_round.dart';
import '../services/burner_condition_round_idempotency_store.dart';
import '../services/burner_condition_round_service.dart';
import '../services/burner_condition_submission_controller.dart';

const burnerConditionRoundReportLimit = 1000;
const burnerConditionRoundHistoryDisclosure =
    'Showing up to $burnerConditionRoundReportLimit rounds in the selected period.';

@immutable
final class LatestBurnerConditionRoundsQuery {
  factory LatestBurnerConditionRoundsQuery({
    required String actorUid,
    required Iterable<String> assetInstanceIds,
  }) {
    final normalizedIds =
        assetInstanceIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return LatestBurnerConditionRoundsQuery._(
      actorUid: actorUid.trim(),
      assetInstanceIds: List<String>.unmodifiable(normalizedIds),
    );
  }

  const LatestBurnerConditionRoundsQuery._({
    required this.actorUid,
    required this.assetInstanceIds,
  });

  final String actorUid;
  final List<String> assetInstanceIds;

  String get cacheKey => <String>[
    'current-burner-condition-rounds',
    actorUid,
    ...assetInstanceIds,
  ].join('|');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatestBurnerConditionRoundsQuery &&
          actorUid == other.actorUid &&
          listEquals(assetInstanceIds, other.assetInstanceIds);

  @override
  int get hashCode => Object.hash(actorUid, Object.hashAll(assetInstanceIds));
}

final latestBurnerConditionRoundsProvider = StreamProvider.autoDispose
    .family<
      Map<String, BurnerConditionRound>,
      LatestBurnerConditionRoundsQuery
    >((ref, query) {
      final actorAsync = ref.watch(currentAppUserProvider);
      if (actorAsync.isLoading) {
        throw StateError('Burner-condition access is still being verified.');
      }
      if (actorAsync.hasError) {
        throw StateError('Burner-condition access could not be verified.');
      }
      final actor = actorAsync.value;
      if (actor == null ||
          !actor.isApproved ||
          actor.uid != query.actorUid ||
          query.actorUid.isEmpty) {
        throw StateError('Approved burner-condition access is required.');
      }
      if (query.assetInstanceIds.isEmpty) {
        return Stream<Map<String, BurnerConditionRound>>.value(
          const <String, BurnerConditionRound>{},
        );
      }
      final cacheTrust = ref.watch(burnerConditionRoundCacheTrustProvider)
        ..observeActor(query.actorUid);
      final firestore = ref.watch(burnerConditionFirestoreProvider);
      final snapshots = firestore
          .collection('burner_condition_current')
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: cacheTrust,
        actorUid: query.actorUid,
        queryKey: query.cacheKey,
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).asyncMap(
        (snapshot) => _resolveCurrentBurnerConditionRounds(
          firestore: firestore,
          pointerSnapshot: snapshot,
          assetInstanceIds: query.assetInstanceIds,
        ),
      );
    });

final burnerConditionFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

typedef BurnerComplianceCurrentReader =
    Future<Map<String, BurnerConditionRound>> Function(
      LatestBurnerConditionRoundsQuery query,
    );

final burnerComplianceCurrentReaderProvider =
    Provider<BurnerComplianceCurrentReader>((ref) {
      ref.watch(
        currentAppUserProvider.select((value) {
          if (value.isLoading || value.hasError) return null;
          final actor = value.value;
          return actor?.canRecordBurnerConditionRound == true
              ? actor!.uid
              : null;
        }),
      );
      ref.watch(signOutInProgressProvider);
      final firestore = ref.watch(burnerConditionFirestoreProvider);
      var disposed = false;
      ref.onDispose(() => disposed = true);
      return (query) {
        void requireSameActor() {
          if (disposed) {
            throw StateError(
              'Burner-compliance access changed. Reopen and retry.',
            );
          }
          final actor = ref.read(currentAppUserProvider);
          if (ref.read(signOutInProgressProvider) ||
              actor.isLoading ||
              actor.hasError ||
              actor.value == null ||
              !actor.value!.canRecordBurnerConditionRound ||
              actor.value!.uid != query.actorUid) {
            throw StateError('Approved burner-compliance access is required.');
          }
        }

        return readCurrentBurnerConditionRoundsFromServer(
          firestore: firestore,
          query: query,
          requireSameActor: requireSameActor,
        );
      };
    });

/// Command preparation needs a fresh authoritative baseline. A live UI stream
/// may correctly surface an untrusted initial cache event before its server
/// event; taking that stream's first future would incorrectly abort this action.
Future<Map<String, BurnerConditionRound>>
readCurrentBurnerConditionRoundsFromServer({
  required FirebaseFirestore firestore,
  required LatestBurnerConditionRoundsQuery query,
  required void Function() requireSameActor,
  Duration timeout = const Duration(seconds: 20),
}) async {
  requireSameActor();
  return (() async {
    final pointers = await firestore
        .collection('burner_condition_current')
        .get(const GetOptions(source: Source.server));
    requireSameActor();
    _requireAuthoritativeBurnerSnapshot(pointers.metadata);
    final rounds = await _resolveCurrentBurnerConditionRounds(
      firestore: firestore,
      pointerSnapshot: pointers,
      assetInstanceIds: query.assetInstanceIds,
      requireServer: true,
    );
    requireSameActor();
    return rounds;
  })().timeout(timeout);
}

void _requireAuthoritativeBurnerSnapshot(SnapshotMetadata metadata) {
  if (metadata.isFromCache || metadata.hasPendingWrites) {
    throw const ActorSessionSnapshotTrustException();
  }
}

Future<Map<String, BurnerConditionRound>> _resolveCurrentBurnerConditionRounds({
  required FirebaseFirestore firestore,
  required QuerySnapshot<Map<String, dynamic>> pointerSnapshot,
  required List<String> assetInstanceIds,
  bool requireServer = false,
}) async {
  final requestedIds = assetInstanceIds.toSet();
  final pointers = <String, BurnerConditionCurrentPointer>{};
  for (final document in pointerSnapshot.docs) {
    if (!requestedIds.contains(document.id)) continue;
    pointers[document.id] = BurnerConditionCurrentPointer.fromMap(
      document.data(),
      document.id,
    );
  }

  final roundsCollection = firestore.collection('burner_condition_rounds');
  final resolvedEntries = await Future.wait(
    assetInstanceIds.map((assetInstanceId) async {
      final pointer = pointers[assetInstanceId];
      if (pointer != null) {
        final document = await roundsCollection
            .doc(pointer.roundId)
            .get(const GetOptions(source: Source.server));
        if (requireServer) {
          _requireAuthoritativeBurnerSnapshot(document.metadata);
        }
        final data = document.data();
        if (!document.exists || data == null) {
          throw PersistedDataFormatException(
            field: 'roundId',
            source: 'burner_condition_current/$assetInstanceId',
            detail: 'referenced round is missing',
          );
        }
        final round = BurnerConditionRound.fromMap(data, document.id);
        return MapEntry(assetInstanceId, pointer.requireMatchingRound(round));
      }

      final legacySnapshot = await roundsCollection
          .where('assetInstanceId', isEqualTo: assetInstanceId)
          .orderBy('observedAt', descending: true)
          .limit(2)
          .get(const GetOptions(source: Source.server));
      if (requireServer) {
        _requireAuthoritativeBurnerSnapshot(legacySnapshot.metadata);
      }
      if (legacySnapshot.docs.isEmpty) {
        return MapEntry<String, BurnerConditionRound?>(assetInstanceId, null);
      }
      final round = BurnerConditionRound.fromMap(
        legacySnapshot.docs.first.data(),
        legacySnapshot.docs.first.id,
      );
      if (round.assetInstanceId != assetInstanceId) {
        throw PersistedDataFormatException(
          field: 'assetInstanceId',
          source: 'burner_condition_rounds/${round.roundId}',
          detail: 'does not match the requested governed asset',
        );
      }
      if (legacySnapshot.docs.length > 1) {
        final runnerUp = BurnerConditionRound.fromMap(
          legacySnapshot.docs[1].data(),
          legacySnapshot.docs[1].id,
        );
        if (runnerUp.observedAt.isAtSameMomentAs(round.observedAt)) {
          throw PersistedDataFormatException(
            field: 'observedAt',
            source: 'burner_condition_rounds/$assetInstanceId',
            detail:
                'legacy current round is ambiguous and needs reconciliation',
          );
        }
      }
      return MapEntry<String, BurnerConditionRound?>(assetInstanceId, round);
    }),
  );
  return Map<String, BurnerConditionRound>.unmodifiable(
    <String, BurnerConditionRound>{
      for (final entry in resolvedEntries)
        if (entry.value != null) entry.key: entry.value!,
    },
  );
}

typedef BurnerConditionRoundQuery = ({
  String actorUid,
  DateTime startInclusive,
  DateTime endExclusive,
  String? assetInstanceId,
});

final burnerConditionRoundServiceProvider =
    Provider<BurnerConditionRoundService>((ref) {
      return BurnerConditionRoundService(
        submissions: BurnerConditionSubmissionController(
          store: ref.watch(durableSubmissionRepositoryProvider),
          requireActor: () {
            final state = ref.read(currentAppUserProvider);
            if (state.isLoading ||
                state.hasError ||
                state.valueOrNull == null) {
              throw const BurnerConditionRoundException(
                'Current account access must be verified before continuing.',
                code: 'permission-denied',
              );
            }
            return state.valueOrNull!;
          },
          requireCapability: (uid) async {
            await const CommandCapabilityService().requireCapabilities(
              callableName: burnerConditionRoundCallableName,
              originActorUid: uid,
              requiredCapabilities: {'assetHierarchy.v2'},
            );
          },
          invoke: (envelope) async =>
              (await FirebaseFunctions.instanceFor(
                        region: burnerConditionRoundCallableRegion,
                      )
                      .httpsCallable(burnerConditionRoundCallableName)
                      .call<Object?>(envelope))
                  .data,
          readLegacy: ref
              .watch(burnerConditionRoundIdempotencyStoreProvider)
              .readRawEvidence,
        ),
      );
    });

final burnerConditionRoundCacheTrustProvider = Provider<ActorSessionCacheTrust>(
  (ref) {
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
  },
);

final burnerConditionRoundsProvider = StreamProvider.autoDispose
    .family<List<BurnerConditionRound>, BurnerConditionRoundQuery>((
      ref,
      query,
    ) {
      final actorAsync = ref.watch(currentAppUserProvider);
      if (actorAsync.isLoading) {
        throw StateError('Burner-report access is still being verified.');
      }
      if (actorAsync.hasError) {
        throw StateError('Burner-report access could not be verified.');
      }
      final actor = actorAsync.value;
      if (actor == null ||
          !actor.canViewReports ||
          actor.uid != query.actorUid ||
          query.actorUid.trim().isEmpty) {
        throw StateError('Approved burner-report access is required.');
      }
      final cacheTrust = ref.watch(burnerConditionRoundCacheTrustProvider)
        ..observeActor(query.actorUid);
      Query<Map<String, dynamic>> rounds = FirebaseFirestore.instance
          .collection('burner_condition_rounds');
      final assetInstanceId = query.assetInstanceId?.trim();
      if (assetInstanceId != null && assetInstanceId.isNotEmpty) {
        rounds = rounds.where('assetInstanceId', isEqualTo: assetInstanceId);
      }
      final snapshots = rounds
          .where(
            'observedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(query.startInclusive),
          )
          .where(
            'observedAt',
            isLessThan: Timestamp.fromDate(query.endExclusive),
          )
          .orderBy('observedAt', descending: true)
          .limit(burnerConditionRoundReportLimit)
          .snapshots(includeMetadataChanges: true);
      return admitActorSessionSnapshots(
        snapshots,
        trust: cacheTrust,
        actorUid: query.actorUid,
        queryKey: burnerConditionRoundQueryKey(query),
        isFromCache: (snapshot) => snapshot.metadata.isFromCache,
        hasPendingWrites: (snapshot) => snapshot.metadata.hasPendingWrites,
      ).map(
        (snapshot) => List<BurnerConditionRound>.unmodifiable(
          snapshot.docs.map(
            (document) =>
                BurnerConditionRound.fromMap(document.data(), document.id),
          ),
        ),
      );
    });

String burnerConditionRoundQueryKey(BurnerConditionRoundQuery query) {
  final assetInstanceId = query.assetInstanceId?.trim();
  return <String>[
    'burner-rounds',
    query.startInclusive.toUtc().toIso8601String(),
    query.endExclusive.toUtc().toIso8601String(),
    assetInstanceId == null || assetInstanceId.isEmpty ? '*' : assetInstanceId,
  ].join('|');
}
