import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/incremental_list_footer.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_list_filter.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/presentation/quality_home_screen.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 9, 27);
final _actor = AppUser(
  uid: 'reader',
  name: 'Reader',
  email: 'reader@example.invalid',
  roles: [AppRole.operations],
  isApproved: true,
  createdAt: _now,
);

void main() {
  for (final metric in [
    (label: 'Total', count: 4, filter: AbnormalityListFilter.all),
    (label: 'RA pending', count: 2, filter: AbnormalityListFilter.open),
    (label: 'RA Done', count: 1, filter: AbnormalityListFilter.completed),
  ]) {
    testWidgets('charge ${metric.label} counter opens its exact population', (
      tester,
    ) async {
      await _show(
        tester,
        const ChargeAbnormalitiesScreen(sourceChargeNo: 91234),
        width: 320,
        textScale: 1.6,
        abnormalities: [
          _abnormality(0, ReannealingStatus.pendingDecision),
          _abnormality(1, ReannealingStatus.required),
          _abnormality(2, ReannealingStatus.completed),
          _abnormality(3, ReannealingStatus.notRequired),
        ],
      );
      final tile = find.byKey(
        ValueKey('charge-abnormality-metric-${metric.label}'),
      );
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tile.hitTestable(), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final field = find.byKey(
        const ValueKey('charge-abnormality-status-filter'),
      );
      expect(
        tester.state<FormFieldState<AbnormalityListFilter>>(field).value,
        metric.filter,
      );
      await _expectPage(
        tester,
        find.byKey(const ValueKey('charge-abnormalities-scroll')),
        metric.count,
        metric.count,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Quality filters and warning cards stay usable with large text', (
    tester,
  ) async {
    await _show(
      tester,
      const QualityHomeScreen(),
      width: 320,
      textScale: 1.6,
      warnings: [
        _warning(0, QualityWarningStatus.open),
        _warning(1, QualityWarningStatus.closureRequested),
      ],
    );
    final list = find.byKey(const ValueKey('quality-warnings-list'));
    await _chooseSegment(
      tester,
      list,
      'quality-warning-status-filter',
      'Review',
    );
    await _expectPage(tester, list, 1, 1);
    expect(find.text('Charge 10001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Large-text monitoring filters expose cancelled records', (
    tester,
  ) async {
    await _show(
      tester,
      const QualityHomeScreen.monitoring(),
      width: 320,
      textScale: 1.6,
      monitoring: [
        _monitoring(0, QualityMonitoringStatus.active),
        _monitoring(1, QualityMonitoringStatus.closed, cancelled: true),
      ],
    );
    final list = find.byKey(const ValueKey('quality-monitoring-list'));
    await _chooseSegment(
      tester,
      list,
      'quality-monitoring-status-filter',
      'Cancelled',
    );
    await _expectPage(tester, list, 1, 1);
    expect(find.text('Monitoring cycle 001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A narrow large-text charge card keeps its observation readable',
    (tester) async {
      await _show(
        tester,
        const ChargeAbnormalitiesScreen(sourceChargeNo: 91234),
        width: 320,
        textScale: 1.6,
        abnormalities: [_abnormality(0, ReannealingStatus.pendingDecision)],
      );
      final list = find.byKey(const ValueKey('charge-abnormalities-scroll'));
      await _expectPage(tester, list, 1, 1);
      expect(find.text('Observation 000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Quality status controls fit a narrow phone', (tester) async {
    await _show(tester, const QualityHomeScreen.monitoring(), width: 320);
    expect(
      find.byKey(const ValueKey('quality-monitoring-status-filter')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Quality warning status filters page 15, 30, remainder without limiting totals',
    (tester) async {
      final warnings = [
        for (var i = 0; i < 34; i++) _warning(i, QualityWarningStatus.open),
        for (var i = 34; i < 52; i++) _warning(i, QualityWarningStatus.closed),
        _warning(52, QualityWarningStatus.closureRequested),
        _warning(53, QualityWarningStatus.closureRequested),
      ].reversed.toList();
      await _show(tester, const QualityHomeScreen(), warnings: warnings);
      expect(find.text('Warnings (36)'), findsOneWidget);
      final list = find.byKey(const ValueKey('quality-warnings-list'));
      await _expectPage(tester, list, 15, 36);
      await _more(tester);
      await _expectPage(tester, list, 30, 36);
      await _more(tester);
      await _expectPage(tester, list, 36, 36);
      expect(
        find.byKey(const ValueKey('business-list-show-more')),
        findsNothing,
      );
      await _chooseSegment(
        tester,
        list,
        'quality-warning-status-filter',
        'All',
      );
      await _expectPage(tester, list, 15, 54);
      await _chooseSegment(
        tester,
        list,
        'quality-warning-status-filter',
        'Closed',
      );
      await _expectPage(tester, list, 15, 18);
      await _more(tester);
      await _expectPage(tester, list, 18, 18);
      await _chooseSegment(
        tester,
        list,
        'quality-warning-status-filter',
        'Review',
      );
      await _expectPage(tester, list, 2, 2);
      expect(warnings.length, 54);
      expect(
        warnings.first.warningId,
        'warning-053',
        reason: 'The provider list is not sorted or truncated in place',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Monitoring defaults open and distinguishes closed from cancelled after paging',
    (tester) async {
      final requests = [
        for (var i = 0; i < 34; i++)
          _monitoring(i, QualityMonitoringStatus.active),
        for (var i = 34; i < 52; i++)
          _monitoring(i, QualityMonitoringStatus.closed),
        _monitoring(52, QualityMonitoringStatus.closed, cancelled: true),
      ];
      await _show(
        tester,
        const QualityHomeScreen.monitoring(),
        monitoring: requests,
      );
      expect(find.text('Monitoring (34)'), findsOneWidget);
      final list = find.byKey(const ValueKey('quality-monitoring-list'));
      await _expectPage(tester, list, 15, 34);
      await _more(tester);
      await _expectPage(tester, list, 30, 34);
      await _more(tester);
      await _expectPage(tester, list, 34, 34);
      await _chooseSegment(
        tester,
        list,
        'quality-monitoring-status-filter',
        'All',
      );
      await _expectPage(tester, list, 15, 53);
      await _chooseSegment(
        tester,
        list,
        'quality-monitoring-status-filter',
        'Closed',
      );
      await _expectPage(tester, list, 15, 18);
      await _chooseSegment(
        tester,
        list,
        'quality-monitoring-status-filter',
        'Cancelled',
      );
      await _expectPage(tester, list, 1, 1);
      expect(find.text('Monitoring cycle 052'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Charge list pages matching RA states and resets after All or completed selection',
    (tester) async {
      final records = [
        for (var i = 0; i < 20; i++)
          _abnormality(i, ReannealingStatus.pendingDecision),
        for (var i = 20; i < 34; i++)
          _abnormality(i, ReannealingStatus.required),
        for (var i = 34; i < 52; i++)
          _abnormality(i, ReannealingStatus.completed),
        _abnormality(52, ReannealingStatus.notApplicable),
        _abnormality(53, ReannealingStatus.notRequired),
      ].reversed.toList();
      await _show(
        tester,
        const ChargeAbnormalitiesScreen(sourceChargeNo: 91234),
        abnormalities: records,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('charge-abnormalities-summary')),
          matching: find.text('54'),
        ),
        findsOneWidget,
      );
      final list = find.byKey(const ValueKey('charge-abnormalities-scroll'));
      await _expectPage(tester, list, 15, 34);
      await _more(tester);
      await _expectPage(tester, list, 30, 34);
      await _more(tester);
      await _expectPage(tester, list, 34, 34);
      await _chooseRa(tester, list, 'All');
      await _expectPage(tester, list, 15, 54);
      await _chooseRa(tester, list, 'RA completed');
      await _expectPage(tester, list, 15, 18);
      await _more(tester);
      await _expectPage(tester, list, 18, 18);
      await _chooseRa(tester, list, 'RA not applicable');
      await _expectPage(tester, list, 1, 1);
      expect(find.text('Observation 052'), findsOneWidget);
      expect(records.first.firestoreId, 'case-053');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _show(
  WidgetTester tester,
  Widget screen, {
  List<QualityWarning> warnings = const [],
  List<QualityMonitoringRequest> monitoring = const [],
  List<ChargeAbnormality> abnormalities = const [],
  double width = 430,
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 850));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => Stream.value(_actor)),
        qualityWarningsProvider.overrideWith((ref) => Stream.value(warnings)),
        qualityMonitoringRequestsProvider.overrideWith(
          (ref) => Stream.value(monitoring),
        ),
        linkedQualityAbnormalityProvider.overrideWith(
          (ref, id) => Stream.value(null),
        ),
        abnormalitiesForChargeProvider(
          91234,
        ).overrideWith((ref) => Stream.value(abnormalities)),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _scrollable(Finder list) =>
    find.descendant(of: list, matching: find.byType(Scrollable)).first;
Future<void> _expectPage(
  WidgetTester tester,
  Finder list,
  int visible,
  int total,
) async {
  final footer = find.descendant(
    of: list,
    matching: find.byType(IncrementalListFooter),
  );
  await tester.scrollUntilVisible(
    footer,
    700,
    scrollable: _scrollable(list),
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
  final widget = tester.widget<IncrementalListFooter>(footer);
  expect(widget.visibleCount, visible);
  expect(widget.totalCount, total);
  expect(find.text('Showing $visible of $total'), findsOneWidget);
}

Future<void> _more(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('business-list-show-more'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _chooseSegment(
  WidgetTester tester,
  Finder list,
  String key,
  String label,
) async {
  final filter = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    filter,
    -700,
    scrollable: _scrollable(list),
    maxScrolls: 100,
  );
  await Scrollable.ensureVisible(tester.element(filter), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: filter, matching: find.text(label)));
  await tester.pumpAndSettle();
}

Future<void> _chooseRa(WidgetTester tester, Finder list, String label) async {
  final filter = find.byKey(const ValueKey('charge-abnormality-status-filter'));
  await tester.scrollUntilVisible(
    filter,
    -700,
    scrollable: _scrollable(list),
    maxScrolls: 100,
  );
  await Scrollable.ensureVisible(tester.element(filter), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(filter);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

QualityWarning _warning(int i, QualityWarningStatus status) => QualityWarning(
  warningId: 'warning-${i.toString().padLeft(3, '0')}',
  sourceType: QualityWarningSourceType.issue,
  sourceId: 'issue-$i',
  sourceVersion: 1,
  sourceChargeNo: 10000 + i,
  sourceSummary: 'Warning $i',
  sourceSeverity: 'low',
  warningReason: 'Reported observation',
  affectedAssets: const [],
  status: status,
  createdAt: _now,
  createdByUid: 'reader',
  updatedAt: _now,
  updatedByUid: 'reader',
  version: 1,
);
QualityMonitoringRequest _monitoring(
  int i,
  QualityMonitoringStatus status, {
  bool cancelled = false,
}) => QualityMonitoringRequest(
  requestId: 'monitoring-${i.toString().padLeft(3, '0')}',
  baseNumber: 101,
  grade: 'Test grade',
  cycleReference: 'Monitoring cycle ${i.toString().padLeft(3, '0')}',
  chargeNumbers: const [],
  reason: 'Cycle observation',
  status: status,
  visibilityState: status == QualityMonitoringStatus.active
      ? QualityMonitoringVisibilityState.active
      : QualityMonitoringVisibilityState.recent,
  visibleUntil: _now.add(const Duration(days: 1)),
  archivedAt: null,
  createdAt: _now,
  createdByUid: 'reader',
  updatedAt: _now,
  updatedByUid: 'reader',
  version: 1,
  monitoringDisposition: cancelled ? 'cancelled' : null,
  closedAt: status == QualityMonitoringStatus.closed ? _now : null,
  closedByUid: status == QualityMonitoringStatus.closed ? 'reader' : null,
  closeReason: status == QualityMonitoringStatus.closed
      ? 'Recorded decision'
      : null,
);
ChargeAbnormality _abnormality(int i, ReannealingStatus status) =>
    ChargeAbnormality.createRaCoilColour(
        firestoreId: 'case-${i.toString().padLeft(3, '0')}',
        sourceChargeNo: 91234,
        affectedAssets: const [],
        observedReason: 'Observation ${i.toString().padLeft(3, '0')}',
        loggedByUid: 'reader',
        loggedByName: 'Reader',
      )
      ..reannealingStatus = status
      ..reannealedToChargeNo = status == ReannealingStatus.completed
          ? 91235
          : null
      ..loggedAt = _now
      ..updatedAt = _now;
