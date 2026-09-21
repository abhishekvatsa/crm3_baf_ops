import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/providers/burner_condition_round_provider.dart';
import 'package:crm3_baf_ops/features/reports/presentation/operations_report_pdf_screen.dart';
import 'package:crm3_baf_ops/features/reports/presentation/zoomable_pdf_preview.dart';
import 'operations_report_test.dart' as fixtures;

import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/directives/providers/operational_directive_provider.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_provider.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:crm3_baf_ops/features/reports/domain/operations_report_document.dart';
import 'package:crm3_baf_ops/features/reports/domain/operations_report_query_plan.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:crm3_baf_ops/features/reports/services/operations_report_pdf_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final interruption in ['loading', 'error']) {
    testWidgets(
      'prepared PDF retains its exact future and bytes after authority $interruption',
      (tester) async {
        final h = _PreparationHarness();
        addTearDown(h.dispose);
        await h.open(tester);
        final firstPreview = tester.widget<ZoomablePdfPreview>(
          find.byType(ZoomablePdfPreview),
        );
        final firstFuture = firstPreview.documentBuilder(
          PdfPageFormat.a4.landscape,
        );
        final firstBytes = await tester.runAsync(() async => await firstFuture);
        expect(firstBytes, isNotNull);
        expect(firstBytes!.take(4), [0x25, 0x50, 0x44, 0x46]);

        if (interruption == 'loading') {
          h.container.invalidate(currentAppUserProvider);
        } else {
          h.actors.addError(StateError('authority temporarily unavailable'));
        }
        await tester.pump();
        expect(find.byType(ZoomablePdfPreview), findsNothing);
        expect(find.byType(OperationsReportPdfPreviewScreen), findsNothing);

        h.actors.add(h.actor);
        await tester.pump();
        final restoredPreview = tester.widget<ZoomablePdfPreview>(
          find.byType(ZoomablePdfPreview),
        );
        final restoredFuture = restoredPreview.documentBuilder(
          PdfPageFormat.a4.landscape,
        );
        final restoredBytes = await tester.runAsync(
          () async => await restoredFuture,
        );
        expect(restoredFuture, same(firstFuture));
        expect(restoredBytes, same(firstBytes));
        expect(restoredPreview.fileName, firstPreview.fileName);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('confirmed account change permanently closes a prepared report', (
    tester,
  ) async {
    final h = _PreparationHarness();
    addTearDown(h.dispose);
    await h.open(tester);
    final preview = tester.widget<ZoomablePdfPreview>(
      find.byType(ZoomablePdfPreview),
    );
    await tester.runAsync(
      () async => await preview.documentBuilder(PdfPageFormat.a4.landscape),
    );
    h.actors.add(
      AppUser(
        uid: 'another-admin',
        name: 'Another Admin',
        email: 'another@example.invalid',
        roles: [AppRole.admin],
        isApproved: true,
        createdAt: DateTime.utc(2026),
      ),
    );
    await tester.pump();
    expect(find.byType(ZoomablePdfPreview), findsNothing);
    expect(find.text('Report access required'), findsOneWidget);
    h.actors.add(h.actor);
    await tester.pump();
    expect(find.byType(ZoomablePdfPreview), findsNothing);
    expect(find.text('Report access required'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preparation queries the registry in its report, including replacements',
    (tester) async {
      final furnaceClass = fixtures.assetClass('shells', 'Furnace', 'furnace');
      final oldFurnace = fixtures.asset('old-shell', furnaceClass, 1);
      final replacement = fixtures.asset('replacement-shell', furnaceClass, 1);
      final newFurnace = fixtures.asset('new-shell', furnaceClass, 2);
      final selected = {OperationsReportSection.burnerUvCondition};
      final filter = OperationsReportFilter(
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 21),
        queryPlan: OperationsReportQueryPlan.forSections(selected),
      );
      final classes = [furnaceClass];
      OperationsReport snapshot(List<AssetInstanceRecord> assets) =>
          buildOperationsReport(
            filter: filter,
            tickets: [],
            executions: [],
            events: [],
            assetClasses: classes,
            assetInstances: assets,
            overview: const PlantAssetOverview(classes: [], assets: []),
            asOf: DateTime.utc(2026, 9, 21),
          );
      var report = snapshot([oldFurnace]);
      final calls = <List<String>>[];
      final scope = (actorUid: 'admin', filter: filter);
      final container = ProviderContainer(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(
              AppUser(
                uid: 'admin',
                name: 'Admin',
                email: 'admin@example.invalid',
                roles: [AppRole.admin],
                isApproved: true,
                createdAt: DateTime.utc(2026),
              ),
            ),
          ),
          operationsReportProvider.overrideWith(
            (ref, scope) => AsyncData(report),
          ),
          latestBurnerConditionRoundsProvider.overrideWith((ref, query) {
            calls.add(query.assetInstanceIds);
            // Keep preparation open while the inventory changes.
            return const Stream.empty();
          }),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: OperationsReportPreparationScreen(
              actorUid: 'admin',
              filter: filter,
              request: OperationsReportDocumentRequest.forPreset(
                preset: OperationsReportDocumentPreset.complete,
                generatedAt: DateTime.utc(2026, 9, 21),
                generatedByName: 'Admin',
                generatedByEmail: 'admin@example.invalid',
              ).copyWith(sections: selected),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(calls.last, ['old-shell']);
      final assets = [replacement, newFurnace];
      report = snapshot(assets);
      assets.clear();
      classes.clear();
      container.invalidate(operationsReportProvider(scope));
      await tester.pump();
      expect(calls.last, ['new-shell', 'replacement-shell']);
      expect(report.sourceAssetInstances.length, 2);
      expect(report.sourceAssetClasses.single.id, furnaceClass.id);
      expect(() => report.sourceAssetInstances.clear(), throwsUnsupportedError);
      expect(find.byType(OperationsReportPdfPreviewScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'section union is immutable, order-independent and keeps executive complete',
    () {
      final sections = {OperationsReportSection.plannedMaintenance};
      final plan = OperationsReportQueryPlan.forSections(sections);
      sections.add(OperationsReportSection.executiveSummary);
      expect(plan.includes(OperationsReportSource.plannedWork), true);
      expect(plan.includes(OperationsReportSource.cadence), true);
      expect(plan.includes(OperationsReportSource.alarms), false);
      expect(
        plan,
        OperationsReportQueryPlan.forSections({
          OperationsReportSection.plannedMaintenance,
        }),
      );
      expect(OperationsReportQueryPlan.forSections(sections).isComplete, true);
      expect(
        () => OperationsReportQueryPlan.forSections({}),
        throwsArgumentError,
      );
      expect(
        OperationsReportQueryPlan.forSections({
          OperationsReportSection.safetyCriticalAlarms,
        }).covers(plan),
        false,
      );
    },
  );

  test(
    'focused alarm report never subscribes to unrelated failing business sources',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.hasValue, true, reason: h.report.error?.toString());
      expect(h.unrelatedReads, 0);
      expect(
        h.report.requireValue.filter.queryPlan.includes(
          OperationsReportSource.issues,
        ),
        false,
      );
      expect(h.alarmReads, 1);
    },
  );

  test(
    'included-source failure remains blocking, and authority loss removes ready data',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.settle();
      expect(h.report.hasValue, true);
      h.failAlarms = true;
      h.container.invalidate(criticalAlarmsForReportsProvider);
      await h.settle();
      expect(h.report.hasError, true);
      expect(h.report.error.toString(), contains('alarm source failed'));
      h.failAlarms = false;
      h.container.invalidate(criticalAlarmsForReportsProvider);
      await h.settle();
      expect(h.report.hasValue, true);
      h.actors.add(null);
      await h.settle();
      expect(h.report.hasError, true);
      expect(h.report.error.toString(), contains('Approved report access'));
    },
  );

  test('a narrow snapshot cannot be exported as a complete report', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.settle();
    await expectLater(
      OperationsReportPdfService.build(
        report: h.report.requireValue,
        request: OperationsReportDocumentRequest.forPreset(
          preset: OperationsReportDocumentPreset.complete,
          generatedAt: DateTime.utc(2026, 9, 21),
          generatedByName: 'Admin',
          generatedByEmail: 'admin@example.invalid',
        ),
        assetClassLabel: 'All',
        assetLabel: 'All',
        furnaceAssets: [],
        currentBurnerRounds: {},
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _PreparationHarness {
  _PreparationHarness() {
    final filter = OperationsReportFilter(
      startDate: DateTime.utc(2026, 9, 1),
      endDate: DateTime.utc(2026, 9, 21),
      queryPlan: OperationsReportQueryPlan.forSections({
        OperationsReportSection.safetyCriticalAlarms,
      }),
    );
    final report = buildOperationsReport(
      filter: filter,
      tickets: [],
      executions: [],
      events: [],
      assetClasses: [],
      assetInstances: [],
      overview: const PlantAssetOverview(classes: [], assets: []),
      asOf: DateTime.utc(2026, 9, 21),
    );
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => actors.stream),
        operationsReportProvider.overrideWith(
          (ref, scope) => AsyncData(report),
        ),
      ],
    );
    screen = OperationsReportPreparationScreen(
      actorUid: actor.uid,
      filter: filter,
      request: OperationsReportDocumentRequest.forPreset(
        preset: OperationsReportDocumentPreset.custom,
        generatedAt: DateTime.utc(2026, 9, 21),
        generatedByName: actor.name,
        generatedByEmail: actor.email,
      ).copyWith(sections: {OperationsReportSection.safetyCriticalAlarms}),
    );
  }

  final actor = AppUser(
    uid: 'admin',
    name: 'Admin',
    email: 'admin@example.invalid',
    roles: [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  final actors = StreamController<AppUser?>.broadcast();
  late final ProviderContainer container;
  late final OperationsReportPreparationScreen screen;

  Future<void> open(WidgetTester tester) async {
    // Exercise actual PDF generation while keeping native print/raster support
    // outside this report authority and byte-identity regression.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('net.nfet.printing'),
      (call) async =>
          call.method == 'printingInfo' ? <String, dynamic>{} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('net.nfet.printing'),
        null,
      ),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: screen),
      ),
    );
    actors.add(actor);
    await tester.pump();
    expect(find.byType(ZoomablePdfPreview), findsOneWidget);
  }

  Future<void> dispose() async {
    container.dispose();
    await actors.close();
  }
}

class _Harness {
  _Harness() {
    final actor = AppUser(
      uid: 'admin',
      name: 'Admin',
      email: 'admin@example.invalid',
      roles: [AppRole.admin],
      isApproved: true,
      createdAt: DateTime.utc(2026),
    );
    provider = operationsReportProvider((
      actorUid: actor.uid,
      filter: OperationsReportFilter(
        startDate: DateTime.utc(2026, 9, 1),
        endDate: DateTime.utc(2026, 9, 21),
        queryPlan: OperationsReportQueryPlan.forSections({
          OperationsReportSection.safetyCriticalAlarms,
        }),
      ),
    ));
    Never unexpected() {
      unrelatedReads++;
      throw StateError('unrelated source queried');
    }

    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) async* {
          yield actor;
          yield* actors.stream;
        }),
        assetClassesProvider.overrideWith((ref) => Stream.value([])),
        allAssetInstancesProvider.overrideWith((ref) => Stream.value([])),
        innerCoverProfilesProvider.overrideWith((ref) => Stream.value([])),
        operationsReportClockProvider.overrideWith(
          (ref) => Stream.value(DateTime.utc(2026, 9, 21)),
        ),
        criticalAlarmsForReportsProvider.overrideWith((ref, uid) {
          alarmReads++;
          return failAlarms
              ? Stream.error(StateError('alarm source failed'))
              : Stream.value([]);
        }),
        operationsReportTicketsProvider.overrideWith(
          (ref, scope) => unexpected(),
        ),
        operationsReportExecutionsProvider.overrideWith(
          (ref, scope) => unexpected(),
        ),
        operationsReportExecutionBatchProvider.overrideWith(
          (ref, scope) => unexpected(),
        ),
        operationalEventsForReportsProvider.overrideWith(
          (ref, uid) => unexpected(),
        ),
        maintenanceDueStatesProvider.overrideWith((ref) => unexpected()),
        allInspectionFindingsProvider.overrideWith((ref) => unexpected()),
        qualityWarningsForReportsProvider.overrideWith(
          (ref, uid) => unexpected(),
        ),
        qualityMonitoringRequestsForReportsProvider.overrideWith(
          (ref, uid) => unexpected(),
        ),
        operationsReportAbnormalitiesProvider.overrideWith(
          (ref, uid) => unexpected(),
        ),
        openDirectivesProvider.overrideWith((ref) => unexpected()),
        workflowAllLanesProvider.overrideWith((ref) => unexpected()),
        workflowAllComplianceProvider.overrideWith((ref) => unexpected()),
        plantAssetOverviewProvider.overrideWith((ref) => unexpected()),
      ],
    );
    subscription = container.listen(provider, (_, __) {});
  }
  final actors = StreamController<AppUser?>.broadcast();
  int unrelatedReads = 0;
  int alarmReads = 0;
  bool failAlarms = false;
  late final ProviderContainer container;
  late final AutoDisposeProvider<AsyncValue<OperationsReport>> provider;
  late final ProviderSubscription<AsyncValue<OperationsReport>> subscription;
  AsyncValue<OperationsReport> get report => container.read(provider);
  Future<void> settle() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> dispose() async {
    subscription.close();
    container.dispose();
    await actors.close();
  }
}
