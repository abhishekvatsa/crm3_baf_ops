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
                  actionCount: 17,
                  assuranceCount: 6,
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
      expect(find.text('17'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('0 of 0 assets'), findsOneWidget);
      for (final label in [
        'Availability',
        'Action queue',
        'Assurance',
        'Issues, work and disruptions',
        'Monitoring, overdue and findings',
      ]) {
        final text = find.text(label);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      final availability = tester.getTopLeft(find.text('Availability'));
      final actions = tester.getTopLeft(find.text('Action queue'));
      if (scenario.$1 < 500) {
        expect(actions.dy, greaterThan(availability.dy));
      } else {
        expect(actions.dy, availability.dy);
        expect(actions.dx, greaterThan(availability.dx));
      }
      for (final label in ['Availability', 'Action queue', 'Assurance']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }
      expect(taps, ['plant', 'issues', 'monitoring']);
      expect(tester.takeException(), isNull);
    });
  }
}
