import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:crm3_baf_ops/core/providers/sync_status_provider.dart';
import 'package:crm3_baf_ops/core/release/app_build_identity.dart';
import 'package:crm3_baf_ops/core/release/backend_release_identity_service.dart';
import 'package:crm3_baf_ops/core/services/isar_installed_store_provenance.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/features/admin/presentation/local_diagnostics_screen.dart';
import 'package:crm3_baf_ops/features/admin/services/local_diagnostics_read_adapter.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matching identifiers never display deployment parity', (
    tester,
  ) async {
    const snapshot = LocalReleaseDiagnosticsSnapshot(
      build: AppBuildIdentity(
        appVersion: '1.0.0',
        buildNumber: '31',
        gitCommit: 'client-source-sentinel',
        releaseTag: 'candidate',
        releaseChannel: 'test',
        ciRunId: 'test-run',
        buildTimestampUtc: '2026-10-01T00:00:00Z',
        releaseId: 'client-release-sentinel',
        expectedBackendReleaseId: 'backend-release-sentinel',
        sourceArchiveSha256: 'client-archive-sentinel',
      ),
      backend: BackendReleaseIdentity(
        releaseId: 'backend-release-sentinel',
        firebaseProjectId: 'different-project-sentinel',
        environment: 'different-environment-sentinel',
        gitCommit: 'different-backend-source-sentinel',
        functionsDigest: 'wrong-functions-digest-sentinel',
      ),
    );
    final h = _Harness(releaseSnapshot: snapshot);
    addTearDown(h.close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const MaterialApp(home: LocalDiagnosticsScreen()),
      ),
    );
    h.profiles.add(_actor());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Deployment identity'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Release identifier comparison'), findsOneWidget);
    expect(find.text('identifier matches'), findsOneWidget);
    expect(find.text('Not verified by this screen'), findsOneWidget);
    expect(find.text('Backend parity'), findsNothing);
    expect(
      h.report.toClipboardText(),
      contains('backendReleaseIdComparison: identifier matches'),
    );
    expect(
      h.report.toRecoveryManifestJsonText(),
      contains('"backendDeploymentIdentity": "unverified"'),
    );
    expect(
      h.report.toRecoveryManifestJsonText(),
      contains('"backendParityConfirmed": false'),
    );
    expect(h.remote.requests, isEmpty);
  });

  test(
    'local counts and export settle before a pending or failed backend',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.profile(_actor());
      final report = h.report;
      expect(report.rows.single.totalCount, 37);
      expect(report.totalUnsyncedRows, 2);
      expect(report.releaseSnapshot.backendLoading, isTrue);
      expect(report.toClipboardText(), contains('totalUnsyncedRows: 2'));
      expect(
        report.toClipboardText(),
        contains('backendIdentityStatus: checking'),
      );
      expect(
        report.toRecoveryManifestJsonText(),
        contains('"backendParityConfirmed": false'),
      );
      h.remote.requests.single.completeError(
        const BackendReleaseIdentityException(
          code: 'unauthenticated',
          message: 'Unauthenticated',
        ),
      );
      await h.flush();
      expect(h.report.rows.single.totalCount, 37);
      expect(h.report.generatedAt, report.generatedAt);
      expect(h.report.releaseSnapshot.backendErrorCode, 'unauthenticated');
      expect(h.report.toClipboardText(), contains('installation or sign-in'));
      expect(h.local.reads, 1);
    },
  );

  test(
    'equivalent token/profile and sync events do not restart either read',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.profile(_actor());
      for (var i = 0; i < 12; i++) {
        // Fresh model instances represent profile events after token refresh.
        await h.profile(_actor(observedAt: DateTime.utc(2026, 9, 29, 16, i)));
        h.container.read(syncStatusProvider.notifier).state = i.isEven
            ? SyncStatus.syncing
            : SyncStatus.failed;
        h.container.read(syncRunHealthProvider.notifier).state = SyncRunHealth(
          isRunning: i.isEven,
          lastReason: 'test-$i',
        );
        await h.flush();
      }
      expect(h.remote.requests, hasLength(1));
      expect(h.local.reads, 1);
      expect(h.report.supportSnapshot.syncLastReason, 'test-11');
      h.remote.requests.single.completeError(
        const BackendReleaseIdentityException(
          code: 'unauthenticated',
          message: 'Unauthenticated',
        ),
      );
      await h.flush();
      await h.profile(_actor());
      expect(h.remote.requests, hasLength(1));
      expect(h.report.releaseSnapshot.backendLoading, isFalse);
    },
  );

  test(
    'an explicit refresh creates one new read after a settled failure',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.profile(_actor());
      h.remote.requests.single.completeError(
        const BackendReleaseIdentityException(
          code: 'unavailable',
          message: 'offline',
        ),
      );
      await h.flush();
      h.container.invalidate(localDiagnosticsInventoryProvider);
      h.container.invalidate(localDiagnosticsBackendIdentityProvider);
      await h.flush();
      expect(h.local.reads, 2);
      expect(h.remote.requests, hasLength(2));
      expect(h.report.totalUnsyncedRows, 2);
      expect(h.report.releaseSnapshot.backendLoading, isTrue);
    },
  );

  test(
    'revocation and sign-out hide retained data and reject late responses',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.profile(_actor());
      expect(h.report.rows.single.totalCount, 37);
      await h.profile(_actor(roles: const [AppRole.operations], revision: 2));
      expect(h.container.read(localDiagnosticsReportProvider).hasError, isTrue);
      expect(
        h.container.read(localDiagnosticsReportProvider).valueOrNull,
        isNull,
      );
      h.remote.requests.single.complete(_identity('obsolete'));
      await h.flush();
      expect(
        h.container.read(localDiagnosticsReportProvider).valueOrNull,
        isNull,
      );
      await h.profile(null);
      expect(
        h.container.read(localDiagnosticsReportProvider).valueOrNull,
        isNull,
      );
      expect(h.local.reads, 1);
      expect(h.remote.requests, hasLength(1));
    },
  );

  test(
    'a profile error conceals retained inventory until fresh authority arrives',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.profile(_actor());
      expect(h.report.totalUnsyncedRows, 2);
      h.profiles.addError(StateError('Profile could not be verified'));
      await h.flush();
      expect(h.container.read(localDiagnosticsReportProvider).hasError, isTrue);
      expect(
        h.container.read(localDiagnosticsReportProvider).valueOrNull,
        isNull,
      );
      h.remote.requests.single.complete(_identity('before-profile-error'));
      await h.flush();
      expect(
        h.container.read(localDiagnosticsReportProvider).valueOrNull,
        isNull,
      );
      await h.profile(_actor());
      expect(h.report.releaseSnapshot.backend, isNull);
      expect(h.report.releaseSnapshot.backendLoading, isTrue);
      expect(h.remote.requests, hasLength(2));
      expect(h.local.reads, 2);
    },
  );

  test(
    'account and authority changes replace remote state without stale results',
    () async {
      final h = _Harness();
      addTearDown(h.close);
      await h.profile(_actor());
      final old = h.remote.requests.single;
      await h.profile(_actor(uid: 'other'));
      expect(h.remote.requests, hasLength(2));
      expect(h.report.releaseSnapshot.backend, isNull);
      old.complete(_identity('old-account'));
      await h.flush();
      expect(h.report.releaseSnapshot.backend, isNull);
      h.remote.requests.last.complete(_identity('current-account'));
      await h.flush();
      expect(h.report.releaseSnapshot.backend!.releaseId, 'current-account');
      await h.profile(
        _actor(uid: 'other', revision: 2, roles: const [AppRole.si]),
      );
      expect(h.remote.requests, hasLength(3));
      expect(h.report.releaseSnapshot.backend, isNull);
      expect(h.local.reads, 3);
    },
  );

  testWidgets(
    'disabled-build identity leaves local diagnostics and export usable',
    (tester) async {
      final functions = _NoRequestFunctions();
      final auth = _SignedInAuth();
      final h = _Harness(
        backendService: BackendReleaseIdentityService(
          functions: functions,
          auth: auth,
          appCheckEnabled: false,
          useEmulators: false,
        ),
      );
      addTearDown(h.close);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = call.arguments['text'] as String;
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
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: const MaterialApp(home: LocalDiagnosticsScreen()),
        ),
      );
      h.profiles.add(_actor());
      await tester.pumpAndSettle();
      expect(h.report.rows.single.totalCount, 37);
      expect(h.report.totalUnsyncedRows, 2);
      expect(h.report.releaseSnapshot.backendErrorCode, 'app-check-disabled');
      expect(h.report.releaseSnapshot.backendLoading, isFalse);
      expect(h.report.releaseSnapshot.backendParityConfirmed, isFalse);
      await tester.scrollUntilVisible(
        find.textContaining('not available in this build'),
        500,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.textContaining('not available in this build'),
        findsOneWidget,
      );
      expect(find.byTooltip('Diagnostics actions'), findsOneWidget);
      await tester.tap(find.byTooltip('Diagnostics actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy diagnostics'));
      await tester.pumpAndSettle();
      expect(copied, contains('totalUnsyncedRows: 2'));
      expect(copied, contains('backendIdentityErrorCode: app-check-disabled'));
      expect(copied, contains('not available in this build'));
      expect(copied, isNot(contains('Check connectivity and retry')));
      expect(
        h.report.toRecoveryManifestJsonText(),
        contains('"backendParityConfirmed": false'),
      );
      await tester.tap(find.byTooltip('Refresh diagnostics'));
      await tester.pumpAndSettle();
      expect(h.local.reads, 2);
      expect(functions.requests, 0);
      expect(auth.user.refreshes, 0);
    },
  );

  testWidgets('copy diagnostics works while remote identity is still pending', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.close);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: const MaterialApp(home: LocalDiagnosticsScreen()),
      ),
    );
    h.profiles.add(_actor());
    await tester.pump();
    await tester.pump();
    expect(find.text('Reading local diagnostics'), findsNothing);
    expect(find.byTooltip('Diagnostics actions'), findsOneWidget);
    await tester.tap(find.byTooltip('Diagnostics actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy diagnostics'));
    await tester.pumpAndSettle();
    expect(copied, contains('totalUnsyncedRows: 2'));
    expect(copied, contains('backendIdentityStatus: checking'));
    expect(h.remote.requests, hasLength(1));
    h.profiles.add(_actor(roles: const [AppRole.operations]));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Diagnostics actions'), findsNothing);
    expect(find.text('Admin/SI access required'), findsOneWidget);
  });
}

