import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/morning_review_models.dart';

class MorningReviewFeedUnverifiedException implements Exception {
  const MorningReviewFeedUnverifiedException(this.source);

  final String source;

  @override
  String toString() =>
      'Morning Review data is not server verified ($source). '
      'Check connectivity and refresh.';
}

Stream<T> serverVerifiedMorningReviewFeed<T>(
  Stream<T> snapshots, {
  required bool Function(T snapshot) isServerVerified,
  required String source,
  required Duration verificationGrace,
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  Timer? verificationTimer;
  var serverVerificationObserved = false;
  var unverifiedStateReported = false;

  void cancelVerificationTimer() {
    verificationTimer?.cancel();
    verificationTimer = null;
  }

  controller = StreamController<T>(
    onListen: () {
      verificationTimer = Timer(verificationGrace, () {
        if (!serverVerificationObserved && !controller.isClosed) {
          unverifiedStateReported = true;
          controller.addError(MorningReviewFeedUnverifiedException(source));
        }
      });
      subscription = snapshots.listen(
        (snapshot) {
          if (isServerVerified(snapshot)) {
            serverVerificationObserved = true;
            unverifiedStateReported = false;
            cancelVerificationTimer();
            if (!controller.isClosed) controller.add(snapshot);
            return;
          }
          if (serverVerificationObserved &&
              !unverifiedStateReported &&
              !controller.isClosed) {
            unverifiedStateReported = true;
            controller.addError(MorningReviewFeedUnverifiedException(source));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          cancelVerificationTimer();
          unverifiedStateReported = true;
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
        onDone: () {
          cancelVerificationTimer();
          if (!controller.isClosed) controller.close();
        },
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () async {
      cancelVerificationTimer();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}

class MorningReviewRepository {
  const MorningReviewRepository(this.firestore);

  static const _serverVerificationGrace = Duration(seconds: 12);

  final FirebaseFirestore firestore;

  Stream<MorningReviewSession?> watchSession(String sessionId) =>
      _verifiedDocumentSnapshots(
        firestore
            .collection('morning_review_sessions')
            .doc(sessionId)
            .snapshots(includeMetadataChanges: true),
        'today session',
      ).map((snapshot) {
        if (!snapshot.exists) return null;
        final session = MorningReviewSession.fromMap(
          snapshot.data()!,
          snapshot.id,
        );
        return session.expiresAt.isAfter(DateTime.now()) ? session : null;
      });

  Stream<List<MorningReviewSession>> watchRecentSessions() =>
      _verifiedQuerySnapshots(
        firestore
            .collection('morning_review_sessions')
            .orderBy('plantDay', descending: true)
            .limit(15)
            .snapshots(includeMetadataChanges: true),
        'recent sessions',
      ).map((snapshot) {
        final now = DateTime.now();
        return List.unmodifiable(
          snapshot.docs
              .map(
                (document) =>
                    MorningReviewSession.fromMap(document.data(), document.id),
              )
              .where((session) => session.expiresAt.isAfter(now)),
        );
      });

  Stream<List<MorningReviewParticipant>> watchParticipants(
    String sessionId,
  ) => _sessionQuery('morning_review_participants', sessionId).map((snapshot) {
    final values = snapshot.docs
        .map(
          (document) =>
              MorningReviewParticipant.fromMap(document.data(), document.id),
        )
        .toList(growable: false)
      ..sort((left, right) => left.joinedAt.compareTo(right.joinedAt));
    return List.unmodifiable(values);
  });

  Stream<List<MorningReviewEntry>> watchEntries(String sessionId) =>
      _sessionQuery('morning_review_entries', sessionId).map((snapshot) {
        final values = snapshot.docs
            .map(
              (document) =>
                  MorningReviewEntry.fromMap(document.data(), document.id),
            )
            .toList(growable: false)
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
        return List.unmodifiable(values);
      });

  Stream<List<MorningReviewAction>> watchSessionActions(String sessionId) =>
      _sessionQuery('morning_review_actions', sessionId).map((snapshot) {
        final values = snapshot.docs
            .map(
              (document) =>
                  MorningReviewAction.fromMap(document.data(), document.id),
            )
            .toList(growable: false)
          ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
        return List.unmodifiable(values);
      });

  Stream<List<MorningReviewAction>> watchActiveActions() =>
      _verifiedQuerySnapshots(
        firestore
            .collection('morning_review_actions')
            .where('status', whereIn: const ['open', 'accepted'])
            .snapshots(includeMetadataChanges: true),
        'active actions',
      ).map((snapshot) {
        final values = snapshot.docs
          .map(
            (document) =>
                MorningReviewAction.fromMap(document.data(), document.id),
          )
          .toList(growable: false)..sort((left, right) {
          final leftDue = left.dueAt;
          final rightDue = right.dueAt;
          if (leftDue == null && rightDue != null) return 1;
          if (leftDue != null && rightDue == null) return -1;
          if (leftDue != null && rightDue != null) {
            final dueOrder = leftDue.compareTo(rightDue);
            if (dueOrder != 0) return dueOrder;
          }
          return left.createdAt.compareTo(right.createdAt);
        });
        return List.unmodifiable(values);
      });

  Stream<List<MorningReviewStandingConcern>> watchStandingConcerns() =>
      _verifiedQuerySnapshots(
        firestore
            .collection('morning_review_standing_concerns')
            .where('status', whereIn: const ['active', 'resolved'])
            .snapshots(includeMetadataChanges: true),
        'standing concerns',
      ).map((snapshot) {
        final now = DateTime.now();
        final values = snapshot.docs
          .map(
            (document) => MorningReviewStandingConcern.fromMap(
              document.data(),
              document.id,
            ),
          )
          .where(
            (concern) =>
                concern.status == MorningReviewConcernStatus.active ||
                concern.resolvedAt
                        ?.add(const Duration(days: 14))
                        .isAfter(now) ==
                    true,
          )
          .toList(growable: false)..sort((left, right) {
          final criticality = right.criticality.index.compareTo(
            left.criticality.index,
          );
          return criticality != 0
              ? criticality
              : left.createdAt.compareTo(right.createdAt);
        });
        return List.unmodifiable(values);
      });

  Stream<List<MorningReviewConcernCheck>> watchConcernChecks(
    String sessionId,
  ) => _sessionQuery('morning_review_concern_checks', sessionId).map((
    snapshot,
  ) {
    final values = snapshot.docs
        .map(
          (document) =>
              MorningReviewConcernCheck.fromMap(document.data(), document.id),
        )
        .toList(growable: false)
      ..sort((left, right) => left.checkedAt.compareTo(right.checkedAt));
    return List.unmodifiable(values);
  });

  Stream<MorningReviewDocument?> watchDocument(String sessionId) =>
      _verifiedDocumentSnapshots(
        firestore
            .collection('morning_review_documents')
            .doc(sessionId)
            .snapshots(includeMetadataChanges: true),
        'finalized document',
      ).map((snapshot) {
        if (!snapshot.exists) return null;
        final document = MorningReviewDocument.fromMap(
          snapshot.data()!,
          snapshot.id,
        );
        return document.expiresAt.isAfter(DateTime.now()) ? document : null;
      });

  Stream<QuerySnapshot<Map<String, dynamic>>> _sessionQuery(
    String collection,
    String sessionId,
  ) => _verifiedQuerySnapshots(
    firestore
        .collection(collection)
        .where('sessionId', isEqualTo: sessionId)
        .limit(250)
        .snapshots(includeMetadataChanges: true),
    collection,
  );

  Stream<DocumentSnapshot<Map<String, dynamic>>> _verifiedDocumentSnapshots(
    Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots,
    String source,
  ) => _verifiedSnapshots(
    snapshots,
    metadataOf: (snapshot) => snapshot.metadata,
    source: source,
  );

  Stream<QuerySnapshot<Map<String, dynamic>>> _verifiedQuerySnapshots(
    Stream<QuerySnapshot<Map<String, dynamic>>> snapshots,
    String source,
  ) => _verifiedSnapshots(
    snapshots,
    metadataOf: (snapshot) => snapshot.metadata,
    source: source,
  );

  Stream<T> _verifiedSnapshots<T>(
    Stream<T> snapshots, {
    required SnapshotMetadata Function(T snapshot) metadataOf,
    required String source,
  }) => serverVerifiedMorningReviewFeed(
    snapshots,
    isServerVerified: (snapshot) {
      final metadata = metadataOf(snapshot);
      return !metadata.isFromCache && !metadata.hasPendingWrites;
    },
    source: source,
    verificationGrace: _serverVerificationGrace,
  );
}
