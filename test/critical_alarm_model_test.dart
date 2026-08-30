import 'dart:io';

import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> raisedAlarm({
  String alarmTypeKey = 'fire',
  String alarmTypeName = 'Fire',
  String criticalityKey = 'highest',
  int criticalityRank = 1,
  String status = 'raised',
  String? details,
  bool detailsPending = true,
}) {
  final now = DateTime.utc(2026, 8, 26, 1, 2, 3);
  return {
    'schemaVersion': 1,
    'alarmId': 'alarm-1',
    'alarmTypeKey': alarmTypeKey,
    'alarmTypeName': alarmTypeName,
    'criticalityKey': criticalityKey,
    'criticalityRank': criticalityRank,
    'status': status,
    'version': 1,
    'location': 'BAF shop north bay',
    'assetTypeKey': null,
    'assetNumber': null,
    'details': details,
    'detailsPending': detailsPending,
    'raisedByUid': 'ops-1',
    'raisedByName': 'Operator One',
    'raisedAt': now,
    'detailsProvidedByUid': details == null ? null : 'ops-1',
    'detailsProvidedByName': details == null ? null : 'Operator One',
    'detailsProvidedAt': details == null ? null : now,
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
    'createdAt': now,
    'updatedAt': now,
  };
}

Map<String, dynamic> contact() => {
  'schemaVersion': 1,
  'contactId': 'fire-room',
  'version': 1,
  'status': 'active',
  'label': 'Fire control room',
  'contactKind': 'landline',
  'dialValue': '+916572200000',
  'alarmTypeKeys': ['fire'],
  'priority': 1,
  'notes': null,
  'createdAt': DateTime.utc(2026, 8, 26),
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'updatedAt': DateTime.utc(2026, 8, 26),
  'updatedByUid': 'admin-1',
  'updatedByName': 'Admin One',
};

