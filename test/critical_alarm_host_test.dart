import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/presentation/critical_alarm_host.dart';
import 'package:crm3_baf_ops/features/critical_alarm/presentation/critical_alarm_screen.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _channel = MethodChannel('in.co.sail.bsl.crm3.bafops/critical_alarm');

CriticalAlarm _supportConfirmedAlarm() {
  final raisedAt = DateTime.utc(2026, 8, 26, 1, 2);
  final supportAt = DateTime.utc(2026, 8, 26, 1, 4);
  return CriticalAlarm(
    id: 'alarm-support-confirmed',
    definition: CriticalAlarmDefinition.byKey['fire']!,
    status: CriticalAlarmStatus.supportConfirmed,
    version: 2,
    location: 'BAF north bay',
    assetTypeKey: null,
    assetNumber: null,
    details: 'Visible flame beside the utility gallery',
    detailsPending: false,
    raisedByUid: 'operator-1',
    raisedByName: 'Operator One',
    raisedAt: raisedAt,
    detailsProvidedByName: 'Operator One',
    detailsProvidedAt: raisedAt,
    supportBasis: CriticalAlarmSupportBasis.supportDispatched,
    supportNote: 'Fire response support dispatched to the north bay.',
    supportConfirmedByName: 'Admin One',
    supportConfirmedAt: supportAt,
    resolutionSummary: null,
    resolvedByName: null,
    resolvedAt: null,
    withdrawalReason: null,
    withdrawnByName: null,
    withdrawnAt: null,
    updatedAt: supportAt,
  );
}

CriticalAlarm _raisedAlarm() {
  final raisedAt = DateTime.utc(2026, 8, 26, 1, 2);
  return CriticalAlarm(
    id: 'alarm-raised',
    definition: CriticalAlarmDefinition.byKey['fire']!,
    status: CriticalAlarmStatus.raised,
    version: 1,
    location: 'BAF north bay',
    assetTypeKey: null,
    assetNumber: null,
    details: 'Visible flame beside the utility gallery',
    detailsPending: false,
    raisedByUid: 'operator-1',
    raisedByName: 'Operator One',
    raisedAt: raisedAt,
    detailsProvidedByName: 'Operator One',
    detailsProvidedAt: raisedAt,
    supportBasis: null,
    supportNote: null,
    supportConfirmedByName: null,
    supportConfirmedAt: null,
    resolutionSummary: null,
    resolvedByName: null,
    resolvedAt: null,
    withdrawalReason: null,
    withdrawnByName: null,
    withdrawnAt: null,
    updatedAt: raisedAt,
  );
}

