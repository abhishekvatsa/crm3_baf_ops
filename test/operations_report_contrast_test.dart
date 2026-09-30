import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/reports/models/operations_report.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color first, Color second) {
  final firstLight = first.computeLuminance();
  final secondLight = second.computeLuminance();
  final high = firstLight > secondLight ? firstLight : secondLight;
  final low = firstLight < secondLight ? firstLight : secondLight;
  return (high + 0.05) / (low + 0.05);
}

void main() {
  testWidgets(
    'large report values remain readable on their actual dark metric surfaces',
    (tester) async {
      final date = DateTime(2026, 9, 30);
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: OperationsManagementReadout(
                report: _report(
                  OperationsReportFilter(startDate: date, endDate: date),
                ),
                onAvailability: () {},
                onWork: () {},
                onAssurance: () {},
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
        final ink = tester.widget<Ink>(
          find.descendant(of: tile, matching: find.byType(Ink)),
        );
        final decoration = ink.decoration! as BoxDecoration;
        final background = Color.alphaBlend(
          decoration.color!,
          BafColors.graphite,
        );
        final value = tester
            .widgetList<Text>(
              find.descendant(of: tile, matching: find.byType(Text)),
            )
            .first;
        expect(
          _contrast(value.style!.color!, background),
          greaterThanOrEqualTo(3.0),
          reason: '$label is large bold text on a dark surface',
        );
      }
    },
  );

  testWidgets(
    'each selected narrow report tab has a visible icon on the pale selected surface',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = OperationsReportView.overview;
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => OperationsReportViewSelector(
                selected: selected,
                onChanged: (next) => setState(() => selected = next),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Overview',
        'Work',
        'Control',
        'Reliability',
        'Assurance',
      ]) {
        final chip = find.widgetWithText(ChoiceChip, label);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
        final avatar = find.descendant(of: chip, matching: find.byType(Icon));
        final icon = tester.widget<Icon>(avatar);
        final foreground =
            icon.color ?? IconTheme.of(tester.element(avatar)).color!;
        final background = Color.alphaBlend(
          BafAppTheme.light.chipTheme.selectedColor!,
          BafColors.surfaceRaised,
        );
        expect(
          _contrast(foreground, background),
          greaterThanOrEqualTo(3.0),
          reason: '$label selected icon must remain discernible',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
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