AppUser _actor({
  String uid = 'owner',
  int revision = 1,
  List<AppRole> roles = const [AppRole.admin],
  DateTime? observedAt,
}) => AppUser(
  uid: uid,
  name: 'Test',
  email: 'test@example.invalid',
  roles: roles,
  isApproved: true,
  authorityRevision: revision,
  createdAt: DateTime.utc(2026),
  authorityFromCache: false,
  authorityObservedAt: observedAt ?? DateTime.utc(2026),
);

BackendReleaseIdentity _identity(String release) => BackendReleaseIdentity(
  releaseId: release,
  firebaseProjectId: 'test-project',
  environment: 'test',
);

class _Harness {
  final BackendReleaseIdentityService? backendService;
  final LocalReleaseDiagnosticsSnapshot? releaseSnapshot;
  final profiles = StreamController<AppUser?>.broadcast();
  final local = _LocalReader();
  final remote = _RemoteReader();
  late final ProviderContainer container = ProviderContainer(
    overrides: [
      currentAppUserProvider.overrideWith((ref) => profiles.stream),
      localDiagnosticsReadAdapterProvider.overrideWithValue(local),
      backendReleaseIdentityServiceProvider.overrideWithValue(
        backendService ?? remote,
      ),
      if (releaseSnapshot != null)
        localDiagnosticsBackendIdentityProvider.overrideWith(
          (ref) async => releaseSnapshot!,
        ),
    ],
  );
  late final ProviderSubscription<AsyncValue<LocalDiagnosticsReport>>
  subscription;
  _Harness({this.backendService, this.releaseSnapshot}) {
    subscription = container.listen(
      localDiagnosticsReportProvider,
      (_, _) {},
      fireImmediately: true,
    );
  }
  LocalDiagnosticsReport get report =>
      container.read(localDiagnosticsReportProvider).requireValue;
  Future<void> profile(AppUser? actor) async {
    profiles.add(actor);
    await flush();
  }

