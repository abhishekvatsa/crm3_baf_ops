import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// One unconfirmed creation per account/project. Never rotate an uncertain ID.
class MonitoringCreationStore {
  MonitoringCreationStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _load = preferencesLoader ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _load;
  static Future<void> _tail = Future<void>.value();
  static const _uuid = Uuid();
  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  String _key(String scope) {
    if (scope.trim().isEmpty) {
      throw StateError('Sign in before creating monitoring.');
    }
    return 'PENDING_QUALITY_MONITORING::${Uri.encodeComponent(scope)}';
  }

  Map<String, dynamic>? _read(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return _validate(jsonDecode(raw));
  }

  Map<String, dynamic> _validate(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value.length != 10 ||
        value['schemaVersion'] != 1 ||
        value['operation'] != 'CREATE_QUALITY_MONITORING_REQUEST' ||
        value['expectedVersion'] != 0 ||
        value['requestId'] is! String ||
        !_uuidPattern.hasMatch(value['requestId'] as String) ||
        value['monitoringRequestId'] is! String ||
        !_uuidPattern.hasMatch(value['monitoringRequestId'] as String) ||
        value['baseNumber'] is! int ||
        (value['baseNumber'] as int) <= 0 ||
        (value['baseNumber'] as int) > 9007199254740991 ||
        value['grade'] is! String ||
        (value['grade'] as String).trim().isEmpty ||
        (value['grade'] as String).length > 120 ||
        value['cycleReference'] is! String ||
        (value['cycleReference'] as String).trim().isEmpty ||
        (value['cycleReference'] as String).length > 200 ||
        value['reason'] is! String ||
        (value['reason'] as String).trim().isEmpty ||
        (value['reason'] as String).length > 2000 ||
        value['chargeNumbers'] is! List ||
        (value['chargeNumbers'] as List).length > 50 ||
        (value['chargeNumbers'] as List).toSet().length !=
            (value['chargeNumbers'] as List).length ||
        (value['chargeNumbers'] as List).any(
          (v) => v is! int || v < 10000 || v > 99999,
        )) {
      throw const FormatException(
        'Saved monitoring request needs recovery; it was not replaced.',
      );
    }
    return value;
  }

  Future<Map<String, dynamic>?> pending(String scope) => _serial(() async {
    final prefs = await _load();
    await prefs.reload();
    return _read(prefs, _key(scope));
  });

  Future<Map<String, dynamic>> prepare(
    String scope,
    Map<String, dynamic> payload,
  ) => _serial(() async {
    final prefs = await _load();
    await prefs.reload();
    final key = _key(scope);
    final existing = _read(prefs, key);
    if (existing != null) {
      for (final entry in payload.entries) {
        final retained = existing[entry.key];
        if (entry.value is List
            ? retained is! List || !listEquals(retained, entry.value as List)
            : retained != entry.value) {
          throw StateError(
            'Confirm the pending monitoring request before creating another.',
          );
        }
      }
      return existing;
    }
    final request = <String, dynamic>{
      'schemaVersion': 1,
      'requestId': _uuid.v4(),
      'monitoringRequestId': _uuid.v4(),
      'operation': 'CREATE_QUALITY_MONITORING_REQUEST',
      'expectedVersion': 0,
      ...payload,
    };
    _validate(request);
    if (!await prefs.setString(key, jsonEncode(request))) {
      throw StateError(
        'Could not retain the monitoring request. Nothing was sent.',
      );
    }
    return _read(prefs, key)!;
  });

  Future<void> complete(String scope, String requestId) => _serial(() async {
    final prefs = await _load();
    await prefs.reload();
    final key = _key(scope);
    if (_read(prefs, key)?['requestId'] == requestId &&
        !await prefs.remove(key)) {
      throw StateError(
        'Monitoring was confirmed, but its local receipt still needs reconciliation. Retry safely.',
      );
    }
  });
}
