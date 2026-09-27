import 'dart:async';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/core/services/app_network_access_status.dart';
import 'package:crm3_baf_ops/core/services/sync_coordinator.dart';
import 'package:crm3_baf_ops/core/services/sync_rejection_service.dart';
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final role in [AppRole.si, AppRole.operations]) {
    testWidgets(
      '$role More opens shared health panel and can recheck only with current authority',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final actor = _actor(role: role);
        final ownRowVisible = role == AppRole.si;
        expect(actor.canOpenAdminDataBrowser, isFalse);
        final actors = StreamController<AppUser?>();
        addTearDown(actors.close);
        final coordinator = _Coordinator();
        final own = _rejection(actor.uid, 'my-held-package');
        final other = _rejection('other-user', 'private-other-package');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentAppUserProvider.overrideWith((ref) => actors.stream),
              syncCoordinatorProvider.overrideWithValue(coordinator),
              syncPendingCountsProvider.overrideWith(
                (ref) async => const SyncPendingCounts(templatePackages: 1),
              ),
              recentSyncRejectionsProvider.overrideWith(
                (ref) => Stream.value([other, if (ownRowVisible) own]),
              ),
              unresolvedPermanentSyncRejectionCountProvider.overrideWith(
                (ref) => Stream.value(2),
              ),
              appNetworkAccessProvider.overrideWith(
                (ref) => Stream.value(AppNetworkAccess.allowed),
              ),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                ref.watch(currentAppUserProvider);
                return MaterialApp(home: Scaffold(body: _more(actor)));
              },
            ),
          ),
        );
        actors.add(actor);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Sync health'),
          350,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Sync health'));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        final recheck = find.byKey(const Key('recheck-held-sync-changes'));
        await tester.ensureVisible(recheck);
        await tester.pumpAndSettle();
        final callback = tester.widget<OutlinedButton>(recheck).onPressed!;
        await tester.tap(recheck);
        await tester.pumpAndSettle();
        expect(coordinator.reasons, ['manual_rejection_recheck']);
        expect(coordinator.forced, [true]);
        if (ownRowVisible) {
          await tester.scrollUntilVisible(
            find.text('template_package/my-held-package'),
            220,
            scrollable: find.byType(Scrollable).last,
          );
        }
        expect(find.textContaining('private-other-package'), findsNothing);
        expect(find.text('Review retry hold'), findsNothing);
        expect(find.text('Mark reviewed'), findsNothing);
        actors.add(
          role == AppRole.si
              ? null
              : AppUser(
                  uid: 'replacement',
                  name: 'Replacement',
                  email: 'other@example.invalid',
                  roles: [AppRole.operations],
                  isApproved: true,
                  createdAt: DateTime.utc(2026),
                ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Account verification required'), findsOneWidget);
        callback();
        await tester.pumpAndSettle();
        expect(coordinator.reasons, ['manual_rejection_recheck']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('unapproved More does not expose Sync health', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: _more(_actor(approved: false)))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sync health'), findsNothing);
  });
}

AppUser _actor({bool approved = true, AppRole role = AppRole.si}) => AppUser(
  uid: 'si',
  name: 'SI',
  email: 'si@example.invalid',
  roles: [role],
  isApproved: approved,
  createdAt: DateTime.utc(2026),
);
SyncRejection _rejection(String uid, String id) => SyncRejection()
  ..entityType = 'template_package'
  ..entityId = id
  ..originatingUid = uid
  ..isLikelyPermanent = true
  ..message = 'Rejected package change';

class _Coordinator implements SyncCoordinator {
  final reasons = <String>[];
  final forced = <bool>[];
  @override
  Future<SyncRequestOutcome> runFullSyncWithResult({
    String reason = 'unknown',
    bool force = false,
  }) async {
    reasons.add(reason);
    forced.add(force);
    return SyncRequestOutcome.succeeded;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
