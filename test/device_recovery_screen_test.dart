import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/admin/presentation/device_recovery_screen.dart';
import 'package:crm3_baf_ops/features/admin/providers/user_directory_provider.dart';
import 'package:crm3_baf_ops/features/admin/services/device_recovery_command_service.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _installation = '11111111-1111-4111-8111-111111111111';

void main() {
  testWidgets('non-admin cannot read the recovery user or device inventory', (
    tester,
  ) async {
    var userReads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_operator()),
          ),
          allUsersProvider.overrideWith((ref) {
            userReads++;
            return Stream.value([_operator()]);
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const DeviceRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrator access required'), findsOneWidget);
    expect(userReads, 0);
  });

  testWidgets('admin targets exactly one non-admin phone after confirmation', (
    tester,
  ) async {
    final calls = <Map<String, Object?>>[];
    final service = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'admin-1',
      invoke: (payload) async {
        calls.add(Map<String, Object?>.from(payload));
        if (payload['operation'] == deviceRecoveryListOperation) {
          return <String, dynamic>{
            'ok': true,
            'operation': deviceRecoveryListOperation,
            'targetUid': 'operator-1',
            'installations': [
              <String, Object?>{
                'installationId': _installation,
                'platform': 'android',
                'updatedAt': '2026-08-25T12:00:00.000Z',
                'recoveryStatus': 'none',
                'recoveryRequestId': null,
                'recoveryUpdatedAt': null,
              },
            ],
          };
        }
        return <String, dynamic>{
          'ok': true,
          'operation': deviceRecoveryRequestOperation,
          'requestId': payload['requestId'],
          'targetUid': payload['targetUid'],
          'installationId': payload['installationId'],
          'status': 'pending',
        };
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => Stream.value(_admin())),
          allUsersProvider.overrideWith((ref) => Stream.value([_operator()])),
          deviceRecoveryCommandServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const DeviceRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operator One'));
    await tester.pumpAndSettle();

    expect(find.text('ANDROID 11111111'), findsOneWidget);
    await tester.tap(find.byTooltip('Reset this phone'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Audited reason'),
      'Stale pilot records require a protected full refresh.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Type RESET 11111111'),
      'RESET WRONG',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Request reset'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter the exact selected-phone confirmation.'),
      findsOneWidget,
    );
    expect(calls, hasLength(1));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Type RESET 11111111'),
      'RESET 11111111',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Request reset'));
    await tester.pumpAndSettle();

    final requests =
        calls
            .where(
              (call) => call['operation'] == deviceRecoveryRequestOperation,
            )
            .toList();
    expect(requests, hasLength(1));
    expect(requests.single['targetUid'], 'operator-1');
    expect(requests.single['installationId'], _installation);
    expect(
      requests.single['reason'],
      'Stale pilot records require a protected full refresh.',
    );
    expect(
      find.text('Protected reset requested for the selected phone.'),
      findsOneWidget,
    );
  });

  test(
    'command client denies admin-only reset without making a server call',
    () async {
      var requests = 0;
      final service = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-1',
        invoke: (payload) async {
          requests++;
          return {};
        },
      );

      await expectLater(
        service.requestReset(
          actor: _operator(),
          targetUid: 'operator-1',
          installationId: _installation,
          reason: 'An operator must never issue an administrator reset.',
        ),
        throwsA(isA<DeviceRecoveryException>()),
      );
      expect(requests, 0);
    },
  );

  test('command client rejects a pending request for another phone', () async {
    final service = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'operator-1',
      invoke:
          (_) async => <String, dynamic>{
            'ok': true,
            'operation': deviceRecoveryPollOperation,
            'installationId': _installation,
            'request': <String, Object?>{
              'requestId': '33333333-3333-4333-8333-333333333333',
              'targetUid': 'operator-1',
              'installationId': '22222222-2222-4222-8222-222222222222',
              'status': 'pending',
              'requestedByUid': 'admin-1',
              'requestedByName': 'Administrator',
              'reason': 'Protect this particular registered installation.',
              'requestedAt': '2026-08-25T12:00:00.000Z',
              'expiresAt': '2026-08-26T12:00:00.000Z',
            },
          },
    );

    await expectLater(
      service.pollPending(actor: _operator(), installationId: _installation),
      throwsA(isA<DeviceRecoveryException>()),
    );
  });

  test(
    'command client rejects completion from another approved account',
    () async {
      var requests = 0;
      final service = DeviceRecoveryCommandService(
        authenticatedUidLookup: () => 'operator-2',
        invoke: (payload) async {
          requests++;
          return <String, dynamic>{};
        },
      );
      const recoveryRequest = DeviceRecoveryRequest(
        requestId: '33333333-3333-4333-8333-333333333333',
        targetUid: 'operator-1',
        installationId: _installation,
        requestedByUid: 'admin-1',
        requestedByName: 'Administrator',
        reason: 'Protect this particular registered installation.',
        requestedAt: '2026-08-25T12:00:00.000Z',
        expiresAt: '2026-08-26T12:00:00.000Z',
      );

      await expectLater(
        service.completeReset(
          actor: _operator(uid: 'operator-2'),
          request: recoveryRequest,
          backupFileCount: 1,
          clearedCursorCount: 1,
          backedUpUnsyncedRows: 0,
        ),
        throwsA(isA<DeviceRecoveryException>()),
      );
      await expectLater(
        service.claimReset(
          actor: _operator(uid: 'operator-2'),
          request: recoveryRequest,
        ),
        throwsA(isA<DeviceRecoveryException>()),
      );
      await expectLater(
        service.failReset(
          actor: _operator(uid: 'operator-2'),
          request: recoveryRequest,
          failureCode: 'device-recovery-backup-failed',
        ),
        throwsA(isA<DeviceRecoveryException>()),
      );
      expect(requests, 0);
    },
  );

  testWidgets('claimed phone reset cannot be cancelled from the admin screen', (
    tester,
  ) async {
    final service = DeviceRecoveryCommandService(
      authenticatedUidLookup: () => 'admin-1',
      invoke:
          (_) async => <String, dynamic>{
            'ok': true,
            'operation': deviceRecoveryListOperation,
            'targetUid': 'operator-1',
            'installations': [
              <String, Object?>{
                'installationId': _installation,
                'platform': 'android',
                'updatedAt': '2026-08-25T12:00:00.000Z',
                'recoveryStatus': 'in_progress',
                'recoveryRequestId': '33333333-3333-4333-8333-333333333333',
                'recoveryUpdatedAt': '2026-08-25T12:01:00.000Z',
              },
            ],
          },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => Stream.value(_admin())),
          allUsersProvider.overrideWith((ref) => Stream.value([_operator()])),
          deviceRecoveryCommandServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const DeviceRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Operator One'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Reset in progress'), findsOneWidget);
    expect(find.byTooltip('Cancel pending reset'), findsNothing);
    expect(find.byTooltip('Reset this phone'), findsNothing);
  });
}

AppUser _operator({String uid = 'operator-1'}) => AppUser(
  uid: uid,
  name: 'Operator One',
  email: 'operator@example.invalid',
  roles: const [AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 25),
);

AppUser _admin() => AppUser(
  uid: 'admin-1',
  name: 'Administrator',
  email: 'admin@example.invalid',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 8, 25),
);
