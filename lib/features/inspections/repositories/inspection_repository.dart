import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/inspection_campaign.dart';

class InspectionRepository {
  InspectionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<InspectionDefinition>> watchDefinitions() => _firestore
      .collection('inspection_definitions')
      .snapshots()
      .map((snapshot) {
        final rows = snapshot.docs
          .map((doc) => InspectionDefinition.fromMap(doc.data(), doc.id))
          .toList(growable: false)..sort((left, right) {
          final status = left.status.index.compareTo(right.status.index);
          return status != 0
              ? status
              : left.frozen.title.compareTo(right.frozen.title);
        });
        return List<InspectionDefinition>.unmodifiable(rows);
      });

  Stream<List<InspectionCampaign>> watchCampaigns() =>
      _firestore.collection('inspection_campaigns').snapshots().map((snapshot) {
        final rows = snapshot.docs
          .map((doc) => InspectionCampaign.fromMap(doc.data(), doc.id))
          .toList(growable: false)..sort((left, right) {
          final status = left.status.index.compareTo(right.status.index);
          return status != 0
              ? status
              : right.createdAt.compareTo(left.createdAt);
        });
        return List<InspectionCampaign>.unmodifiable(rows);
      });

  Stream<List<InspectionObservation>> watchObservations(String campaignId) =>
      _firestore
          .collection('inspection_observations')
          .where('campaignId', isEqualTo: campaignId)
          .snapshots()
          .map((snapshot) {
            final rows = snapshot.docs
              .map((doc) => InspectionObservation.fromMap(doc.data(), doc.id))
              .toList(growable: false)..sort(
              (left, right) => right.observedAt.compareTo(left.observedAt),
            );
            return List<InspectionObservation>.unmodifiable(rows);
          });

  Stream<List<InspectionFinding>> watchFindings(String campaignId) => _firestore
      .collection('inspection_findings')
      .where('campaignId', isEqualTo: campaignId)
      .snapshots()
      .map(_decodeFindings);

  Stream<List<InspectionFinding>> watchAllFindings() => _firestore
      .collection('inspection_findings')
      .snapshots()
      .map(_decodeFindings);

  List<InspectionFinding> _decodeFindings(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final rows = snapshot.docs
      .map((doc) => InspectionFinding.fromMap(doc.data(), doc.id))
      .toList(growable: false)..sort((left, right) {
      final blocking = right.blocksCampaignClosure ? 1 : 0;
      final leftBlocking = left.blocksCampaignClosure ? 1 : 0;
      final order = blocking.compareTo(leftBlocking);
      return order != 0 ? order : right.updatedAt.compareTo(left.updatedAt);
    });
    return List<InspectionFinding>.unmodifiable(rows);
  }
}
