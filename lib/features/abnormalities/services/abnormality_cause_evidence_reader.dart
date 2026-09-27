import 'package:cloud_firestore/cloud_firestore.dart';

class AbnormalityCauseEvidence {
  const AbnormalityCauseEvidence({required this.id, required this.label});
  final String id;
  final String label;
}

/// Read-only choices for an already admitted abnormality form. The governed
/// mutation rechecks same-charge identity and process classification at save.
class AbnormalityCauseEvidenceReader {
  AbnormalityCauseEvidenceReader({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<AbnormalityCauseEvidence>> load({
    required int sourceChargeNo,
    required bool maintenance,
    String? abnormalityId,
  }) async {
    final snapshot = await _firestore
        .collection(
          maintenance ? 'maintenance_records' : 'charge_abnormalities',
        )
        .where(
          maintenance ? 'chargeNoAtEvent' : 'sourceChargeNo',
          isEqualTo: sourceChargeNo,
        )
        .get(const GetOptions(source: Source.server));
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          if (data['isDeleted'] == true ||
              (!maintenance && doc.id == abnormalityId)) {
            return false;
          }
          if (maintenance) return true;
          final assessment = data['assessment'];
          return assessment is Map
              ? assessment['observationKind'] == 'processEquipment' &&
                    const [
                      'process',
                      'equipment',
                      'other',
                    ].contains(data['category'])
              : const ['process', 'equipment'].contains(data['category']);
        })
        .map(
          (record) => AbnormalityCauseEvidence(
            id: record.id,
            label:
                (record.data()[maintenance
                            ? 'description'
                            : 'observedReason'] ??
                        'Recorded observation')
                    .toString(),
          ),
        )
        .toList(growable: false);
  }
}
