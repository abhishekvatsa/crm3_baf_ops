import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../data/morning_review_repository.dart';
import '../domain/morning_review_models.dart';
import '../services/morning_review_command_service.dart';

final morningReviewRepositoryProvider = Provider<MorningReviewRepository>((
  ref,
) {
  return MorningReviewRepository(FirebaseFirestore.instance);
});

final _morningReviewCommandServiceByActorProvider =
    Provider.family<MorningReviewCommandService, String>((ref, actorScope) {
      return MorningReviewCommandService(
        functions: FirebaseFunctions.instanceFor(
          region: morningReviewCallableRegion,
        ),
        actorScope: actorScope,
        durableStore: ref.watch(durableSubmissionRepositoryProvider),
        requireActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady ||
              ref.read(firebaseAuthProvider).currentUser?.uid !=
                  access.actor?.uid) {
            throw MorningReviewCommandException(
              access.isReady
                  ? 'Your signed-in account changed. The saved change is retained.'
                  : access.message,
            );
          }
          return access.actor!;
        },
        requireCapability: (uid) async {
          await const CommandCapabilityService().requireCapabilities(
            callableName: morningReviewV2CallableName,
            originActorUid: uid,
            requiredCapabilities: const {'assetHierarchy.v2'},
          );
        },
        readSubject: ref
            .watch(morningReviewRepositoryProvider)
            .readSubjectFromServer,
      );
    });

final morningReviewCommandServiceProvider =
    Provider<MorningReviewCommandService>((ref) {
      final actorScope = ref.watch(
        currentAppUserProvider.select(
          (value) =>
              CurrentActorAccess.resolve(value).actor?.uid ?? 'unverified',
        ),
      );
      return ref.watch(_morningReviewCommandServiceByActorProvider(actorScope));
    });

final morningReviewPlantDayProvider = Provider<String>((ref) {
  final now = DateTime.now().toUtc();
  final india = now.add(const Duration(hours: 5, minutes: 30));
  final nextIndiaDay = DateTime.utc(india.year, india.month, india.day + 1);
  final nextPlantMidnight = nextIndiaDay.subtract(
    const Duration(hours: 5, minutes: 30),
  );
  final timer = Timer(nextPlantMidnight.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return currentIndiaPlantDay(now);
});

final currentMorningReviewSessionProvider =
    StreamProvider<MorningReviewSession?>((ref) {
      final actor = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      ).actor;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(null);
      }
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchSession(ref.watch(morningReviewPlantDayProvider));
    });

final recentMorningReviewSessionsProvider =
    StreamProvider<List<MorningReviewSession>>((ref) {
      final actor = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      ).actor;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(const <MorningReviewSession>[]);
      }
      return ref.watch(morningReviewRepositoryProvider).watchRecentSessions();
    });

final morningReviewParticipantsProvider = StreamProvider.autoDispose
    .family<List<MorningReviewParticipant>, String>((ref, sessionId) {
      if (CurrentActorAccess.resolve(
            ref.watch(currentAppUserProvider),
          ).actor?.canViewMorningReview !=
          true) {
        return Stream.value(const <MorningReviewParticipant>[]);
      }
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchParticipants(sessionId);
    });

final morningReviewEntriesProvider = StreamProvider.autoDispose
    .family<List<MorningReviewEntry>, String>((ref, sessionId) {
      if (CurrentActorAccess.resolve(
            ref.watch(currentAppUserProvider),
          ).actor?.canViewMorningReview !=
          true) {
        return Stream.value(const <MorningReviewEntry>[]);
      }
      return ref.watch(morningReviewRepositoryProvider).watchEntries(sessionId);
    });

final morningReviewActionsProvider = StreamProvider.autoDispose
    .family<List<MorningReviewAction>, String>((ref, sessionId) {
      if (CurrentActorAccess.resolve(
            ref.watch(currentAppUserProvider),
          ).actor?.canViewMorningReview !=
          true) {
        return Stream.value(const <MorningReviewAction>[]);
      }
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchSessionActions(sessionId);
    });

final activeMorningReviewActionsProvider =
    StreamProvider<List<MorningReviewAction>>((ref) {
      final actor = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      ).actor;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(const <MorningReviewAction>[]);
      }
      return ref.watch(morningReviewRepositoryProvider).watchActiveActions();
    });

final morningReviewStandingConcernsProvider =
    StreamProvider<List<MorningReviewStandingConcern>>((ref) {
      final actor = CurrentActorAccess.resolve(
        ref.watch(currentAppUserProvider),
      ).actor;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(const <MorningReviewStandingConcern>[]);
      }
      return ref.watch(morningReviewRepositoryProvider).watchStandingConcerns();
    });

final morningReviewConcernChecksProvider = StreamProvider.autoDispose
    .family<List<MorningReviewConcernCheck>, String>((ref, sessionId) {
      if (CurrentActorAccess.resolve(
            ref.watch(currentAppUserProvider),
          ).actor?.canViewMorningReview !=
          true) {
        return Stream.value(const <MorningReviewConcernCheck>[]);
      }
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchConcernChecks(sessionId);
    });

final morningReviewDocumentProvider = StreamProvider.autoDispose
    .family<MorningReviewDocument?, String>((ref, sessionId) {
      if (CurrentActorAccess.resolve(
            ref.watch(currentAppUserProvider),
          ).actor?.canViewMorningReview !=
          true) {
        return Stream.value(null);
      }
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchDocument(sessionId);
    });
