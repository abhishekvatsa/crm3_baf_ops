import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Observation choices remain readable on a large-text phone', (
    tester,
  ) async {
    await _openForm(tester, width: 320, textScale: 1.6);
    final selector = find.byKey(const ValueKey('abnormality-observation-kind'));
    await _reveal(tester, selector);
    expect(
      tester
          .widget<SegmentedButton<AbnormalityObservationKind>>(selector)
          .direction,
      Axis.vertical,
    );
    await tester.tap(find.text('Process / equipment'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<AbnormalityObservationKind>>(selector)
          .selected,
      {AbnormalityObservationKind.processEquipment},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'adding governed equipment to a new result does not invent a root cause',
    (tester) async {
      final repository = _Repository();
      await _openForm(tester, repository: repository);
      final observation = find.byKey(const ValueKey('abnormality-observation'));
      await _reveal(tester, observation);
      await tester.enterText(
        observation,
        'Uneven coil colour observed; cause unknown',
      );
      await _reveal(tester, _field('Asset class'));
      await tester.tap(_field('Asset class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace').last);
      await tester.pumpAndSettle();
      await _reveal(tester, _field('Registered asset'));
      await tester.tap(_field('Registered asset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace 7').last);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Add affected equipment'));
      await tester.tap(find.text('Add affected equipment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log abnormality'));
      await tester.pumpAndSettle();
      expect(
        repository.saved,
        isNotNull,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data)
            .join('\n'),
      );
      final saved = repository.saved!;
      expect(saved.affectedAssets.single.assetType, AssetType.furnace);
      expect(saved.observationKind, AbnormalityObservationKind.resultFinding);
      expect(saved.possibleRootReasonCategory, RootReasonCategory.unknown);
      expect(saved.possibleRootReasonNotes, isNull);
      expect(saved.assessment!.candidateCauses, isEmpty);
      expect(saved.toMap()['possibleRootReasonCategory'], 'unknown');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editing retains historical explicit cause notes', (
    tester,
  ) async {
    final old = ChargeAbnormality.createRaCoilColour(
      firestoreId: 'historical-cause',
      sourceChargeNo: 91234,
      affectedAssets: const [
        AffectedAssetRef(assetType: AssetType.furnace, assetNumber: 7),
      ],
      observedReason: 'Historical coil observation',
      loggedByUid: 'operator',
      loggedByName: 'Operator',
      possibleRootReasonCategory: RootReasonCategory.furnaceRelated,
      possibleRootReasonNotes:
          'Original operator hypothesis retained for review',
    )..assessment = null;
    await _openForm(tester, existing: old);
    await _reveal(tester, find.text('Retained historical cause notes'));
    final field = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<RootReasonCategory>,
    );
    expect(
      tester.state<FormFieldState<RootReasonCategory>>(field).value,
      RootReasonCategory.furnaceRelated,
    );
    expect(
      find.text('Original operator hypothesis retained for review'),
      findsOneWidget,
    );
    expect(
      old.possibleRootReasonNotes,
      'Original operator hypothesis retained for review',
    );
  });

  testWidgets(
    'historical edit keeps unknown kind and completion date without invented facts',
    (tester) async {
      final old = ChargeAbnormality.createRaCoilColour(
        firestoreId: 'legacy',
        sourceChargeNo: 91234,
        affectedAssets: const [
          AffectedAssetRef(assetType: AssetType.furnace, assetNumber: 7),
        ],
        observedReason: 'Historical observation',
        loggedByUid: 'operator',
        loggedByName: 'Operator',
        reannealedToChargeNo: 91235,
      )..assessment = null;
      await _openForm(tester, existing: old);
      final mode = tester.widget<SegmentedButton<AbnormalityObservationKind>>(
        find.byKey(const ValueKey('abnormality-observation-kind')),
      );
      expect(mode.selected, {AbnormalityObservationKind.legacyUnknown});
      expect(
        mode.segments.map((value) => value.value),
        contains(AbnormalityObservationKind.legacyUnknown),
      );
      await _reveal(tester, find.byKey(const ValueKey('ra-performed-at')));
      expect(
        find.text('Choose the actual completion date and time'),
        findsOneWidget,
      );
      expect(old.raPerformedAt, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a deliberate RA decision survives changing the observation classification',
    (tester) async {
      await _openForm(tester);
      final ra = find.byKey(const ValueKey('abnormality-ra-decision'));
      await _reveal(tester, ra);
      await tester.tap(ra);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Required').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Process / equipment'));
      await tester.pumpAndSettle();
      await _reveal(tester, ra);
      expect(
        tester.state<FormFieldState<ReannealingStatus>>(ra).value,
        ReannealingStatus.required,
      );
      expect(
        find.byKey(const ValueKey('abnormality-ra-performed')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'new form separates result and process observations with no automatic RA',
    (tester) async {
      await _openForm(tester);
      final mode = tester.widget<SegmentedButton<AbnormalityObservationKind>>(
        find.byKey(const ValueKey('abnormality-observation-kind')),
      );
      expect(mode.selected, {AbnormalityObservationKind.resultFinding});
      final observation = find.byKey(const ValueKey('abnormality-observation'));
      await _reveal(tester, observation);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: observation,
                matching: find.byType(TextField),
              ),
            )
            .decoration!
            .labelText,
        'Observed result',
      );
      expect(find.text('Possible root-reason area'), findsNothing);
      await tester.drag(find.byType(ListView).last, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Process / equipment'));
      await tester.pumpAndSettle();
      await _reveal(tester, observation);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: observation,
                matching: find.byType(TextField),
              ),
            )
            .decoration!
            .labelText,
        'Process or equipment observation',
      );
      await _reveal(
        tester,
        find.byKey(const ValueKey('abnormality-ra-decision')),
      );
      final decision = tester
          .widget<DropdownButtonFormField<ReannealingStatus>>(
            find.byKey(const ValueKey('abnormality-ra-decision')),
          );
      expect(decision.initialValue, ReannealingStatus.pendingDecision);
      expect(
        find.byKey(const ValueKey('abnormality-ra-performed')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'empty live asset catalogue retains an open menu and rejects its old choice',
    (tester) async {
      final live = await _openForm(tester);
      await _reveal(tester, _field('Asset class'));
      await tester.tap(_field('Asset class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace').last);
      await tester.pumpAndSettle();
      final assetField = _field('Registered asset');
      await _reveal(tester, assetField);
      final state = tester.state(assetField);
      await tester.tap(assetField);
      await tester.pumpAndSettle();
      live.assets.add([]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(assetField), same(state));
      await tester.tap(find.text('Furnace 7').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Add affected equipment'), findsNothing);
      expect(tester.state<FormFieldState<String>>(assetField).value, isNull);
    },
  );

  testWidgets(
    'open abnormality menus survive unrelated live catalogue additions',
    (tester) async {
      final live = await _openForm(tester);
      final classField = _field('Asset class');
      await _reveal(tester, classField);
      final classState = tester.state(classField);
      await tester.tap(classField);
      await tester.pumpAndSettle();
      live.classes.add([
        _assetClass(),
        _assetClass(id: 'cooler', name: 'Cooler', legacy: 'forcedCooler'),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(classField), same(classState));
      await tester.tap(find.text('Furnace').last);
      await tester.pumpAndSettle();

      final assetField = _field('Registered asset');
      await _reveal(tester, assetField);
      final assetState = tester.state(assetField);
      await tester.tap(assetField);
      await tester.pumpAndSettle();
      live.assets.add([_asset(7), _asset(8)]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(assetField), same(assetState));
      await tester.tap(find.text('Furnace 7').last);
      await tester.pumpAndSettle();
      expect(
        tester.state<FormFieldState<String>>(assetField).value,
        'furnace-7',
      );
      final add = find.text('Add affected equipment');
      await _reveal(tester, add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Select at least one governed affected asset before logging this abnormality.',
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'withdrawn asset cannot return through an already open abnormality menu',
    (tester) async {
      final live = await _openForm(tester);
      await _reveal(tester, _field('Asset class'));
      await tester.tap(_field('Asset class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace').last);
      await tester.pumpAndSettle();
      live.assets.add([_asset(7), _asset(8)]);
      await tester.pumpAndSettle();
      final assetField = _field('Registered asset');
      await _reveal(tester, assetField);
      await tester.tap(assetField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furnace 7').last);
      await tester.pumpAndSettle();
      final assetState = tester.state(assetField);
      await tester.tap(assetField);
      await tester.pumpAndSettle();
      live.assets.add([
        _asset(7, status: AssetHierarchyStatus.retired),
        _asset(8),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(assetField), same(assetState));
      // The native popup retains the items captured when it opened. Its stale
      // response must not restore withdrawn equipment or bypass current eligibility.
      await tester.tap(find.text('Furnace 7').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state<FormFieldState<String>>(assetField).value, isNull);
      expect(find.text('Add affected equipment'), findsNothing);
      expect(find.textContaining('no longer available'), findsOneWidget);
      expect(
        find.text(
          'Select at least one governed affected asset before logging this abnormality.',
        ),
        findsOneWidget,
      );
    },
  );
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is DropdownButtonFormField<String> &&
      widget.decoration.labelText == label,
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    220,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.4);
  await tester.pumpAndSettle();
}

class _LiveCatalogue {
  final classes = StreamController<List<AssetClassRecord>>.broadcast();
  final assets = StreamController<List<AssetInstanceRecord>>.broadcast();
}

Future<_LiveCatalogue> _openForm(
  WidgetTester tester, {
  ChargeAbnormality? existing,
  _Repository? repository,
  double width = 900,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final live = _LiveCatalogue();
  addTearDown(live.classes.close);
  addTearDown(live.assets.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'operator',
              name: 'Operator',
              email: 'operator@example.test',
              roles: existing == null
                  ? const [AppRole.operations]
                  : const [AppRole.admin],
              isApproved: true,
              createdAt: DateTime.utc(2026),
            ),
          ),
        ),
        abnormalitiesForChargeProvider.overrideWith(
          (ref, charge) => Stream.value([if (existing != null) existing]),
        ),
        activeAbnormalityTypesProvider.overrideWith(
          (ref) => Stream.value([_type(), _colourType()]),
        ),
        abnormalityRepositoryProvider.overrideWithValue(
          repository ?? _Repository(),
        ),
        syncCoordinatorProvider.overrideWithValue(_Sync()),
        assetClassesProvider.overrideWith((ref) async* {
          yield [_assetClass()];
          yield* live.classes.stream;
        }),
        assetInstancesProvider.overrideWith((ref, classId) async* {
          yield [_asset(7)];
          yield* live.assets.stream;
        }),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ChargeAbnormalitiesScreen(sourceChargeNo: 91234),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (existing == null) {
    await tester.tap(find.text('Log Abnormality'));
  } else {
    await tester.tap(
      find.byKey(const ValueKey('charge-abnormality-status-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Edit'));
    await tester.tap(find.byTooltip('Edit'));
  }
  await tester.pumpAndSettle();
  return live;
}

AbnormalityType _type() => AbnormalityType()
  ..firestoreId = 'type'
  ..code = 'HJ'
  ..title = 'Observed defect'
  ..category = AbnormalityCategory.process
  ..severity = AbnormalitySeverity.medium
  ..isActive = true
  ..createdAt = DateTime.utc(2026)
  ..updatedAt = DateTime.utc(2026);

AbnormalityType _colourType() => AbnormalityType.seedRaCoilColour()
  ..suggestsReannealing =
      true; // Old catalogue advice must not become a decision.

class _Repository extends Fake implements AbnormalityRepository {
  ChargeAbnormality? saved;
  @override
  Future<void> saveAbnormality(
    ChargeAbnormality abnormality, {
    required AppUser actor,
    AuditContext? auditContext,
  }) async {
    saved = copyChargeAbnormality(abnormality);
  }

  @override
  Future<List<AbnormalityType>> getActiveTypes() async => [
    _type(),
    _colourType(),
  ];
}

class _Sync extends Fake implements SyncCoordinator {
  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unspecified',
    bool force = false,
  }) async => SyncRequestOutcome.queued;
}

AssetClassRecord _assetClass({
  String id = 'furnace',
  String name = 'Furnace',
  String legacy = 'furnace',
}) => AssetClassRecord(
  id: id,
  code: id.toUpperCase(),
  name: name,
  majorArea: 'BAF',
  legacyAssetTypeKey: legacy,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: DateTime.utc(2026),
  createdByUid: 'admin',
  updatedAt: DateTime.utc(2026),
  updatedByUid: 'admin',
  lastMutationId: 'fixture',
);

AssetInstanceRecord _asset(
  int number, {
  AssetHierarchyStatus status = AssetHierarchyStatus.active,
}) => AssetInstanceRecord(
  id: 'furnace-$number',
  assetClassId: 'furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetNumber: number,
  name: 'Furnace $number',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: const ['contractSupervisor'],
  status: status,
  activeComponentCount: 0,
  version: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  lastMutationId: 'fixture',
);
