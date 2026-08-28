import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_block_condition_projection.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_block_lifecycle_event.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/data/uv_detector_lifecycle_event.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:flutter_test/flutter_test.dart';

const _burnerBlockReference = AssetHierarchyReference(
  scope: AssetHierarchyReferenceScope.componentDefinitionOnAsset,
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  nodeId: 'node-burner-block',
  nodeVersion: 3,
  nodeName: 'Burner blocks and firing tubes',
  assetInstanceId: 'furnace-7',
  assetInstanceVersion: 4,
  assetNumber: 7,
  assetInstanceName: 'Furnace 7',
  hierarchyPath: <String>[
    'Furnace',
    'Refractory system',
    'Burner blocks and firing tubes',
  ],
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'RED',
  accountableRoleKeys: <String>['seniorRefractory'],
);

const _uvReference = AssetHierarchyReference(
  scope: AssetHierarchyReferenceScope.componentDefinitionOnAsset,
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  nodeId: 'node-uv-detector',
  nodeVersion: 3,
  nodeName: 'UV flame scanner and peep sight',
  assetInstanceId: 'furnace-7',
  assetInstanceVersion: 4,
  assetNumber: 7,
  assetInstanceName: 'Furnace 7',
  hierarchyPath: <String>[
    'Furnace',
    'Burner and flame supervision',
    'UV flame scanner and peep sight',
  ],
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Instrumentation & Automation',
  accountableRoleKeys: <String>['seniorInstrumentation'],
);

ComponentAction _replacement({
  BurnerBlockSupplyMode mode = BurnerBlockSupplyMode.sailRed,
  String? supplier,
  String? purchaseOrder,
  ActionStatus status = ActionStatus.resolved,
}) => ComponentAction(
  id: 'action-1',
  asset: 'Furnace 7',
  component: 'Burner blocks and firing tubes',
  hierarchyPath: _burnerBlockReference.hierarchyPath,
  assetHierarchyRef: _burnerBlockReference,
  actionType: ActionType.replacement,
  replacement: ReplacementType.newPart,
  status: status,
  createdAt: DateTime.utc(2026, 8, 28, 8),
  burnerPosition: 3,
  burnerBlockSupplyMode: mode,
  burnerBlockSupplierName: supplier,
  burnerBlockPurchaseOrderNumber: purchaseOrder,
);

BurnerBlockLifecycleEvent _event({
  required String id,
  required int position,
  required DateTime completedAt,
  DateTime? actionPerformedAt,
}) => BurnerBlockLifecycleEvent(
  eventId: id,
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetInstanceId: 'furnace-7',
  assetInstanceName: 'Furnace 7',
  assetNumber: 7,
  hierarchyNodeId: 'node-burner-block',
  hierarchyNodeName: 'Burner blocks and firing tubes',
  hierarchyPath: const <String>[
    'Furnace',
    'Refractory system',
    'Burner blocks and firing tubes',
  ],
  componentTag: null,
  burnerPosition: position,
  replacementDisposition: BurnerBlockReplacementDisposition.newPart,
  supplyMode: BurnerBlockLifecycleSupplyMode.sailRed,
  supplierName: null,
  purchaseOrderNumber: null,
  performedByName: 'Mechanical Technician One',
  sourceType: BurnerBlockLifecycleSourceType.workflowPlannedJob,
  sourceId: 'execution-1',
  sourceModuleId: 'module-1',
  sourceActionId: 'action-1',
  sourceActionIndex: 0,
  actionPerformedAt: actionPerformedAt ?? completedAt,
  completedAt: completedAt,
  completedByUid: 'supervisor-1',
  completedByName: 'Supervisor One',
  recordedAt: completedAt,
  version: 1,
);

UvDetectorLifecycleEvent _uvEvent({
  required String id,
  required int position,
  required DateTime completedAt,
  DateTime? actionPerformedAt,
}) => UvDetectorLifecycleEvent(
  eventId: id,
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetInstanceId: 'furnace-7',
  assetInstanceName: 'Furnace 7',
  assetNumber: 7,
  hierarchyNodeId: 'node-uv-detector',
  hierarchyNodeName: 'UV flame scanner and peep sight',
  hierarchyPath: _uvReference.hierarchyPath,
  componentTag: null,
  burnerPosition: position,
  replacementDisposition: UvDetectorReplacementDisposition.newPart,
  performedByName: 'I&A Technician One',
  sourceType: UvDetectorLifecycleSourceType.workflowPlannedJob,
  sourceId: 'execution-1',
  sourceModuleId: 'module-1',
  sourceActionId: 'action-uv-1',
  sourceActionIndex: 0,
  actionPerformedAt: actionPerformedAt ?? completedAt,
  completedAt: completedAt,
  completedByUid: 'supervisor-1',
  completedByName: 'Supervisor One',
  recordedAt: completedAt,
  version: 1,
);

