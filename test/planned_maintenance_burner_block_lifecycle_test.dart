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
  String evidenceKind = 'inspection',
  Map<String, BurnerEvidenceProvenance> evidenceProvenance = const {},
}) => BurnerConditionRound(
  evidenceKind: evidenceKind,
  evidenceProvenance: evidenceProvenance,
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
  test(
    'inherited UV age permits a later replacement despite newer compliance envelope',
    () {
      final round = _round(
        id: 'compliance',
        observedAt: DateTime.utc(2026, 9, 3),
        redHot: [],
        uvConditions: {1: BurnerUvCondition.melted},
        evidenceKind: 'directiveCompliance',
        evidenceProvenance: {
          'uv.1.condition': BurnerEvidenceProvenance(
            kind: 'inherited',
            sourceRoundId: 'old',
            observedAt: DateTime.utc(2026, 9, 1),
            observerUid: 'ops',
            observerName: 'Operations',
          ),
        },
      );
      final projection = projectBurnerBlockCondition(
        round: round,
        newerRedHotObservations: {},
        lifecycleEvents: [],
        currentUvLifecycleEvents: [
          _uvEvent(
            id: 'replacement',
            position: 1,
            completedAt: DateTime.utc(2026, 9, 2),
          ),
        ],
        currentCollectionsAuthoritative: true,
        assetInstanceId: 'furnace-7',
      );
      expect(
        projection.uvConditionsByPosition[1],
        BurnerUvCondition.serviceable,
      );
    },
  );

  test(
    'authoritative empty current collections do not resurrect raw history',
    () {
      final projection = projectBurnerBlockCondition(
        round: null,
        newerRedHotObservations: {},
        lifecycleEvents: [
          _event(
            id: 'history',
            position: 1,
            completedAt: DateTime.utc(2026, 9, 2),
          ),
        ],
        currentCollectionsAuthoritative: true,
        assetInstanceId: 'furnace-7',
      );
      expect(projection.replacementsByPosition, isEmpty);
    },
  );

  group('planned-maintenance burner-block lifecycle', () {
    test(
      'SAIL/RED and purchased provenance survive canonical serialization',
      () {
        final sail = ComponentAction.decode(
          ComponentAction.encode(<ComponentAction>[_replacement()]),
          source: 'planned maintenance',
        ).single;
        final purchased = ComponentAction.decode(
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
      final decoded = ComponentAction.decode(
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

    test(
      'the current projection overrides corrected raw history for its position',
      () {
        final rawEvent = _event(
          id: 'event-corrected-raw',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 29),
          completedAt: DateTime.utc(2026, 8, 29, 1),
        );
        final currentEvent = _event(
          id: 'event-current',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 28),
          completedAt: DateTime.utc(2026, 8, 28, 1),
        );
        final projection = projectBurnerBlockCondition(
          round: _round(
            id: 'round-red-hot',
            observedAt: DateTime.utc(2026, 8, 27),
            redHot: const [3],
          ),
          newerRedHotObservations: const <int, DateTime>{},
          lifecycleEvents: <BurnerBlockLifecycleEvent>[rawEvent],
          currentLifecycleEvents: <BurnerBlockLifecycleEvent>[currentEvent],
          assetInstanceId: 'furnace-7',
        );

        expect(projection.replacementsByPosition[3]?.eventId, 'event-current');
        expect(projection.redHotPositions, isEmpty);
      },
    );

    test(
      'a corrected effective installation time changes the snapshot key',
      () {
        final before = _event(
          id: 'event-current',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 21),
          completedAt: DateTime.utc(2026, 8, 21, 1),
        );
        final after = _event(
          id: 'event-current',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 23),
          completedAt: DateTime.utc(2026, 8, 23, 1),
        );
        BurnerBlockConditionProjection project(
          BurnerBlockLifecycleEvent event,
        ) => projectBurnerBlockCondition(
          round: _round(
            id: 'round-red-hot',
            observedAt: DateTime.utc(2026, 8, 22),
            redHot: const [3],
          ),
          newerRedHotObservations: const <int, DateTime>{},
          lifecycleEvents: const <BurnerBlockLifecycleEvent>[],
          currentLifecycleEvents: <BurnerBlockLifecycleEvent>[event],
          assetInstanceId: 'furnace-7',
        );

        final beforeProjection = project(before);
        final afterProjection = project(after);

        expect(beforeProjection.sourceKey, isNot(afterProjection.sourceKey));
        expect(beforeProjection.redHotPositions, contains(3));
        expect(afterProjection.redHotPositions, isEmpty);
      },
    );

    test(
      'a corrected UV current row restores a later observed fault despite raw history',
      () {
        final original = _uvEvent(
          id: 'uv-corrected',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 23),
          completedAt: DateTime.utc(2026, 8, 24),
        );
        final corrected = _uvEvent(
          id: 'uv-corrected',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 21),
          completedAt: DateTime.utc(2026, 8, 24),
        );
        BurnerBlockConditionProjection project(
          List<UvDetectorLifecycleEvent> current,
        ) => projectBurnerBlockCondition(
          round: _round(
            id: 'uv-fault',
            observedAt: DateTime.utc(2026, 8, 22),
            redHot: [],
            uvConditions: {3: BurnerUvCondition.melted},
          ),
          newerRedHotObservations: {},
          lifecycleEvents: [],
          uvLifecycleEvents: [original],
          currentUvLifecycleEvents: current,
          currentCollectionsAuthoritative: true,
          assetInstanceId: 'furnace-7',
        );
        final before = project([original]);
        final after = project([corrected]);
        expect(before.uvConditionsByPosition[3], BurnerUvCondition.serviceable);
        expect(after.uvConditionsByPosition[3], BurnerUvCondition.melted);
        expect(
          after.uvReplacementsByPosition[3]?.actionPerformedAt,
          DateTime.utc(2026, 8, 21),
        );
        expect(before.sourceKey, isNot(after.sourceKey));
        final missing = project([]);
        expect(missing.uvReplacementsByPosition, isEmpty);
        expect(missing.uvConditionsByPosition[3], BurnerUvCondition.melted);
      },
    );

    test(
      'UV correction can select an earlier event as authoritative current installation',
      () {
        final original = _uvEvent(
          id: 'later-raw',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 29),
          completedAt: DateTime.utc(2026, 8, 30),
        );
        final nowCurrent = _uvEvent(
          id: 'earlier-current',
          position: 3,
          actionPerformedAt: DateTime.utc(2026, 8, 27),
          completedAt: DateTime.utc(2026, 8, 28),
        );
        final projection = projectBurnerBlockCondition(
          round: null,
          newerRedHotObservations: {},
          lifecycleEvents: [],
          uvLifecycleEvents: [original, nowCurrent],
          currentUvLifecycleEvents: [nowCurrent],
          currentCollectionsAuthoritative: true,
          assetInstanceId: 'furnace-7',
        );
        expect(
          projection.uvReplacementsByPosition[3]?.eventId,
          'earlier-current',
        );
        expect(projection.latestEvidenceAt, nowCurrent.actionPerformedAt);
      },
    );

    test('a late report of earlier work stays history', () {
      // The same sequence the backend's own regression uses: the block at
      // position 3 was replaced on the 28th, and a replacement carried out on
      // the 27th is reported afterwards. What is installed now is what was
      // installed last, so the late report is history on both sides.
      final performedLater = _event(
        id: 'event-first',
        position: 3,
        actionPerformedAt: DateTime.utc(2026, 8, 28, 8),
        completedAt: DateTime.utc(2026, 8, 28, 9),
      );
      final recordedLater = _event(
        id: 'event-later-recorded',
        position: 3,
        actionPerformedAt: DateTime.utc(2026, 8, 27, 8),
        completedAt: DateTime.utc(2026, 8, 28, 10),
      );
      final performedLaterUv = _uvEvent(
        id: 'uv-first',
        position: 3,
        actionPerformedAt: DateTime.utc(2026, 8, 28, 8),
        completedAt: DateTime.utc(2026, 8, 28, 9),
      );
      final recordedLaterUv = _uvEvent(
        id: 'uv-later-recorded',
        position: 3,
        actionPerformedAt: DateTime.utc(2026, 8, 27, 8),
        completedAt: DateTime.utc(2026, 8, 28, 10),
      );

      final projection = projectBurnerBlockCondition(
        round: null,
        newerRedHotObservations: const <int, DateTime>{},
        lifecycleEvents: <BurnerBlockLifecycleEvent>[
          performedLater,
          recordedLater,
        ],
        uvLifecycleEvents: <UvDetectorLifecycleEvent>[
          performedLaterUv,
          recordedLaterUv,
        ],
        assetInstanceId: 'furnace-7',
      );

      expect(projection.replacementsByPosition[3]?.eventId, 'event-first');
      expect(projection.uvReplacementsByPosition[3]?.eventId, 'uv-first');
    });

    test('a tie on physical time is broken by the recorded time', () {
      final recordedFirst = _event(
        id: 'event-recorded-first',
        position: 4,
        actionPerformedAt: DateTime.utc(2026, 8, 28, 8),
        completedAt: DateTime.utc(2026, 8, 28, 9),
      );
      final recordedSecond = _event(
        id: 'event-recorded-second',
        position: 4,
        actionPerformedAt: DateTime.utc(2026, 8, 28, 8),
        completedAt: DateTime.utc(2026, 8, 28, 10),
      );

      final projection = projectBurnerBlockCondition(
        round: null,
        newerRedHotObservations: const <int, DateTime>{},
        lifecycleEvents: <BurnerBlockLifecycleEvent>[
          recordedSecond,
          recordedFirst,
        ],
        uvLifecycleEvents: const <UvDetectorLifecycleEvent>[],
        assetInstanceId: 'furnace-7',
      );

      // Delivery order carries no meaning, so the answer does not depend on it.
      expect(
        projection.replacementsByPosition[4]?.eventId,
        'event-recorded-second',
      );
    });
  });
}
