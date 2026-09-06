import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_evidence_snapshot.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/inspection_programmes_screen.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('audit PDF action stays hidden for an empty campaign', (
    tester,
  ) async {
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
    );

    await tester.pumpWidget(_testApp(campaign));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inspection-campaign-pdf-action')),
      findsNothing,
    );
  });

  testWidgets('audit PDF action appears after a reading exists', (
    tester,
  ) async {
    final observedAt = DateTime.utc(2026, 9, 5, 10);
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
      disposition: InspectionTargetDisposition.observed,
      lastObservationId: 'reading-1',
      lastObservedAt: observedAt,
    );

    await tester.pumpWidget(
      _testApp(
        campaign,
        observations: <InspectionObservation>[
          _observation(
            campaign: campaign,
            target: campaign.targets.single,
            id: 'reading-1',
            observedAt: observedAt,
            recordedAt: observedAt,
            value: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inspection-campaign-pdf-action')),
      findsOneWidget,
    );
    expect(find.byTooltip('Create audit PDF'), findsOneWidget);
  });

  for (final unverifiedSource in ['observations', 'findings']) {
    testWidgets('audit PDF stays disabled for cached $unverifiedSource', (
      tester,
    ) async {
      final observedAt = DateTime.utc(2026, 9, 5, 10);
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
        disposition: InspectionTargetDisposition.observed,
        lastObservationId: 'reading-1',
        lastObservedAt: observedAt,
      );

      await tester.pumpWidget(
        _testApp(
          campaign,
          observations: <InspectionObservation>[
            _observation(
              campaign: campaign,
              target: campaign.targets.single,
              id: 'reading-1',
              observedAt: observedAt,
              recordedAt: observedAt,
              value: true,
            ),
          ],
          observationsServerVerified: unverifiedSource != 'observations',
          findingsServerVerified: unverifiedSource != 'findings',
        ),
      );
      await tester.pumpAndSettle();

      final action = tester.widget<IconButton>(
        find.byKey(const ValueKey('inspection-campaign-pdf-action')),
      );
      expect(action.onPressed, isNull);
      expect(
        find.byTooltip('Reconnect to verify complete audit data'),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'Inner Cover audit keeps Base identity and headings visible deep in the grid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final campaign = _innerCoverCampaign();

      await tester.pumpWidget(_testApp(campaign));
      await tester.pumpAndSettle();

      final corner = find.byKey(
        const ValueKey('inspection-audit-fixed-corner'),
      );
      final base222 = find.byKey(
        const ValueKey(
          'inspection-audit-row-base-222|link-inner-cover-n22-base-222',
        ),
      );
      final verticalPane = find.byKey(
        const ValueKey('inspection-audit-vertical-scroll'),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pumpAndSettle();
      final cornerTop = tester.getTopLeft(corner).dy;

      await tester.drag(verticalPane, const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(find.text('Base 222 (N22)').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(corner).dy, moreOrLessEquals(cornerTop));
      expect(find.text('Base (Inner Cover)'), findsOneWidget);

      final rowLeft = tester.getTopLeft(base222).dx;
      final header = find.byKey(
        const ValueKey('inspection-audit-header-inner-cover-shell|Check 8'),
      );
      final scrollCell = find.byKey(
        const ValueKey(
          'inspection-audit-cell-class-inner-cover:inner-cover-n22|inner-cover-shell|Check 1|link:link-inner-cover-n22-base-222',
        ),
      );
      final cell = find.byKey(
        const ValueKey(
          'inspection-audit-cell-class-inner-cover:inner-cover-n22|inner-cover-shell|Check 8|link:link-inner-cover-n22-base-222',
        ),
      );
      final headerBefore = tester.getTopLeft(header).dx;

      await tester.drag(scrollCell, const Offset(-900, 0));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(base222).dx, moreOrLessEquals(rowLeft));
      expect(tester.getTopLeft(header).dx, lessThan(headerBefore));
      expect(header.hitTestable(), findsOneWidget);
      expect(cell.hitTestable(), findsOneWidget);
      expect(
        tester.getCenter(header).dx,
        moreOrLessEquals(tester.getCenter(cell).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final subject in [
    (
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
      heading: 'Furnace',
    ),
    (
      assetTypeKey: 'base',
      assetClassId: 'class-base',
      assetInstanceId: 'base-205',
      assetNumber: 205,
      label: 'Base 205',
      heading: 'Base',
    ),
  ]) {
    testWidgets(
      '${subject.heading} campaign uses its governed asset identity',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final campaign = _assetCampaign(
          assetTypeKey: subject.assetTypeKey,
          assetClassId: subject.assetClassId,
          assetInstanceId: subject.assetInstanceId,
          assetNumber: subject.assetNumber,
          label: subject.label,
        );

        await tester.pumpWidget(_testApp(campaign));
        await tester.pumpAndSettle();
        for (
          var attempt = 0;
          attempt < 4 &&
              find
                  .byKey(const ValueKey('inspection-audit-fixed-corner'))
                  .evaluate()
                  .isEmpty;
          attempt += 1
        ) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -240));
          await tester.pumpAndSettle();
        }

        final row = find.byKey(
          ValueKey('inspection-audit-row-${subject.assetInstanceId}'),
        );
        expect(find.text(subject.heading), findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text(subject.label)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final viewport in [
    (size: const Size(320, 720), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(900, 800), scale: 1.0),
  ]) {
    testWidgets('reusable audit board remains usable at $viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(viewport.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _testApp(_innerCoverCampaign(), textScale: viewport.scale),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (
        var attempt = 0;
        attempt < 4 &&
            find
                .byKey(const ValueKey('inspection-audit-fixed-corner'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const ValueKey('inspection-audit-fixed-corner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inspection-audit-scrollable-grid')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('adding governed targets inherits the campaign audit columns', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp(_innerCoverCampaign(), textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Campaign actions'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add governed targets'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Check 1, Check 2, Check 3, Check 4, Check 5, Check 6, Check 7, Check 8',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'audit board follows the server-certified current observation identity',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final laterOccurrence = DateTime.utc(2026, 9, 5, 10);
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
        disposition: InspectionTargetDisposition.observed,
        lastObservationId: 'backdated-follow-up',
        lastObservedAt: laterOccurrence.subtract(const Duration(hours: 1)),
      );
      final target = campaign.targets.single;
      final observations = <InspectionObservation>[
        _observation(
          campaign: campaign,
          target: target,
          id: 'later-occurrence',
          observedAt: laterOccurrence,
          recordedAt: laterOccurrence,
          value: true,
        ),
        _observation(
          campaign: campaign,
          target: target,
          id: 'backdated-follow-up',
          observedAt: laterOccurrence.subtract(const Duration(hours: 1)),
          recordedAt: laterOccurrence.add(const Duration(hours: 1)),
          value: false,
        ),
      ];

      await tester.pumpWidget(_testApp(campaign, observations: observations));
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 4 &&
            find
                .byKey(const ValueKey('inspection-audit-fixed-corner'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pumpAndSettle();
      }

      final cell = find.byKey(
        ValueKey('inspection-audit-cell-${target.targetKey}'),
      );
      expect(
        find.descendant(of: cell, matching: find.text('No')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('Yes')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'audit board uses the latest occurrence when no certified receipt exists',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final latest = DateTime.utc(2026, 9, 5, 10);
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
      );
      final target = campaign.targets.single;
      final observations = <InspectionObservation>[
        _observation(
          campaign: campaign,
          target: target,
          id: 'older-reading',
          observedAt: latest.subtract(const Duration(hours: 1)),
          recordedAt: latest.subtract(const Duration(hours: 1)),
          value: false,
        ),
        _observation(
          campaign: campaign,
          target: target,
          id: 'latest-reading',
          observedAt: latest,
          recordedAt: latest,
          value: true,
        ),
      ];

      await tester.pumpWidget(_testApp(campaign, observations: observations));
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 4 &&
            find
                .byKey(const ValueKey('inspection-audit-fixed-corner'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pumpAndSettle();
      }

      final cell = find.byKey(
        ValueKey('inspection-audit-cell-${target.targetKey}'),
      );
      expect(
        find.descendant(of: cell, matching: find.text('Yes')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('No')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _testApp(
  InspectionCampaign campaign, {
  double textScale = 1,
  List<InspectionObservation> observations = const <InspectionObservation>[],
  bool observationsServerVerified = true,
  bool findingsServerVerified = true,
}) => ProviderScope(
  overrides: [
    currentAppUserProvider.overrideWith(
      (_) => Stream<AppUser?>.value(_admin()),
    ),
    inspectionCampaignsProvider.overrideWith((_) => Stream.value([campaign])),
    inspectionObservationsProvider(campaign.id).overrideWith(
      (_) => Stream.value(
        InspectionEvidenceSnapshot<InspectionObservation>(
          records: observations,
          isServerVerified: observationsServerVerified,
        ),
      ),
    ),
    inspectionFindingsProvider(campaign.id).overrideWith(
      (_) => Stream.value(
        InspectionEvidenceSnapshot<InspectionFinding>(
          records: const <InspectionFinding>[],
          isServerVerified: findingsServerVerified,
        ),
      ),
    ),
    assetHierarchyNodesProvider(campaign.assetClassId).overrideWith(
      (_) => Stream.value(
        campaign.assetTypeKey == 'innerCover'
            ? <AssetHierarchyNode>[_shellNode()]
            : const <AssetHierarchyNode>[],
      ),
    ),
    allAssetInstancesProvider.overrideWith((_) => Stream.value(const [])),
    innerCoverProfilesProvider.overrideWith((_) => Stream.value(const [])),
    innerCoverAssignmentsProvider.overrideWith((_) => Stream.value(const [])),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: InspectionCampaignDetailScreen(campaignId: campaign.id),
  ),
);

AppUser _admin() => AppUser(
  uid: 'admin-1',
  name: 'Admin One',
  email: 'admin@example.invalid',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 1, 1),
);

AssetHierarchyNode _shellNode() => AssetHierarchyNode(
  id: 'inner-cover-shell',
  assetClassId: 'class-inner-cover',
  nodeType: AssetHierarchyNodeType.component,
  name: 'Shell condition',
  contactArrangement: ElectricalContactArrangement.notStated,
  ownershipStatus: AssetOwnershipStatus.unassigned,
  sortOrder: 1,
  ancestorNodeIds: const [],
  hierarchyPath: const ['Inner Cover', 'Shell condition'],
  activeChildCount: 0,
  status: AssetHierarchyStatus.active,
  version: 3,
  createdAt: DateTime.utc(2026, 1, 1),
  createdByUid: 'admin-1',
  updatedAt: DateTime.utc(2026, 1, 1),
  updatedByUid: 'admin-1',
  lastMutationId: 'seed-node',
);

InspectionCampaign _innerCoverCampaign() {
  final now = DateTime.utc(2026, 9, 5, 4);
  final positions = List<String>.generate(8, (index) => 'Check ${index + 1}');
  final targets = <InspectionCampaignTarget>[
    for (var index = 0; index < 22; index++)
      for (final position in positions)
        InspectionCampaignTarget(
          targetKey:
              'class-inner-cover:inner-cover-n${index + 1}|inner-cover-shell|$position|link:link-inner-cover-n${index + 1}-base-${index + 201}',
          assetTypeKey: 'innerCover',
          assetClassId: 'class-inner-cover',
          assetNumber: index + 201,
          assetInstanceId: 'inner-cover-n${index + 1}',
          assetInstanceVersion: 1,
          assetInstanceName: 'Inner Cover N${index + 1}',
          hostAssetClassId: 'class-base',
          hostAssetInstanceId: 'base-${index + 201}',
          hostAssetInstanceVersion: 1,
          hostAssetNumber: index + 201,
          hostAssetInstanceName: 'Base ${index + 201}',
          subjectSerialNumber: 'N${index + 1}',
          linkageId: 'link-inner-cover-n${index + 1}-base-${index + 201}',
          linkageVersion: 1,
          linkedAt: now,
          componentNodeId: 'inner-cover-shell',
          physicalPosition: position,
          disposition: InspectionTargetDisposition.pending,
          dispositionReason: null,
          dispositionAt: now,
          dispositionByUid: 'admin-1',
          dispositionByName: 'Admin One',
          addedLater: false,
          lastObservationId: null,
          lastObservedAt: null,
        ),
  ];
  return InspectionCampaign(
    id: 'campaign-inner-covers',
    version: 1,
    status: InspectionCampaignStatus.open,
    definition: const FrozenInspectionDefinition(
      id: 'definition-inner-cover-shell',
      version: 1,
      code: 'INNER_COVER_SHELL',
      title: 'Inner Cover shell audit',
      description: 'Inspect installed Inner Covers by governed Base position.',
      assetTypeKeys: ['innerCover'],
      assetClassIds: ['class-inner-cover'],
      componentNodeIds: ['inner-cover-shell'],
      valueType: InspectionValueType.boolean,
      unit: null,
      choiceValues: [],
      minimumValue: null,
      maximumValue: null,
      preconditions: [],
      requiresChargeNo: false,
    ),
    purpose: 'Verify all currently installed Inner Covers.',
    assetTypeKey: 'innerCover',
    assetClassId: 'class-inner-cover',
    populationMode: InspectionCampaignPopulationMode.installedInnerCoversByBase,
    hostAssetClassId: 'class-base',
    targetAssetNumbers: List<int>.generate(22, (index) => index + 201),
    physicalPositionLabels: positions,
    targets: targets,
    expectedPopulation: targets.length,
    baselineCampaignId: null,
    observerRoleKeys: const ['seniorMechanical'],
    observationCount: 0,
    distinctTargetKeys: const [],
    latestObservationAt: null,
    createdAt: now,
  );
}

InspectionCampaign _assetCampaign({
  required String assetTypeKey,
  required String assetClassId,
  required String assetInstanceId,
  required int assetNumber,
  required String label,
  InspectionTargetDisposition disposition = InspectionTargetDisposition.pending,
  String? lastObservationId,
  DateTime? lastObservedAt,
}) {
  final now = DateTime.utc(2026, 9, 5, 4);
  final target = InspectionCampaignTarget(
    targetKey: '$assetClassId:$assetInstanceId|asset|-',
    assetTypeKey: assetTypeKey,
    assetClassId: assetClassId,
    assetNumber: assetNumber,
    assetInstanceId: assetInstanceId,
    assetInstanceVersion: 2,
    assetInstanceName: label,
    hostAssetClassId: null,
    hostAssetInstanceId: null,
    hostAssetInstanceVersion: null,
    hostAssetNumber: null,
    hostAssetInstanceName: null,
    subjectSerialNumber: null,
    linkageId: null,
    linkageVersion: null,
    linkedAt: null,
    componentNodeId: null,
    physicalPosition: null,
    disposition: disposition,
    dispositionReason: null,
    dispositionAt: now,
    dispositionByUid: 'admin-1',
    dispositionByName: 'Admin One',
    addedLater: false,
    lastObservationId: lastObservationId,
    lastObservedAt: lastObservedAt,
  );
  return InspectionCampaign(
    id: 'campaign-$assetInstanceId',
    version: 1,
    status: InspectionCampaignStatus.open,
    definition: FrozenInspectionDefinition(
      id: 'definition-$assetTypeKey',
      version: 1,
      code: '${assetTypeKey.toUpperCase()}_AUDIT',
      title: '$label audit',
      description: 'Governed asset inspection.',
      assetTypeKeys: [assetTypeKey],
      assetClassIds: [assetClassId],
      componentNodeIds: const [],
      valueType: InspectionValueType.boolean,
      unit: null,
      choiceValues: const [],
      minimumValue: null,
      maximumValue: null,
      preconditions: const [],
      requiresChargeNo: false,
    ),
    purpose: 'Inspect $label.',
    assetTypeKey: assetTypeKey,
    assetClassId: assetClassId,
    populationMode: InspectionCampaignPopulationMode.assetInstances,
    hostAssetClassId: null,
    targetAssetNumbers: [assetNumber],
    physicalPositionLabels: const [],
    targets: [target],
    expectedPopulation: 1,
    baselineCampaignId: null,
    observerRoleKeys: const ['operations'],
    observationCount: 0,
    distinctTargetKeys: const [],
    latestObservationAt: null,
    createdAt: now,
  );
}

InspectionObservation _observation({
  required InspectionCampaign campaign,
  required InspectionCampaignTarget target,
  required String id,
  required DateTime observedAt,
  required DateTime recordedAt,
  required bool value,
}) => InspectionObservation(
  id: id,
  campaignId: campaign.id,
  definition: campaign.definition,
  assetTypeKey: target.assetTypeKey,
  assetNumber: target.assetNumber,
  assetClassId: target.assetClassId,
  assetInstanceId: target.assetInstanceId,
  hostAssetClassId: target.hostAssetClassId,
  hostAssetInstanceId: target.hostAssetInstanceId,
  hostAssetInstanceVersion: target.hostAssetInstanceVersion,
  hostAssetNumber: target.hostAssetNumber,
  hostAssetInstanceName: target.hostAssetInstanceName,
  subjectSerialNumber: target.subjectSerialNumber,
  linkageId: target.linkageId,
  linkageVersion: target.linkageVersion,
  linkedAt: target.linkedAt,
  componentNodeId: target.componentNodeId,
  componentNodeVersion: null,
  componentName: null,
  hierarchyPath: const <String>[],
  physicalPosition: target.physicalPosition,
  targetKey: target.targetKey,
  observedAt: observedAt,
  observerUid: 'admin-1',
  observerName: 'Admin One',
  numericValue: null,
  booleanValue: value,
  textValue: null,
  choiceValue: null,
  unit: null,
  outOfRange: !value,
  operatingConditions: const <String, String>{},
  chargeNo: null,
  note: null,
  evidenceUrls: const <String>[],
  supersedesObservationId: null,
  baselineCampaignId: null,
  baselineObservationId: null,
  comparisonOutcome: null,
  recordedAt: recordedAt,
);
