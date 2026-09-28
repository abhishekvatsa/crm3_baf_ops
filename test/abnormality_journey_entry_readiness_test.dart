import 'dart:async';

import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/charge_abnormalities_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/dev_abnormality_journey_test.dart' as journey;

void main() {
  setUp(() {
    final previous = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = previous);
  });

  testWidgets(
    'mounted-button tap before catalogue sync does not open later by itself',
    (tester) async {
      final fixture = await _mount(tester);
      await tester.tap(
        find.byKey(const ValueKey('charge-abnormalities-create')),
      );
      await tester.pumpAndSettle();
      expect(fixture.repository.reads, 1);
      expect(
        find.textContaining('No active abnormality types found.'),
        findsOneWidget,
      );
      expect(find.text('Log charge abnormality'), findsNothing);

      fixture.publishTypes();
      await tester.pumpAndSettle();
      // Waiting only for the title after the premature tap cannot recover.
      expect(find.text('Log charge abnormality'), findsNothing);
      await tester.runAsync(
        () => journey.openAbnormalityForm(tester, readinessSeconds: 2),
      );
      expect(fixture.repository.reads, 2);
      expect(find.text('Log charge abnormality'), findsOneWidget);
    },
  );

  testWidgets(
    'entry waits for real catalogue data and keyboard closure before its single tap',
    (tester) async {
      final fixture = await _mount(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.runAsync(() async {
        final catalogue = Timer(
          const Duration(milliseconds: 150),
          fixture.publishTypes,
        );
        final keyboard = Timer(const Duration(milliseconds: 450), () {
          expect(fixture.repository.reads, 0);
          tester.view.resetViewInsets();
        });
        try {
          await journey.openAbnormalityForm(tester, readinessSeconds: 3);
        } finally {
          catalogue.cancel();
          keyboard.cancel();
        }
      });
      expect(fixture.repository.reads, 1);
      expect(find.text('Log charge abnormality'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('entry waits for an incoming page transition before tapping', (
    tester,
  ) async {
    final fixture = await _mount(tester, incomingTransition: true);
    fixture.publishTypes();
    await tester.pump();
    final target = find.byKey(const ValueKey('charge-abnormalities-create'));
    expect(target, findsOneWidget);
    final route = ModalRoute.of(tester.element(target))!;
    expect(route.animation!.status, AnimationStatus.forward);
    expect(fixture.repository.reads, 0);
    await tester.runAsync(
      () => journey.openAbnormalityForm(tester, readinessSeconds: 4),
    );
    expect(fixture.repository.reads, 1);
    expect(route.animation!.status, AnimationStatus.completed);
    expect(find.text('Log charge abnormality'), findsOneWidget);
  });

  testWidgets(
    'missing required catalogue row fails without a tap or invented data',
    (tester) async {
      final fixture = await _mount(tester);
      Object? failure;
      await tester.runAsync(() async {
        try {
          await journey.openAbnormalityForm(tester, readinessSeconds: 1);
        } catch (error) {
          failure = error;
        }
      });
      expect(failure, isA<TestFailure>());
      expect(fixture.repository.reads, 0);
      expect(fixture.repository.types, isEmpty);
      expect(find.text('Log charge abnormality'), findsNothing);
    },
  );

  testWidgets(
    'actor change during form preparation still fails and never retries the tap',
    (tester) async {
      final fixture = await _mount(tester);
      fixture.publishTypes();
      await tester.pumpAndSettle();
      fixture.repository.beforeReadCompletes = () async {
        fixture.actors.add(_actor(approved: false));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      };
      Object? failure;
      await tester.runAsync(() async {
        try {
          await journey.openAbnormalityForm(tester, readinessSeconds: 1);
        } catch (error) {
          failure = error;
        }
      });
      expect(failure, isA<TestFailure>());
      expect(fixture.repository.reads, 1);
      expect(find.text('Log charge abnormality'), findsNothing);
      expect(find.text('Charge-abnormality access required'), findsOneWidget);
    },
  );
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  bool incomingTransition = false,
}) async {
  final fixture = _Fixture();
  addTearDown(fixture.types.close);
  addTearDown(fixture.actors.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((ref) async* {
          yield _actor();
          yield* fixture.actors.stream;
        }),
        activeAbnormalityTypesProvider.overrideWith((ref) async* {
          yield fixture.repository.types;
          yield* fixture.types.stream;
        }),
        abnormalitiesForChargeProvider.overrideWith(
          (ref, charge) => Stream.value([]),
        ),
        abnormalityRepositoryProvider.overrideWithValue(fixture.repository),
        syncCoordinatorProvider.overrideWithValue(_Sync()),
        assetClassesProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: incomingTransition
            ? Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      PageRouteBuilder<void>(
                        transitionDuration: const Duration(seconds: 2),
                        pageBuilder: (_, animation, secondary) =>
                            const ChargeAbnormalitiesScreen(
                              sourceChargeNo: 91234,
                            ),
                        transitionsBuilder: (_, animation, secondary, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    child: const Text('Open fixture charge'),
                  ),
                ),
              )
            : const ChargeAbnormalitiesScreen(sourceChargeNo: 91234),
      ),
    ),
  );
  if (incomingTransition) {
    await tester.tap(find.text('Open fixture charge'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  } else {
    await tester.pumpAndSettle();
  }
  return fixture;
}

AppUser _actor({bool approved = true}) => AppUser(
  uid: 'operator',
  name: 'Operator',
  email: 'operator@example.test',
  roles: const [AppRole.operations],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

class _Fixture {
  final repository = _Repository();
  final types = StreamController<List<AbnormalityType>>();
  final actors = StreamController<AppUser>();
  void publishTypes() {
    repository.types = [
      AbnormalityType()
        ..firestoreId = 'surface-scale'
        ..code = 'SURF-SCALE'
        ..title = 'Surface scale'
        ..category = AbnormalityCategory.process
        ..severity = AbnormalitySeverity.medium
        ..isActive = true
        ..createdAt = DateTime.utc(2026)
        ..updatedAt = DateTime.utc(2026),
    ];
    types.add(repository.types);
  }
}

class _Repository extends Fake implements AbnormalityRepository {
  List<AbnormalityType> types = [];
  int reads = 0;
  Future<void> Function()? beforeReadCompletes;
  @override
  Future<List<AbnormalityType>> getActiveTypes() async {
    reads++;
    await beforeReadCompletes?.call();
    return types;
  }
}

class _Sync extends Fake implements SyncCoordinator {}
