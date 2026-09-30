import 'dart:async';

import 'package:crm3_baf_ops/core/providers/operations_report_clock_provider.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_events_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final item in [
    (filter: 'open', count: 2, title: 'Synthetic open critical', label: 'Open'),
    (
      filter: 'critical',
      count: 1,
      title: 'Synthetic open critical',
      label: 'Critical open',
    ),
    (
      filter: 'resolved',
      count: 1,
      title: 'Synthetic resolved critical',
      label: 'Recent resolved',
    ),
    (
      filter: 'withdrawn',
      count: 1,
      title: 'Synthetic withdrawn critical',
      label: 'Withdrawn',
    ),
  ]) {
    testWidgets('${item.filter} summary selects the exact counted records', (
      tester,
    ) async {
      await _pump(tester, _events);
      final summary = _metric(item.filter);
      expect(
        find.descendant(of: summary, matching: find.text('${item.count}')),
        findsOneWidget,
      );
      await tester.tap(summary);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(summary).properties.selected, isTrue);
      expect(tester.widget<Semantics>(summary).properties.button, isTrue);
      expect(
        tester.widget<Semantics>(summary).properties.label,
        '${item.label}, ${item.count} events',
      );
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('operational-event-status-filter')),
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(ValueKey('operational-event-filter-${item.filter}')),
            )
            .selected,
        isTrue,
      );
      await _scrollTo(
        tester,
        find.byKey(const ValueKey('operational-event-list')),
      );
      final list = tester.widget<SliverList>(
        find.byKey(const ValueKey('operational-event-list')),
      );
      expect(list.delegate.estimatedChildCount, item.count * 2 - 1);
      await _scrollTo(tester, find.text(item.title));
      expect(find.text(item.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'zero critical count is actionable and names the empty selection',
    (tester) async {
      await _pump(tester, [_event('open-advisory')]);
      await tester.tap(_metric('critical'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('No critical open operational events'));
      expect(find.text('No critical open operational events'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('operational-event-list')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'live events update the selected count without changing filter or writing',
    (tester) async {
      final changes = StreamController<List<OperationalEvent>>();
      addTearDown(changes.close);
      await _pump(tester, _events, changes: changes.stream);
      await tester.tap(_metric('critical'));
      await tester.pumpAndSettle();
      changes.add([_event('open-advisory')]);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(_metric('critical')).properties.selected,
        isTrue,
      );
      expect(
        find.descendant(of: _metric('critical'), matching: find.text('0')),
        findsOneWidget,
      );
      await _scrollTo(tester, find.text('No critical open operational events'));
      expect(find.text('No critical open operational events'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('revoked approval hides summary and event content', (
    tester,
  ) async {
    final actors = StreamController<AppUser?>();
    addTearDown(actors.close);
    await _pump(tester, _events, actors: actors.stream);
    expect(_metric('open'), findsOneWidget);
    actors.add(_actor(approved: false));
    await tester.pumpAndSettle();
    expect(_metric('open'), findsNothing);
    expect(find.text('Operational-event access required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final geometry in [
    (width: 320.0, scale: 2.0),
    (width: 390.0, scale: 1.0),
    (width: 800.0, scale: 1.0),
  ]) {
    testWidgets(
      'summary remains readable and tappable at ${geometry.width}/${geometry.scale}',
      (tester) async {
        await _pump(tester, [], width: geometry.width, scale: geometry.scale);
        for (final filter in ['open', 'critical', 'resolved', 'withdrawn']) {
          await _scrollTo(tester, _metric(filter));
          final rect = tester.getRect(_metric(filter));
          expect(rect.width, greaterThanOrEqualTo(120));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(geometry.width));
          for (final label in tester.widgetList<Text>(
            find.descendant(of: _metric(filter), matching: find.byType(Text)),
          )) {
            expect(label.overflow, isNot(TextOverflow.ellipsis));
            expect(label.maxLines, isNull);
          }
          await tester.tap(_metric(filter));
          await tester.pumpAndSettle();
          expect(
            tester.widget<Semantics>(_metric(filter)).properties.selected,
            isTrue,
          );
          expect(tester.takeException(), isNull);
        }
        await _scrollTo(
          tester,
          find.byKey(const ValueKey('operational-event-status-filter')),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Finder _metric(String name) =>
    find.byKey(ValueKey('operational-event-summary-$name'));
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 40,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

final _now = DateTime(2026, 9, 30, 12);
final _events = [
  _event('open-critical', severity: OperationalEventSeverity.critical),
  _event('open-advisory'),
  _event(
    'resolved-critical',
    severity: OperationalEventSeverity.critical,
    resolved: true,
  ),
  _event(
    'withdrawn-critical',
    severity: OperationalEventSeverity.critical,
    withdrawn: true,
  ),
];
AppUser _actor({bool approved = true}) => AppUser(
  uid: 'synthetic-operator',
  name: 'Synthetic Operator',
  email: 'fixture@example.test',
  roles: [AppRole.operations],
  isApproved: approved,
  createdAt: _now,
);
Future<void> _pump(
  WidgetTester tester,
  List<OperationalEvent> events, {
  double width = 800,
  double scale = 1,
  Stream<List<OperationalEvent>>? changes,
  Stream<AppUser?>? actors,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) async* {
          yield _actor();
          if (actors != null) yield* actors;
        }),
        assetClassesProvider.overrideWith((ref) => Stream.value(const [])),
        allAssetInstancesProvider.overrideWith((ref) => Stream.value(const [])),
        operationalEventsProvider.overrideWith((ref, uid) async* {
          yield events;
          if (changes != null) yield* changes;
        }),
        operationalEventsForReportsProvider.overrideWith(
          (ref, uid) => Stream.value(events),
        ),
        operationsReportClockProvider.overrideWith((ref) => Stream.value(_now)),
        operationalEventServiceProvider.overrideWith(
          (ref) => throw StateError('Summary must not access mutation service'),
        ),
        operationalEventIssueLinkServiceProvider.overrideWith(
          (ref) =>
              throw StateError('Summary must not access link mutation service'),
        ),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const OperationalEventsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

OperationalEvent _event(
  String id, {
  OperationalEventSeverity severity = OperationalEventSeverity.advisory,
  bool resolved = false,
  bool withdrawn = false,
}) => OperationalEvent(
  eventId: id,
  eventType: OperationalEventType.crane,
  title: 'Synthetic ${id.replaceAll('-', ' ')}',
  description: 'Synthetic event for local interaction checks',
  severity: severity,
  scope: OperationalEventScope.plantWide,
  affectedAssetClassIds: const [],
  affectedAssetInstanceIds: const [],
  startedAt: _now.subtract(const Duration(hours: 1)),
  status: resolved
      ? OperationalEventStatus.resolved
      : OperationalEventStatus.open,
  createdAt: _now.subtract(const Duration(hours: 1)),
  createdByUid: 'synthetic-operator',
  createdByName: 'Synthetic Operator',
  resolvedAt: resolved ? _now : null,
  resolvedByUid: resolved ? 'synthetic-operator' : null,
  resolvedByName: resolved ? 'Synthetic Operator' : null,
  resolutionNote: resolved ? 'Synthetic resolved' : null,
  version: 1,
  updatedAt: _now,
  updatedByUid: 'synthetic-operator',
  updatedByName: 'Synthetic Operator',
  lastMutationId: 'synthetic-$id',
  isWithdrawn: withdrawn,
  withdrawalReason: withdrawn ? 'Duplicate synthetic event' : null,
  withdrawnAt: withdrawn ? _now : null,
  withdrawnByUid: withdrawn ? 'synthetic-operator' : null,
  withdrawnByName: withdrawn ? 'Synthetic Operator' : null,
);