BurnerConditionRound _round({
  required String id,
  required DateTime observedAt,
  required List<int> redHot,
  Map<int, BurnerUvCondition> uvConditions = const <int, BurnerUvCondition>{},
}) => BurnerConditionRound(
  roundId: id,
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetInstanceId: 'furnace-7',
  assetInstanceVersion: 4,
  assetNumber: 7,
  assetName: 'Furnace 7',
  observations: <BurnerConditionObservation>[
    for (var position = 1; position <= 8; position++)
      BurnerConditionObservation(
        position: position,
        flameObservation: BurnerRoundFlameObservation.seen,
        redHotObserved: redHot.contains(position),
      ),
  ],
  redHotPositions: redHot,
  microampPositions: const <int>[],
  uvObservations: <BurnerUvObservation>[
    for (var position = 1; position <= 8; position++)
      BurnerUvObservation(
        position: position,
        condition: uvConditions[position] ?? BurnerUvCondition.serviceable,
      ),
  ],
  observedAt: observedAt,
  recordedByUid: 'auditor-1',
  recordedByName: 'Auditor One',
  fingerprint: 'fingerprint-$id',
);

void main() {
  group('planned-maintenance burner-block lifecycle', () {
    test(
      'SAIL/RED and purchased provenance survive canonical serialization',
      () {
        final sail =
            ComponentAction.decode(
              ComponentAction.encode(<ComponentAction>[_replacement()]),
              source: 'planned maintenance',
            ).single;
        final purchased =
            ComponentAction.decode(
              ComponentAction.encode(<ComponentAction>[
                _replacement(
                  mode: BurnerBlockSupplyMode.purchased,
                  supplier: 'Industrial Refractories Ltd',
                  purchaseOrder: 'PO-2026-411',
                ),
              ]),
              source: 'planned maintenance',
            ).single;

        expect(sail.burnerPosition, 3);
        expect(sail.burnerBlockSupplyMode, BurnerBlockSupplyMode.sailRed);
        expect(
          purchased.burnerBlockSupplyMode,
          BurnerBlockSupplyMode.purchased,
        );
        expect(
          purchased.burnerBlockSupplierName,
          'Industrial Refractories Ltd',
        );
        expect(purchased.burnerBlockPurchaseOrderNumber, 'PO-2026-411');
      },
    );

    test('incomplete or contradictory lifecycle evidence fails closed', () {
      expect(
        () => ComponentAction(
          asset: 'Furnace 7',
          component: 'Burner blocks and firing tubes',
          hierarchyPath: _burnerBlockReference.hierarchyPath,
          assetHierarchyRef: _burnerBlockReference,
          actionType: ActionType.replacement,
          replacement: ReplacementType.newPart,
          burnerPosition: 3,
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => _replacement(supplier: 'Not valid for SAIL/RED'),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => _replacement(status: ActionStatus.inProgress),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('numbered governed UV replacement survives serialization', () {
      final action = ComponentAction(
        id: 'action-uv-1',
        asset: 'Furnace 7',
        component: _uvReference.nodeName,
        hierarchyPath: _uvReference.hierarchyPath,
        assetHierarchyRef: _uvReference,
        actionType: ActionType.replacement,
        replacement: ReplacementType.newPart,
        status: ActionStatus.resolved,
        burnerPosition: 3,
      );
      final decoded =
          ComponentAction.decode(
            ComponentAction.encode(<ComponentAction>[action]),
            source: 'planned UV replacement',
          ).single;

      expect(decoded.burnerPosition, 3);
      expect(decoded.isGovernedUvDetectorReplacement, isTrue);
    });

    test('UV replacement and later audit use physical evidence time', () {
      final missingAuditAt = DateTime.utc(2026, 8, 20, 8);
      final replacementAt = DateTime.utc(2026, 8, 21, 8);
      final laterAuditAt = DateTime.utc(2026, 8, 22, 8);
      final event = _uvEvent(
        id: 'uv-event-1',
        position: 3,
        completedAt: replacementAt,
      );
      final afterReplacement = projectBurnerBlockCondition(
        round: _round(
          id: 'round-missing',
          observedAt: missingAuditAt,
          redHot: const <int>[],
          uvConditions: const <int, BurnerUvCondition>{
            3: BurnerUvCondition.missing,
          },
        ),
        newerRedHotObservations: const <int, DateTime>{},
        lifecycleEvents: const <BurnerBlockLifecycleEvent>[],
        uvLifecycleEvents: <UvDetectorLifecycleEvent>[event],
        assetInstanceId: 'furnace-7',
      );
      final afterLaterAudit = projectBurnerBlockCondition(
        round: _round(
          id: 'round-later-missing',
          observedAt: laterAuditAt,
          redHot: const <int>[],
          uvConditions: const <int, BurnerUvCondition>{
            3: BurnerUvCondition.missing,
          },
        ),
        newerRedHotObservations: const <int, DateTime>{},
        lifecycleEvents: const <BurnerBlockLifecycleEvent>[],
        uvLifecycleEvents: <UvDetectorLifecycleEvent>[event],
        assetInstanceId: 'furnace-7',
      );

      expect(
        afterReplacement.uvConditionsByPosition[3],
        BurnerUvCondition.serviceable,
      );
      expect(
        afterLaterAudit.uvConditionsByPosition[3],
        BurnerUvCondition.missing,
      );
    });

    test('a completed replacement clears only older red-hot evidence', () {
      final auditAt = DateTime.utc(2026, 8, 20, 8);
      final replacementAt = DateTime.utc(2026, 8, 21, 8);
      final projection = projectBurnerBlockCondition(
        round: _round(id: 'round-1', observedAt: auditAt, redHot: const [3, 4]),
        newerRedHotObservations: const <int, DateTime>{},
        lifecycleEvents: <BurnerBlockLifecycleEvent>[
          _event(id: 'event-1', position: 3, completedAt: replacementAt),
        ],
        assetInstanceId: 'furnace-7',
      );

      expect(projection.redHotPositions, <int>{4});
      expect(projection.replacementsByPosition[3]?.eventId, 'event-1');
      expect(projection.latestEvidenceAt, replacementAt);
    });

    test('a later issue or audit supersedes replacement evidence', () {
      final replacementAt = DateTime.utc(2026, 8, 21, 8);
      final issueAt = DateTime.utc(2026, 8, 22, 8);
      final auditAt = DateTime.utc(2026, 8, 23, 8);
      final event = _event(
        id: 'event-1',
        position: 3,
        completedAt: replacementAt,
      );

      final issueProjection = projectBurnerBlockCondition(
        round: null,
        newerRedHotObservations: <int, DateTime>{3: issueAt},
        lifecycleEvents: <BurnerBlockLifecycleEvent>[event],
        assetInstanceId: 'furnace-7',
      );
      final auditProjection = projectBurnerBlockCondition(
        round: _round(id: 'round-2', observedAt: auditAt, redHot: const [3]),
        newerRedHotObservations: const <int, DateTime>{},
        lifecycleEvents: <BurnerBlockLifecycleEvent>[event],
        assetInstanceId: 'furnace-7',
      );

      expect(issueProjection.redHotPositions, contains(3));
      expect(auditProjection.redHotPositions, contains(3));
    });

    test(
      'a delayed job closure does not erase a later red-hot observation',
      () {
        final performedAt = DateTime.utc(2026, 8, 21, 10);
        final redHotAt = DateTime.utc(2026, 8, 21, 12);
        final closedAt = DateTime.utc(2026, 8, 21, 14);
        final projection = projectBurnerBlockCondition(
          round: null,
          newerRedHotObservations: <int, DateTime>{3: redHotAt},
          lifecycleEvents: <BurnerBlockLifecycleEvent>[
            _event(
              id: 'delayed-closure',
              position: 3,
              actionPerformedAt: performedAt,
              completedAt: closedAt,
            ),
          ],
          assetInstanceId: 'furnace-7',
        );

        expect(projection.redHotPositions, contains(3));
        expect(projection.latestEvidenceAt, redHotAt);
      },
    );

    test('the newest replacement for the exact Furnace is authoritative', () {
      final older = _event(
        id: 'event-old',
        position: 3,
        completedAt: DateTime.utc(2026, 8, 20),
      );
      final newer = _event(
        id: 'event-new',
        position: 3,
        completedAt: DateTime.utc(2026, 8, 22),
      );
      final otherFurnace = BurnerBlockLifecycleEvent(
        eventId: 'event-other',
        assetClassId: newer.assetClassId,
        assetClassCode: newer.assetClassCode,
        assetClassName: newer.assetClassName,
        assetInstanceId: 'furnace-8',
        assetInstanceName: 'Furnace 8',
        assetNumber: 8,
        hierarchyNodeId: newer.hierarchyNodeId,
        hierarchyNodeName: newer.hierarchyNodeName,
        hierarchyPath: newer.hierarchyPath,
        componentTag: null,
        burnerPosition: 3,
        replacementDisposition: newer.replacementDisposition,
        supplyMode: newer.supplyMode,
        supplierName: null,
        purchaseOrderNumber: null,
        performedByName: 'Mechanical Technician Two',
        sourceType: newer.sourceType,
        sourceId: 'execution-other',
        sourceModuleId: null,
        sourceActionId: null,
        sourceActionIndex: 0,
        actionPerformedAt: DateTime.utc(2026, 8, 24),
        completedAt: DateTime.utc(2026, 8, 24),
        completedByUid: 'supervisor-1',
        completedByName: 'Supervisor One',
        recordedAt: DateTime.utc(2026, 8, 24),
        version: 1,
      );

      final projection = projectBurnerBlockCondition(
        round: null,
        newerRedHotObservations: const <int, DateTime>{},
        lifecycleEvents: <BurnerBlockLifecycleEvent>[
          older,
          otherFurnace,
          newer,
        ],
        assetInstanceId: 'furnace-7',
      );

      expect(projection.replacementsByPosition[3]?.eventId, 'event-new');
      expect(projection.replacementsByPosition, hasLength(1));
    });
  });
}
