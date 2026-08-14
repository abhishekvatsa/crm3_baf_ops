import '../data/equipment_status_record.dart';

class EquipmentCommandIdentity {
  final String aggregateId;
  final Map<String, Object?> payload;

  const EquipmentCommandIdentity._({
    required this.aggregateId,
    required this.payload,
  });

  factory EquipmentCommandIdentity.fromRecord(EquipmentStatusRecord record) {
    final assetTypeKey = record.assetTypeKey.trim();
    if (assetTypeKey.isEmpty || record.assetNumber < 1) {
      throw const FormatException('Equipment command identity is incomplete.');
    }

    final payload = <String, Object?>{
      'assetTypeKey': assetTypeKey,
      'assetNumber': record.assetNumber,
    };
    if (assetTypeKey != 'governedCustom') {
      return EquipmentCommandIdentity._(
        aggregateId: 'equipment_${assetTypeKey}_${record.assetNumber}',
        payload: Map<String, Object?>.unmodifiable(payload),
      );
    }

    final assetClassId = record.assetClassId?.trim();
    final assetInstanceId = record.assetInstanceId?.trim();
    final firestoreId = record.firestoreId?.trim();
    if (assetClassId == null ||
        assetClassId.isEmpty ||
        assetInstanceId == null ||
        assetInstanceId.isEmpty ||
        firestoreId == null ||
        firestoreId.isEmpty) {
      throw const FormatException(
        'Governed custom equipment command identity is incomplete.',
      );
    }
    final expectedFirestoreId =
        'governedCustom_${assetClassId}_$assetInstanceId';
    if (firestoreId != expectedFirestoreId) {
      throw const FormatException(
        'Governed custom equipment projection identity is inconsistent.',
      );
    }
    payload
      ..['assetClassId'] = assetClassId
      ..['assetInstanceId'] = assetInstanceId;
    return EquipmentCommandIdentity._(
      aggregateId: 'equipment_$expectedFirestoreId',
      payload: Map<String, Object?>.unmodifiable(payload),
    );
  }
}
