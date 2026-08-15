import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';

Map<String, dynamic> profileMap({
  String state = 'available',
  String? baseId,
  int? baseNumber,
  String? baseName,
  String? linkageId,
}) => <String, dynamic>{
  'schemaVersion': 1,
  'innerCoverId': 'cover-1',
  'assetClassId': 'class-1',
  'assetClassCode': 'INNER_COVER',
  'assetClassName': 'Inner Cover',
  'serialNumber': 'GR-26',
  'normalizedSerialNumber': 'GR26',
  'sourceType': 'purchased',
  'lifecycleState': state,
  'traceabilityGrade': 'T3',
  'supplierOrFabricator': 'Supplier',
  'receivedOrCompletedOn': DateTime.utc(2026, 8, 1),
  'drawingReference': 'IC-001',
  'materialGrade': 'SS 321',
  'acceptanceReference': 'ACC-1',
  'acceptedAt': DateTime.utc(2026, 8, 2),
  'acceptedByUid': 'admin-1',
  'acceptedByName': 'Admin One',
  'currentBaseAssetInstanceId': baseId,
  'currentBaseAssetNumber': baseNumber,
  'currentBaseAssetName': baseName,
  'currentLinkageId': linkageId,
  'version': 2,
  'createdAt': DateTime.utc(2026, 8, 1),
  'updatedAt': DateTime.utc(2026, 8, 2),
  'lastMutationId': 'mutation-1',
};

void main() {
  test('profile decoder preserves complete installed projection', () {
    final profile = InnerCoverProfile.fromMap(
      profileMap(
        state: 'installed',
        baseId: 'base-201',
        baseNumber: 201,
        baseName: 'Base 201',
        linkageId: 'link-1',
      ),
      'cover-1',
    );
    expect(profile.serialNumber, 'GR-26');
    expect(profile.normalizedSerialNumber, 'GR26');
    expect(profile.currentBaseAssetNumber, 201);
    expect(profile.traceabilityGrade, InnerCoverTraceabilityGrade.t3);
  });

  test('partial or stale Base projection fails closed', () {
    expect(
      () => InnerCoverProfile.fromMap(
        profileMap(state: 'installed', baseId: 'base-201'),
        'cover-1',
      ),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () =>
          InnerCoverProfile.fromMap(profileMap(baseId: 'base-201'), 'cover-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('partial acceptance evidence and reversed chronology fail closed', () {
    expect(
      () => InnerCoverProfile.fromMap({
        ...profileMap(),
        'acceptedByUid': null,
      }, 'cover-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
    expect(
      () => InnerCoverProfile.fromMap({
        ...profileMap(),
        'acceptedAt': DateTime.utc(2026, 7, 31),
      }, 'cover-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('linkage closure requires complete removal evidence', () {
    final active = <String, dynamic>{
      'schemaVersion': 1,
      'linkageId': 'link-1',
      'baseAssetInstanceId': 'base-201',
      'baseAssetNumber': 201,
      'baseAssetName': 'Base 201',
      'innerCoverId': 'cover-1',
      'innerCoverSerialNumber': 'GR26',
      'installedAt': DateTime.utc(2026, 8, 1),
      'installedByUid': 'admin-1',
      'installedByName': 'Admin One',
      'removedAt': null,
      'removalAction': null,
      'removalReason': null,
      'active': true,
      'version': 1,
    };
    expect(InnerCoverLinkage.fromMap(active, 'link-1').active, isTrue);
    expect(
      () => InnerCoverLinkage.fromMap({
        ...active,
        'active': false,
        'removedAt': DateTime.utc(2026, 8, 2),
      }, 'link-1'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
