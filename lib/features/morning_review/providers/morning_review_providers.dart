import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/morning_review_repository.dart';
import '../domain/morning_review_models.dart';
import '../services/morning_review_command_service.dart';

final morningReviewRepositoryProvider = Provider<MorningReviewRepository>((
  ref,
) {
  return MorningReviewRepository(FirebaseFirestore.instance);
});

final morningReviewCommandServiceProvider =
    Provider<MorningReviewCommandService>((ref) {
      final actorUid = ref.watch(currentAppUserProvider).value?.uid;
      return MorningReviewCommandService(
        functions: FirebaseFunctions.instanceFor(
          region: morningReviewCallableRegion,
        ),
        actorScope: actorUid ?? 'signed-out',
      );
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
      final actor = ref.watch(currentAppUserProvider).value;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(null);
      }
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchSession(ref.watch(morningReviewPlantDayProvider));
    });

final recentMorningReviewSessionsProvider =
    StreamProvider<List<MorningReviewSession>>((ref) {
      final actor = ref.watch(currentAppUserProvider).value;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(const <MorningReviewSession>[]);
      }
      return ref.watch(morningReviewRepositoryProvider).watchRecentSessions();
    });

final morningReviewParticipantsProvider = StreamProvider.autoDispose
    .family<List<MorningReviewParticipant>, String>((ref, sessionId) {
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchParticipants(sessionId);
    });

final morningReviewEntriesProvider = StreamProvider.autoDispose
    .family<List<MorningReviewEntry>, String>((ref, sessionId) {
      return ref.watch(morningReviewRepositoryProvider).watchEntries(sessionId);
    });

final morningReviewActionsProvider = StreamProvider.autoDispose
    .family<List<MorningReviewAction>, String>((ref, sessionId) {
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchSessionActions(sessionId);
    });

final activeMorningReviewActionsProvider =
    StreamProvider<List<MorningReviewAction>>((ref) {
      final actor = ref.watch(currentAppUserProvider).value;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(const <MorningReviewAction>[]);
      }
      return ref.watch(morningReviewRepositoryProvider).watchActiveActions();
    });

final morningReviewStandingConcernsProvider =
    StreamProvider<List<MorningReviewStandingConcern>>((ref) {
      final actor = ref.watch(currentAppUserProvider).value;
      if (actor == null || !actor.canViewMorningReview) {
        return Stream.value(const <MorningReviewStandingConcern>[]);
      }
      return ref.watch(morningReviewRepositoryProvider).watchStandingConcerns();
    });

final morningReviewConcernChecksProvider = StreamProvider.autoDispose
    .family<List<MorningReviewConcernCheck>, String>((ref, sessionId) {
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchConcernChecks(sessionId);
    });

final morningReviewDocumentProvider = StreamProvider.autoDispose
    .family<MorningReviewDocument?, String>((ref, sessionId) {
      return ref
          .watch(morningReviewRepositoryProvider)
          .watchDocument(sessionId);
    });
