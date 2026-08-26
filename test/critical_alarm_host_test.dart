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
      final user = AppUser(
        uid: 'operator-1',
        name: 'Operator One',
        email: 'operator@example.com',
        roles: const [AppRole.operations],
        isApproved: true,
        createdAt: DateTime.utc(2026),
      );
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((_) => Stream.value(user)),
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
}
