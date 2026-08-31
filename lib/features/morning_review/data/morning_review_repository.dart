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

class MorningReviewRepository {
  const MorningReviewRepository(this.firestore);

  final FirebaseFirestore firestore;

  Stream<MorningReviewSession?> watchSession(String sessionId) async* {
    await for (final snapshot in _verifiedDocumentSnapshots(
      firestore
          .collection('morning_review_sessions')
          .doc(sessionId)
          .snapshots(includeMetadataChanges: true),
      'today session',
    )) {
      if (!snapshot.exists) {
        yield null;
        continue;
      }
      final session = MorningReviewSession.fromMap(
        snapshot.data()!,
        snapshot.id,
      );
      yield session.expiresAt.isAfter(DateTime.now()) ? session : null;
    }
  }

  Stream<List<MorningReviewSession>> watchRecentSessions() async* {
    await for (final snapshot in _verifiedQuerySnapshots(
      firestore
          .collection('morning_review_sessions')
          .orderBy('plantDay', descending: true)
          .limit(15)
          .snapshots(includeMetadataChanges: true),
      'recent sessions',
    )) {
      final now = DateTime.now();
      yield List.unmodifiable(
        snapshot.docs
            .map(
              (document) =>
                  MorningReviewSession.fromMap(document.data(), document.id),
            )
            .where((session) => session.expiresAt.isAfter(now)),
      );
    }
  }

  Stream<List<MorningReviewParticipant>> watchParticipants(
    String sessionId,
  ) async* {
    await for (final snapshot in _sessionQuery(
      'morning_review_participants',
      sessionId,
    )) {
      final values = snapshot.docs
          .map(
            (document) =>
                MorningReviewParticipant.fromMap(document.data(), document.id),
          )
          .toList(growable: false)
        ..sort((left, right) => left.joinedAt.compareTo(right.joinedAt));
      yield List.unmodifiable(values);
    }
  }

  Stream<List<MorningReviewEntry>> watchEntries(String sessionId) async* {
    await for (final snapshot in _sessionQuery(
      'morning_review_entries',
      sessionId,
    )) {
      final values = snapshot.docs
          .map(
            (document) =>
                MorningReviewEntry.fromMap(document.data(), document.id),
          )
          .toList(growable: false)
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
      yield List.unmodifiable(values);
    }
  }

  Stream<List<MorningReviewAction>> watchSessionActions(
    String sessionId,
  ) async* {
    await for (final snapshot in _sessionQuery(
      'morning_review_actions',
      sessionId,
    )) {
      final values = snapshot.docs
          .map(
            (document) =>
                MorningReviewAction.fromMap(document.data(), document.id),
          )
          .toList(growable: false)
        ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
      yield List.unmodifiable(values);
    }
  }

  Stream<List<MorningReviewAction>> watchActiveActions() async* {
    await for (final snapshot in _verifiedQuerySnapshots(
      firestore
          .collection('morning_review_actions')
          .where('status', whereIn: const ['open', 'accepted'])
          .snapshots(includeMetadataChanges: true),
      'active actions',
    )) {
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
      yield List.unmodifiable(values);
    }
  }

  Stream<List<MorningReviewStandingConcern>> watchStandingConcerns() async* {
    await for (final snapshot in _verifiedQuerySnapshots(
      firestore
          .collection('morning_review_standing_concerns')
          .where('status', whereIn: const ['active', 'resolved'])
          .snapshots(includeMetadataChanges: true),
      'standing concerns',
    )) {
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
              concern.resolvedAt?.add(const Duration(days: 14)).isAfter(now) ==
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
      yield List.unmodifiable(values);
    }
  }

  Stream<List<MorningReviewConcernCheck>> watchConcernChecks(
    String sessionId,
  ) async* {
    await for (final snapshot in _sessionQuery(
      'morning_review_concern_checks',
      sessionId,
    )) {
      final values = snapshot.docs
          .map(
            (document) =>
                MorningReviewConcernCheck.fromMap(document.data(), document.id),
          )
          .toList(growable: false)
        ..sort((left, right) => left.checkedAt.compareTo(right.checkedAt));
      yield List.unmodifiable(values);
    }
  }

  Stream<MorningReviewDocument?> watchDocument(String sessionId) async* {
    await for (final snapshot in _verifiedDocumentSnapshots(
      firestore
          .collection('morning_review_documents')
          .doc(sessionId)
          .snapshots(includeMetadataChanges: true),
      'finalized document',
    )) {
      if (!snapshot.exists) {
        yield null;
        continue;
      }
      final document = MorningReviewDocument.fromMap(
        snapshot.data()!,
        snapshot.id,
      );
      yield document.expiresAt.isAfter(DateTime.now()) ? document : null;
    }
  }

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
  }) async* {
    await for (final snapshot in snapshots) {
      final metadata = metadataOf(snapshot);
      if (metadata.isFromCache || metadata.hasPendingWrites) {
        yield* Stream<T>.error(MorningReviewFeedUnverifiedException(source));
        continue;
      }
      yield snapshot;
    }
  }
}
