import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../tool/test_support/home_class_overview_fixture.dart';

void main() {
  for (final scenario in [
    (320.0, 1.0),
    (390.0, 1.8),
    (800.0, 1.0),
    (320.0, 2.5),
  ]) {
    testWidgets(
      'pulse preserves action and assurance routes without a pooled percent at $scenario',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(scenario.$1, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final taps = <String>[];
        final full = homeClassOverviewFixture();
        final available = PlantAssetOverview(
          classes: full.classes
              .where((c) => ['furnaces', 'coolers'].contains(c.assetClass.id))
              .toList(),
          assets: full.assets
              .where((r) => r.asset.assetClassId != 'bases')
              .toList(),
        );
        await _pump(tester, available, taps, scale: scenario.$2);
        expect(find.text('Availability'), findsNothing);
        expect(find.textContaining(RegExp(r'^\d+%$')), findsNothing);
        expect(
          find.text('17 open issues form the leading action queue.'),
          findsOneWidget,
        );
        expect(find.text('No recorded class restrictions.'), findsOneWidget);
        for (final label in ['Action queues', 'Assurance queues']) {
          final text = find.text(label);
          expect(
            tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
            isFalse,
          );
          await tester.ensureVisible(text);
          await tester.pumpAndSettle();
          await tester.tap(text);
        }
        expect(taps, ['issues', 'monitoring']);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'pulse identifies the restricted class even when other classes are all available',
    (tester) async {
      final taps = <String>[];
      await _pump(tester, homeClassOverviewFixture(), taps);
      final base = find.byKey(const ValueKey('home-pulse-class-bases'));
      expect(base, findsOneWidget);
      expect(tester.getSize(base).height, greaterThanOrEqualTo(48));
      expect(
        find.byKey(const ValueKey('home-pulse-class-furnaces')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-pulse-class-coolers')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('home-pulse-class-covers')),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp(r'Bases.*12 unavailable')),
        findsOneWidget,
      );
      await tester.ensureVisible(base);
      await tester.pumpAndSettle();
      await tester.tap(base);
      expect(taps, ['class:bases']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unverified class conditions stay visible without all-clear claims',
    (tester) async {
      final taps = <String>[];
      await _pump(tester, homeClassOverviewFixture(unverified: true), taps);
      expect(
        find.textContaining(RegExp(r'Bases.*1 unverified')),
        findsOneWidget,
      );
      expect(find.text('No recorded class restrictions.'), findsNothing);
      final retry = find.text(
        'Live sources are incomplete. Refresh before final decisions.',
      );
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      expect(taps, ['retry']);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  PlantAssetOverview overview,
  List<String> taps, {
  double scale = 1,
}) async {
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
          padding: const EdgeInsets.all(16),
          child: HomeManagementPulsePanel(
            plantOverview: AsyncData(overview),
            dataUnavailable: false,
            onOpenReports: () => taps.add('reports'),
            onPlantCondition: () => taps.add('plant'),
            onOpenClass: (id) => taps.add('class:$id'),
            onIssues: () => taps.add('issues'),
            onWork: () => taps.add('work'),
            onControl: () => taps.add('control'),
            onQualityMonitoring: () => taps.add('monitoring'),
            onRetry: () => taps.add('retry'),
            onMaintenanceRhythm: () => taps.add('rhythm'),
            onInspectionProgrammes: () => taps.add('inspection'),
            ticketCount: 17,
            executionCount: 0,
            directiveCount: 0,
            workflowAttentionCount: 0,
            openOperationalEventCount: 0,
            openQualityWarningCount: 0,
            activeQualityMonitoringCount: 6,
            overdueMaintenanceCount: 0,
            activeInspectionFindingCount: 0,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
