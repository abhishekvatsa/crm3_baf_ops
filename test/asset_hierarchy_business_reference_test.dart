import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';

const definitionReference = AssetHierarchyReference(
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  nodeId: 'definition-pressure-transmitter',
  nodeVersion: 4,
  nodeName: 'Pressure transmitter',
  hierarchyPath: <String>['Pressure system', 'Pressure transmitter'],
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Instrumentation',
  accountableRoleKeys: <String>['seniorInstrumentation'],
);

const installedReference = AssetHierarchyReference(
  scope: AssetHierarchyReferenceScope.installedComponent,
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  nodeId: 'definition-pressure-transmitter',
  nodeVersion: 4,
  nodeName: 'Pressure transmitter',
  assetInstanceId: 'furnace-7',
  assetInstanceVersion: 3,
  assetNumber: 7,
  assetInstanceName: 'Furnace 7',
  componentInstanceId: 'furnace-7-pressure-transmitter',
  componentInstanceVersion: 2,
  componentTag: 'PT-701',
  hierarchyPath: <String>['Pressure system', 'Pressure transmitter'],
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Instrumentation',
  accountableRoleKeys: <String>['seniorInstrumentation'],
);

void main() {
  test('templates retain reusable definition scope', () {
    final template =
        JobTemplate()
          ..firestoreId = 'template-1'
          ..jobName = 'Furnace pressure audit'
          ..applicableAssetType = AssetType.furnace
          ..assetHierarchyRefJson = definitionReference.encode()
          ..createdAt = DateTime.utc(2026)
          ..updatedAt = DateTime.utc(2026);

    expect(
      template.assetHierarchyReference?.scope,
      AssetHierarchyReferenceScope.definition,
    );
    expect(template.toMap()['assetHierarchyRefJson'], definitionReference.encode());
  });

  test('tickets and work actions retain installed physical identity', () {
    final ticket =
        MaintenanceRecord()
          ..firestoreId = 'ticket-1'
          ..assetHierarchyRefJson = installedReference.encode();
    expect(ticket.assetHierarchyReference?.assetInstanceId, 'furnace-7');
    expect(
      ticket.assetHierarchyReference?.componentInstanceId,
      'furnace-7-pressure-transmitter',
    );

    final encoded = ComponentAction.encode(<ComponentAction>[
      ComponentAction(
        asset: 'Furnace 7',
        component: 'Pressure transmitter',
        tag: 'PT-701',
        assetHierarchyRef: installedReference,
        actionType: ActionType.issue,
        status: ActionStatus.issue,
        issue: 'Pressure indication drifts at operating temperature.',
        createdAt: DateTime.utc(2026),
      ),
    ]);
    final decoded = ComponentAction.decode(encoded, source: 'work action');
    expect(decoded.single.assetHierarchyRef?.scope,
        AssetHierarchyReferenceScope.installedComponent);
    expect(decoded.single.assetHierarchyRef?.componentTag, 'PT-701');
  });

  test('malformed stored references fail closed at every business boundary', () {
    final ticket = MaintenanceRecord()..assetHierarchyRefJson = '{"schemaVersion":2}';
    expect(
      () => ticket.assetHierarchyReference,
      throwsA(isA<PersistedDataFormatException>()),
    );

    final malformedAction = ComponentAction(
      asset: 'Furnace 7',
      component: 'Pressure transmitter',
      actionType: ActionType.issue,
      status: ActionStatus.issue,
      createdAt: DateTime.utc(2026),
    ).toMap()
      ..['assetHierarchyRef'] = <String, dynamic>{'schemaVersion': 2};
    expect(
      () => ComponentAction.fromMap(malformedAction, source: 'work action'),
      throwsA(isA<PersistedDataFormatException>()),
    );
  });
}
