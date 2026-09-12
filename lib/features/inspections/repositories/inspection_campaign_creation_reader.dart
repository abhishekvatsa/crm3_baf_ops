import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/inspection_campaign_submission.dart';

/// One exact server document; browse streams/cache are never creation evidence.
class InspectionCampaignCreationReader {
  InspectionCampaignCreationReader({FirebaseFirestore? firestore})
    : _firestore = firestore;
  final FirebaseFirestore? _firestore;

  Future<Map<String, dynamic>> read(String campaignId) async {
    final snapshot = await (_firestore ?? FirebaseFirestore.instance)
        .collection('inspection_campaigns')
        .doc(campaignId)
        .get(const GetOptions(source: Source.server));
    if (snapshot.metadata.isFromCache ||
        snapshot.metadata.hasPendingWrites ||
        !snapshot.exists ||
        snapshot.data() == null) {
      throw const InspectionCampaignSubmissionException(
        'The programme acceptance is saved, but its current server record could not be confirmed. Check it again.',
      );
    }
    return snapshot.data()!;
  }
}
