import 'dart:async';

import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/presentation/critical_alarm_screen.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _approvedUser([List<AppRole> roles = const [AppRole.operations]]) =>
    AppUser(
      uid: 'operator-1',
      name: 'Operator One',
      email: 'operator@example.com',
      roles: roles,
      isApproved: true,
      createdAt: DateTime.utc(2026),
    );

CriticalAlarm _raisedFire() {
  final now = DateTime.utc(2026, 8, 26, 1, 2);
  return CriticalAlarm.fromFirestore({
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
    'details': 'Visible flame near the utility gallery',
    'detailsPending': false,
    'raisedByUid': 'operator-1',
    'raisedByName': 'Operator One',
    'raisedAt': now,
    'detailsProvidedByUid': 'operator-1',
    'detailsProvidedByName': 'Operator One',
    'detailsProvidedAt': now,
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
  }, 'alarm-1');
}

CriticalAlarm _resolvedFire() {
  final raisedAt = DateTime.utc(2026, 8, 26, 1, 2);
  final supportAt = DateTime.utc(2026, 8, 26, 1, 4);
  final resolvedAt = DateTime.utc(2026, 8, 26, 1, 8);
  return CriticalAlarm.fromFirestore({
    'schemaVersion': 1,
    'alarmId': 'alarm-resolved',
    'alarmTypeKey': 'fire',
    'alarmTypeName': 'Fire',
    'criticalityKey': 'highest',
    'criticalityRank': 1,
    'status': 'resolved',
    'version': 3,
    'location': 'BAF north bay',
    'assetTypeKey': null,
    'assetNumber': null,
    'details': 'Visible flame near the utility gallery',
    'detailsPending': false,
    'raisedByUid': 'operator-1',
    'raisedByName': 'Operator One',
    'raisedAt': raisedAt,
    'detailsProvidedByUid': 'operator-1',
    'detailsProvidedByName': 'Operator One',
    'detailsProvidedAt': raisedAt,
    'supportBasis': 'supportDispatched',
    'supportNote': 'Fire response support dispatched to the north bay.',
    'supportConfirmedByUid': 'admin-1',
    'supportConfirmedByName': 'Admin One',
    'supportConfirmedAt': supportAt,
    'resolutionSummary': 'Area isolated and verified safe.',
    'resolvedByUid': 'admin-1',
    'resolvedByName': 'Admin One',
    'resolvedAt': resolvedAt,
    'withdrawalReason': null,
    'withdrawnByUid': null,
    'withdrawnByName': null,
    'withdrawnAt': null,
    'createdAt': raisedAt,
    'updatedAt': resolvedAt,
  }, 'alarm-resolved');
}

CriticalAlarmContact _contact({
  required String id,
  required String label,
  required String typeKey,
}) => CriticalAlarmContact.fromFirestore({
  'schemaVersion': 1,
  'contactId': id,
  'version': 1,
  'status': 'active',
  'label': label,
  'contactKind': 'landline',
  'dialValue': '+916572200000',
  'alarmTypeKeys': [typeKey],
  'priority': 1,
  'notes': null,
  'createdAt': DateTime.utc(2026, 8, 26),
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'updatedAt': DateTime.utc(2026, 8, 26),
  'updatedByUid': 'admin-1',
  'updatedByName': 'Admin One',
}, id);

