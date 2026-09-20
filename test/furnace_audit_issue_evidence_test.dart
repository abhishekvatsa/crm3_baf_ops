import 'dart:convert';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/domain/furnace_audit_draft.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_administrative_closure.dart';
import 'package:flutter_test/flutter_test.dart';

final observed = DateTime.utc(2026, 9, 20, 8);
final closed = observed.add(const Duration(hours: 2));

AssetClassRecord assetClass(String id) => AssetClassRecord(
  id: id,
  code: 'FR',
  name: 'Furnace',
  majorArea: 'BAF',
  legacyAssetTypeKey: 'furnace',
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: observed,
  createdByUid: 'admin',
  updatedAt: observed,
  updatedByUid: 'admin',
  lastMutationId: 'class-$id',
);

AssetInstanceRecord asset(
  String id, {
  String classId = 'class-a',
  int number = 7,
}) => AssetInstanceRecord(
  id: id,
  assetClassId: classId,
  assetClassCode: 'FR',
  assetClassName: 'Furnace',
  assetNumber: number,
  name: 'Furnace $number',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 8,
  version: 2,
  createdAt: observed,
  updatedAt: observed,
  lastMutationId: 'asset-$id',
);

String reference({
  String id = 'furnace-a',
  String classId = 'class-a',
  int number = 7,
}) => AssetHierarchyReference(
  scope: AssetHierarchyReferenceScope.physicalAsset,
  assetClassId: classId,
  assetClassCode: 'FR',
  assetClassName: 'Furnace',
  nodeId: id,
  nodeVersion: 1,
  nodeName: 'Furnace $number',
  assetInstanceId: id,
  assetInstanceVersion: 1,
  assetNumber: number,
  assetInstanceName: 'Furnace $number',
  hierarchyPath: ['Furnace', 'Furnace $number'],
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
).encode();

MaintenanceRecord concern() => MaintenanceRecord()
  ..firestoreId = 'issue-a'
  ..version = 2
  ..isSynced = true
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..classification = burnerLockoutClassification
  ..assetHierarchyRefJson = reference()
  ..status = TicketStatus.closedWithoutResolution
  ..isResolved = true
  ..administrativeClosure = const IssueAdministrativeClosure(
    disposition: IssueAdministrativeClosureDisposition.stillRelevant,
    reason: 'Unresolved burner condition still requires follow-up.',
  )
  ..createdAt = observed
  ..updatedAt = closed
  ..burnerLockoutCase = BurnerLockoutCase(
    positions: [3],
    redHotPositions: [3],
    commonMode: false,
    cycleStage: BurnerCycleStage.firing,
    flameObservation: BurnerObservation.notChecked,
    sparkObservation: BurnerObservation.notChecked,
    relightAttempts: 0,
    remainsLockedOut: true,
  );

FurnaceAuditIssueEvidence evidence(
  MaintenanceRecord ticket, {
  AssetInstanceRecord? furnace,
  List<AssetClassRecord>? classes,
  List<AssetInstanceRecord>? assets,
  BurnerConditionRound? round,
}) => FurnaceAuditIssueEvidence.fromTickets(
  tickets: [ticket],
  furnace: furnace ?? asset('furnace-a'),
  assetClasses: classes ?? [assetClass('class-a')],
  assets: assets ?? [furnace ?? asset('furnace-a')],
  round: round,
);

