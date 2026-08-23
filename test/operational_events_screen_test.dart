import 'dart:async';

import 'package:crm3_baf_ops/core/providers/operations_report_clock_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_events_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone layout exposes event entry and impact intelligence', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final clock = StreamController<DateTime>();
    addTearDown(clock.close);
    clock.add(now);
    final event = _openCraneEvent(now);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_operationsUser(now)),
          ),
          assetClassesProvider.overrideWith((ref) => Stream.value(const [])),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          operationalEventsProvider.overrideWith(
            (ref) => Stream.value([event]),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref) => Stream.value([event]),
          ),
          operationsReportClockProvider.overrideWith((ref) => clock.stream),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Add event'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('operational-events-monthly-impact')),
      findsOneWidget,
    );
    expect(find.text('Cumulative impact'), findsOneWidget);
    expect(find.text('Occurrences'), findsOneWidget);
    expect(find.text('Event records'), findsOneWidget);
    expect(find.textContaining('Highest impact topic: Crane'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('operational-event-topic-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Water').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('operational-event-topic-water')),
      findsOneWidget,
    );
    expect(find.textContaining('Highest impact topic:'), findsNothing);

    final totalImpact = find.textContaining('Total impact');
    await tester.scrollUntilVisible(
      totalImpact,
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(totalImpact, findsOneWidget);
    expect(find.textContaining('Total impact 1h 30m'), findsOneWidget);
    expect(find.textContaining('ongoing'), findsOneWidget);

    clock.add(now.add(const Duration(minutes: 1)));
    await tester.pump();
    expect(find.textContaining('Total impact 1h 31m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unapproved direct entry performs no operational data reads', (
    tester,
  ) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_operationsUser(now, approved: false)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.error(StateError('asset classes must not be read')),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.error(StateError('assets must not be read')),
          ),
          operationalEventsProvider.overrideWith(
            (ref) => Stream.error(StateError('events must not be read')),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref) => Stream.error(StateError('history must not be read')),
          ),
          operationsReportClockProvider.overrideWith(
            (ref) => Stream.error(StateError('clock must not be read')),
          ),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Operational-event access required'), findsOneWidget);
    expect(find.text('Monthly impact'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

AppUser _operationsUser(DateTime now, {bool approved = true}) => AppUser(
  uid: 'operations-1',
  name: 'Operations One',
  email: 'operations@example.com',
  roles: const [AppRole.operations],
  isApproved: approved,
  createdAt: now,
);

OperationalEvent _openCraneEvent(DateTime now) {
  final startedAt = now.subtract(const Duration(minutes: 90));
  return OperationalEvent(
    eventId: 'crane-event-1',
    eventType: OperationalEventType.crane,
    title: 'Charging crane unavailable',
    description: 'Crane movement is unavailable during charging operations.',
    severity: OperationalEventSeverity.significant,
    scope: OperationalEventScope.plantWide,
    affectedAssetClassIds: const [],
    affectedAssetInstanceIds: const [],
    startedAt: startedAt,
    status: OperationalEventStatus.open,
    createdAt: startedAt,
    createdByUid: 'operations-1',
    createdByName: 'Operations One',
    resolvedAt: null,
    resolvedByUid: null,
    resolvedByName: null,
    resolutionNote: null,
    version: 1,
    updatedAt: now,
    updatedByUid: 'operations-1',
    updatedByName: 'Operations One',
    lastMutationId: 'event-create-1',
  );
}
