import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/baf_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BAF UI system v2', () {
    for (final size in <Size>[
      const Size(320, 700),
      const Size(412, 915),
      const Size(900, 700),
    ]) {
      testWidgets('shared page primitives remain stable at ${size.width}px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: BafAppTheme.light,
            home: Scaffold(
              body: BafContentFrame(
                child: ListView(
                  children: [
                    const BafScreenIntro(
                      title: 'Equipment availability and maintenance state',
                      subtitle:
                          'Authoritative workflow facts, operational readiness and accountable recovery.',
                      icon: Icons.precision_manufacturing_outlined,
                      accent: BafColors.assets,
                      trailing: Chip(label: Text('47 assets')),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    BafSearchField(
                      hintText: 'Search asset, component or responsibility',
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    const BafRecordSurface(
                      accent: BafColors.warning,
                      child: Text(
                        'Base 201 requires operational support before maintenance can continue.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('47 assets'), findsOneWidget);
        expect(find.byType(BafSearchField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('state panel exposes a clear recovery action', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: BafStatePanel.error(
              title: 'Workflow state is unavailable',
              message: 'The latest governed projection could not be loaded.',
              onPrimary: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared surfaces tolerate enlarged text on a narrow phone', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: BafStatePanel(
                icon: Icons.fact_check_outlined,
                color: BafColors.directives,
                title: 'No actionable compliance obligations',
                message:
                    'Nothing currently needs acknowledgement, completion or supervisory review in this lane.',
                primaryLabel: 'Refresh obligations',
                primaryIcon: Icons.refresh_rounded,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refresh obligations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final size in <Size>[
      const Size(320, 700),
      const Size(412, 915),
      const Size(1024, 768),
    ]) {
      testWidgets('screen shell and all governed states fit at ${size.width}px', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            theme: BafAppTheme.light,
            home: BafScreenScaffold(
              title: 'Maintenance intelligence',
              subtitle: 'Due state, governed plans and completion history',
              icon: Icons.event_repeat_rounded,
              accent: BafColors.planned,
              actions: [
                IconButton(
                  tooltip: 'Refresh maintenance intelligence',
                  onPressed: () {},
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
              body: ListView(
                children: const [
                  BafLoadingPanel(label: 'Loading governed maintenance state'),
                  BafStatePanel(
                    icon: Icons.lock_outline_rounded,
                    color: BafColors.danger,
                    title: 'Approved authority required',
                    message:
                        'An approved maintenance role is required to continue.',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Maintenance intelligence'), findsOneWidget);
        expect(find.byTooltip('Refresh maintenance intelligence'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('app-bar identity remains stable at 200 percent text scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(2),
                ),
                child: child!,
              ),
          home: const BafScreenScaffold(
            title: 'Inspection programmes',
            subtitle: 'Component evidence across selected assets',
            icon: Icons.fact_check_outlined,
            accent: BafColors.instrument,
            body: BafStatePanel(
              icon: Icons.inbox_outlined,
              color: BafColors.instrument,
              title: 'No active programmes',
              message: 'There are no inspection campaigns in this view.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Inspection programmes'), findsOneWidget);
      expect(find.text('Component evidence across selected assets'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('migrated operational surfaces use the shared page language', () {
      const paths = <String>[
        'lib/features/maintenance_workflow/presentation/screens/'
            'equipment_status_board.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'lane_classification_screen.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'compliance_inbox_screen.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'compliance_detail_screen.dart',
        'lib/features/maintenance_workflow/presentation/screens/'
            'workflow_diagnostics_screen.dart',
      ];

      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(source, contains('BafAppBarTitle('), reason: path);
        expect(source, contains('BafContentFrame('), reason: path);
      }
    });

    test('primary creation does not float over directive records', () {
      final source = File(
        'lib/features/directives/presentation/directives_screen.dart',
      ).readAsStringSync();

      expect(source, contains("label: const Text('New Directive')"));
      expect(source, contains('onCreate:'));
      expect(source, isNot(contains('FloatingActionButton')));
      expect(source, isNot(contains('Positioned(')));
    });

    test('operational events exposes one stable creation control', () {
      final source = File(
        'lib/features/operational_events/presentation/'
        'operational_events_screen.dart',
      ).readAsStringSync();

      expect(source, contains("tooltip: 'Record event'"));
      expect(source, isNot(contains('FloatingActionButton')));
    });

    test('user-facing screens cannot regress to legacy shell states', () {
      final files = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('_screen.dart') ||
                file.path.endsWith('_form.dart'),
          );
      final plainAppBarTitle = RegExp(
        r'appBar\s*:\s*AppBar\([\s\S]{0,180}?title\s*:\s*(?:const\s+)?Text\(',
      );
      final bareStateScaffold = RegExp(
        r'Scaffold\([\s\S]{0,220}?body\s*:\s*(?:const\s+)?Center\('
        r'[\s\S]{0,120}?(?:CircularProgressIndicator|Text)\(',
      );

      for (final file in files) {
        final source = file.readAsStringSync();
        expect(
          plainAppBarTitle.hasMatch(source),
          isFalse,
          reason: '${file.path} uses a plain text app-bar identity',
        );
        expect(
          bareStateScaffold.hasMatch(source),
          isFalse,
          reason: '${file.path} uses a bare full-screen state',
        );
      }
    });

    test('display typography does not use ad-hoc letter spacing', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final expression = RegExp(r'letterSpacing\s*:\s*(-?\d+(?:\.\d+)?)');

      for (final file in dartFiles) {
        final source = file.readAsStringSync();
        for (final match in expression.allMatches(source)) {
          expect(
            double.parse(match.group(1)!),
            0,
            reason: '${file.path} uses non-system letter spacing',
          );
        }
      }
    });
  });
}