void main() {
  group('critical alarm catalogue and decoding', () {
    test('contains the five governed hazards with server-owned ranks', () {
      expect(CriticalAlarmDefinition.byKey.keys, {
        'fire',
        'majorGasLeakage',
        'blast',
        'nitrogenFailure',
        'hotWellPumpFailure',
      });
      expect(CriticalAlarmDefinition.byKey['fire']!.criticalityKey, 'highest');
      expect(
        CriticalAlarmDefinition.byKey['majorGasLeakage']!.criticalityKey,
        'highest',
      );
      expect(CriticalAlarmDefinition.byKey['blast']!.criticalityKey, 'highest');
      expect(
        CriticalAlarmDefinition.byKey['nitrogenFailure']!.criticalityKey,
        'critical',
      );
      expect(
        CriticalAlarmDefinition.byKey['hotWellPumpFailure']!.criticalityKey,
        'critical',
      );
      expect(
        CriticalAlarmDefinition.values.map((definition) => definition.key),
        [
          'fire',
          'majorGasLeakage',
          'blast',
          'nitrogenFailure',
          'hotWellPumpFailure',
        ],
      );
    });

    test('accepts a canonical details-pending raised alarm', () {
      final alarm = CriticalAlarm.fromFirestore(raisedAlarm(), 'alarm-1');
      expect(alarm.status, CriticalAlarmStatus.raised);
      expect(alarm.detailsPending, isTrue);
      expect(alarm.definition.name, 'Fire');
    });

    test('rejects a malformed criticality pair', () {
      expect(
        () => CriticalAlarm.fromFirestore(
          raisedAlarm(criticalityKey: 'highest', criticalityRank: 2),
          'alarm-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('accepts an immutable snapshot from a live custom definition', () {
      final alarm = CriticalAlarm.fromFirestore(
        raisedAlarm(
          alarmTypeKey: 'critical_alarm_definition_custom',
          alarmTypeName: 'Hydrogen pressure collapse',
          criticalityKey: 'highest',
          criticalityRank: 1,
        ),
        'alarm-1',
      );
      expect(alarm.definition.name, 'Hydrogen pressure collapse');
    });

    test('rejects unknown fields and inconsistent detail state', () {
      expect(
        () => CriticalAlarm.fromFirestore({
          ...raisedAlarm(),
          'clientSeverity': 'low',
        }, 'alarm-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => CriticalAlarm.fromFirestore(
          raisedAlarm(details: 'Visible flame', detailsPending: true),
          'alarm-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('requires support and resolution evidence for terminal progress', () {
      expect(
        () => CriticalAlarm.fromFirestore(
          raisedAlarm(status: 'resolved'),
          'alarm-1',
        ),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('rejects partial detail and lifecycle actor evidence', () {
      expect(
        () => CriticalAlarm.fromFirestore({
          ...raisedAlarm(details: 'Visible flame', detailsPending: false),
          'detailsProvidedByUid': null,
        }, 'alarm-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => CriticalAlarm.fromFirestore({
          ...raisedAlarm(status: 'supportConfirmed'),
          'supportBasis': 'supportDispatched',
          'supportNote': 'Fire response team dispatched',
          'supportConfirmedByUid': 'ops-2',
          'supportConfirmedByName': null,
          'supportConfirmedAt': DateTime.utc(2026, 8, 26, 1, 3),
        }, 'alarm-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('rejects chronology that predates record creation', () {
      expect(
        () => CriticalAlarm.fromFirestore({
          ...raisedAlarm(),
          'updatedAt': DateTime.utc(2026, 8, 25),
        }, 'alarm-1'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test(
      'accepts concise detail evidence and rejects out-of-order lifecycle evidence',
      () {
        final concise = CriticalAlarm.fromFirestore(
          raisedAlarm(details: 'x', detailsPending: false),
          'alarm-1',
        );
        expect(concise.details, 'x');
        final raised = raisedAlarm(
          details: 'Visible flame beside the transfer path',
          detailsPending: false,
        );
        expect(
          () => CriticalAlarm.fromFirestore({
            ...raised,
            'raisedAt': DateTime.utc(2026, 8, 26, 1, 2, 4),
          }, 'alarm-1'),
          throwsA(isA<PersistedDataFormatException>()),
        );
      },
    );
  });

  group('critical alarm contacts', () {
    test('accepts an exact hazard-specific directory entry', () {
      final decoded = CriticalAlarmContact.fromFirestore(
        contact(),
        'fire-room',
      );
      expect(decoded.alarmTypeKeys, ['fire']);
      expect(decoded.kind, CriticalAlarmContactKind.landline);
    });

    test('rejects duplicated or malformed hazard mappings', () {
      expect(
        () => CriticalAlarmContact.fromFirestore({
          ...contact(),
          'alarmTypeKeys': ['fire', 'fire'],
        }, 'fire-room'),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => CriticalAlarmContact.fromFirestore({
          ...contact(),
          'alarmTypeKeys': [' genericEmergency '],
        }, 'fire-room'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('rejects a dial target that does not match its contact kind', () {
      expect(
        () => CriticalAlarmContact.fromFirestore({
          ...contact(),
          'contactKind': 'plantExtension',
          'dialValue': '+916572200000',
        }, 'fire-room'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });

    test('rejects malformed audit identity and chronology', () {
      expect(
        () => CriticalAlarmContact.fromFirestore({
          ...contact(),
          'createdByUid': null,
        }, 'fire-room'),
        throwsA(isA<PersistedDataFormatException>()),
      );
      expect(
        () => CriticalAlarmContact.fromFirestore({
          ...contact(),
          'updatedAt': DateTime.utc(2026, 8, 25),
        }, 'fire-room'),
        throwsA(isA<PersistedDataFormatException>()),
      );
    });
  });

  test(
    'active alarm and exact-contact reads cannot be displaced by history caps',
    () {
      final repository =
          File(
            'lib/features/critical_alarm/data/critical_alarm_repository.dart',
          ).readAsStringSync();
      final activeBody = RegExp(
        r'watchActiveAlarms\(\) async\* \{([\s\S]*?)\n  \}\n\n  Stream<List<CriticalAlarm>> watchAlarms',
      ).firstMatch(repository)?.group(1);
      expect(activeBody, isNotNull);
      expect(
        activeBody,
        contains("whereIn: const ['raised', 'supportConfirmed']"),
      );
      expect(activeBody, isNot(contains('.limit(')));
      expect(activeBody, contains('CriticalAlarmLiveSnapshot.unavailable()'));
      expect(activeBody, contains('CriticalAlarmLiveSnapshot.staleLastKnown'));
      expect(activeBody, contains('CriticalAlarmLiveSnapshot.serverVerified'));
      expect(repository, isNot(contains('.limit(100)')));

      final providers =
          File(
            'lib/features/critical_alarm/providers/critical_alarm_providers.dart',
          ).readAsStringSync();
      expect(providers, contains('.watchActiveAlarms()'));
    },
  );
}