Future<void> _pump(
  WidgetTester tester, {
  List<CriticalAlarm> alarms = const [],
  List<CriticalAlarmContact> contacts = const [],
  AppUser? user,
  Stream<AppUser?>? userStream,
  String? initialAlarmId,
  CriticalAlarmLiveSnapshot? activeSnapshot,
}) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (_) => userStream ?? Stream.value(user ?? _approvedUser()),
        ),
        criticalAlarmFeedProvider.overrideWith((_) => Stream.value(alarms)),
        activeCriticalAlarmsProvider.overrideWith(
          (_) => Stream.value(
            activeSnapshot ??
                CriticalAlarmLiveSnapshot.serverVerified(
                  alarms: alarms.where((alarm) => alarm.isActive).toList(),
                  verifiedAt: DateTime.utc(2026, 8, 26, 1, 5),
                ),
          ),
        ),
        criticalAlarmContactsProvider.overrideWith(
          (_) => Stream.value(contacts),
        ),
        criticalAlarmDefinitionsProvider.overrideWith(
          (_) => Stream.value(CriticalAlarmDefinition.values),
        ),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: CriticalAlarmScreen(initialAlarmId: initialAlarmId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'raise flow starts blank and requires a governed reason and location',
    (tester) async {
      await _pump(tester);

      expect(find.text('Critical safety'), findsOneWidget);
      expect(find.textContaining('Coordination aid only'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Raise alarm'));
      await tester.pumpAndSettle();

      expect(find.text('Raise critical safety alarm'), findsOneWidget);
      expect(find.text('Fire - Highest'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'blank alarm sheet');
      await tester.ensureVisible(
        find.byKey(const ValueKey('critical-alarm-review')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('critical-alarm-review')));
      await tester.pump();
      expect(find.text('Select the alarm reason'), findsOneWidget);
      expect(find.text('Enter the location'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'validated alarm sheet');

      await tester.ensureVisible(
        find.byKey(const ValueKey('critical-alarm-reason')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('critical-alarm-reason')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'open alarm reason menu');
      await tester.tap(find.text('Fire - Highest').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'selected alarm reason');
      await tester.enterText(
        find.byKey(const ValueKey('critical-alarm-location')),
        'BAF north bay',
      );
      await tester.enterText(
        find.byKey(const ValueKey('critical-alarm-details')),
        'Visible flame near the north bay utility gallery',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('critical-alarm-review')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('critical-alarm-review')));
      await tester.pumpAndSettle();

      expect(find.text('Raise Fire?'), findsOneWidget);
      expect(find.textContaining('never queued offline'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'alarm confirmation dialog',
      );
    },
  );

  testWidgets('an alarm card shows only contacts mapped to its exact hazard', (
    tester,
  ) async {
    await _pump(
      tester,
      alarms: [_raisedFire()],
      contacts: [
        _contact(id: 'fire-room', label: 'Fire control room', typeKey: 'fire'),
        _contact(
          id: 'gas-room',
          label: 'Gas response room',
          typeKey: 'majorGasLeakage',
        ),
      ],
    );

    expect(find.text('Fire control room'), findsOneWidget);
    expect(find.text('+916572200000'), findsOneWidget);
    expect(find.text('Gas response room'), findsNothing);
    expect(find.text('Confirm support'), findsNothing);
    expect(find.text('Raised in error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale active alarms remain readable but are not labelled live', (
    tester,
  ) async {
    final alarm = _raisedFire();
    await _pump(
      tester,
      alarms: [alarm],
      activeSnapshot: CriticalAlarmLiveSnapshot.staleLastKnown(
        alarms: [alarm],
        lastVerifiedAt: DateTime.utc(2026, 8, 26, 1, 5),
      ),
    );

    expect(find.text('Active (?)'), findsOneWidget);
    expect(
      find.byKey(const Key('critical-alarm-stale-feed-notice')),
      findsOneWidget,
    );
    expect(find.textContaining('Not live:'), findsOneWidget);
    expect(find.text('Visible flame near the utility gallery'), findsOneWidget);
    expect(find.text('Raised in error'), findsNothing);
    expect(find.text('Add details'), findsNothing);
    expect(
      find.text(
        'Live server verification is required before changing this alarm.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin sees governed support action on a raised alarm', (
    tester,
  ) async {
    await _pump(
      tester,
      alarms: [_raisedFire()],
      user: _approvedUser(const [AppRole.admin]),
    );

    expect(find.text('Confirm support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification deep-link follows a resolved alarm into History', (
    tester,
  ) async {
    await _pump(
      tester,
      alarms: [_resolvedFire()],
      initialAlarmId: 'alarm-resolved',
    );

    expect(find.text('Resolved by Admin One'), findsOneWidget);
    expect(find.text('Area isolated and verified safe.'), findsOneWidget);
    expect(find.text('Raised in error'), findsNothing);
    expect(find.text('Add details'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'retained approval cannot expose alarm actions after authority failure',
    (tester) async {
      final users = StreamController<AppUser?>();
      addTearDown(users.close);
      users.add(_approvedUser());
      await _pump(tester, alarms: [_raisedFire()], userStream: users.stream);

      expect(find.text('Raise alarm'), findsOneWidget);
      expect(find.text('Raised in error'), findsOneWidget);

      users.addError(StateError('authority refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('Raise alarm'), findsNothing);
      expect(find.text('Raised in error'), findsNothing);
      expect(find.text('Alarm access unavailable'), findsOneWidget);
      expect(find.textContaining('No cached authority'), findsOneWidget);
    },
  );
}