void main() {
  test(
    'still-relevant closure retains observation and exact revision dependency',
    () {
      final result = evidence(concern());
      expect(result.newerRedHotObservations, {3: observed});
      expect(result.basis, [
        {'id': 'issue-a', 'version': 2, 'updatedAt': closed.toIso8601String()},
      ]);
    },
  );

  test('relevance-ended and technically resolved issues do not contribute', () {
    final ended = concern()
      ..administrativeClosure = const IssueAdministrativeClosure(
        disposition: IssueAdministrativeClosureDisposition.relevanceEnded,
        reason: 'Follow-up is no longer relevant.',
      );
    final resolved = concern()
      ..status = TicketStatus.resolved
      ..administrativeClosure = null;
    for (final ticket in [ended, resolved]) {
      expect(evidence(ticket).basis, isEmpty);
      expect(evidence(ticket).newerRedHotObservations, isEmpty);
    }
  });

  test('an unaccepted local closure cannot clear the retained condition', () {
    final ticket = concern()
      ..isSynced = false
      ..status = TicketStatus.resolved
      ..administrativeClosure = null;
    expect(evidence(ticket).newerRedHotObservations, {3: observed});
  });

  test(
    'later inspection prevails without treating closure as a fresh observation',
    () {
      final round = BurnerConditionRound(
        roundId: 'round-new',
        assetClassId: 'class-a',
        assetClassCode: 'FR',
        assetClassName: 'Furnace',
        assetInstanceId: 'furnace-a',
        assetInstanceVersion: 2,
        assetNumber: 7,
        assetName: 'Furnace 7',
        redHotPositions: [],
        microampPositions: [],
        observations: [
          for (var position = 1; position <= 8; position++)
            BurnerConditionObservation(
              position: position,
              flameObservation: BurnerRoundFlameObservation.notChecked,
              redHotObserved: false,
            ),
        ],
        observedAt: observed.add(const Duration(hours: 1)),
        recordedByUid: 'operations',
        recordedByName: 'Operations',
        fingerprint: 'test',
      );
      final result = evidence(concern(), round: round);
      expect(result.newerRedHotObservations, isEmpty);
      expect(result.basis, hasLength(1));
    },
  );

  test(
    'canonical subject survives renumbering but never leaks to a reused number',
    () {
      expect(
        evidence(
          concern(),
          furnace: asset('furnace-a', number: 8),
        ).newerRedHotObservations,
        {3: observed},
      );
      expect(evidence(concern(), furnace: asset('furnace-b')).basis, isEmpty);
      expect(
        evidence(
          concern(),
          furnace: asset('furnace-a', classId: 'class-b'),
        ).basis,
        isEmpty,
      );
    },
  );

  test('legacy fallback requires one class and one physical candidate', () {
    final ticket = concern()..assetHierarchyRefJson = null;
    expect(evidence(ticket).basis, hasLength(1));
    expect(
      () => evidence(
        ticket,
        classes: [assetClass('class-a'), assetClass('retired-class')],
      ),
      throwsFormatException,
    );
    expect(
      () => evidence(
        ticket,
        assets: [asset('furnace-a'), asset('old-furnace-a')],
      ),
      throwsFormatException,
    );
  });

  test('definition-only legacy reference keeps its known class identity', () {
    final ticket = concern()
      ..assetHierarchyRefJson = const AssetHierarchyReference(
        assetClassId: 'class-a',
        assetClassCode: 'FR',
        assetClassName: 'Furnace',
        nodeId: 'burner-block',
        nodeVersion: 1,
        nodeName: 'Burner block',
        hierarchyPath: ['Furnace', 'Burner block'],
        ownershipStatus: AssetOwnershipStatus.confirmed,
        ownerDiscipline: 'Mechanical',
        accountableRoleKeys: ['mechanical'],
      ).encode();
    expect(
      evidence(
        ticket,
        classes: [assetClass('class-a'), assetClass('class-b')],
      ).basis,
      hasLength(1),
    );
    expect(
      evidence(ticket, furnace: asset('furnace-b', classId: 'class-b')).basis,
      isEmpty,
    );
  });

  test(
    'strong malformed or internally contradictory references cannot fall back to number',
    () {
      expect(
        () => evidence(concern()..assetHierarchyRefJson = '{bad json'),
        throwsFormatException,
      );
      expect(
        () => evidence(concern()..assetHierarchyRefJson = reference(number: 8)),
        throwsFormatException,
      );
    },
  );

  test(
    'a definition reference cannot masquerade as canonical physical evidence',
    () {
      final raw = jsonDecode(reference()) as Map<String, dynamic>;
      raw['schemaVersion'] = 2;
      raw['scope'] = 'definition';
      expect(
        () => evidence(concern()..assetHierarchyRefJson = jsonEncode(raw)),
        throwsFormatException,
      );
    },
  );
}
