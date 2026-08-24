import 'dart:async';

import 'package:crm3_baf_ops/core/security/actor_session_cache_trust.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_condition_round.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/burner_condition_round_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/reports/presentation/burner_reliability_screen.dart';
import 'package:crm3_baf_ops/features/reports/providers/operations_report_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final startDate = DateTime(2026, 8, 1);
  final endDate = DateTime(2026, 8, 31);
  final period = (
    actorUid: 'operations-1',
    startInclusive: startDate,
    endExclusive: DateTime(2026, 9, 1),
  );
  final allRoundsQuery = (
    actorUid: 'operations-1',
    startInclusive: startDate,
    endExclusive: DateTime(2026, 9, 1),
    assetInstanceId: null as String?,
  );
  final furnaceRoundsQuery = (
    actorUid: 'operations-1',
    startInclusive: startDate,
    endExclusive: DateTime(2026, 9, 1),
    assetInstanceId: 'furnace-2' as String?,
  );

  test(
    'burner cache requires exact-query server proof for each actor',
    () async {
      final trust = ActorSessionCacheTrust()..observeActor('operations-1');
      final queryKey = burnerConditionRoundQueryKey(furnaceRoundsQuery);
      final firstSession =
          await admitActorSessionSnapshots(
            Stream.fromIterable(const [
              (fromCache: true, value: 'unproved-cache'),
              (fromCache: false, value: 'server'),
              (fromCache: true, value: 'proved-cache'),
            ]),
            trust: trust,
            actorUid: 'operations-1',
            queryKey: queryKey,
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();
      expect(firstSession.map((snapshot) => snapshot.value), [
        'server',
        'proved-cache',
      ]);

      trust.observeActor('operations-2');
      final switchedOffline =
          await admitActorSessionSnapshots(
            Stream.value(const (fromCache: true, value: 'actor-a-cache')),
            trust: trust,
            actorUid: 'operations-2',
            queryKey: queryKey,
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();
      expect(switchedOffline, isEmpty);

      final secondSession =
          await admitActorSessionSnapshots(
            Stream.fromIterable(const [
              (fromCache: false, value: 'actor-b-server'),
              (fromCache: true, value: 'actor-b-cache'),
            ]),
            trust: trust,
            actorUid: 'operations-2',
            queryKey: queryKey,
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();
      expect(secondSession.map((snapshot) => snapshot.value), [
        'actor-b-server',
        'actor-b-cache',
      ]);

      final differentQueryCache =
          await admitActorSessionSnapshots(
            Stream.value(const (
              fromCache: true,
              value: 'different-query-cache',
            )),
            trust: trust,
            actorUid: 'operations-2',
            queryKey: burnerConditionRoundQueryKey(allRoundsQuery),
            isFromCache: (snapshot) => snapshot.fromCache,
          ).toList();
      expect(differentQueryCache, isEmpty);
    },
  );

  testWidgets(
    'approved user sees phone-width burner reliability and microamp evidence',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.utc(2026, 8, 16, 8);
      final furnaceClass = _furnaceClass(now: now);
      final furnace = _furnace(now: now);
      final ticket = _burnerTicket(now: now);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream.value(_user(now: now)),
            ),
            assetClassesProvider.overrideWith(
              (ref) => Stream.value([furnaceClass]),
            ),
            allAssetInstancesProvider.overrideWith(
              (ref) => Stream.value([furnace]),
            ),
            operationsReportTicketsProvider(
              period,
            ).overrideWith((ref) => Stream.value([ticket])),
            burnerConditionRoundsProvider(
              furnaceRoundsQuery,
            ).overrideWith((ref) => Stream.value([_round(now: now)])),
          ],
          child: MaterialApp(
            home: BurnerReliabilityScreen(
              initialStartDate: startDate,
              initialEndDate: endDate,
              initialAssetInstanceId: 'furnace-2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Burner reliability'), findsOneWidget);
      expect(find.text('Lockout reports'), findsOneWidget);
      expect(find.text('Condition rounds'), findsOneWidget);
      expect(find.text('Open positions'), findsOneWidget);
      expect(find.text('Red-hot records'), findsOneWidget);
      expect(find.text('FR-02-B01'), findsOneWidget);
      expect(find.text('3.6 microamp on 16 Aug 2026'), findsOneWidget);
      expect(find.text('1 red hot'), findsOneWidget);
      expect(find.text('UV detector cleaning: 1'), findsOneWidget);
      expect(find.text('1 rounds'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'approved account switch replaces and disposes burner-round evidence',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final actors = StreamController<AppUser?>();
      final queryActors = <String>[];
      final disposedActors = <String>[];
      addTearDown(actors.close);
      final now = DateTime.utc(2026, 8, 16, 8);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
            assetClassesProvider.overrideWith(
              (ref) => Stream.value([_furnaceClass(now: now)]),
            ),
            allAssetInstancesProvider.overrideWith(
              (ref) => Stream.value([_furnace(now: now)]),
            ),
            operationsReportTicketsProvider.overrideWith(
              (ref, scope) => Stream.value(const <MaintenanceRecord>[]),
            ),
            burnerConditionRoundsProvider.overrideWith((ref, query) {
              queryActors.add(query.actorUid);
              ref.onDispose(() => disposedActors.add(query.actorUid));
              return Stream.value(
                query.actorUid == 'operations-1'
                    ? <BurnerConditionRound>[_round(now: now)]
                    : const <BurnerConditionRound>[],
              );
            }),
          ],
          child: MaterialApp(
            home: BurnerReliabilityScreen(
              initialStartDate: startDate,
              initialEndDate: endDate,
              initialAssetInstanceId: 'furnace-2',
            ),
          ),
        ),
      );

      actors.add(_user(now: now));
      await tester.pumpAndSettle();
      expect(find.text('3.6 microamp on 16 Aug 2026'), findsOneWidget);

      actors.add(_user(now: now, uid: 'operations-2'));
      await tester.pumpAndSettle();

      expect(queryActors, containsAllInOrder(['operations-1', 'operations-2']));
      expect(disposedActors, contains('operations-1'));
      expect(find.text('3.6 microamp on 16 Aug 2026'), findsNothing);
      expect(find.text('No burner evidence in this period'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unapproved user cannot read burner reliability evidence', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 16);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_user(now: now, approved: false)),
          ),
        ],
        child: MaterialApp(
          home: BurnerReliabilityScreen(
            initialStartDate: startDate,
            initialEndDate: endDate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved report access is required.'), findsOneWidget);
    expect(find.text('Burner reliability'), findsNothing);
  });

  testWidgets('ambiguous Furnace mapping withholds report evidence', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 16);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_user(now: now)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([
              _furnaceClass(now: now),
              _furnaceClass(now: now, id: 'furnace-class-duplicate'),
            ]),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value([_furnace(now: now)]),
          ),
          operationsReportTicketsProvider(period).overrideWith(
            (ref) => Stream.error(
              StateError('ticket evidence must not be requested'),
            ),
          ),
        ],
        child: MaterialApp(
          home: BurnerReliabilityScreen(
            initialStartDate: startDate,
            initialEndDate: endDate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Furnace authority needs reconciliation'), findsOneWidget);
    expect(
      find.text('Could not load burner reliability evidence.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed classified burner evidence withholds totals', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 16);
    final corrupt = _burnerTicket(now: now)..metadataJson = '{malformed';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_user(now: now)),
          ),
          assetClassesProvider.overrideWith(
            (ref) => Stream.value([_furnaceClass(now: now)]),
          ),
          allAssetInstancesProvider.overrideWith(
            (ref) => Stream.value([_furnace(now: now)]),
          ),
          operationsReportTicketsProvider(
            period,
          ).overrideWith((ref) => Stream.value([corrupt])),
          burnerConditionRoundsProvider(
            allRoundsQuery,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: BurnerReliabilityScreen(
            initialStartDate: startDate,
            initialEndDate: endDate,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Burner evidence needs repair'), findsOneWidget);
    expect(find.text('Lockout reports'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

BurnerConditionRound _round({required DateTime now}) => BurnerConditionRound(
  roundId: 'round-1',
  assetClassId: 'furnace-class',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetInstanceId: 'furnace-2',
  assetInstanceVersion: 1,
  assetNumber: 2,
  assetName: 'Furnace 2',
  observations: List<BurnerConditionObservation>.generate(
    8,
    (index) => BurnerConditionObservation(
      position: index + 1,
      flameObservation: BurnerRoundFlameObservation.seen,
      redHotObserved: false,
      microampReading: index == 0 ? 3.6 : null,
    ),
  ),
  redHotPositions: const [],
  microampPositions: const [1],
  observedAt: now.add(const Duration(hours: 1)),
  recordedByUid: 'operations-1',
  recordedByName: 'Operations One',
  fingerprint: 'burnerround1-sha256:${'a' * 64}',
);

AppUser _user({
  required DateTime now,
  bool approved = true,
  String uid = 'operations-1',
}) => AppUser(
  uid: uid,
  name: 'Operations One',
  email: 'operations@example.com',
  roles: const [AppRole.operations],
  isApproved: approved,
  createdAt: now,
);

AssetClassRecord _furnaceClass({
  required DateTime now,
  String id = 'furnace-class',
}) => AssetClassRecord(
  id: id,
  code: 'FURNACE',
  name: 'Furnace',
  majorArea: 'BAF shop',
  legacyAssetTypeKey: AssetType.furnace.name,
  status: AssetHierarchyStatus.active,
  version: 1,
  createdAt: now,
  createdByUid: 'admin-1',
  updatedAt: now,
  updatedByUid: 'admin-1',
  lastMutationId: 'class-mutation-$id',
);

AssetInstanceRecord _furnace({required DateTime now}) => AssetInstanceRecord(
  id: 'furnace-2',
  assetClassId: 'furnace-class',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnace',
  assetNumber: 2,
  name: 'Furnace 2',
  plantTag: 'FR-02',
  serviceState: AssetServiceState.inService,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Operations',
  accountableRoleKeys: const ['operations'],
  status: AssetHierarchyStatus.active,
  activeComponentCount: 8,
  version: 1,
  createdAt: now.subtract(const Duration(days: 500)),
  updatedAt: now,
  lastMutationId: 'asset-mutation',
);

MaintenanceRecord _burnerTicket({required DateTime now}) {
  final action = buildBurnerComponentAction(
    ticketId: 'burner-ticket-1',
    furnaceNumber: 2,
    burnerPosition: 1,
    code: BurnerActionCode.uvDetectorCleaning,
    outcome: BurnerResolutionOutcome.returnedToService,
    microampReading: 3.4,
    performedBy: 'I&A One',
    performedAt: now,
  );
  final record =
      MaintenanceRecord()
        ..firestoreId = 'burner-ticket-1'
        ..assetType = AssetType.furnace
        ..assetNumber = 2
        ..maintenanceType = MaintenanceType.breakdown
        ..classification = burnerLockoutClassification
        ..description = 'Burner 1 locked out with a red-hot block observation.'
        ..routedTo = RoutedTo.instrumentation
        ..status = TicketStatus.resolved
        ..isResolved = true
        ..component = 'Burner system'
        ..subsystem = 'Burner system'
        ..startDate = now.subtract(const Duration(hours: 2))
        ..endDate = now
        ..createdAt = now.subtract(const Duration(hours: 2))
        ..updatedAt = now
        ..resolutionHistoryJson = '[]'
        ..burnerLockoutCase = BurnerLockoutCase(
          positions: const [1],
          commonMode: false,
          cycleStage: BurnerCycleStage.firing,
          flameObservation: BurnerObservation.notSeen,
          sparkObservation: BurnerObservation.seen,
          relightAttempts: 1,
          remainsLockedOut: true,
          redHotPositions: const [1],
        ).withResolution(
          BurnerLockoutResolution(
            outcomes: {1: BurnerResolutionOutcome.returnedToService},
            microampReadings: {1: 3.4},
          ),
          actions: [action],
        )
        ..actions = [action];
  return record;
}
