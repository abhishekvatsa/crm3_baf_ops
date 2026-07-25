import 'package:crm3_baf_ops/features/maintenance_workflow/domain/maintenance_lane.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_actor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seven accountable lanes include governed shared work', () {
    expect(MaintenanceLaneCatalog.crm3.definitions.length, 7);
    expect(
      MaintenanceLaneCatalog.crm3.definitions.map((lane) => lane.id),
      contains(MaintenanceLaneId.shared),
    );
  });

  test('shared lane is delegated under the generated plant policy', () {
    final definition =
        MaintenanceLaneCatalog.crm3.definition(MaintenanceLaneId.shared);
    expect(definition.code, 'SHARED');
    expect(definition.displayName, 'Shared / Safety / Administration');
    expect(definition.delegated, isTrue);
    expect(definition.delegationBasis, 'plant-v2-shared-coordination');
  });

  test('EMD is a first-class lane coordinated by Admin/SI', () {
    final definition =
        MaintenanceLaneCatalog.crm3.definition(MaintenanceLaneId.emd);
    expect(definition.delegated, isTrue);
    expect(definition.delegationBasis, 'plant-v1-emd-admin-si-coordination');
    expect(
      definition.mayAcknowledge(
        WorkflowActorContext(
          uid: 'a',
          displayName: 'A',
          roleKeys: const ['admin'],
        ),
      ),
      isTrue,
    );
    expect(
      definition.mayAcknowledge(
        WorkflowActorContext(
          uid: 'c',
          displayName: 'C',
          roleKeys: const ['contractSupervisor'],
        ),
      ),
      isFalse,
    );
  });
}
