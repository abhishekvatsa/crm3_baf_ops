import 'dart:async';
import 'dart:convert';

import 'package:crm3_baf_ops/core/persistence/durable_submission.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/domain/critical_alarm_models.dart';
import 'package:crm3_baf_ops/features/critical_alarm/presentation/critical_alarm_screen.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/critical_alarm/services/critical_alarm_command_service.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
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
  List<DurableSubmission> pending = const [],
  CriticalAlarmCommandService? commands,
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
          (_) => Stream.value(
            CriticalAlarmContactsSnapshot(
              contacts: contacts,
              malformedDocumentIds: const <String>[],
            ),
          ),
        ),
        criticalAlarmDefinitionsProvider.overrideWith(
          (_) => Stream.value(
            CriticalAlarmDefinitionsSnapshot(
              definitions: CriticalAlarmDefinition.values,
              malformedDocumentIds: const <String>[],
            ),
          ),
        ),
        criticalAlarmPendingSubmissionsProvider.overrideWith(
          (_) => Stream.value(pending),
        ),
        if (commands != null)
          criticalAlarmCommandServiceProvider.overrideWithValue(commands),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: CriticalAlarmScreen(initialAlarmId: initialAlarmId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _SavedCommandService implements CriticalAlarmCommandService {
  final resumedIds = <String>[];

  @override
  Future<WorkflowCommandReceipt> resume(String submissionId) async {
    resumedIds.add(submissionId);
    return WorkflowCommandReceipt(
      commandId: submissionId,
      resultKey: 'critical-alarm-raised',
      aggregateVersion: 1,
      result: const {},
      appliedAt: DateTime.utc(2026, 9, 19),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DurableSubmission _savedRaise() => DurableSubmission(
  submissionId: 'saved-raise',
  actorUid: 'operator-1',
  requestId: 'saved-raise',
  aggregateId: 'saved-alarm',
  resourceKey: 'criticalAlarm:saved-alarm',
  protocol: 'criticalAlarm.v1',
  envelopeJson: jsonEncode({
    'protocolVersion': 2,
    'originActorUid': 'operator-1',
    'command': {
      'commandId': 'saved-raise',
      'commandType': 'raiseCriticalAlarm',
      'aggregateId': 'saved-alarm',
      'expectedVersion': 0,
      'payload': {
        'alarmTypeKey': 'fire',
        'location': 'North bay',
        'initialDetails': 'Flame beside utility gallery',
      },
    },
  }),
  displayMetadataJson: null,
  state: DurableSubmissionState.uncertain,
  attemptCount: 1,
  createdAt: DateTime.utc(2026, 9, 18, 9),
  updatedAt: DateTime.utc(2026, 9, 18, 9),
  claimToken: null,
  claimExpiresAt: null,
  nextRetryAt: null,
  receiptJson: null,
  receiptSha256: null,
  lastErrorCode: null,
  lastErrorMessage: null,
  legacySourceKey: null,
  legacySourceBase64: null,
);

void main() {
  _currentActorConfirmationTests();
  testWidgets('multiple saved actions leave the alarm workspace usable', (
    tester,
  ) async {
    await _pump(tester, pending: [_savedRaise(), _savedRaise(), _savedRaise()]);
    expect(find.text('Review and retry'), findsWidgets);
    expect(find.text('Raise alarm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Review and retry').first);
    await tester.pumpAndSettle();
    expect(find.text('Retry this saved action?'), findsOneWidget);
    await tester.tap(find.text('Keep saved'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final confirm in [false, true]) {
    testWidgets('saved action is reviewed before retry; confirm=$confirm', (
      tester,
    ) async {
      final commands = _SavedCommandService();
      await _pump(tester, pending: [_savedRaise()], commands: commands);
      expect(commands.resumedIds, isEmpty);
      await tester.tap(find.text('Review and retry'));
      await tester.pumpAndSettle();
      expect(find.text('Retry this saved action?'), findsOneWidget);
      expect(find.textContaining('Location: North bay'), findsOneWidget);
      expect(
        find.textContaining('Flame beside utility gallery'),
        findsOneWidget,
      );
      expect(find.textContaining('Saved:'), findsOneWidget);
      expect(find.textContaining('it may take effect now'), findsOneWidget);
      expect(commands.resumedIds, isEmpty);
      await tester.tap(find.text(confirm ? 'Confirm and retry' : 'Keep saved'));
      await tester.pumpAndSettle();
      expect(commands.resumedIds, confirm ? ['saved-raise'] : isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

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
      expect(find.textContaining('original command is saved'), findsOneWidget);
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
    expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
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

// All actions here terminate in an in-memory service spy. No alarm is sent.
class _ConfirmationCommands implements CriticalAlarmCommandService {
  final calls = <Invocation>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return Future<WorkflowCommandReceipt>.value(
      WorkflowCommandReceipt(
        commandId: 'synthetic-command',
        resultKey: 'synthetic-accepted',
        aggregateVersion: 2,
        result: const {},
        appliedAt: DateTime.utc(2026),
      ),
    );
  }
}

AppUser _dialogActor({
  String uid = 'origin-admin',
  bool approved = true,
  AppRole role = AppRole.admin,
}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.invalid',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);

CriticalAlarm _dialogAlarm({bool supported = false}) => CriticalAlarm(
  id: 'synthetic-alarm',
  definition: CriticalAlarmDefinition.values.first,
  status: supported
      ? CriticalAlarmStatus.supportConfirmed
      : CriticalAlarmStatus.raised,
  version: supported ? 2 : 1,
  location: 'Synthetic test bay',
  assetTypeKey: null,
  assetNumber: null,
  details: 'Synthetic retained details',
  detailsPending: false,
  raisedByUid: 'origin-admin',
  raisedByName: 'Origin',
  raisedAt: DateTime.utc(2026),
  detailsProvidedByName: 'Origin',
  detailsProvidedAt: DateTime.utc(2026),
  supportBasis: supported ? CriticalAlarmSupportBasis.supportDispatched : null,
  supportNote: supported ? 'Synthetic response' : null,
  supportConfirmedByName: supported ? 'Origin' : null,
  supportConfirmedAt: supported ? DateTime.utc(2026) : null,
  resolutionSummary: null,
  resolvedByName: null,
  resolvedAt: null,
  withdrawalReason: null,
  withdrawnByName: null,
  withdrawnAt: null,
  updatedAt: DateTime.utc(2026),
);

void _currentActorConfirmationTests() {
  for (final action in ['raise', 'details', 'support', 'resolve', 'withdraw']) {
    for (final interruption in [
      'account switch',
      'refresh',
      'error',
      'approval lost',
    ]) {
      testWidgets('alarm $action queued confirmation blocks $interruption', (
        tester,
      ) async {
        final harness = _AlarmConfirmationHarness(action);
        await harness.pump(tester);
        await harness.open(tester);
        final confirm = tester.widget<FilledButton>(harness.confirm).onPressed!;
        await harness.interrupt(tester, interruption);
        confirm();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump();
        expect(harness.commands.calls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('alarm $action dialog waits for its original approved actor', (
      tester,
    ) async {
      final harness = _AlarmConfirmationHarness(action);
      await harness.pump(tester);
      await harness.open(tester);
      await harness.interrupt(tester, 'account switch');
      expect(find.text('Account verification required'), findsOneWidget);
      expect(harness.confirm, findsNothing);
      harness.actors.add(_dialogActor());
      await tester.pumpAndSettle();
      expect(find.text('Account verification required'), findsNothing);
      await tester.tap(harness.confirm);
      await tester.pumpAndSettle();
      expect(harness.commands.calls, hasLength(1));
      expect(harness.commands.calls.single.memberName, switch (action) {
        'raise' => #raise,
        'details' => #provideDetails,
        'support' => #confirmSupport,
        'resolve' => #resolve,
        _ => #withdraw,
      });
      final call = harness.commands.calls.single;
      if (action == 'raise') {
        expect(call.namedArguments[#location], 'Synthetic test bay');
        expect(
          call.namedArguments[#initialDetails],
          'Synthetic retained details',
        );
      } else if (action == 'support') {
        expect(
          call.namedArguments[#basis],
          CriticalAlarmSupportBasis.supportDispatched,
        );
        expect(call.namedArguments[#responderNote], 'Synthetic response');
      } else {
        expect(
          (call.positionalArguments.first as CriticalAlarm).id,
          'synthetic-alarm',
        );
        expect(call.positionalArguments[1], 'Synthetic retained details');
      }
      expect(tester.takeException(), isNull);
    });
  }
}

class _AlarmConfirmationHarness {
  _AlarmConfirmationHarness(this.action);
  final String action;
  final actors = StreamController<AppUser?>.broadcast();
  final commands = _ConfirmationCommands();
  late ProviderContainer container;
  bool firstAuthority = true;

  Finder get confirm => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, switch (action) {
      'raise' => 'Confirm and send',
      'support' => 'Confirm support',
      _ => 'Confirm',
    }),
  );

  Future<void> pump(WidgetTester tester) async {
    addTearDown(actors.close);
    await _pump(
      tester,
      alarms: [_dialogAlarm(supported: action == 'resolve')],
      commands: commands,
      userStream: Stream<AppUser?>.multi((sink) {
        if (firstAuthority) {
          firstAuthority = false;
          sink.add(_dialogActor());
        }
        final subscription = actors.stream.listen(
          sink.add,
          onError: sink.addError,
          onDone: sink.close,
        );
        sink.onCancel = subscription.cancel;
      }),
    );
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(CriticalAlarmScreen)),
    );
  }

  Future<void> open(WidgetTester tester) async {
    final opener = find.text(switch (action) {
      'raise' => 'Raise alarm',
      'details' => 'Update details',
      'support' => 'Confirm support',
      'resolve' => 'Resolve',
      _ => 'Raised in error',
    });
    await tester.ensureVisible(opener);
    await tester.tap(opener);
    await tester.pumpAndSettle();
    if (action == 'raise') {
      final dropdown = tester
          .widget<DropdownButtonFormField<CriticalAlarmDefinition>>(
            find.byKey(const ValueKey('critical-alarm-reason')),
          );
      dropdown.onChanged!(CriticalAlarmDefinition.values.first);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('critical-alarm-location')),
        'Synthetic test bay',
      );
      await tester.enterText(
        find.byKey(const ValueKey('critical-alarm-details')),
        'Synthetic retained details',
      );
      await tester.tap(find.byKey(const ValueKey('critical-alarm-review')));
      await tester.pumpAndSettle();
    } else if (action == 'support') {
      final dropdown = tester
          .widget<DropdownButtonFormField<CriticalAlarmSupportBasis>>(
            find.byType(DropdownButtonFormField<CriticalAlarmSupportBasis>),
          );
      dropdown.onChanged!(CriticalAlarmSupportBasis.supportDispatched);
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'Synthetic response');
    } else {
      await tester.enterText(
        find.byType(TextField).last,
        'Synthetic retained details',
      );
    }
    await tester.pump();
  }

  Future<void> interrupt(WidgetTester tester, String interruption) async {
    switch (interruption) {
      case 'account switch':
        actors.add(_dialogActor(uid: 'other-admin'));
      case 'refresh':
        container.invalidate(currentAppUserProvider);
      case 'error':
        actors.addError(StateError('Synthetic authority unavailable'));
      case 'approval lost':
        actors.add(_dialogActor(approved: false));
    }
    await tester.pump();
    await tester.pump();
  }
}