  Future<void> flush() async {
    await Future<void>.delayed(Duration.zero);
    await container.pump();
    if (container.read(localDiagnosticsAuthorityProvider) != null) {
      // Settle only the local inventory; remote identity intentionally remains
      // pending in these cases, so awaiting the composed report would hide the
      // original dependency defect.
      await container.read(localDiagnosticsInventoryProvider.future);
      await container.pump();
    }
  }

  Future<void> close() async {
    subscription.close();
    container.dispose();
    await profiles.close();
  }
}

class _RemoteReader extends BackendReleaseIdentityService {
  final requests = <Completer<BackendReleaseIdentity>>[];
  @override
  Future<BackendReleaseIdentity> fetch() {
    final request = Completer<BackendReleaseIdentity>();
    requests.add(request);
    return request.future;
  }
}

class _LocalReader extends LocalDiagnosticsReadAdapter {
  int reads = 0;
  @override
  Future<LocalDiagnosticsPersistenceSnapshot> read() async {
    reads++;
    return LocalDiagnosticsPersistenceSnapshot(
      rows: const [
        LocalDiagnosticsCollectionSnapshot(
          label: 'Maintenance tickets',
          totalCount: 37,
          unsyncedCount: 2,
        ),
      ],
      unresolvedRejections: 1,
      likelyPermanentRejections: 0,
      totalRejections: 1,
      knowledgeMetaRows: 0,
      commandJournal: const LocalDiagnosticsCommandJournalSnapshot(
        ready: 1,
        sending: 0,
        uncertainOutcome: 3,
        manualReview: 1,
        applied: 7,
        rejected: 2,
        total: 14,
      ),
      governance: const LocalDiagnosticsGovernanceSnapshot(
        activePackages: 1,
        retiredPackages: 0,
        archivedPackages: 0,
        publishedVersions: 1,
        draftVersions: 0,
        retiredVersions: 0,
        archivedVersions: 0,
        publishAuditRows: 1,
      ),
      provenanceInventory: IsarInstalledStoreProvenanceInventory.unsupported(),
    );
  }
}

class _NoRequestFunctions extends Fake implements FirebaseFunctions {
  int requests = 0;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    requests++;
    throw StateError('Disabled-build diagnostics must not create a callable.');
  }
}

class _SignedInAuth extends Fake implements FirebaseAuth {
  final user = _SignedInUser();
  @override
  User get currentUser => user;
}

class _SignedInUser extends Fake implements User {
  int refreshes = 0;
  @override
  String get uid => 'owner';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    refreshes++;
    throw StateError('Disabled-build diagnostics must not refresh a token.');
  }
}
