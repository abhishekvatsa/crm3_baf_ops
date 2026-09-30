import 'dart:io';
import 'dart:ui' as ui;

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

HomeQueueItem queue(
  HomeQueueKind kind, {
  String title = 'Review linked work',
  int? count = 2,
  bool action = true,
  bool unavailable = false,
  VoidCallback? onTap,
}) => HomeQueueItem(
  kind: kind,
  title: title,
  detail: unavailable
      ? 'Count unavailable'
      : 'Open the source queue to follow up',
  icon: Icons.assignment_outlined,
  color: BafColors.warning,
  count: count,
  needsAction: action,
  unavailable: unavailable,
  onTap: onTap ?? () {},
);

void main() {
  const evidenceDirectory = String.fromEnvironment('HOME_LAYOUT_EVIDENCE_DIR');
  if (evidenceDirectory.isNotEmpty) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(() async {
      await (FontLoader('Roboto')
            ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Roboto-Medium.ttf')))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
  }
  test(
    'queue identity removes repeated surfaces, never distinct linked records',
    () {
      final result = HomeQueuePartition([
        queue(HomeQueueKind.operationalEvents, action: false),
        queue(HomeQueueKind.operationalEvents),
        queue(HomeQueueKind.issues),
        queue(HomeQueueKind.qualityMonitoring, count: 7, action: false),
      ]);
      expect(result.attention.map((item) => item.kind), [
        HomeQueueKind.operationalEvents,
        HomeQueueKind.issues,
      ]);
      expect(result.attention.map((item) => item.count), [2, 2]);
      expect(result.attentionQueueCount, 2);
      expect(result.watch.single.kind, HomeQueueKind.qualityMonitoring);
      expect(result.watch.single.count, 7);
      expect(
        () => HomeQueuePartition([
          queue(HomeQueueKind.issues, count: 1),
          queue(HomeQueueKind.issues, count: 2),
        ]),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'one surface retains the action route and updates with queue state',
    (tester) async {
      final taps = <String>[];
      Widget page(bool active) => MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HomeAttentionQueues(
              dataUnavailable: false,
              onRetry: () {},
              items: [
                queue(
                  HomeQueueKind.operationalEvents,
                  count: active ? 3 : 0,
                  action: false,
                  onTap: () => taps.add('watch'),
                ),
                if (active)
                  queue(
                    HomeQueueKind.operationalEvents,
                    count: 3,
                    onTap: () => taps.add('action'),
                  ),
                queue(
                  HomeQueueKind.issues,
                  count: 4,
                  onTap: () => taps.add('issues'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      expect(
        find.byKey(const ValueKey('home-queue-operationalEvents')),
        findsOneWidget,
      );
      expect(find.text('Review linked work'), findsNWidgets(2));
      expect(find.text('2 queues'), findsOneWidget);
      expect(find.text('Operational watch'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('home-queue-operationalEvents')),
      );
      await tester.tap(find.byKey(const ValueKey('home-queue-issues')));
      expect(taps, ['action', 'issues']);

      await tester.pumpWidget(page(false));
      expect(find.text('1 queue'), findsOneWidget);
      expect(find.text('Operational watch'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-queue-operationalEvents')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('home-queue-operationalEvents')),
      );
      expect(taps.last, 'watch');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('incomplete monitoring never creates a false all-clear badge', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeAttentionQueues(
            items: [
              queue(
                HomeQueueKind.qualityMonitoring,
                count: null,
                action: false,
                unavailable: true,
              ),
            ],
            dataUnavailable: false,
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    expect(find.text('Incomplete'), findsOneWidget);
    expect(find.text('All clear'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-attention-refresh')));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty action queues make no claim about separate safety alerts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeAttentionQueues(
              items: [
                queue(HomeQueueKind.qualityMonitoring, count: 2, action: false),
              ],
              dataUnavailable: false,
              onRetry: () {},
            ),
          ),
        ),
      );
      expect(find.text('No actions'), findsOneWidget);
      expect(find.text('No actions in these queues.'), findsOneWidget);
      expect(find.text('All clear'), findsNothing);
      expect(
        find.text('No open work currently requires your attention.'),
        findsNothing,
      );
      expect(find.text('Operational watch'), findsOneWidget);
    },
  );

  for (final scenario in [
    (320.0, 1.0),
    (390.0, 1.0),
    (390.0, 1.8),
    (320.0, 2.5),
  ]) {
    testWidgets('compact Home surfaces fit $scenario without truncation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(scenario.$1, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: evidenceDirectory.isEmpty
              ? BafAppTheme.light
              : BafAppTheme.light.copyWith(
                  textTheme: BafAppTheme.light.textTheme.apply(
                    fontFamily: 'Roboto',
                  ),
                ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
              child: ColoredBox(
                color: BafColors.background,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        HomeManagementPulsePanel(
                          plantOverview: const AsyncData(
                            PlantAssetOverview(classes: [], assets: []),
                          ),
                          dataUnavailable: false,
                          onOpenReports: () {},
                          onPlantCondition: () {},
                          onIssues: () {},
                          onWork: () {},
                          onControl: () {},
                          onQualityMonitoring: () {},
                          onRetry: () {},
                          onMaintenanceRhythm: () {},
                          onInspectionProgrammes: () {},
                          ticketCount: 4,
                          executionCount: 0,
                          directiveCount: 0,
                          workflowAttentionCount: 0,
                          openOperationalEventCount: 1,
                          openQualityWarningCount: 4,
                          activeQualityMonitoringCount: 2,
                          overdueMaintenanceCount: 0,
                          activeInspectionFindingCount: 0,
                        ),
                        const SizedBox(height: 16),
                        HomeAttentionQueues(
                          dataUnavailable: false,
                          onRetry: () {},
                          items: [
                            queue(
                              HomeQueueKind.qualityWarnings,
                              title: 'Review quality warnings',
                              count: 4,
                            ),
                            queue(
                              HomeQueueKind.operationalEvents,
                              title: 'Review plant disruptions',
                              count: 1,
                            ),
                            queue(
                              HomeQueueKind.issues,
                              title: 'Review open issues',
                              count: 4,
                            ),
                            queue(
                              HomeQueueKind.qualityMonitoring,
                              title: 'Cycle monitoring',
                              count: 2,
                              action: false,
                            ),
                            queue(
                              HomeQueueKind.abnormalities,
                              title: 'Cycle abnormalities',
                              count: null,
                              action: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.byType(RichText),
      )) {
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
      if (evidenceDirectory.isNotEmpty && scenario == (390.0, 1.0)) {
        await tester.runAsync(() async {
          final image =
              await (capture.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(evidenceDirectory).create(recursive: true);
          await File(
            '$evidenceDirectory/home-390-scale-1.0-readable.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
