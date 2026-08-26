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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
              (_) => Stream.value([_supportConfirmedAlarm()]),
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
    final alarmFeed = StreamController<List<CriticalAlarm>>();
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

    alarmFeed.add([_raisedAlarm()]);
    await tester.pumpAndSettle();
    expect(showAttempts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(showAttempts, 2);
  });
}