AppUser _user({bool approved = true}) => AppUser(
  uid: 'operator-1',
  name: 'Operator One',
  email: 'operator@example.com',
  roles: const [AppRole.operations],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

CriticalAlarmLiveSnapshot _verified(List<CriticalAlarm> alarms) =>
    CriticalAlarmLiveSnapshot.serverVerified(
      alarms: alarms,
      verifiedAt: DateTime.utc(2026, 8, 26, 1, 5),
    );

CriticalAlarmLiveSnapshot _stale(List<CriticalAlarm> alarms) =>
    CriticalAlarmLiveSnapshot.staleLastKnown(
      alarms: alarms,
      lastVerifiedAt: DateTime.utc(2026, 8, 26, 1, 5),
    );

CriticalAlarmLiveSnapshot _partial(List<CriticalAlarm> alarms) =>
    CriticalAlarmLiveSnapshot.partiallyVerified(
      alarms: alarms,
      malformedDocumentCount: 1,
      lastVerifiedAt: DateTime.utc(2026, 8, 26, 1, 5),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('alarm listeners use state captured before widget disposal', () {
    final source = File(
      'lib/features/critical_alarm/presentation/critical_alarm_host.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');

    expect(
      RegExp(r'ref\.read\(').allMatches(source),
      hasLength(1),
      reason:
          'Alarm stream and lifecycle callbacks must not resolve providers after their Consumer element is disposed.',
    );
    expect(
      source,
      contains(
        '_alarmPlatform = ref.read(criticalAlarmPlatformServiceProvider);',
      ),
    );
    expect(source, contains('final actor = _latestAlarmActor;'));
    expect(source, contains('if (!mounted) return;\n    final ringing ='));
  });

  testWidgets(
    'verified server feed clears notifications created before this process',
    (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return call.method == 'reconcileActiveNotifications' ? 1 : null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith(
              (_) => Stream.value(_verified([_supportConfirmedAlarm()])),
            ),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reconciliation = calls.lastWhere(
        (call) => call.method == 'reconcileActiveNotifications',
      );
      expect(
        (reconciliation.arguments as Map<Object?, Object?>)['ringingAlarmIds'],
        isEmpty,
      );
    },
  );

  testWidgets(
    'authority loading or failure cannot cancel verified alarm notifications',
    (tester) async {
      final calls = <MethodCall>[];
      final users = StreamController<AppUser?>();
      addTearDown(users.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return call.method == 'reconcileActiveNotifications' ? 0 : null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentAppUserProvider.overrideWith((_) => users.stream)],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();
      expect(
        calls.where((call) => call.method == 'reconcileActiveNotifications'),
        isEmpty,
      );

      users.addError(StateError('authority unavailable'));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'reconcileActiveNotifications'),
        isEmpty,
      );

      users.add(_user(approved: false));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'reconcileActiveNotifications'),
        hasLength(1),
      );
    },
  );

  testWidgets('failed native notification is retried after settings resume', (
    tester,
  ) async {
    final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
    addTearDown(alarmFeed.close);
    var showAttempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'showActiveNotification') {
            showAttempts += 1;
            return showAttempts > 1;
          }
          if (call.method == 'isNotificationReady') return true;
          if (call.method == 'reconcileActiveNotifications') return 0;
          return null;
        });
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
          activeCriticalAlarmsProvider.overrideWith((_) => alarmFeed.stream),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => CriticalAlarmHost(
            navigatorKey: navigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(body: Text('Operations')),
        ),
      ),
    );
    await tester.pump();

    alarmFeed.add(_verified([_raisedAlarm()]));
    await tester.pumpAndSettle();
    expect(showAttempts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(showAttempts, 2);
  });

  testWidgets(
    'notification posting is withheld when device readiness is false',
    (tester) async {
      final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(alarmFeed.close);
      var showAttempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'isNotificationReady') return false;
            if (call.method == 'showActiveNotification') {
              showAttempts += 1;
              return true;
            }
            if (call.method == 'reconcileActiveNotifications') return 0;
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith((_) => alarmFeed.stream),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();
      alarmFeed.add(_verified([_raisedAlarm()]));
      await tester.pumpAndSettle();

      expect(showAttempts, 0);
    },
  );

  testWidgets(
    'initial cache snapshot does not flash an outage before server verification',
    (tester) async {
      final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(alarmFeed.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'reconcileActiveNotifications') return 0;
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith((_) => alarmFeed.stream),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();

      alarmFeed.add(CriticalAlarmLiveSnapshot.unavailable());
      await tester.pump();
      expect(find.textContaining('alarm feed is not live'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('alarm feed is not live'), findsNothing);

      alarmFeed.add(_verified(const <CriticalAlarm>[]));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('alarm feed is not live'), findsNothing);
    },
  );

  testWidgets(
    'sustained startup unavailability becomes visible after the grace period',
    (tester) async {
      final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(alarmFeed.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'reconcileActiveNotifications') return 0;
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith((_) => alarmFeed.stream),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();

      alarmFeed.add(CriticalAlarmLiveSnapshot.unavailable());
      await tester.pump();
      expect(find.textContaining('alarm feed is not live'), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('alarm feed is not live'), findsNothing);

      await tester.pump(const Duration(seconds: 9));
      expect(find.textContaining('alarm feed is not live'), findsOneWidget);
    },
  );

  testWidgets(
    'sustained startup loading becomes visible after the grace period',
    (tester) async {
      final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(alarmFeed.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'reconcileActiveNotifications') return 0;
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith((_) => alarmFeed.stream),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('alarm feed is not live'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('alarm feed is not live'), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('alarm feed is not live'), findsNothing);

      await tester.pump(const Duration(seconds: 9));
      expect(find.textContaining('alarm feed is not live'), findsOneWidget);
    },
  );

  testWidgets(
    'stale alarm feed is labelled and cannot reconcile notifications',
    (tester) async {
      final calls = <MethodCall>[];
      final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(alarmFeed.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            if (call.method == 'showActiveNotification') return true;
            if (call.method == 'isNotificationReady') return true;
            if (call.method == 'reconcileActiveNotifications') return 0;
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith((_) => alarmFeed.stream),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();

      alarmFeed.add(_verified([_raisedAlarm()]));
      await tester.pumpAndSettle();
      final verifiedReconciliations = calls
          .where((call) => call.method == 'reconcileActiveNotifications')
          .length;
      expect(verifiedReconciliations, 1);

      alarmFeed.add(_stale([_raisedAlarm()]));
      await tester.pumpAndSettle();
      expect(find.textContaining('alarm feed is not live'), findsOneWidget);
      expect(
        calls.where((call) => call.method == 'reconcileActiveNotifications'),
        hasLength(verifiedReconciliations),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'reconcileActiveNotifications'),
        hasLength(verifiedReconciliations),
      );

      alarmFeed.add(_verified(const <CriticalAlarm>[]));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'reconcileActiveNotifications'),
        hasLength(verifiedReconciliations + 1),
      );
    },
  );

  testWidgets(
    'partial feed notifies valid additions without global reconciliation',
    (tester) async {
      final calls = <MethodCall>[];
      final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(alarmFeed.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            if (call.method == 'isNotificationReady') return true;
            if (call.method == 'showActiveNotification') return true;
            if (call.method == 'reconcileActiveNotifications') return 0;
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith((_) => alarmFeed.stream),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();

      alarmFeed.add(_verified(const <CriticalAlarm>[]));
      await tester.pumpAndSettle();
      final verifiedReconciliations = calls
          .where((call) => call.method == 'reconcileActiveNotifications')
          .length;

      alarmFeed.add(_partial([_raisedAlarm()]));
      await tester.pumpAndSettle();

      expect(
        calls.where((call) => call.method == 'showActiveNotification'),
        hasLength(1),
      );
      expect(
        calls.where((call) => call.method == 'reconcileActiveNotifications'),
        hasLength(verifiedReconciliations),
      );
      expect(
        calls.where((call) => call.method == 'cancelNotification'),
        isEmpty,
      );
    },
  );

  for (final loseAuthority in [false, true]) {
    testWidgets(
      'partial alarm retries after settings only with current approval: '
      'authority lost=$loseAuthority',
      (tester) async {
        final calls = <MethodCall>[];
        final alarmFeed = StreamController<CriticalAlarmLiveSnapshot>();
        final users = StreamController<AppUser?>();
        addTearDown(alarmFeed.close);
        addTearDown(users.close);
        var ready = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, (call) async {
              calls.add(call);
              if (call.method == 'isNotificationReady') return ready;
              if (call.method == 'showActiveNotification') return true;
              if (call.method == 'reconcileActiveNotifications') return 0;
              return null;
            });
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((_) => users.stream),
              activeCriticalAlarmsProvider.overrideWith(
                (_) => alarmFeed.stream,
              ),
            ],
            child: MaterialApp(
              navigatorKey: navigatorKey,
              builder: (context, child) => CriticalAlarmHost(
                navigatorKey: navigatorKey,
                child: child ?? const SizedBox.shrink(),
              ),
              home: const Scaffold(body: Text('Operations')),
            ),
          ),
        );
        users.add(_user());
        alarmFeed.add(_verified(const <CriticalAlarm>[]));
        await tester.pumpAndSettle();
        final reconciliations = calls
            .where((call) => call.method == 'reconcileActiveNotifications')
            .length;
        alarmFeed.add(_partial([_raisedAlarm()]));
        await tester.pumpAndSettle();
        expect(
          calls.where((call) => call.method == 'showActiveNotification'),
          isEmpty,
        );

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        if (loseAuthority) {
          users.addError(StateError('authority verification unavailable'));
          await tester.pumpAndSettle();
        }
        ready = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          calls.where((call) => call.method == 'showActiveNotification'),
          hasLength(loseAuthority ? 0 : 1),
        );
        expect(
          calls.where((call) => call.method == 'reconcileActiveNotifications'),
          hasLength(reconciliations),
        );
        expect(
          calls.where((call) => call.method == 'cancelNotification'),
          isEmpty,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(
          calls.where((call) => call.method == 'showActiveNotification'),
          hasLength(loseAuthority ? 0 : 1),
          reason: 'A successful retry must not post the same alarm twice.',
        );
      },
    );
  }

  testWidgets('global alarm launcher yields interaction to modal routes', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'reconcileActiveNotifications') return 0;
          return null;
        });
    final navigatorKey = GlobalKey<NavigatorState>();
    final routeObserver = CriticalAlarmLauncherRouteObserver();
    addTearDown(routeObserver.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
          activeCriticalAlarmsProvider.overrideWith(
            (_) => Stream.value(_verified(const <CriticalAlarm>[])),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[routeObserver],
          builder: (context, child) => CriticalAlarmHost(
            navigatorKey: navigatorKey,
            launcherObscuredListenable: routeObserver.obscured,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('Governed hierarchy picker'),
                    ),
                  ),
                  child: const Text('Open modal'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('global-critical-alarm-launcher')),
      findsOneWidget,
    );
    await tester.tap(find.text('Open modal'));
    await tester.pumpAndSettle();

    expect(find.text('Governed hierarchy picker'), findsOneWidget);
    expect(
      find.byKey(const Key('global-critical-alarm-launcher')),
      findsNothing,
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('global-critical-alarm-launcher')),
      findsOneWidget,
    );
  });

  testWidgets('global alarm launcher hides inside critical safety workspace', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'reconcileActiveNotifications') return 0;
          return null;
        });
    final navigatorKey = GlobalKey<NavigatorState>();
    final routeObserver = CriticalAlarmLauncherRouteObserver();
    addTearDown(routeObserver.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
          activeCriticalAlarmsProvider.overrideWith(
            (_) => Stream.value(_verified(const <CriticalAlarm>[])),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: <NavigatorObserver>[routeObserver],
          builder: (context, child) => CriticalAlarmHost(
            navigatorKey: navigatorKey,
            launcherObscuredListenable: routeObserver.obscured,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(
                        name: CriticalAlarmScreen.routeName,
                      ),
                      builder: (_) => const Scaffold(
                        body: Text('Critical safety workspace'),
                      ),
                    ),
                  ),
                  child: const Text('Open critical safety'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('global-critical-alarm-launcher')),
      findsOneWidget,
    );
    await tester.tap(find.text('Open critical safety'));
    await tester.pumpAndSettle();

    expect(find.text('Critical safety workspace'), findsOneWidget);
    expect(
      find.byKey(const Key('global-critical-alarm-launcher')),
      findsNothing,
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('global-critical-alarm-launcher')),
      findsOneWidget,
    );
  });

  testWidgets(
    'safety access reserves space instead of covering route controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = 0;
      await _pumpLauncherHost(
        tester,
        body: Align(
          alignment: Alignment.topRight,
          child: FilledButton(
            onPressed: () => opened++,
            child: const Text('First route action'),
          ),
        ),
      );
      final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
      final action = find.text('First route action');
      expect(
        tester.getRect(launcher).overlaps(tester.getRect(action)),
        isFalse,
      );
      expect(
        tester.getRect(action).top,
        greaterThanOrEqualTo(tester.getRect(launcher).bottom),
      );
      expect(tester.getSize(launcher).height, greaterThanOrEqualTo(48));
      await tester.tap(action);
      await tester.pump();
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('safety access fits a narrow phone at large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpLauncherHost(tester, textScale: 2.0, snapshot: _stale(const []));
    final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
    expect(find.text('Safety alarms'), findsOneWidget);
    expect(find.text('Live status not verified.'), findsOneWidget);
    expect(tester.getRect(launcher).right, lessThanOrEqualTo(320));
    expect(
      tester.getRect(find.byType(Scaffold)).top,
      greaterThanOrEqualTo(tester.getRect(launcher).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reserved safety row remains in the actual route semantics tree',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pumpLauncherHost(tester);
        final reachable = tester.semantics.simulatedAccessibilityTraversal();
        expect(
          reachable.any((node) {
            final data = node.getSemanticsData();
            return data.label == 'Critical safety alarms. No active alarms.' &&
                data.hasAction(SemanticsAction.tap);
          }),
          isTrue,
        );
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'reserved safety header paints the status bar with contrasting icons',
    (tester) async {
      await _pumpLauncherHost(
        tester,
        systemInsets: const EdgeInsets.only(top: 24),
      );
      var region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const Key('critical-safety-system-ui')),
      );
      expect(region.value.statusBarIconBrightness, Brightness.dark);
      expect(region.value.statusBarColor, const Color(0xFFFDFEFE));
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpLauncherHost(
        tester,
        snapshot: _verified([_supportConfirmedAlarm()]),
      );
      region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byKey(const Key('critical-safety-system-ui')),
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarColor, const Color(0xFFBE3F4C));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quiet alarm access keeps an explicit verified state', (
    tester,
  ) async {
    await _pumpLauncherHost(tester);
    final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
    final semantics = tester.widget<Semantics>(launcher);
    expect(semantics.properties.label, contains('No active alarms.'));
    expect(semantics.properties.label, isNot(contains('Drag to reposition.')));
    expect(semantics.properties.onTap, isNotNull);
    expect(
      find.descendant(of: launcher, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpLauncherHost(tester, snapshot: _stale(const []));
    expect(
      tester.widget<Semantics>(launcher).properties.label,
      contains('Live status not verified.'),
    );
    expect(
      tester.widget<Semantics>(launcher).properties.label,
      isNot(contains('No active alarms.')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpLauncherHost(
      tester,
      snapshot: _verified([_supportConfirmedAlarm()]),
    );
    expect(
      tester.widget<Semantics>(launcher).properties.label,
      contains('1 active alarm.'),
    );
  });

  testWidgets('global alarm launcher applies device safe insets exactly once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const systemInsets = EdgeInsets.fromLTRB(16, 44, 12, 34);
    await _pumpLauncherHost(tester, systemInsets: systemInsets);

    final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
    final position = tester.getTopLeft(launcher);
    expect(position.dx, closeTo(systemInsets.left, 1));
    expect(position.dy, closeTo(systemInsets.top, 1));
    expect(tester.getSize(launcher).height, greaterThanOrEqualTo(48));
    expect(
      tester.getTopLeft(find.byType(Scaffold)).dy,
      closeTo(tester.getRect(launcher).bottom, 1),
    );
  });

  testWidgets(
    'alarm refresh cannot advertise its retained empty snapshot as live',
    (tester) async {
      final pendingFeed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(pendingFeed.close);
      var subscriptions = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            if (call.method == 'reconcileActiveNotifications') return 0;
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
            activeCriticalAlarmsProvider.overrideWith((_) {
              subscriptions++;
              return subscriptions == 1
                  ? Stream.value(_verified(const []))
                  : pendingFeed.stream;
            }),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
      expect(
        tester.widget<Semantics>(launcher).properties.label,
        contains('No active alarms.'),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CriticalAlarmHost)),
        listen: false,
      );
      container.invalidate(activeCriticalAlarmsProvider);
      await tester.pump();
      final refreshing = container.read(activeCriticalAlarmsProvider);
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.hasValue, isTrue);
      await tester.pump();
      expect(
        tester.widget<Semantics>(launcher).properties.label,
        contains('Live status not verified.'),
      );
      expect(
        tester.widget<Semantics>(launcher).properties.label,
        isNot(contains('No active alarms.')),
      );
      pendingFeed.add(_verified(const []));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<Semantics>(launcher).properties.label,
        contains('No active alarms.'),
      );
    },
  );

  testWidgets('global alarm launcher stays above an open keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpLauncherHost(
      tester,
      viewInsets: const EdgeInsets.only(bottom: 300),
    );

    final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
    expect(tester.getRect(launcher).bottom, lessThan(500));
    expect(
      tester.getTopLeft(find.byType(Scaffold)).dy,
      greaterThanOrEqualTo(tester.getRect(launcher).bottom),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLauncherHost(
  WidgetTester tester, {
  EdgeInsets systemInsets = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  CriticalAlarmLiveSnapshot? snapshot,
  double textScale = 1,
  Widget body = const Text('Operations'),
}) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        if (call.method == 'reconcileActiveNotifications') return 0;
        return null;
      });
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((_) => Stream.value(_user())),
        activeCriticalAlarmsProvider.overrideWith(
          (_) => Stream.value(snapshot ?? _verified(const <CriticalAlarm>[])),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) {
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              padding: systemInsets,
              viewPadding: systemInsets,
              viewInsets: viewInsets,
              textScaler: TextScaler.linear(textScale),
            ),
            child: CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
