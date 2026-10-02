import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart'
    show AppRole;
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/presentation/quality_home_screen.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  testWidgets('the 4 Open and 11 Closed numbers select their warning lists', (
    tester,
  ) async {
    await _pump(tester, warnings: _screenshotPopulation());
    expect(find.text('Open warning 0'), findsOneWidget);
    await tester.tap(
      find.descendant(of: _metric('closed'), matching: find.text('11')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Closed warning 0'), findsOneWidget);
    expect(find.text('Open warning 0'), findsNothing);
    _expectSelected(tester, 'closed', 'Closed', 11);
    await tester.tap(
      find.descendant(of: _metric('open'), matching: find.text('4')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open warning 0'), findsOneWidget);
    expect(find.text('Closed warning 0'), findsNothing);
    _expectSelected(tester, 'open', 'Open', 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Open includes review and both filter controls stay synchronized',
    (tester) async {
      await _pump(
        tester,
        warnings: [
          _warning('Open', 0, QualityWarningStatus.open),
          _warning('Review', 0, QualityWarningStatus.closureRequested),
          _warning('Closed', 0, QualityWarningStatus.closed),
        ],
        size: const Size(360, 1400),
      );
      expect(
        find.text('Open includes warnings awaiting review.'),
        findsOneWidget,
      );
      _expectSelected(tester, 'open', 'Open', 2);
      expect(find.text('Open warning 0'), findsOneWidget);
      expect(find.text('Review warning 0'), findsOneWidget);
      await tester.tap(_metric('review'));
      await tester.pumpAndSettle();
      _expectSelected(tester, 'review', 'Review', 1);
      expect(find.text('Review warning 0'), findsOneWidget);
      expect(find.text('Open warning 0'), findsNothing);
      expect(find.text('Closed warning 0'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Review'))
            .selected,
        isTrue,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      for (final label in ['Open', 'Review', 'Closed']) {
        final count = label == 'Open' ? 2 : 1;
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('$label warnings: $count'))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isFalse,
        );
      }
      await tester.tap(find.widgetWithText(ChoiceChip, 'Closed'));
      await tester.pumpAndSettle();
      _expectSelected(tester, 'closed', 'Closed', 1);
      expect(find.text('Closed warning 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero Review remains actionable and gives an honest empty view', (
    tester,
  ) async {
    await _pump(tester, warnings: _screenshotPopulation());
    await tester.tap(
      find.descendant(of: _metric('review'), matching: find.text('0')),
    );
    await tester.pumpAndSettle();
    _expectSelected(tester, 'review', 'Review', 0);
    expect(find.text('No warnings in this view'), findsOneWidget);
    expect(find.text('Open warning 0'), findsNothing);
    expect(find.text('Closed warning 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected summary follows live counts without resetting the filter',
    (tester) async {
      final feed = StreamController<List<QualityWarning>>();
      addTearDown(feed.close);
      await _pump(tester, warnings: const [], feed: feed.stream);
      feed.add([_warning('Open', 0, QualityWarningStatus.open)]);
      await tester.pumpAndSettle();
      await tester.tap(_metric('closed'));
      await tester.pumpAndSettle();
      expect(find.text('No warnings in this view'), findsOneWidget);
      feed.add([
        _warning('Closed', 0, QualityWarningStatus.closed),
        _warning('Closed', 1, QualityWarningStatus.closed),
      ]);
      await tester.pumpAndSettle();
      _expectSelected(tester, 'closed', 'Closed', 2);
      expect(find.text('Closed warning 0'), findsOneWidget);
      expect(find.text('No warnings in this view'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('summary taps reset the visible batch after Show more', (
    tester,
  ) async {
    await _pump(
      tester,
      warnings: [
        _warning('Open', 0, QualityWarningStatus.open),
        for (var i = 0; i < 31; i++)
          _warning('Closed', i, QualityWarningStatus.closed),
      ],
    );
    await tester.tap(_metric('closed'));
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byKey(const ValueKey('quality-warnings-list')),
      matching: find.byType(Scrollable),
    );
    final more = find.byKey(const ValueKey('business-list-show-more'));
    await tester.scrollUntilVisible(
      more,
      600,
      scrollable: list,
      maxScrolls: 40,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Showing 30 of 31'),
      600,
      scrollable: list,
      maxScrolls: 40,
    );
    await tester.scrollUntilVisible(
      _metric('open'),
      -600,
      scrollable: list,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(_metric('open')),
      alignment: 0.2,
    );
    await tester.pumpAndSettle();
    await tester.tap(_metric('open'));
    await tester.pumpAndSettle();
    await tester.tap(_metric('closed'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Showing 15 of 31'),
      600,
      scrollable: list,
      maxScrolls: 40,
    );
    expect(find.text('Showing 30 of 31'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets('summary actions fit width $width at double text size', (
      tester,
    ) async {
      await _pump(
        tester,
        warnings: _screenshotPopulation(),
        size: Size(width, 1200),
        textScale: 2,
      );
      await tester.tap(_metric('closed'));
      await tester.pumpAndSettle();
      _expectSelected(tester, 'closed', 'Closed', 11);
      await tester.tap(_metric('review'));
      await tester.pumpAndSettle();
      expect(find.text('No warnings in this view'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Finder _metric(String status) =>
    find.byKey(ValueKey('quality-warning-metric-$status'));

void _expectSelected(WidgetTester tester, String key, String label, int count) {
  expect(_metric(key), findsOneWidget);
  expect(
    tester.getSemantics(find.bySemanticsLabel('$label warnings: $count')),
    matchesSemantics(
      label: '$label warnings: $count',
      isButton: true,
      isSelected: true,
      hasSelectedState: true,
      hasTapAction: true,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required List<QualityWarning> warnings,
  Stream<List<QualityWarning>>? feed,
  Size size = const Size(360, 1000),
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(
            AppUser(
              uid: 'quality-viewer',
              name: 'Quality Viewer',
              email: 'viewer@example.com',
              roles: const [AppRole.operations],
              isApproved: true,
              createdAt: DateTime.utc(2026, 9, 1),
            ),
          ),
        ),
        qualityWarningsProvider.overrideWith(
          (ref) => feed ?? Stream.value(warnings),
        ),
        qualityMonitoringRequestsProvider.overrideWith(
          (ref) => Stream.value(const <QualityMonitoringRequest>[]),
        ),
        linkedQualityAbnormalityProvider.overrideWith(
          (ref, id) => Stream<ChargeAbnormality?>.value(null),
        ),
        qualityCommandServiceProvider.overrideWith(
          (ref) =>
              throw StateError('Filtering must not access mutation commands'),
        ),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const QualityHomeScreen(),
      ),
    ),
  );
  // A live feed may not have emitted its first population yet.
  if (feed == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

List<QualityWarning> _screenshotPopulation() => [
  for (var i = 0; i < 4; i++) _warning('Open', i, QualityWarningStatus.open),
  for (var i = 0; i < 11; i++)
    _warning('Closed', i, QualityWarningStatus.closed),
];

QualityWarning _warning(String label, int index, QualityWarningStatus status) {
  final now = DateTime.utc(2026, 9, 1);
  return QualityWarning(
    warningId: '$label-$index',
    sourceType: QualityWarningSourceType.issue,
    sourceId: '$label-source-$index',
    sourceVersion: 1,
    sourceChargeNo: 50000 + index,
    sourceSummary: '$label warning $index',
    sourceSeverity: 'medium',
    warningReason: 'Synthetic test warning',
    affectedAssets: const [],
    status: status,
    createdAt: now,
    createdByUid: 'creator',
    updatedAt: now,
    updatedByUid: 'creator',
    version: 1,
    closureRequestedAt: status == QualityWarningStatus.closureRequested
        ? now
        : null,
    closureRequestedByUid: status == QualityWarningStatus.closureRequested
        ? 'creator'
        : null,
    closureRequestReason: status == QualityWarningStatus.closureRequested
        ? 'Review requested'
        : null,
    closedAt: status == QualityWarningStatus.closed ? now : null,
    closedByUid: status == QualityWarningStatus.closed ? 'reviewer' : null,
    closureDisposition: status == QualityWarningStatus.closed
        ? QualityWarningClosureDisposition.coilFoundAcceptable
        : null,
  );
}
