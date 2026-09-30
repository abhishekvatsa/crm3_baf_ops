import 'dart:ui' show SemanticsAction;
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

  for (final entry in const {
    'Availability': 'Current plant picture',
    'Issue outcomes': 'Work in period',
    'Issue impact': 'Work in period',
    'Planned complete': 'Work in period',
    'Assurance due': 'Maintenance assurance',
  }.entries) {
    testWidgets('${entry.key} opens its scoped section even with zero records', (
      tester,
    ) async {
      final scopes = <OperationsReportFilter>[];
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(tester, scopes);
      final before = scopes.last;
      final tile = find.byKey(ValueKey('operations-readout-${entry.key}'));
      await _reveal(tester, tile);
      final semantics = tester.ensureSemantics();
      final data = tester.getSemantics(tile).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains(entry.key));
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text(entry.value).hitTestable(), findsOneWidget);
      expect(
        scopes.every((scope) => scope == before),
        isTrue,
        reason:
            'Readout navigation must preserve the report date and asset scope',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('all readout tiles remain usable at 320px and scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final hits = <String>[];
      final date = DateTime(2026, 9, 30);
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OperationsManagementReadout(
                  report: _report(
                    OperationsReportFilter(startDate: date, endDate: date),
                  ),
                  onAvailability: () => hits.add('plant'),
                  onWork: () => hits.add('work'),
                  onAssurance: () => hits.add('assurance'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Availability',
        'Issue outcomes',
        'Issue impact',
        'Planned complete',
        'Assurance due',
      ]) {
        final tile = find.byKey(ValueKey('operations-readout-$label'));
        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(tile);
      }
      expect(hits, ['plant', 'work', 'work', 'work', 'assurance']);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _open(
  WidgetTester tester,
  List<OperationsReportFilter> scopes,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'report-reader',
              email: 'report-reader@example.invalid',
              name: 'Reader',
              roles: [AppRole.admin],
              isApproved: true,
              createdAt: DateTime(2026),
            ),
          ),
        ),
        assetClassesProvider.overrideWith(
          (ref) => Stream.value(const <AssetClassRecord>[]),
        ),
        allAssetInstancesProvider.overrideWith(
          (ref) => Stream.value(const <AssetInstanceRecord>[]),
        ),
        innerCoverProfilesProvider.overrideWith(
          (ref) => Stream.value(const <InnerCoverProfile>[]),
        ),
        operationsReportProvider.overrideWith((ref, scope) {
          scopes.add(scope.filter);
          return AsyncData(_report(scope.filter));
        }),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const FleetStatusScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    400,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 25,
  );
  await tester.pumpAndSettle();
}

OperationsReport _report(OperationsReportFilter filter) => OperationsReport(
  filter: filter,
  asOf: DateTime(2026, 9, 30),
  tickets: const [],
  executions: const [],
  events: const [],
  eventOccurrences: const [],
  dueStates: const [],
  inspectionFindings: const [],
  assetStates: const [],
  classSummaries: const [],
  topComponents: const [],
  topSubsystemPaths: const [],
  sourceTicketCount: 0,
  sourceExecutionCount: 0,
  sourceEventCount: 0,
  sourceDueStateCount: 0,
  sourceInspectionFindingCount: 0,
  disruptionCount: 0,
  openDisruptionCount: 0,
  disruptionDuration: Duration.zero,
);
