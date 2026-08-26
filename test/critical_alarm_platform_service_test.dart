import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/services/critical_alarm_platform_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

const _channel = MethodChannel('in.co.sail.bsl.crm3.bafops/critical_alarm');

CriticalAlarm _alarm() => CriticalAlarm.fromFirestore({
  'schemaVersion': 1,
  'alarmId': 'alarm-1',
  'alarmTypeKey': 'fire',
  'alarmTypeName': 'Fire',
  'criticalityKey': 'highest',
  'criticalityRank': 1,
  'status': 'raised',
  'version': 1,
  'location': 'BAF north bay',
  'assetTypeKey': null,
  'assetNumber': null,
  'details': null,
  'detailsPending': true,
  'raisedByUid': 'operator-1',
  'raisedByName': 'Operator One',
  'raisedAt': DateTime.utc(2026, 8, 26),
  'detailsProvidedByUid': null,
  'detailsProvidedByName': null,
  'detailsProvidedAt': null,
  'supportBasis': null,
  'supportNote': null,
  'supportConfirmedByUid': null,
  'supportConfirmedByName': null,
  'supportConfirmedAt': null,
  'resolutionSummary': null,
  'resolvedByUid': null,
  'resolvedByName': null,
  'resolvedAt': null,
  'withdrawalReason': null,
  'withdrawnByUid': null,
  'withdrawnByName': null,
  'withdrawnAt': null,
  'createdAt': DateTime.utc(2026, 8, 26),
  'updatedAt': DateTime.utc(2026, 8, 26),
}, 'alarm-1');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test(
    'consumes the alarm identity retained by an Android notification tap',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return call.method == 'consumeOpenedAlarmId'
                ? 'alarm-from-notification'
                : null;
          });

      const service = CriticalAlarmPlatformService();
      expect(
        await service.initializeAlarmOpenListener(),
        'alarm-from-notification',
      );
      expect(calls.single.method, 'consumeOpenedAlarmId');
    },
  );

  test(
    'sends exact notification, reconciliation, cancellation and dialler requests',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            calls.add(call);
            return call.method == 'showActiveNotification' ? true : null;
          });

      const service = CriticalAlarmPlatformService();
      expect(await service.showActiveNotification(_alarm()), isTrue);
      expect(
        await service.reconcileActiveNotifications({'alarm-2', 'alarm-1'}),
        0,
      );
      await service.cancelNotification('alarm-1');
      await service.openDialer('+916572200000');

      expect(calls.map((call) => call.method), [
        'showActiveNotification',
        'reconcileActiveNotifications',
        'cancelNotification',
        'openDialer',
      ]);
      expect(
        (calls.first.arguments as Map<Object?, Object?>)['alarmId'],
        'alarm-1',
      );
      expect((calls[1].arguments as Map<Object?, Object?>)['ringingAlarmIds'], [
        'alarm-1',
        'alarm-2',
      ]);
      expect(
        (calls.last.arguments as Map<Object?, Object?>)['dialValue'],
        '+916572200000',
      );
    },
  );

  test(
    'Android keys notification replacement and cancellation by exact alarm tag',
    () {
      final source =
          File(
            'android/app/src/main/kotlin/in/co/sail/bsl/crm3/bafops/MainActivity.kt',
          ).readAsStringSync();
      expect(source, contains('notificationTag(alarmId)'));
      expect(source, contains('CRITICAL_NOTIFICATION_ID'));
      expect(source, contains('manager.activeNotifications'));
      expect(source, contains('CRITICAL_NOTIFICATION_TAG_PREFIX'));
      expect(source, contains('crm3://critical-alarm/'));
      expect(
        source,
        contains(
          'notificationManager().cancel(\n                        notificationTag(alarmId),',
        ),
      );
    },
  );
}
