import 'dart:async';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/presentation/critical_alarm_host.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
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
            builder:
                (context, child) => CriticalAlarmHost(
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
            builder:
                (context, child) => CriticalAlarmHost(
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
          builder:
              (context, child) => CriticalAlarmHost(
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
            builder:
                (context, child) => CriticalAlarmHost(
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
            builder:
                (context, child) => CriticalAlarmHost(
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
            builder:
                (context, child) => CriticalAlarmHost(
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
            builder:
                (context, child) => CriticalAlarmHost(
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
      final verifiedReconciliations =
          calls
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
          builder:
              (context, child) => CriticalAlarmHost(
                navigatorKey: navigatorKey,
                launcherObscuredListenable: routeObserver.obscured,
                child: child ?? const SizedBox.shrink(),
              ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed:
                          () => showDialog<void>(
                            context: context,
                            builder:
                                (context) => const AlertDialog(
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

  testWidgets(
    'global alarm launcher retains every high-frequency drag sample',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpLauncherHost(tester);

      final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
      final before = tester.getTopLeft(launcher);
      final gesture = await tester.startGesture(tester.getCenter(launcher));
      for (var index = 0; index < 10; index++) {
        await gesture.moveBy(const Offset(-8, 0));
      }
      await gesture.up();
      await tester.pump();

      final after = tester.getTopLeft(launcher);
      expect(after.dx, closeTo(before.dx - 80, 1));
      expect(after.dy, closeTo(before.dy, 1));
    },
  );

  testWidgets('global alarm launcher applies device safe insets exactly once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const systemInsets = EdgeInsets.fromLTRB(16, 44, 12, 34);
    await _pumpLauncherHost(tester, systemInsets: systemInsets);

    final launcher = find.byKey(const Key('global-critical-alarm-launcher'));
    final gesture = await tester.startGesture(tester.getCenter(launcher));
    await gesture.moveBy(const Offset(-1000, -1000));
    await gesture.up();
    await tester.pump();

    final position = tester.getTopLeft(launcher);
    expect(position.dx, closeTo(systemInsets.left + 12, 1));
    expect(position.dy, closeTo(systemInsets.top + 12, 1));
    expect(tester.getSize(launcher), const Size.square(48));
  });
}

Future<void> _pumpLauncherHost(
  WidgetTester tester, {
  EdgeInsets systemInsets = EdgeInsets.zero,
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
          (_) => Stream.value(_verified(const <CriticalAlarm>[])),
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
            ),
            child: CriticalAlarmHost(
              navigatorKey: navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
        home: const Scaffold(body: Text('Operations')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
