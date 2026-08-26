import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/critical_alarm_models.dart';

class CriticalAlarmPlatformService {
  const CriticalAlarmPlatformService();

  static const MethodChannel _channel = MethodChannel(
    'in.co.sail.bsl.crm3.bafops/critical_alarm',
  );
  static final StreamController<String> _openedAlarmController =
      StreamController<String>.broadcast();
  static bool _openListenerInstalled = false;

  Stream<String> get openedAlarmIds => _openedAlarmController.stream;

  Future<String?> initializeAlarmOpenListener() async {
    if (kIsWeb) return null;
    if (!_openListenerInstalled) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'criticalAlarmOpened') return null;
        final arguments = call.arguments;
        final alarmId =
            arguments is Map ? arguments['alarmId']?.toString().trim() : null;
        if (alarmId != null && alarmId.isNotEmpty) {
          _openedAlarmController.add(alarmId);
        }
        return null;
      });
      _openListenerInstalled = true;
    }
    try {
      final alarmId = await _channel.invokeMethod<String>(
        'consumeOpenedAlarmId',
      );
      final trimmed = alarmId?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> showActiveNotification(CriticalAlarm alarm) async {
    if (kIsWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('showActiveNotification', {
            'alarmId': alarm.id,
            'title':
                '${alarm.definition.criticalityLabel.toUpperCase()}: ${alarm.definition.name}',
            'body':
                '${alarm.location} - raised by ${alarm.raisedByName}. Follow the plant emergency procedure.',
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> cancelNotification(String alarmId) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('cancelNotification', {
        'alarmId': alarmId,
      });
    } on PlatformException {
      // Firestore remains the authoritative alarm state.
    } on MissingPluginException {
      // Non-Android platforms retain the in-app alarm surface.
    }
  }

  Future<int> reconcileActiveNotifications(Set<String> ringingAlarmIds) async {
    if (kIsWeb) return 0;
    final orderedIds = ringingAlarmIds.toList()..sort();
    try {
      return await _channel.invokeMethod<int>('reconcileActiveNotifications', {
            'ringingAlarmIds': orderedIds,
          }) ??
          0;
    } on PlatformException {
      return 0;
    } on MissingPluginException {
      return 0;
    }
  }

  Future<void> openDialer(String dialValue) async {
    if (kIsWeb) {
      throw PlatformException(
        code: 'dialler-unavailable',
        message: 'The device dialler is unavailable on this platform.',
      );
    }
    await _channel.invokeMethod<void>('openDialer', {'dialValue': dialValue});
  }
}
