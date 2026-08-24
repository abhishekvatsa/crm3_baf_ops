import 'dart:async';
import 'dart:io';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_reports_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/compliance_request_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/compliance_notification_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event.dart';
import 'package:crm3_baf_ops/features/operational_events/data/operational_event_issue_link.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_event_issue_links_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_events_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/reports/presentation/fleet_status_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report and link guards reject every loading authority state', () {
    for (final path in <String>[
      'lib/features/abnormalities/presentation/abnormality_reports_screen.dart',
      'lib/features/maintenance_workflow/presentation/screens/compliance_notification_screen.dart',
      'lib/features/operational_events/presentation/operational_event_issue_links_screen.dart',
      'lib/features/reports/presentation/fleet_status_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('actorAsync.isLoading && !actorAsync.hasValue')),
        reason: path,
      );
    }
  });

  testWidgets('management reports reject before report-source reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const FleetStatusScreen(),
      overrides: [
        assetClassesProvider.overrideWith((ref) {
          reads++;
          throw StateError('asset classes must not be read');
        }),
        allAssetInstancesProvider.overrideWith((ref) {
          reads++;
          throw StateError('assets must not be read');
        }),
        operationsReportProvider.overrideWith((ref, scope) {
          reads++;
          throw StateError('report must not be built');
        }),
      ],
    );

    expect(find.text('Report access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('abnormality reports reject before repository access', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const AbnormalityReportsScreen(),
      overrides: [
        abnormalityRepositoryProvider.overrideWith((ref) {
          reads++;
          throw StateError('abnormality repository must not be read');
        }),
      ],
    );

    expect(find.text('Abnormality-report access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('compliance notifications reject before record lookup', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const ComplianceNotificationScreen(complianceId: 'request-1'),
      overrides: [
        workflowComplianceRecordProvider.overrideWith((ref, scope) {
          reads++;
          throw StateError('compliance record must not be read');
        }),
      ],
    );

    expect(find.text('Compliance access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('compliance notification applies the exact request audience', (
    tester,
  ) async {
    var reads = 0;
    final request =
        ComplianceRequestRecord()
          ..firestoreId = 'request-1'
          ..linkedWorkflowId = 'workflow-1'
          ..title = 'Operations support'
          ..description = 'Move the furnace to the maintenance position.'
          ..targetLaneKey = 'inst'
          ..originLaneKey = 'elec'
          ..raisedByUid = 'operations-raiser'
          ..statusKey = 'raised';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(
              _approvedActor(AppRole.seniorMechanical),
            ),
          ),
          workflowComplianceRecordProvider.overrideWith((ref, scope) {
            reads++;
            return Future.value(request);
          }),
        ],
        child: const MaterialApp(
          home: ComplianceNotificationScreen(complianceId: 'request-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compliance audience required'), findsOneWidget);
    expect(find.text(request.description), findsNothing);
    expect(reads, 1);
    expect(tester.takeException(), isNull);
  });

  test('compliance lookup does not reuse an earlier actor offline', () async {
    final actors = StreamController<AppUser?>();
    var pointReads = 0;
    final request =
        ComplianceRequestRecord()
          ..firestoreId = 'request-1'
          ..linkedWorkflowId = 'workflow-1'
          ..title = 'Operations support'
          ..description = 'Actor A server-proved description.'
          ..targetLaneKey = 'mech'
          ..originLaneKey = 'elec'
          ..raisedByUid = 'operations-raiser'
          ..statusKey = 'raised';
    addTearDown(actors.close);

    final container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => actors.stream),
        workflowCompliancePointReaderProvider.overrideWith((ref) {
          return (complianceId) async {
            pointReads++;
            if (pointReads == 1) return request;
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          };
        }),
      ],
    );
    addTearDown(container.dispose);

    final firstActor = container.read(currentAppUserProvider.future);
    actors.add(_approvedActor(AppRole.seniorMechanical));
    await firstActor;
    const actorAScope = (
      actorUid: 'approved-seniorMechanical',
      complianceId: 'request-1',
    );
    final first = await container.read(
      workflowComplianceRecordProvider(actorAScope).future,
    );
    expect(first?.description, request.description);

    container.invalidate(workflowComplianceRecordProvider(actorAScope));
    final sameActorOffline = await container.read(
      workflowComplianceRecordProvider(actorAScope).future,
    );
    expect(sameActorOffline?.description, request.description);

    actors.add(_approvedActor(AppRole.admin));
    await _waitForActor(container, 'approved-admin');
    await expectLater(
      container.read(
        workflowComplianceRecordProvider((
          actorUid: 'approved-admin',
          complianceId: 'request-1',
        )).future,
      ),
      throwsA(isA<StateError>()),
    );
    expect(pointReads, 3);
  });

  test(
    'compliance lookup retains a tombstone only as trusted absence',
    () async {
      final tombstone =
          ComplianceRequestRecord()
            ..firestoreId = 'request-deleted'
            ..isDeleted = true;
      var pointReads = 0;
      final container = ProviderContainer(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(
              _approvedActor(AppRole.seniorMechanical),
            ),
          ),
          workflowCompliancePointReaderProvider.overrideWith((ref) {
            return (complianceId) async {
              pointReads++;
              if (pointReads == 1) return tombstone;
              throw FirebaseException(
                plugin: 'cloud_firestore',
                code: 'unavailable',
              );
            };
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentAppUserProvider.future);
      const scope = (
        actorUid: 'approved-seniorMechanical',
        complianceId: 'request-deleted',
      );

      expect(
        await container.read(workflowComplianceRecordProvider(scope).future),
        isNull,
      );
      container.invalidate(workflowComplianceRecordProvider(scope));
      expect(
        await container.read(workflowComplianceRecordProvider(scope).future),
        isNull,
      );
      expect(pointReads, 2);
    },
  );

  test('compliance session cache retains only the continuous actor', () {
    final request = ComplianceRequestRecord()..firestoreId = 'request-1';
    final cache = ActorSessionComplianceCache()..observeActor('actor-a');

    expect(
      cache.remember(
        actorUid: 'actor-a',
        complianceId: 'request-1',
        record: request,
      ),
      isTrue,
    );
    expect(cache.lookup(actorUid: 'actor-a', complianceId: 'request-1'), (
      isTrusted: true,
      record: request,
    ));

    cache.observeActor('actor-b');
    expect(
      cache.lookup(actorUid: 'actor-b', complianceId: 'request-1').isTrusted,
      isFalse,
    );
    cache.observeActor(null);
    expect(
      cache.lookup(actorUid: 'actor-a', complianceId: 'request-1').isTrusted,
      isFalse,
    );
  });

  testWidgets('event issue links reject before event and link reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: OperationalEventIssueLinksScreen(event: _event()),
      overrides: [
        operationalEventsProvider.overrideWith((ref, actorUid) {
          reads++;
          throw StateError('events must not be read');
        }),
        operationalEventIssueLinksProvider.overrideWith((ref, scope) {
          reads++;
          throw StateError('event links must not be read');
        }),
      ],
    );

    expect(find.text('Event-link access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('operational events reject before event and asset reads', (
    tester,
  ) async {
    var reads = 0;

    await _pumpUnapproved(
      tester,
      screen: const OperationalEventsScreen(),
      overrides: [
        operationalEventsProvider.overrideWith((ref, actorUid) {
          reads++;
          throw StateError('events must not be read');
        }),
        assetClassesProvider.overrideWith((ref) {
          reads++;
          throw StateError('asset classes must not be read');
        }),
        allAssetInstancesProvider.overrideWith((ref) {
          reads++;
          throw StateError('assets must not be read');
        }),
      ],
    );

    expect(find.text('Operational-event access required'), findsOneWidget);
    expect(reads, 0);
  });

  testWidgets('issue event links reject before linked-event reads', (
    tester,
  ) async {
    var reads = 0;
    final issue = MaintenanceRecord()..firestoreId = 'issue-1';

    await _pumpUnapproved(
      tester,
      screen: MaintenanceIssueEventLinksScreen(issue: issue),
      overrides: [
        operationalIssueEventLinksProvider.overrideWith((ref, scope) {
          reads++;
          throw StateError('issue links must not be read');
        }),
      ],
    );

    expect(find.text('Issue-link access required'), findsOneWidget);
    expect(reads, 0);
  });

  test('event and link providers dispose after their last listener', () async {
    var eventDisposals = 0;
    var eventLinkDisposals = 0;
    var issueLinkDisposals = 0;
    final container = ProviderContainer(
      overrides: [
        operationalEventsProvider.overrideWith((ref, actorUid) {
          ref.onDispose(() => eventDisposals++);
          return Stream<List<OperationalEvent>>.value(const []);
        }),
        operationalEventIssueLinksProvider.overrideWith((ref, scope) {
          ref.onDispose(() => eventLinkDisposals++);
          return Stream<List<OperationalEventIssueLink>>.value(const []);
        }),
        operationalIssueEventLinksProvider.overrideWith((ref, scope) {
          ref.onDispose(() => issueLinkDisposals++);
          return Stream<List<OperationalEventIssueLink>>.value(const []);
        }),
      ],
    );
    addTearDown(container.dispose);

    final events = container.listen(
      operationalEventsProvider('approved-operations'),
      (_, _) {},
    );
    final eventLinks = container.listen(
      operationalEventIssueLinksProvider((
        actorUid: 'approved-operations',
        eventId: 'event-1',
      )),
      (_, _) {},
    );
    final issueLinks = container.listen(
      operationalIssueEventLinksProvider((
        actorUid: 'approved-operations',
        issueId: 'issue-1',
      )),
      (_, _) {},
    );
    events.close();
    eventLinks.close();
    issueLinks.close();
    await Future<void>.delayed(Duration.zero);

    expect(eventDisposals, 1);
    expect(eventLinkDisposals, 1);
    expect(issueLinkDisposals, 1);
  });

  test(
    'same-session cache survives offline reopen but not actor switch',
    () async {
      final trust = ActorSessionCacheTrust()..observeActor('actor-a');
      const queryKey = 'events:reports';

      final firstOnline =
          await admitActorSessionSnapshots(
            Stream.value(const (fromCache: false, value: 'actor-a-server')),
            trust: trust,
            actorUid: 'actor-a',
            queryKey: queryKey,
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();
      final reopenedOffline =
          await admitActorSessionSnapshots(
            Stream.value(const (fromCache: true, value: 'actor-a-cache')),
            trust: trust,
            actorUid: 'actor-a',
            queryKey: queryKey,
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();

      trust.observeActor('actor-b');
      final switchedOffline =
          await admitActorSessionSnapshots(
            Stream.value(const (fromCache: true, value: 'shared-disk-cache')),
            trust: trust,
            actorUid: 'actor-b',
            queryKey: queryKey,
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();
      final secondOnline =
          await admitActorSessionSnapshots(
            Stream.fromIterable(const [
              (fromCache: false, value: 'actor-b-server'),
              (fromCache: true, value: 'actor-b-cache-refresh'),
            ]),
            trust: trust,
            actorUid: 'actor-b',
            queryKey: queryKey,
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();

      expect(firstOnline.map((snapshot) => snapshot.value), ['actor-a-server']);
      expect(reopenedOffline.map((snapshot) => snapshot.value), [
        'actor-a-cache',
      ]);
      expect(switchedOffline, isEmpty);
      expect(secondOnline.map((snapshot) => snapshot.value), [
        'actor-b-server',
        'actor-b-cache-refresh',
      ]);

      trust.observeActor(null);
      expect(
        trust.acceptSnapshot(
          actorUid: 'actor-b',
          queryKey: queryKey,
          isFromCache: true,
        ),
        isFalse,
      );
    },
  );

  testWidgets('report graph switches actor scope and disposes on revocation', (
    tester,
  ) async {
    final actors = StreamController<AppUser?>();
    final reportActors = <String>[];
    final disposedActors = <String>[];
    addTearDown(actors.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
          assetClassesProvider.overrideWith((ref) => Stream.value(const [])),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          operationsReportProvider.overrideWith((ref, scope) {
            reportActors.add(scope.actorUid);
            ref.onDispose(() => disposedActors.add(scope.actorUid));
            return const AsyncLoading();
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const FleetStatusScreen(),
        ),
      ),
    );

    actors.add(_approvedActor(AppRole.operations));
    await tester.pump();
    await tester.pump();
    actors.add(_approvedActor(AppRole.admin));
    await tester.pump();
    await tester.pump();
    actors.add(_unapprovedActor());
    await tester.pump();
    await tester.pump();

    expect(reportActors, ['approved-operations', 'approved-admin']);
    expect(
      disposedActors,
      containsAll(['approved-operations', 'approved-admin']),
    );
    expect(find.text('Report access required'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved account switch starts actor-scoped event reads', (
    tester,
  ) async {
    final actors = StreamController<AppUser?>();
    final eventActors = <String>[];
    final linkActors = <String>[];
    addTearDown(actors.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => actors.stream),
          operationalEventsProvider.overrideWith((ref, actorUid) {
            eventActors.add(actorUid);
            return Stream<List<OperationalEvent>>.value([_event()]);
          }),
          operationalEventIssueLinksProvider.overrideWith((ref, scope) {
            linkActors.add(scope.actorUid);
            return Stream<List<OperationalEventIssueLink>>.value(const []);
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: OperationalEventIssueLinksScreen(event: _event()),
        ),
      ),
    );

    actors.add(_approvedActor(AppRole.operations));
    await tester.pumpAndSettle();
    actors.add(_approvedActor(AppRole.admin));
    await tester.pumpAndSettle();

    expect(eventActors, ['approved-operations', 'approved-admin']);
    expect(linkActors, ['approved-operations', 'approved-admin']);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUnapproved(
  WidgetTester tester, {
  required Widget screen,
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream<AppUser?>.value(_unapprovedActor()),
        ),
        ...overrides,
      ],
      child: MaterialApp(theme: BafAppTheme.light, home: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

AppUser _unapprovedActor() => AppUser(
  uid: 'revoked-operations',
  name: 'Revoked Operations',
  email: 'revoked.operations@example.com',
  roles: const <AppRole>[AppRole.operations],
  isApproved: false,
  createdAt: DateTime.utc(2026, 8, 24),
);

AppUser _approvedActor(AppRole role) => AppUser(
  uid: 'approved-${role.name}',
  name: 'Approved ${role.name}',
  email: 'approved.${role.name}@example.com',
  roles: <AppRole>[role],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 24),
);

OperationalEvent _event() {
  final startedAt = DateTime.utc(2026, 8, 24, 8);
  return OperationalEvent(
    eventId: 'event-1',
    eventType: OperationalEventType.crane,
    title: 'Crane unavailable',
    description: 'Crane movement is unavailable.',
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
    updatedAt: startedAt,
    updatedByUid: 'operations-1',
    updatedByName: 'Operations One',
    lastMutationId: 'event-create-1',
  );
}

Future<void> _waitForActor(ProviderContainer container, String uid) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (container.read(currentAppUserProvider).value?.uid == uid) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('Timed out waiting for actor $uid.');
}
