import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/morning_review_models.dart';
import 'morning_review_rows.dart';

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

  Future<Map<String, dynamic>> readSubjectFromServer(
    String collection,
    String id,
  ) async {
    if (!const {
          'morning_review_sessions',
          'morning_review_participants',
          'morning_review_entries',
          'morning_review_actions',
          'morning_review_standing_concerns',
          'morning_review_concern_checks',
          'morning_review_documents',
        }.contains(collection) ||
        id.isEmpty ||
        id.contains('/')) {
      throw const MorningReviewFeedUnverifiedException(
        'saved subject identity',
      );
    }
    final document = await firestore
        .collection(collection)
        .doc(id)
        .get(const GetOptions(source: Source.server));
    if (!document.exists ||
        document.metadata.isFromCache ||
        document.metadata.hasPendingWrites) {
      throw const MorningReviewFeedUnverifiedException('saved change');
    }
    return document.data()!;
  }

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
        return session.isOpen ||
                (session.expiresAt?.isAfter(DateTime.now()) ?? false)
            ? session
            : null;
      });

  MorningReviewRows<T> _rows<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    T Function(Map<String, dynamic>, String) decode, {
    bool Function(T)? keep,
    int Function(T, T)? compare,
  }) => decodeMorningReviewRows(
    snapshot.docs.map((row) => (id: row.id, data: row.data())),
    decode,
    keep: keep,
    compare: compare,
  );

  Stream<List<MorningReviewSession>> watchRecentSessions() =>
      combineMorningReviewRows(
        [
          _verifiedQuerySnapshots(
            firestore
                .collection('morning_review_sessions')
                .where('status', isEqualTo: 'open')
                .snapshots(includeMetadataChanges: true),
            'unfinished sessions',
          ).map((snapshot) => _rows(snapshot, MorningReviewSession.fromMap)),
          _verifiedQuerySnapshots(
            firestore
                .collection('morning_review_sessions')
                .orderBy('plantDay', descending: true)
                .limit(30)
                .snapshots(includeMetadataChanges: true),
            'recent sessions',
          ).map(
            (snapshot) => _rows(
              snapshot,
              MorningReviewSession.fromMap,
              keep: (session) =>
                  !session.isOpen &&
                  (session.expiresAt?.isAfter(DateTime.now()) ?? false),
            ),
          ),
        ],
        identity: (session) => session.sessionId,
        compare: (a, b) => b.plantDay.compareTo(a.plantDay),
      );

  Stream<List<MorningReviewParticipant>> watchParticipants(String sessionId) =>
      _sessionQuery('morning_review_participants', sessionId).map(
        (snapshot) => _rows(
          snapshot,
          MorningReviewParticipant.fromMap,
          compare: (a, b) => a.joinedAt.compareTo(b.joinedAt),
        ),
      );

  Stream<List<MorningReviewEntry>> watchEntries(String sessionId) =>
      _sessionQuery('morning_review_entries', sessionId).map(
        (snapshot) => _rows(
          snapshot,
          MorningReviewEntry.fromMap,
          compare: (a, b) => a.createdAt.compareTo(b.createdAt),
        ),
      );

  Stream<List<MorningReviewAction>> watchSessionActions(String sessionId) =>
      _sessionQuery('morning_review_actions', sessionId).map(
        (snapshot) => _rows(
          snapshot,
          MorningReviewAction.fromMap,
          compare: (a, b) => a.createdAt.compareTo(b.createdAt),
        ),
      );

  // Includes retained completed carried work; the screen distinguishes active
  // commitments from their recent outcomes instead of making completion vanish.
  Stream<List<MorningReviewAction>> watchActiveActions() =>
      _verifiedQuerySnapshots(
        firestore
            .collection('morning_review_actions')
            .where(
              'status',
              whereIn: const ['open', 'accepted', 'completed', 'cancelled'],
            )
            .snapshots(includeMetadataChanges: true),
        'active and recently completed actions',
      ).map(
        (snapshot) => _rows(
          snapshot,
          MorningReviewAction.fromMap,
          keep: (action) =>
              action.status == MorningReviewActionStatus.cancelled ||
              !action.isTerminal ||
              action.completedAt
                      ?.add(const Duration(days: 14))
                      .isAfter(DateTime.now()) ==
                  true,
          compare: (a, b) => a.createdAt.compareTo(b.createdAt),
        ),
      );

  Stream<List<MorningReviewStandingConcern>> watchStandingConcerns() =>
      _verifiedQuerySnapshots(
        firestore
            .collection('morning_review_standing_concerns')
            .where('status', whereIn: const ['active', 'resolved'])
            .snapshots(includeMetadataChanges: true),
        'standing concerns',
      ).map(
        (snapshot) => _rows(
          snapshot,
          MorningReviewStandingConcern.fromMap,
          keep: (concern) =>
              concern.status == MorningReviewConcernStatus.active ||
              concern.resolvedAt
                      ?.add(const Duration(days: 14))
                      .isAfter(DateTime.now()) ==
                  true,
          compare: (a, b) => b.criticality.index.compareTo(a.criticality.index),
        ),
      );

  Stream<List<MorningReviewConcernCheck>> watchConcernChecks(
    String sessionId,
  ) => _sessionQuery('morning_review_concern_checks', sessionId).map(
    (snapshot) => _rows(
      snapshot,
      MorningReviewConcernCheck.fromMap,
      compare: (a, b) => a.checkedAt.compareTo(b.checkedAt),
    ),
  );

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
