import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final retainedValue in [false, true]) {
    testWidgets(
      'plant query denial is visible without throwing (retained=$retainedValue)',
      (tester) async {
        var retries = 0;
        const confirmed = AsyncData(
          PlantAssetOverview(classes: [], assets: []),
        );
        final denied = AsyncError<PlantAssetOverview>(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
          StackTrace.fromString('MethodChannelQuery.snapshots'),
        );
        final state = retainedValue
            ? denied.copyWithPrevious(confirmed)
            : denied;
        await tester.pumpWidget(_panel(state, () => retries++));
        expect(tester.takeException(), isNull);
        expect(find.text('Plant data unavailable'), findsOneWidget);
        expect(find.text('0 of 0 assets'), findsNothing);
        expect(
          find.text('No exception in these summary queues.'),
          findsNothing,
        );
        final retry = find.text(
          'Live sources are incomplete. Refresh before final decisions.',
        );
        expect(retry, findsOneWidget);
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        expect(retries, 1);

        await tester.pumpWidget(_panel(confirmed, () => retries++));
        expect(find.text('Plant data unavailable'), findsNothing);
        expect(find.text('No equipment inventory verified.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _panel(AsyncValue<PlantAssetOverview> state, VoidCallback retry) =>
    MaterialApp(
      theme: BafAppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeManagementPulsePanel(
            plantOverview: state,

            dataUnavailable: false,
            onOpenReports: () {},
            onPlantCondition: () {},
            onIssues: () {},
            onWork: () {},
            onControl: () {},
            onQualityMonitoring: () {},
            onRetry: retry,
            onMaintenanceRhythm: () {},
            onInspectionProgrammes: () {},
            ticketCount: 0,
            executionCount: 0,
            directiveCount: 0,
            workflowAttentionCount: 0,
            openOperationalEventCount: 0,
            openQualityWarningCount: 0,
            activeQualityMonitoringCount: 0,
            overdueMaintenanceCount: 0,
            activeInspectionFindingCount: 0,
          ),
        ),
      ),
    );
