// ignore_for_file: invalid_use_of_visible_for_testing_member
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

const channel = MethodChannel('in.co.sail.bsl.crm3.bafops/critical_alarm');
CriticalAlarm alarm({bool supported = false}) {
  final raised = DateTime.utc(2026, 9, 19, 10);
  final updated = supported ? raised.add(const Duration(minutes: 1)) : raised;
  return CriticalAlarm(
    id: 'same-alarm',
    definition: CriticalAlarmDefinition.byKey['fire']!,
    status: supported
        ? CriticalAlarmStatus.supportConfirmed
        : CriticalAlarmStatus.raised,
    version: supported ? 2 : 1,
    location: 'North bay',
    assetTypeKey: null,
    assetNumber: null,
    details: 'Flame observed',
    detailsPending: false,
    raisedByUid: 'operator-1',
    raisedByName: 'Operator One',
    raisedAt: raised,
    detailsProvidedByName: 'Operator One',
    detailsProvidedAt: raised,
    supportBasis: supported
        ? CriticalAlarmSupportBasis.supportDispatched
        : null,
    supportNote: supported ? 'Response dispatched' : null,
    supportConfirmedByName: supported ? 'Admin One' : null,
    supportConfirmedAt: supported ? updated : null,
    resolutionSummary: null,
    resolvedByName: null,
    resolvedAt: null,
    withdrawalReason: null,
    withdrawnByName: null,
    withdrawnAt: null,
    updatedAt: updated,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  for (final delay in ['none', 'readiness', 'posting']) {
    testWidgets('newer partial support wins over old post; delay=$delay', (
      tester,
    ) async {
      final feed = StreamController<CriticalAlarmLiveSnapshot>();
      addTearDown(feed.close);
      final ready = Completer<bool>();
      final post = Completer<void>();
      final visible = <String>{};
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'isNotificationReady') {
              return delay == 'readiness' ? ready.future : true;
            }
            if (call.method == 'showActiveNotification') {
              if (delay == 'posting') await post.future;
              visible.add((call.arguments as Map)['alarmId'] as String);
              return true;
            }
            if (call.method == 'cancelNotification') {
              visible.remove((call.arguments as Map)['alarmId']);
            }
            if (call.method == 'reconcileActiveNotifications') {
              visible.retainAll(
                (call.arguments as Map)['ringingAlarmIds'] as List,
              );
              return 0;
            }
            return null;
          });
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (_) => Stream.value(
                AppUser(
                  uid: 'operator-1',
                  name: 'Operator One',
                  email: 'operator@example.invalid',
                  roles: const [AppRole.operations],
                  isApproved: true,
                  createdAt: DateTime.utc(2026),
                ),
              ),
            ),
            activeCriticalAlarmsProvider.overrideWith((_) => feed.stream),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) =>
                CriticalAlarmHost(navigatorKey: navigatorKey, child: child!),
            home: const Scaffold(body: Text('Operations')),
          ),
        ),
      );
      await tester.pump();
      feed.add(
        CriticalAlarmLiveSnapshot.serverVerified(
          alarms: [alarm()],
          verifiedAt: DateTime.utc(2026, 9, 19, 10),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        calls.where((c) => c.method == 'isNotificationReady'),
        hasLength(1),
      );
      final reconciliations = calls
          .where((c) => c.method == 'reconcileActiveNotifications')
          .length;
      visible.add('unreadable-other-alarm');
      feed.add(
        CriticalAlarmLiveSnapshot.partiallyVerified(
          alarms: [alarm(supported: true)],
          malformedDocumentCount: 1,
          lastVerifiedAt: DateTime.utc(2026, 9, 19, 10, 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        visible,
        {'unreadable-other-alarm'},
        reason:
            'Only the positive same-ID support row authorizes cancellation.',
      );
      if (delay == 'readiness') {
        ready.complete(true);
        await tester.pumpAndSettle();
      }
      if (delay == 'posting') {
        post.complete();
        await tester.pumpAndSettle();
      }
      expect(
        calls.where((c) => c.method == 'reconcileActiveNotifications'),
        hasLength(reconciliations),
      );
      expect(
        visible,
        {'unreadable-other-alarm'},
        reason:
            'The pending old raise must not reintroduce its notification after newer same-ID support.',
      );
      if (delay == 'readiness') {
        expect(
          calls.where((c) => c.method == 'showActiveNotification'),
          isEmpty,
          reason: 'Recheck the alarm before native posting, not only after it.',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
