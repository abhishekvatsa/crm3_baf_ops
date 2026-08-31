import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/morning_review_models.dart';

class MorningReviewRepository {
  const MorningReviewRepository(this.firestore);

  final FirebaseFirestore firestore;

  Stream<MorningReviewSession?> watchSession(String sessionId) async* {
    await for (final snapshot in firestore
        .collection('morning_review_sessions')
        .doc(sessionId)
        .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
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
    await for (final snapshot in firestore
        .collection('morning_review_sessions')
        .orderBy('plantDay', descending: true)
        .limit(15)
        .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
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
      if (!_isServerVerified(snapshot)) continue;
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
      if (!_isServerVerified(snapshot)) continue;
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
      if (!_isServerVerified(snapshot)) continue;
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
    await for (final snapshot in firestore
        .collection('morning_review_actions')
        .where('status', whereIn: const ['open', 'accepted'])
        .limit(250)
        .snapshots(includeMetadataChanges: true)) {
      if (!_isServerVerified(snapshot)) continue;
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
    await for (final snapshot in firestore
        .collection('morning_review_standing_concerns')
        .limit(250)
        .snapshots(includeMetadataChanges: true)) {
      if (!_isServerVerified(snapshot)) continue;
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
      if (!_isServerVerified(snapshot)) continue;
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
    await for (final snapshot in firestore
        .collection('morning_review_documents')
        .doc(sessionId)
        .snapshots(includeMetadataChanges: true)) {
      if (snapshot.metadata.isFromCache || snapshot.metadata.hasPendingWrites) {
        continue;
      }
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
  ) => firestore
      .collection(collection)
      .where('sessionId', isEqualTo: sessionId)
      .limit(250)
      .snapshots(includeMetadataChanges: true);

  bool _isServerVerified(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      !snapshot.metadata.isFromCache && !snapshot.metadata.hasPendingWrites;
}
