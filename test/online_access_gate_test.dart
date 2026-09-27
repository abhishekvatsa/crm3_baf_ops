import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/presentation/login_screen.dart';
import 'package:crm3_baf_ops/features/auth/services/auth_service.dart';
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
      var profileSubscriptions = 0;
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_SignedInUser()),
          ),
          currentAppUserProvider.overrideWith((ref) {
            profileSubscriptions++;
            return Stream.value(account());
          }),
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
      pending = Completer<AppUser?>();
      await tester.tap(find.text('Check access again'));
      await tester.pump();
      expect(
        profileSubscriptions,
        1,
        reason: 'A server-check failure does not restart a healthy profile.',
      );
      pending.complete(account(server: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Protected saved work'), findsOneWidget);
    },
  );

  testWidgets(
    'initial profile error blocks access and retry restarts its feed',
    (tester) async {
      var profileSubscriptions = 0;
      var serverReads = 0;
      final retriedProfile = StreamController<AppUser?>();
      final checked = Completer<AppUser?>();
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_SignedInUser()),
          ),
          currentAppUserProvider.overrideWith((ref) {
            profileSubscriptions++;
            return profileSubscriptions == 1
                ? Stream<AppUser?>.error(
                    FirebaseException(
                      plugin: 'cloud_firestore',
                      code: 'permission-denied',
                    ),
                  )
                : retriedProfile.stream;
          }),
          onlineAccessReaderProvider.overrideWithValue((_) {
            serverReads++;
            return checked.future;
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await retriedProfile.close();
      });
      await _pumpGate(tester, container);
      expect(tester.takeException(), isNull);
      expect(find.text('Online access check required'), findsOneWidget);
      expect(find.text('Protected saved work'), findsNothing);
      expect(
        find.text('Protected saved work', skipOffstage: false),
        findsOneWidget,
      );
      expect(serverReads, 0);

      await tester.tap(find.text('Check access again'));
      await tester.pump();
      await tester.pump();
      expect(profileSubscriptions, 2);
      expect(find.text('Protected saved work'), findsNothing);
      retriedProfile.add(account());
      await tester.pump();
      await tester.pump();
      expect(serverReads, 1);
      expect(find.text('Protected saved work'), findsNothing);
      checked.complete(account(server: true));
      await tester.pump();
      await tester.pump();
      expect(find.text('Protected saved work'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported accessDisposition remains recoverable after corrected server proof',
    (tester) async {
      var corrected = false;
      var profileSubscriptions = 0;
      var serverReads = 0;
      final checked = Completer<AppUser?>();
      Map<String, dynamic> wire() => {
        ...account().toFirestore(),
        'accessDisposition': corrected ? 'approved' : 'unsupported-value',
      };
      AppUser decode(Map<String, dynamic> data) => AppUser.fromFirestore(
        data,
        'user',
        fromCache: false,
        observedAt: DateTime.utc(2026, 9, 27),
      );
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(_SignedInUser()),
          ),
          currentAppUserProvider.overrideWith((ref) {
            profileSubscriptions++;
            return Stream.value(wire()).map(decode);
          }),
          onlineAccessReaderProvider.overrideWithValue((uid) {
            expect(uid, 'user');
            serverReads++;
            return checked.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      await _pumpGate(tester, container);
      expect(
        container.read(currentAppUserProvider).error,
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('access disposition'),
        ),
      );
      expect(find.text('Protected saved work'), findsNothing);
      expect(find.text('Check access again'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(serverReads, 0);
      expect(tester.takeException(), isNull);

      corrected = true;
      await tester.tap(find.text('Check access again'));
      await tester.pump();
      await tester.pump();
      expect(profileSubscriptions, 2);
      expect(serverReads, 1);
      expect(find.text('Protected saved work'), findsNothing);
      expect(
        find.text('Protected saved work', skipOffstage: false),
        findsOneWidget,
      );
      checked.complete(decode(wire()));
      await tester.pump();
      await tester.pump();
      expect(find.text('Protected saved work'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile error conceals a retained approved actor and editor', (
    tester,
  ) async {
    final profiles = StreamController<AppUser?>();
    final nextCheck = Completer<AppUser?>();
    final editor = TextEditingController();
    final focus = FocusNode();
    var serverReads = 0;
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_SignedInUser())),
        currentAppUserProvider.overrideWith((ref) => profiles.stream),
        onlineAccessReaderProvider.overrideWithValue((_) {
          serverReads++;
          return serverReads == 1
              ? Future.value(account(server: true))
              : nextCheck.future;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await profiles.close();
      editor.dispose();
      focus.dispose();
    });
    final approved = account();
    profiles.add(approved);
    await _pumpGate(
      tester,
      container,
      editor: TextField(controller: editor, focusNode: focus),
    );
    expect(find.text('Protected saved work'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'Unsent inspection evidence',
    );
    profiles.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await tester.pump();
    await tester.pump();
    expect(container.read(currentAppUserProvider).hasError, isTrue);
    expect(container.read(currentAppUserProvider).valueOrNull, same(approved));
    expect(tester.takeException(), isNull);
    expect(find.text('Protected saved work'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextField, skipOffstage: false), findsOneWidget);
    expect(focus.hasFocus, isFalse);
    expect(editor.text, 'Unsent inspection evidence');
    expect(
      serverReads,
      1,
      reason: 'A retained actor cannot start another access check.',
    );

    profiles.add(account(revision: 2));
    await tester.pump();
    await tester.pump();
    expect(find.text('Protected saved work'), findsNothing);
    nextCheck.complete(account(server: true, revision: 2));
    await tester.pump();
    await tester.pump();
    expect(find.text('Protected saved work'), findsOneWidget);
    expect(editor.text, 'Unsent inspection evidence');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile refresh conceals a retained actor until new proof', (
    tester,
  ) async {
    final refreshedProfile = StreamController<AppUser?>();
    final nextCheck = Completer<AppUser?>();
    var profileSubscriptions = 0;
    var serverReads = 0;
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_SignedInUser())),
        currentAppUserProvider.overrideWith((ref) {
          profileSubscriptions++;
          return profileSubscriptions == 1
              ? Stream.value(account())
              : refreshedProfile.stream;
        }),
        onlineAccessReaderProvider.overrideWithValue((_) {
          serverReads++;
          return serverReads == 1
              ? Future.value(account(server: true))
              : nextCheck.future;
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await refreshedProfile.close();
    });
    await _pumpGate(tester, container);
    expect(find.text('Protected saved work'), findsOneWidget);
    container.invalidate(currentAppUserProvider);
    await tester.pump();
    await tester.pump();
    expect(container.read(currentAppUserProvider).isLoading, isTrue);
    expect(container.read(currentAppUserProvider).valueOrNull, isNotNull);
    expect(find.text('Protected saved work'), findsNothing);
    expect(
      find.text('Protected saved work', skipOffstage: false),
      findsOneWidget,
    );
    expect(serverReads, 1);

    refreshedProfile.add(account());
    await tester.pump();
    await tester.pump();
    expect(find.text('Protected saved work'), findsNothing);
    nextCheck.complete(account(server: true));
    await tester.pump();
    await tester.pump();
    expect(find.text('Protected saved work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settled sign-out reveals login despite a retained profile error',
    (tester) async {
      final sessions = StreamController<User?>();
      final profiles = StreamController<AppUser?>();
      var serverReads = 0;
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => sessions.stream),
          currentAppUserProvider.overrideWith((ref) => profiles.stream),
          onlineAccessReaderProvider.overrideWithValue((_) async {
            serverReads++;
            return account(server: true);
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await sessions.close();
        await profiles.close();
      });
      container.listen(authStateProvider, (_, _) {});
      sessions.add(_SignedInUser());
      profiles.add(account());
      await _pumpGate(tester, container);
      expect(find.text('Protected saved work'), findsOneWidget);

      profiles.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Protected saved work'), findsNothing);
      expect(find.text('Online access check required'), findsOneWidget);

      sessions.add(null);
      await tester.pump();
      await tester.pump();
      expect(container.read(currentAppUserProvider).hasError, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Online access check required'), findsNothing);
      expect(
        find.text('Protected saved work', skipOffstage: false),
        findsNothing,
      );
      expect(serverReads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirmed sign-out keeps login locked until cleanup finishes', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        currentAppUserProvider.overrideWith((ref) => Stream.value(account())),
        signOutInProgressProvider.overrideWith((ref) => true),
        onlineAccessReaderProvider.overrideWithValue((_) async {
          fail(
            'Signed-out cleanup must not request access for a stale profile.',
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await _pumpGate(tester, container);
    expect(find.text('Signing out'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(
      find.text('Protected saved work', skipOffstage: false),
      findsNothing,
    );
    container.read(signOutInProgressProvider.notifier).state = false;
    await tester.pump();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Protected saved work', skipOffstage: false),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final uncertainAuth in ['loading', 'error']) {
    testWidgets('$uncertainAuth auth session does not bypass a profile error', (
      tester,
    ) async {
      final sessions = StreamController<User?>();
      var serverReads = 0;
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => sessions.stream),
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.error(
              FirebaseException(
                plugin: 'cloud_firestore',
                code: 'permission-denied',
              ),
            ),
          ),
          onlineAccessReaderProvider.overrideWithValue((_) async {
            serverReads++;
            return account(server: true);
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await sessions.close();
      });
      container.listen(authStateProvider, (_, _) {});
      if (uncertainAuth == 'error') {
        sessions.addError(StateError('Auth session unavailable'));
      }
      await _pumpGate(tester, container);
      expect(find.text('Online access check required'), findsOneWidget);
      expect(find.text('Protected saved work'), findsNothing);
      expect(serverReads, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpGate(
  WidgetTester tester,
  ProviderContainer container, {
  Widget? editor,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: OnlineAccessGate(
          child: Scaffold(
            body: Column(
              children: [
                const Text('Protected saved work'),
                if (editor != null) editor,
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

class _SignedInUser extends Fake implements User {
  @override
  String get uid => 'user';
}
