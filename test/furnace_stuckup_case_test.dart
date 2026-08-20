import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:flutter_test/flutter_test.dart';

AssetHierarchyReference _baseReference({
  InnerCoverPositionState position = InnerCoverPositionState.linked,
}) {
  final linked = position == InnerCoverPositionState.linked;
  return AssetHierarchyReference(
    scope: AssetHierarchyReferenceScope.physicalAsset,
    assetClassId: 'base-class',
    assetClassCode: 'BASE',
    assetClassName: 'Base',
    nodeId: 'base-root',
    nodeVersion: 3,
    nodeName: 'Base',
    assetInstanceId: 'base-117',
    assetInstanceVersion: 8,
    assetNumber: 117,
    assetInstanceName: 'Base 117',
    hierarchyPath: const <String>['Base'],
    ownershipStatus: AssetOwnershipStatus.confirmed,
    ownerDiscipline: 'Operations',
    accountableRoleKeys: const <String>['operations'],
    innerCoverAssociation: InnerCoverEventReference(
      baseAssetInstanceId: 'base-117',
      baseAssetNumber: 117,
      positionState: position,
      innerCoverId: linked ? 'inner-cover-gr26' : null,
      innerCoverSerialNumber: linked ? 'GR26' : null,
      linkageId: linked ? 'link-gr26-base-117' : null,
      assignmentVersion: linked ? 4 : null,
      linkedAt: linked ? DateTime.utc(2026, 8, 1) : null,
      eventAt: DateTime.utc(2026, 8, 20, 8),
      confirmedAt: DateTime.utc(2026, 8, 20, 8, 1),
      confirmedByUid: 'operations-1',
      confirmedByName: 'Operations One',
    ),
  );
}

void main() {
  test('round-trips the complete synchronized stuck-up contract', () {
    final value = FurnaceStuckupCase(
      baseNumber: 117,
      baseAssetReference: _baseReference(),
      suspectedCause: FurnaceStuckupCause.innerCoverBulging,
      operatingContext: FurnaceStuckupOperatingContext.postAnnealingRemoval,
    );

    final decoded = FurnaceStuckupCase.fromSynchronizedFields(
      value.toSynchronizedFields(),
      source: 'test ticket',
    );

    expect(decoded.baseNumber, 117);
    expect(decoded.innerCoverAssociation.innerCoverSerialNumber, 'GR26');
    expect(decoded.suspectedCause, FurnaceStuckupCause.innerCoverBulging);
  });

  test('partial synchronized fields fail closed', () {
    expect(
      () => FurnaceStuckupCase.readOptionalSynchronizedFields(<String, dynamic>{
        'furnaceStuckupSchemaVersion': 1,
        'stuckupBaseNumber': 117,
      }, source: 'partial ticket'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });

  test('requires a currently linked Inner Cover and reportable cause', () {
    expect(
      () => FurnaceStuckupCase(
        baseNumber: 117,
        baseAssetReference: _baseReference(
          position: InnerCoverPositionState.noneLinked,
        ),
        suspectedCause: FurnaceStuckupCause.unknown,
        operatingContext: FurnaceStuckupOperatingContext.other,
      ),
      throwsFormatException,
    );
    expect(
      () => FurnaceStuckupCase(
        baseNumber: 117,
        baseAssetReference: _baseReference(),
        suspectedCause: FurnaceStuckupCause.inconclusive,
        operatingContext: FurnaceStuckupOperatingContext.other,
      ),
      throwsFormatException,
    );
  });

  test('local metadata merge preserves unrelated business envelopes', () {
    final value = FurnaceStuckupCase(
      baseNumber: 117,
      baseAssetReference: _baseReference(),
      suspectedCause: FurnaceStuckupCause.combinedCondition,
      operatingContext: FurnaceStuckupOperatingContext.maintenanceMovement,
    );
    final merged = mergeFurnaceStuckupIntoMaintenanceMetadata(
      '{"burnerLockout":{"schemaVersion":1}}',
      value,
    );
    final decoded = Map<String, dynamic>.from(jsonDecode(merged) as Map);

    expect(decoded['burnerLockout'], isNotNull);
    expect(decoded['furnaceStuckup'], isNotNull);
    expect(FurnaceStuckupCase.tryDecodeLocal(merged)?.baseNumber, 117);
  });

  test(
    'intake is Base-first and binds physical confirmation to one linkage',
    () {
      final source =
          File(
            'lib/features/maintenance/presentation/maintenance_form.dart',
          ).readAsStringSync();

      expect(source, contains("_decoration('Base')"));
      expect(source, contains("label: Text('Different cover')"));
      expect(source, contains('_stuckupConfirmedLinkageId'));
      expect(source, contains('currentAssignment.linkageId !='));
      expect(source, contains("label: const Text('Open Inner Cover pairing')"));
      expect(
        source,
        contains('Correct the Base–Inner Cover pairing before raising'),
      );
    },
  );
}
