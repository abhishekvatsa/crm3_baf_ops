import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/inspection_campaign.dart';
import '../data/inspection_evidence_snapshot.dart';
import '../../../core/serialization/tolerant_snapshot_decode.dart';

class InspectionRepository {
  InspectionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _serverRead = GetOptions(source: Source.server);
  static const _reportReadAttempts = 3;

  Stream<List<InspectionDefinition>> watchDefinitions() => _firestore
      .collection('inspection_definitions')
      .snapshots()
      .map((snapshot) {
        final rows =
            decodeSnapshotDocuments(snapshot, InspectionDefinition.fromMap, source: 'InspectionDefinition')
                .toList(growable: false)
              ..sort((left, right) {
                final status = left.status.index.compareTo(right.status.index);
                return status != 0
                    ? status
                    : left.frozen.title.compareTo(right.frozen.title);
              });
        return List<InspectionDefinition>.unmodifiable(rows);
      });

  Stream<InspectionEvidenceSnapshot<InspectionCampaign>> watchCampaigns() =>
      _firestore
          .collection('inspection_campaigns')
          .snapshots(includeMetadataChanges: true)
          .map((snapshot) {
            final rows =
                decodeSnapshotDocuments(snapshot, InspectionCampaign.fromMap, source: 'InspectionCampaign')
                    .toList(growable: false)
                  ..sort((left, right) {
                    final status = left.status.index.compareTo(
                      right.status.index,
                    );
                    return status != 0
                        ? status
                        : right.createdAt.compareTo(left.createdAt);
                  });
            return InspectionEvidenceSnapshot<InspectionCampaign>(
              records: List<InspectionCampaign>.unmodifiable(rows),
              isServerVerified:
                  !snapshot.metadata.isFromCache &&
                  !snapshot.metadata.hasPendingWrites,
            );
          });

  Stream<InspectionEvidenceSnapshot<InspectionObservation>> watchObservations(
    String campaignId,
  ) => _firestore
      .collection('inspection_observations')
      .where('campaignId', isEqualTo: campaignId)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) {
        return InspectionEvidenceSnapshot<InspectionObservation>(
          records: _decodeObservations(snapshot),
          isServerVerified:
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
        );
      });

  Stream<InspectionEvidenceSnapshot<InspectionFinding>> watchFindings(
    String campaignId,
  ) => _firestore
      .collection('inspection_findings')
      .where('campaignId', isEqualTo: campaignId)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => InspectionEvidenceSnapshot<InspectionFinding>(
          records: _decodeFindings(snapshot),
          isServerVerified:
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
        ),
      );

  Stream<List<InspectionFinding>> watchAllFindings() => _firestore
      .collection('inspection_findings')
      .snapshots()
      .map(_decodeFindings);

  Future<InspectionCampaignReportEvidence> readCampaignReportEvidence(
    String campaignId,
  ) async {
    InspectionCampaignReportEvidence? previous;
    for (var attempt = 0; attempt < _reportReadAttempts; attempt += 1) {
      final current = await _readCampaignReportEvidenceOnce(campaignId);
      if (previous != null &&
          current.hasSameRevisionAs(previous) &&
          current.isInternallyComplete) {
        return current;
      }
      previous = current;
    }
    throw StateError(
      'Complete inspection evidence could not be held stable while the report '
      'was being prepared. '
      'Please try again.',
    );
  }

  Future<InspectionCampaignReportEvidence> _readCampaignReportEvidenceOnce(
    String campaignId,
  ) async {
    final reads = await Future.wait<Object>(<Future<Object>>[
      _firestore
          .collection('inspection_campaigns')
          .doc(campaignId)
          .get(_serverRead),
      _firestore
          .collection('inspection_observations')
          .where('campaignId', isEqualTo: campaignId)
          .get(_serverRead),
      _firestore
          .collection('inspection_findings')
          .where('campaignId', isEqualTo: campaignId)
          .get(_serverRead),
    ]);
    final campaignSnapshot = reads[0] as DocumentSnapshot<Map<String, dynamic>>;
    final observationSnapshot = reads[1] as QuerySnapshot<Map<String, dynamic>>;
    final findingSnapshot = reads[2] as QuerySnapshot<Map<String, dynamic>>;
    final campaignData = campaignSnapshot.data();
    if (!campaignSnapshot.exists || campaignData == null) {
      throw StateError('The inspection campaign is no longer available.');
    }
    return InspectionCampaignReportEvidence(
      campaign: InspectionCampaign.fromMap(campaignData, campaignSnapshot.id),
      // Strict on purpose. A browse list can show what decoded and say it is
      // incomplete; report evidence claiming a complete campaign cannot. The
      // completeness check validates only the findings that survived
      // decoding, so a dropped finding would be absent from both reads, the
      // revisions would match, and an incomplete population would pass as
      // complete.
      observations: observationSnapshot.docs
          .map((doc) => InspectionObservation.fromMap(doc.data(), doc.id))
          .toList(growable: false),
      findings: findingSnapshot.docs
          .map((doc) => InspectionFinding.fromMap(doc.data(), doc.id))
          .toList(growable: false),
    );
  }

  List<InspectionObservation> _decodeObservations(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rows =
        decodeSnapshotDocuments(snapshot, InspectionObservation.fromMap, source: 'InspectionObservation')
            .toList(growable: false)
          ..sort((left, right) {
            final observed = right.observedAt.compareTo(left.observedAt);
            return observed != 0 ? observed : left.id.compareTo(right.id);
          });
    return List<InspectionObservation>.unmodifiable(rows);
  }

  List<InspectionFinding> _decodeFindings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rows =
        decodeSnapshotDocuments(snapshot, InspectionFinding.fromMap, source: 'InspectionFinding')
            .toList(growable: false)
          ..sort((left, right) {
            final blocking = right.blocksCampaignClosure ? 1 : 0;
            final leftBlocking = left.blocksCampaignClosure ? 1 : 0;
            final order = blocking.compareTo(leftBlocking);
            if (order != 0) return order;
            final updatedAt = right.updatedAt.compareTo(left.updatedAt);
            return updatedAt != 0 ? updatedAt : left.id.compareTo(right.id);
          });
    return List<InspectionFinding>.unmodifiable(rows);
  }
}
