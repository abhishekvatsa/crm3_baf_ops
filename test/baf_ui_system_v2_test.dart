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
