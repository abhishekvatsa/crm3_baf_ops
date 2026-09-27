import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/presentation/login_screen.dart';
import 'package:crm3_baf_ops/features/auth/presentation/pending_approval_screen.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/services/online_access_gate.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/support/public_help_links.dart';
import 'package:crm3_baf_ops/features/support/public_help_screen.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('public content does not launch or read an account on opening', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _pumpHelp(tester, (uri) async {
      launched.add(uri);
      return true;
    });
    expect(launched, isEmpty);
    await _tap(tester, 'public-privacy-link');
    await _tap(tester, 'public-support-link');
    await _tap(tester, 'public-deletion-link');
    expect(launched, [
      PublicHelpLinks.privacy,
      PublicHelpLinks.support,
      PublicHelpLinks.accountDeletion,
    ]);
    expect(launched.every((uri) => uri.query.isEmpty), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deletion opens a reviewable draft without claiming deletion', (
    tester,
  ) async {
    final launched = <Uri>[];
    await _pumpHelp(tester, (uri) async {
      launched.add(uri);
      return true;
    });
    await _tap(tester, 'public-deletion-email');
    final draft = launched.single;
    expect(draft.scheme, 'mailto');
    expect(draft.path, PublicHelpLinks.email);
    expect(
      draft.queryParameters['subject'],
      'CRM-III BAF Ops account deletion request',
    );
    expect(draft.queryParameters['body'], PublicHelpLinks.deletionRequest);
    expect(draft.toString(), isNot(contains('+')));
    expect(
      find.textContaining('does not send a request or delete anything'),
      findsOneWidget,
    );
    expect(find.text('Account deleted'), findsNothing);
    expect(find.byType(PublicHelpScreen), findsOneWidget);
  });

  for (final throws in [false, true]) {
    testWidgets('email failure ($throws) keeps address and request copyable', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpHelp(tester, (_) async {
        if (throws) throw PlatformException(code: 'no-handler');
        return false;
      });
      await _tap(tester, 'public-deletion-email');
      expect(
        find.textContaining('No request has been sent by this app.'),
        findsOneWidget,
      );
      expect(copied, isEmpty);
      await _tap(tester, 'public-copy-deletion-request');
      await _tap(tester, 'public-copy-email');
      expect(copied, [PublicHelpLinks.deletionRequest, PublicHelpLinks.email]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('browser failure exposes the exact public URL to copy', (
    tester,
  ) async {
    await _pumpHelp(tester, (_) async => false);
    await _tap(tester, 'public-privacy-link');
    expect(find.text(PublicHelpLinks.privacy.toString()), findsOneWidget);
    expect(find.byKey(const Key('public-privacy-link-copy')), findsOneWidget);
  });

  testWidgets('ordinary help navigation preserves an unsent editor', (
    tester,
  ) async {
    final draft = TextEditingController(text: 'Unsent local work');
    addTearDown(draft.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: draft),
                const PublicHelpAccess(),
              ],
            ),
          ),
        ),
      ),
    );
    await _tap(tester, 'public-help-entry');
    expect(find.byType(PublicHelpScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(draft.text, 'Unsent local work');
    expect(find.text('Unsent local work'), findsOneWidget);
  });

  testWidgets(
    'signed-out gate exposes help above Navigator without a profile',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(null)),
            currentAppUserProvider.overrideWith(
              (ref) => throw StateError(
                'Signed-out public help must not read a profile',
              ),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => OnlineAccessGate(child: child!),
            home: const Scaffold(body: Text('Protected saved work')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
      await _tap(tester, 'public-help-entry');
      expect(find.byType(PublicHelpContent), findsOneWidget);
      expect(find.text('Protected saved work'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('access-check help cannot expose or clear the protected draft', (
    tester,
  ) async {
    final draft = TextEditingController(text: 'Retained pending work');
    final launched = <Uri>[];
    addTearDown(draft.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(_User())),
          currentAppUserProvider.overrideWith((ref) => Stream.value(_actor())),
          onlineAccessReaderProvider.overrideWithValue(
            (_) async => throw StateError('Offline'),
          ),
          publicHelpLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return false;
          }),
        ],
        child: MaterialApp(
          builder: (context, child) => OnlineAccessGate(child: child!),
          home: Scaffold(body: TextField(controller: draft)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Online access check required'), findsOneWidget);
    await _tap(tester, 'public-help-entry');
    await _tap(tester, 'public-deletion-email');
    expect(launched, [PublicHelpLinks.deletionEmail]);
    expect(find.text('Retained pending work'), findsNothing);
    expect(
      find.text('Retained pending work', skipOffstage: false),
      findsOneWidget,
    );
    expect(draft.text, 'Retained pending work');
    await _tap(tester, 'public-help-entry');
    expect(find.text('Check access again'), findsOneWidget);
    expect(find.text('Retained pending work'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending and withdrawn access surface exposes public help', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(_SignedOutAuth())],
        child: const MaterialApp(home: PendingApprovalScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Access review required'), findsOneWidget);
    await _tap(tester, 'public-help-entry');
    expect(find.byType(PublicHelpScreen), findsOneWidget);
    expect(find.text('Account deletion request'), findsOneWidget);
  });

  testWidgets('Operations More can open public help without admin permission', (
    tester,
  ) async {
    final actor = _actor();
    expect(actor.isAdmin, isFalse);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: _more(actor))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Privacy & support'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Privacy & support'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicHelpScreen), findsOneWidget);
    expect(find.text('Account deletion request'), findsOneWidget);
  });

  testWidgets('320px large text keeps request actions readable and reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final launched = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicHelpLauncherProvider.overrideWithValue((uri) async {
            launched.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const PublicHelpScreen(),
        ),
      ),
    );
    await _tap(tester, 'public-deletion-email');
    await _tap(tester, 'public-deletion-link');
    expect(launched, [
      PublicHelpLinks.deletionEmail,
      PublicHelpLinks.accountDeletion,
    ]);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHelp(
  WidgetTester tester,
  Future<bool> Function(Uri) launcher,
) => tester.pumpWidget(
  ProviderScope(
    overrides: [publicHelpLauncherProvider.overrideWithValue(launcher)],
    child: const MaterialApp(home: PublicHelpScreen()),
  ),
);

Future<void> _tap(WidgetTester tester, String id) async {
  final finder = find.byKey(ValueKey(id));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _User implements User {
  @override
  String get uid => 'public-help-test-user';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedOutAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AppUser _actor() => AppUser(
  uid: 'public-help-test-user',
  name: 'Public help test',
  email: 'public-help@example.invalid',
  roles: const [AppRole.operations],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

HomeMoreScreen _more(AppUser actor) => HomeMoreScreen(
  appUser: actor,
  onRaiseIssue: () {},
  onIssues: () {},
  onWork: () {},
  onControl: () {},
  onDirectives: () {},
  onMorningReview: () {},
  onWorkflow: () {},
  onAssetRegistry: () {},
  onPlantCondition: () {},
  onAssets: () {},
  onInnerCovers: () {},
  onFurnaceStuckup: () {},
  onClosed: () {},
  onClosedJobs: () {},
  onMaintenanceRhythm: () {},
  onInspectionProgrammes: () {},
  onReports: () {},
  onBurnerReliability: () {},
  onAdmin: () {},
  onAuditLog: () {},
  onAbnormalities: () {},
  onQuality: () {},
  onQualityMonitoring: () {},
  onOperationalEvents: () {},
  onTemplateAuthoring: () {},
  onTemplatePublisher: () {},
  onKnowledgeGovernance: () {},
  onFrequentIssues: () {},
  onLocalDiagnostics: () {},
);
