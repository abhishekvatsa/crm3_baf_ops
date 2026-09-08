import 'dart:async';

import 'package:crm3_baf_ops/core/providers/operations_report_clock_provider.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_events_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_service.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_creation_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scenario in [
    (
      scope: OperationalEventScope.assetClasses,
      classes: 21,
      assets: 0,
      label: 'Asset classes',
      error: 'Select no more than 20 asset classes.',
    ),
    (
      scope: OperationalEventScope.assets,
      classes: 1,
      assets: 51,
      label: 'Assets',
      error: 'Select no more than 50 assets.',
    ),
    (
      scope: OperationalEventScope.assets,
      classes: 21,
      assets: 21,
      label: 'Assets',
      error: 'Select assets from no more than 20 asset classes.',
    ),
  ]) {
    testWidgets('event form retains oversized ${scenario.classes} classes / '
        '${scenario.assets} assets draft until selection is corrected', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final classes = [
        for (var index = 0; index < scenario.classes; index++)
          AssetClassRecord(
            id: 'class-$index',
            code: 'CLASS$index',
            name: 'Class $index',
            majorArea: 'Test area',
            status: AssetHierarchyStatus.active,
            version: 1,
            createdAt: now,
            createdByUid: 'fixture-author',
            updatedAt: now,
            updatedByUid: 'fixture-author',
            lastMutationId: 'fixture',
          ),
      ];
      final assets = [
        for (var index = 0; index < scenario.assets; index++)
          AssetInstanceRecord(
            id: 'asset-$index',
            assetClassId: classes[index % classes.length].id,
            assetClassCode: classes[index % classes.length].code,
            assetClassName: classes[index % classes.length].name,
            assetNumber: index + 1,
            name: 'Fixture asset $index',
            serviceState: AssetServiceState.inService,
            ownershipStatus: AssetOwnershipStatus.unassigned,
            status: AssetHierarchyStatus.active,
            activeComponentCount: 0,
            version: 1,
            createdAt: now,
            updatedAt: now,
            lastMutationId: 'fixture',
          ),
      ];
      // Prefill the same state the unrestricted selector can produce, then use
      // the real form and selector to verify rejection and boundary recovery.
      final event = _openCraneEvent(
        now,
        scope: scenario.scope,
        classIds: classes.map((item) => item.id).toList(),
        assetIds: assets.map((item) => item.id).toList(),
      );
      final service = _RecordingOperationalEventService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_operationsUser(now)),
            ),
            assetClassesProvider.overrideWith((ref) => Stream.value(classes)),
            allAssetInstancesProvider.overrideWith(
              (ref) => Stream.value(assets),
            ),
            operationalEventsProvider.overrideWith(
              (ref, actorUid) => Stream.value([event]),
            ),
            operationalEventsForReportsProvider.overrideWith(
              (ref, actorUid) => Stream.value([event]),
            ),
            operationsReportClockProvider.overrideWith(
              (ref) => Stream.value(now),
            ),
            operationalEventServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: OperationalEventsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Edit event'));
      await tester.tap(find.byTooltip('Edit event'));
      await tester.pumpAndSettle();
      final title = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Title',
      );
      final reason = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Reason for correction',
      );
      await tester.enterText(title, 'Retained operator draft');
      await tester.enterText(reason, 'Correct the selected operational scope.');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(scenario.error), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Retained operator draft',
      );
      expect(
        tester.widget<TextField>(reason).controller!.text,
        'Correct the selected operational scope.',
      );
      expect(service.updatedDraft, isNull);

      final selection = find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator &&
            widget.decoration.labelText == scenario.label,
      );
      await tester.ensureVisible(selection);
      await tester.tap(selection);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.updatedDraft!.title, 'Retained operator draft');
      expect(service.updateReason, 'Correct the selected operational scope.');
      expect(
        service.updatedDraft!.affectedAssetClassIds,
        hasLength(scenario.classes == 21 ? 20 : 1),
      );
      expect(
        service.updatedDraft!.affectedAssetInstanceIds,
        hasLength(scenario.assets == 0 ? 0 : scenario.assets - 1),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('event entry offers retained creation retry before a new form', (
    tester,
  ) async {
    final now = DateTime.now();
    final service = _PendingCreationService();
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
            (ref, actorUid) => Stream.value(const []),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value(const []),
          ),
          operationsReportClockProvider.overrideWith(
            (ref) => Stream.value(now),
          ),
          operationalEventServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('operational-events-add')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm your previous event'), findsOneWidget);
    expect(find.textContaining('Saved supply interruption'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('operational-event-retry-creation')),
    );
    await tester.pumpAndSettle();
    expect(service.retried, isTrue);
    expect(service.expectedActor, 'operations-1');
    expect(service.expectedRequest, 'pending-request');
    expect(
      find.textContaining('Earlier event submission confirmed'),
      findsOneWidget,
    );
  });

  testWidgets('resolution defaults to verified server closure time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final event = _openCraneEvent(now);
    final service = _RecordingOperationalEventService();
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
            (ref, actorUid) => Stream.value([event]),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value([event]),
          ),
          operationsReportClockProvider.overrideWith(
            (ref) => Stream.value(now),
          ),
          operationalEventServiceProvider.overrideWithValue(service),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final resolve = find.byKey(
      const ValueKey('operational-event-resolve-crane-event-1'),
    );
    await tester.ensureVisible(resolve);
    await tester.pumpAndSettle();
    await tester.tap(resolve);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('operational-event-resolution-time')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('operational-event-resolution-time')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('operational-event-resolution-note')),
      'Crane operation remained stable after restoration checks.',
    );
    await tester.tap(
      find.byKey(const ValueKey('operational-event-resolution-submit')),
    );
    await tester.pumpAndSettle();

    expect(service.event, same(event));
    expect(
      service.resolutionNote,
      'Crane operation remained stable after restoration checks.',
    );
    expect(service.resolvedAt, isNull);
    expect(tester.takeException(), isNull);
  });

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
            (ref, actorUid) => Stream.value([event]),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value([event]),
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

  testWidgets('multi-day impact retains its remaining minutes', (tester) async {
    final now = DateTime(2026, 8, 24, 12);
    final event = _openCraneEvent(
      now,
      elapsed: const Duration(days: 1, minutes: 59),
    );

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
            (ref, actorUid) => Stream.value([event]),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value([event]),
          ),
          operationsReportClockProvider.overrideWith(
            (ref) => Stream.value(now),
          ),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1d 59m'), findsWidgets);
    expect(find.textContaining('Total impact 1d 59m'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resolved event card shows closure date, time, and actor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final resolvedAt = DateTime(2026, 9, 5, 14, 35);
    final event = _resolvedCraneEvent(resolvedAt);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_operationsUser(resolvedAt)),
          ),
          assetClassesProvider.overrideWith((ref) => Stream.value(const [])),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          operationalEventsProvider.overrideWith(
            (ref, actorUid) => Stream.value([event]),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value([event]),
          ),
          operationsReportClockProvider.overrideWith(
            (ref) => Stream.value(resolvedAt),
          ),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('operational-event-status-filter')),
        matching: find.text('Recent resolved'),
      ),
    );
    await tester.pumpAndSettle();

    final closure = find.byKey(
      const ValueKey('operational-event-resolution-crane-event-resolved'),
    );
    await tester.scrollUntilVisible(
      closure,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(closure, findsOneWidget);
    expect(
      find.text('Resolved 05 Sep 2026, 14:35 by Operations Two'),
      findsOneWidget,
    );
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
            (ref, actorUid) =>
                Stream.error(StateError('events must not be read')),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) =>
                Stream.error(StateError('history must not be read')),
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

  testWidgets('authority failure hides a previously approved event view', (
    tester,
  ) async {
    final now = DateTime.now();
    final actors = StreamController<AppUser?>();
    addTearDown(actors.close);
    actors.add(_operationsUser(now));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
          assetClassesProvider.overrideWith((ref) => Stream.value(const [])),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          operationalEventsProvider.overrideWith(
            (ref, actorUid) => Stream.value([_openCraneEvent(now)]),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Add event'), findsOneWidget);

    actors.addError(StateError('authority stream failed'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Approved access could not be verified.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Add event'), findsNothing);
    expect(find.text('Monthly impact'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authorized event entry remains available while feed loads', (
    tester,
  ) async {
    final now = DateTime.now();
    final events = StreamController<List<OperationalEvent>>();
    addTearDown(events.close);

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
            (ref, actorUid) => events.stream,
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Add event'), findsOneWidget);
    expect(find.text('Loading operational events'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('authorized event entry remains available when feed fails', (
    tester,
  ) async {
    final now = DateTime.now();

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
            (ref, actorUid) =>
                Stream.error(StateError('event feed unavailable')),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, actorUid) => Stream.value(const []),
          ),
        ],
        child: const MaterialApp(home: OperationalEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Add event'), findsOneWidget);
    expect(find.textContaining('event feed unavailable'), findsOneWidget);
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

OperationalEvent _openCraneEvent(
  DateTime now, {
  Duration elapsed = const Duration(minutes: 90),
  OperationalEventScope scope = OperationalEventScope.plantWide,
  List<String> classIds = const [],
  List<String> assetIds = const [],
}) {
  final startedAt = now.subtract(elapsed);
  return OperationalEvent(
    eventId: 'crane-event-1',
    eventType: OperationalEventType.crane,
    title: 'Charging crane unavailable',
    description: 'Crane movement is unavailable during charging operations.',
    severity: OperationalEventSeverity.significant,
    scope: scope,
    affectedAssetClassIds: classIds,
    affectedAssetInstanceIds: assetIds,
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

OperationalEvent _resolvedCraneEvent(DateTime resolvedAt) {
  final startedAt = resolvedAt.subtract(const Duration(hours: 2));
  return OperationalEvent(
    eventId: 'crane-event-resolved',
    eventType: OperationalEventType.crane,
    title: 'Charging crane restored',
    description: 'Crane movement was restored after inspection.',
    severity: OperationalEventSeverity.significant,
    scope: OperationalEventScope.plantWide,
    affectedAssetClassIds: const [],
    affectedAssetInstanceIds: const [],
    startedAt: startedAt,
    status: OperationalEventStatus.resolved,
    createdAt: startedAt,
    createdByUid: 'operations-1',
    createdByName: 'Operations One',
    resolvedAt: resolvedAt,
    resolvedByUid: 'operations-2',
    resolvedByName: 'Operations Two',
    resolutionNote: 'Crane movement remained stable after restoration.',
    version: 2,
    updatedAt: resolvedAt,
    updatedByUid: 'operations-2',
    updatedByName: 'Operations Two',
    lastMutationId: 'event-resolve-1',
  );
}

class _RecordingOperationalEventService extends OperationalEventService {
  OperationalEvent? event;
  String? resolutionNote;
  DateTime? resolvedAt;
  OperationalEventDraft? updatedDraft;
  String? updateReason;

  @override
  Future<OperationalEventCommandResult> update({
    required OperationalEvent event,
    required OperationalEventDraft draft,
    required String reason,
  }) async {
    updatedDraft = draft;
    updateReason = reason;
    return OperationalEventCommandResult(
      requestId: 'update-request',
      operation: OperationalEventCommand.update,
      eventId: event.eventId,
      status: event.status,
      version: event.version + 1,
      auditId: 'update-audit',
      committedAt: DateTime.now(),
      idempotentReplay: false,
    );
  }

  @override
  Future<OperationalEventCommandResult> resolve({
    required OperationalEvent event,
    required String resolutionNote,
    DateTime? resolvedAt,
  }) async {
    this.event = event;
    this.resolutionNote = resolutionNote;
    this.resolvedAt = resolvedAt;
    return OperationalEventCommandResult(
      requestId: 'resolution-request',
      operation: OperationalEventCommand.resolve,
      eventId: event.eventId,
      status: OperationalEventStatus.resolved,
      version: event.version + 1,
      auditId: 'resolution-audit',
      committedAt: DateTime.now(),
      idempotentReplay: false,
    );
  }
}

class _PendingCreationService extends OperationalEventService {
  bool retried = false;
  String? expectedActor;
  String? expectedRequest;

  @override
  Future<PendingOperationalEventCreation?> pendingCreation() async =>
      const PendingOperationalEventCreation(
        requestId: 'pending-request',
        eventId: 'pending-event',
        payloadFingerprint: 'pending-fingerprint',
        payload: <String, dynamic>{
          'reason': 'Saved original submission',
          'eventDraft': <String, dynamic>{'title': 'Saved supply interruption'},
        },
      );

  @override
  Future<OperationalEventCommandResult> retryPendingCreation({
    String? expectedActorUid,
    String? expectedRequestId,
  }) async {
    retried = true;
    expectedActor = expectedActorUid;
    expectedRequest = expectedRequestId;
    return OperationalEventCommandResult(
      requestId: 'pending-request',
      operation: OperationalEventCommand.create,
      eventId: 'pending-event',
      status: OperationalEventStatus.open,
      version: 1,
      auditId: 'operational_event_pending-request',
      committedAt: DateTime.utc(2026, 8, 14),
      idempotentReplay: true,
    );
  }
}
