import 'package:crm3_baf_ops/features/maintenance_workflow/data/equipment_status_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/equipment_command_identity.dart';
import 'package:flutter_test/flutter_test.dart';

EquipmentStatusRecord _custom({
  required String assetClassId,
  required String assetInstanceId,
}) =>
    EquipmentStatusRecord()
      ..firestoreId = 'governedCustom_${assetClassId}_$assetInstanceId'
      ..assetTypeKey = 'governedCustom'
      ..assetNumber = 3
      ..assetClassId = assetClassId
      ..assetInstanceId = assetInstanceId;

void main() {
  test('custom equipment commands carry exact physical identity', () {
    final identity = EquipmentCommandIdentity.fromRecord(
      _custom(
        assetClassId: 'class-furnace',
        assetInstanceId: 'asset-furnace-3',
      ),
    );

    expect(
      identity.aggregateId,
      'equipment_governedCustom_class-furnace_asset-furnace-3',
    );
    expect(identity.payload, <String, Object?>{
      'assetTypeKey': 'governedCustom',
      'assetNumber': 3,
      'assetClassId': 'class-furnace',
      'assetInstanceId': 'asset-furnace-3',
    });
  });

  test('same-number custom assets have distinct command aggregates', () {
    final furnace = EquipmentCommandIdentity.fromRecord(
      _custom(
        assetClassId: 'class-furnace',
        assetInstanceId: 'asset-furnace-3',
      ),
    );
    final cooler = EquipmentCommandIdentity.fromRecord(
      _custom(assetClassId: 'class-cooler', assetInstanceId: 'asset-cooler-3'),
    );

    expect(furnace.aggregateId, isNot(cooler.aggregateId));
  });

  test('legacy equipment command identity remains type and number based', () {
    final record =
        EquipmentStatusRecord()
          ..firestoreId = 'furnace_3'
          ..assetTypeKey = 'furnace'
          ..assetNumber = 3;

    final identity = EquipmentCommandIdentity.fromRecord(record);

    expect(identity.aggregateId, 'equipment_furnace_3');
    expect(identity.payload, <String, Object?>{
      'assetTypeKey': 'furnace',
      'assetNumber': 3,
    });
  });

  test('incomplete or inconsistent custom identity fails before dispatch', () {
    final missing =
        EquipmentStatusRecord()
          ..firestoreId = 'governedCustom_3'
          ..assetTypeKey = 'governedCustom'
          ..assetNumber = 3;
    final inconsistent = _custom(
      assetClassId: 'class-furnace',
      assetInstanceId: 'asset-furnace-3',
    )..firestoreId = 'governedCustom_class-cooler_asset-cooler-3';

    expect(
      () => EquipmentCommandIdentity.fromRecord(missing),
      throwsFormatException,
    );
    expect(
      () => EquipmentCommandIdentity.fromRecord(inconsistent),
      throwsFormatException,
    );
  });
}
