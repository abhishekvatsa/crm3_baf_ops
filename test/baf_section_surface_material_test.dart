import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/dashboard/dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final padding in <EdgeInsets>[
    const EdgeInsets.symmetric(
      horizontal: BafSpacing.md,
      vertical: BafSpacing.xs,
    ),
    EdgeInsets.zero,
  ]) {
    testWidgets(
      'section ListTile paints and responds above its surface with $padding',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 915));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var opened = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: BafAppTheme.light,
            home: Scaffold(
              body: BafSectionSurface(
                padding: padding,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.report_problem_outlined),
                  title: const Text('Open issues'),
                  subtitle: const Text('2 requiring attention'),
                  selected: true,
                  selectedTileColor: BafColors.surfaceMuted,
                  onTap: () => opened = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Flutter reports when a decorated surface masks a ListTile's
        // nearest Material. Keep that framework diagnostic active.
        expect(tester.takeException(), isNull);
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Open issues')),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
