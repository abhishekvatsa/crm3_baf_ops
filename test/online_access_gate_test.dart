import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/services/online_access_gate.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';

AppUser account({
  String uid = 'user',
  bool approved = true,
  bool server = false,
  int revision = 1,
}) => AppUser(
  uid: uid,
  name: 'User',
  email: 'user@test.local',
  roles: const [AppRole.operations],
  isApproved: approved,
  authorityRevision: revision,
  createdAt: DateTime.utc(2026),
  authorityFromCache: !server,
  authorityObservedAt: server ? DateTime.utc(2026) : null,
);
void main() {
  test('only matching server-confirmed approved authority can unlock', () {
    expect(onlineAccessMatches(account(), account()), false);
    expect(onlineAccessMatches(account(), account(server: true)), true);
    expect(
      onlineAccessMatches(account(), account(server: true, approved: false)),
      false,
    );
    expect(
      onlineAccessMatches(account(), account(server: true, uid: 'other')),
      false,
    );
    expect(
      onlineAccessMatches(account(), account(server: true, revision: 2)),
      false,
    );
  });
  testWidgets(
    'offline startup and foreground recheck conceal saved work until proof arrives',
    (tester) async {
      var pending = Completer<AppUser?>();
      final container = ProviderContainer(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => Stream.value(account())),
          onlineAccessReaderProvider.overrideWithValue((_) => pending.future),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OnlineAccessGate(
              child: Scaffold(body: Text('Protected saved work')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Online access check required'), findsOneWidget);
      expect(find.text('Protected saved work'), findsNothing);
      pending.complete(account(server: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Protected saved work'), findsOneWidget);
      container.read(accessSessionBackgroundedProvider.notifier).state = true;
      await tester.pump();
      expect(find.text('Protected saved work'), findsNothing);
      pending = Completer<AppUser?>();
      container.invalidate(onlineAccessCheckProvider);
      container.read(accessSessionBackgroundedProvider.notifier).state = false;
      await tester.pump();
      expect(find.text('Protected saved work'), findsNothing);
      pending.completeError(StateError('offline'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Check access again'), findsOneWidget);
      expect(find.text('Protected saved work'), findsNothing);
      // The mounted subtree (and editor state) has not been deleted.
      expect(
        find.text('Protected saved work', skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}
