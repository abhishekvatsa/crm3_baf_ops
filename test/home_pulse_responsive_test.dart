import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [(320.0, 1.0), (390.0, 1.8), (800.0, 1.0)]) {
    testWidgets('pulse preserves signals and actions at $scenario', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(scenario.$1, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: HomeManagementPulsePanel(
                  plantOverview: const AsyncData(
                    PlantAssetOverview(classes: [], assets: []),
                  ),

                  dataUnavailable: false,
                  onOpenReports: () => taps.add('reports'),
                  onPlantCondition: () => taps.add('plant'),
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
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNWidgets(2));
      expect(
        find.text('17 open issues form the leading action queue.'),
        findsOneWidget,
      );
      expect(find.text('0 of 0 assets'), findsOneWidget);
      for (final label in [
        'Availability',
        'Action queues',
        'Assurance queues',
      ]) {
        final text = find.text(label);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      final availability = tester.getTopLeft(find.text('Availability'));
      final actions = tester.getTopLeft(find.text('Action queues'));
      // Ordinary phone text keeps all three metrics on one compact row.
      expect(actions.dy, availability.dy);
      expect(actions.dx, greaterThan(availability.dx));
      if (scenario.$2 == 1.0) {
        final assurance = tester.getTopLeft(find.text('Assurance queues'));
        expect(assurance.dy, availability.dy);
        expect(
          tester.getSize(find.byType(HomeManagementPulsePanel)).height,
          lessThan(270),
        );
      }
      for (final label in [
        'Availability',
        'Action queues',
        'Assurance queues',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }
      expect(taps, ['plant', 'issues', 'monitoring']);
      expect(tester.takeException(), isNull);
    });
  }
}
