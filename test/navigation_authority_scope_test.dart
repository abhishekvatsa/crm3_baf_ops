import 'dart:io';

import 'package:crm3_baf_ops/features/auth/domain/navigation_authority_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app root binds MaterialApp to the live authority scope', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(
      source,
      contains('final navigationAuthority = _navigationAuthorityScope();'),
    );
    expect(
      source,
      contains('key: ValueKey<String>(navigationAuthority.navigatorKey)'),
    );
    expect(source, contains('if (profileAsync.hasError)'));
    expect(source, contains('roles: profile?.roles.map((role) => role.name)'));
  });

  test(
    'AuthGate rejects profile identity mismatch before approval and sync',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final mismatchGuard = source.indexOf('if (user.uid != firebaseUser.uid)');
      final approvalGuard = source.indexOf(
        'if (!user.isApproved)',
        mismatchGuard,
      );
      final startupSync = source.indexOf(
        'return _StartupSyncGate(appUser: user)',
        mismatchGuard,
      );

      expect(mismatchGuard, greaterThanOrEqualTo(0));
      expect(approvalGuard, greaterThan(mismatchGuard));
      expect(startupSync, greaterThan(mismatchGuard));
      expect(source, contains("title: 'Switching account'"));
    },
  );

  test('AuthGate rejects retained auth and profile data while refreshing', () {
    final source = File('lib/main.dart').readAsStringSync();
    final authGate = source.indexOf('class AuthGate extends ConsumerWidget');
    final authLoading = source.indexOf('if (authState.isLoading)', authGate);
    final authError = source.indexOf('if (authState.hasError)', authGate);
    final authValue = source.indexOf(
      'final firebaseUser = authState.value',
      authGate,
    );
    final profileLoading = source.indexOf('if (appUser.isLoading)', authGate);
    final profileError = source.indexOf('if (appUser.hasError)', authGate);
    final profileValue = source.indexOf('final user = appUser.value', authGate);

    expect(authGate, greaterThanOrEqualTo(0));
    expect(authLoading, greaterThan(authGate));
    expect(authError, greaterThan(authLoading));
    expect(authValue, greaterThan(authError));
    expect(profileLoading, greaterThan(authValue));
    expect(profileError, greaterThan(profileLoading));
    expect(profileValue, greaterThan(profileError));
  });

  test(
    'revoked account stays on the approval screen during claimed recovery',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final gateStart = source.indexOf('class _PendingApprovalRecoveryGate ');
      final gateEnd = source.indexOf(
        'class _ProfileBootstrapScreen ',
        gateStart,
      );

      expect(gateStart, greaterThanOrEqualTo(0));
      expect(gateEnd, greaterThan(gateStart));
      final gate = source.substring(gateStart, gateEnd);
      expect(source, contains('_PendingApprovalRecoveryGate(appUser: user)'));
      expect(gate, contains('claimedRecoveryOnly: true'));
      expect(gate, contains('return const PendingApprovalScreen()'));
      expect(gate, isNot(contains('_StartupSyncGate')));
      expect(gate, isNot(contains('HomeScreen')));
    },
  );

  test('approved scope is role-order stable and identity bound', () {
    final first = NavigationAuthorityScope.fromProfile(
      authenticatedUid: 'operator-1',
      profileUid: 'operator-1',
      isApproved: true,
      roles: const <String>['operations', 'shiftSupervisor'],
    );
    final reordered = NavigationAuthorityScope.fromProfile(
      authenticatedUid: 'operator-1',
      profileUid: 'operator-1',
      isApproved: true,
      roles: const <String>['shiftSupervisor', 'operations'],
    );
    final changedRole = NavigationAuthorityScope.fromProfile(
      authenticatedUid: 'operator-1',
      profileUid: 'operator-1',
      isApproved: true,
      roles: const <String>['operations'],
    );

    expect(first.navigatorKey, reordered.navigatorKey);
    expect(first.navigatorKey, isNot(changedRole.navigatorKey));
    expect(first.navigatorKey, contains('operator-1'));
    expect(first.navigatorKey, isNot(contains('Operator One')));
  });

  test('profile identity mismatch fails into a non-approved scope', () {
    final scope = NavigationAuthorityScope.fromProfile(
      authenticatedUid: 'operator-1',
      profileUid: 'different-user',
      isApproved: true,
      roles: const <String>['admin'],
    );

    expect(scope.phase, NavigationAuthorityPhase.profileError);
    expect(scope.navigatorKey, isNot(contains('different-user')));
  });

  testWidgets('approval loss discards every pushed business route', (
    tester,
  ) async {
    final scope = ValueNotifier<NavigationAuthorityScope>(
      NavigationAuthorityScope.fromProfile(
        authenticatedUid: 'operator-1',
        profileUid: 'operator-1',
        isApproved: true,
        roles: const <String>['operations'],
      ),
    );
    addTearDown(scope.dispose);
    await tester.pumpWidget(_AuthorityBoundApp(scope: scope));

    await tester.tap(find.text('Open business screen'));
    await tester.pumpAndSettle();
    expect(find.text('Sensitive business record'), findsOneWidget);

    scope.value = NavigationAuthorityScope.fromProfile(
      authenticatedUid: 'operator-1',
      profileUid: 'operator-1',
      isApproved: false,
      roles: const <String>['operations'],
    );
    await tester.pumpAndSettle();

    expect(find.text('Sensitive business record'), findsNothing);
    expect(find.text('pendingApproval'), findsOneWidget);
  });

  testWidgets('role change dismisses a root business dialog', (tester) async {
    final scope = ValueNotifier<NavigationAuthorityScope>(
      NavigationAuthorityScope.fromProfile(
        authenticatedUid: 'supervisor-1',
        profileUid: 'supervisor-1',
        isApproved: true,
        roles: const <String>['admin'],
      ),
    );
    addTearDown(scope.dispose);
    await tester.pumpWidget(_AuthorityBoundApp(scope: scope));

    await tester.tap(find.text('Open business dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Sensitive edit controls'), findsOneWidget);

    scope.value = NavigationAuthorityScope.fromProfile(
      authenticatedUid: 'supervisor-1',
      profileUid: 'supervisor-1',
      isApproved: true,
      roles: const <String>['operations'],
    );
    await tester.pumpAndSettle();

    expect(find.text('Sensitive edit controls'), findsNothing);
    expect(find.text('approved'), findsOneWidget);
  });
}

class _AuthorityBoundApp extends StatelessWidget {
  const _AuthorityBoundApp({required this.scope});

  final ValueNotifier<NavigationAuthorityScope> scope;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NavigationAuthorityScope>(
      valueListenable: scope,
      builder:
          (context, value, _) => MaterialApp(
            key: ValueKey<String>(value.navigatorKey),
            home: _AuthorityHome(phase: value.phase),
          ),
    );
  }
}

class _AuthorityHome extends StatelessWidget {
  const _AuthorityHome({required this.phase});

  final NavigationAuthorityPhase phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text(phase.name),
          TextButton(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => const Scaffold(
                          body: Text('Sensitive business record'),
                        ),
                  ),
                ),
            child: const Text('Open business screen'),
          ),
          TextButton(
            onPressed:
                () => showDialog<void>(
                  context: context,
                  builder:
                      (_) => const AlertDialog(
                        title: Text('Sensitive edit controls'),
                      ),
                ),
            child: const Text('Open business dialog'),
          ),
        ],
      ),
    );
  }
}
