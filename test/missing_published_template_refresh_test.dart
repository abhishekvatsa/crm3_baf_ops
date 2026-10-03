import 'dart:async';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/template_publication_readiness.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/missing_published_template_refresh.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_active_version_refresh_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/template_active_version_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    _Refresh? refresh, {
    Stream<AppUser?>? actors,
  }) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => actors ?? Stream.value(_actor),
          ),
          templateActiveVersionRefreshProvider.overrideWithValue(refresh),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  MissingPublishedTemplateRefresh(
                    key: ValueKey('si-package-version'),
                    actorUid: 'si',
                    packageId: 'package',
                    versionId: 'old-active',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '320dp enlarged text explains missing copy without implying republication',
    (tester) async {
      await mount(tester, _Refresh());
      expect(find.textContaining('saved copy is missing'), findsOneWidget);
      expect(find.text('Refresh published catalogue'), findsOneWidget);
      expect(find.textContaining('Publish a valid'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('repeat taps are disabled until result; exact ids passed', (
    tester,
  ) async {
    final refresh = _Refresh();
    await mount(tester, refresh);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    expect(refresh.calls, 1);
    expect(refresh.request, ('package', 'old-active'));
    refresh.result.complete(
      const TemplatePublicationReadinessDecision(
        code: TemplatePublicationReadinessCode.ready,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Published catalogue restored'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'denied evidence leaves saved-work guidance and allows deliberate retry',
    (tester) async {
      final refresh = _Refresh();
      await mount(tester, refresh);
      await tester.tap(find.byType(OutlinedButton));
      refresh.result.completeError(
        const TemplateActiveVersionRefreshException(
          'Saved work is retained. Ask an administrator.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved work is retained'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('network failure does not expose raw errors or claim recovery', (
    tester,
  ) async {
    final refresh = _Refresh();
    await mount(tester, refresh);
    await tester.tap(find.byType(OutlinedButton));
    refresh.result.completeError(StateError('private transport data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.textContaining('private transport data'), findsNothing);
    expect(find.textContaining('Published catalogue restored'), findsNothing);
  });
  testWidgets('account change hides stale result and unavailable action', (
    tester,
  ) async {
    final stream = StreamController<AppUser?>();
    addTearDown(stream.close);
    final refresh = _Refresh();
    await mount(tester, refresh, actors: stream.stream);
    stream.add(_actor);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(OutlinedButton));
    stream.add(null);
    await tester.pumpAndSettle();
    refresh.result.complete(
      const TemplatePublicationReadinessDecision(
        code: TemplatePublicationReadinessCode.ready,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.textContaining('Published catalogue restored'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('navigation away during refresh safely disposes result', (
    tester,
  ) async {
    final refresh = _Refresh();
    await mount(tester, refresh);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpWidget(const SizedBox());
    refresh.result.complete(
      const TemplatePublicationReadinessDecision(
        code: TemplatePublicationReadinessCode.ready,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'unsupported local cache path offers review without unusable refresh',
    (tester) async {
      await mount(tester, null);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.textContaining('Ask an administrator'), findsOneWidget);
    },
  );
}

final _actor = AppUser(
  uid: 'si',
  name: 'SI',
  email: 'si@example.invalid',
  roles: [AppRole.si],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _Refresh extends TemplateActiveVersionRefresh {
  _Refresh()
    : super(
        actor: () => null,
        remote: _UnusedRemote(),
        localPackages: () async => [],
        localVersion: (_) async => null,
        localAudits: (_) async => [],
        apply: (_, _) => throw UnimplementedError(),
      );
  final result = Completer<TemplatePublicationReadinessDecision>();
  int calls = 0;
  (String, String)? request;
  @override
  Future<TemplatePublicationReadinessDecision> refresh({
    required String packageId,
    required String versionId,
  }) {
    calls++;
    request = (packageId, versionId);
    return result.future;
  }
}

class _UnusedRemote implements TemplateActiveVersionRemoteReader {
  @override
  Future<TemplatePackage> package(String id) => throw UnimplementedError();
  @override
  Future<TemplateVersion> version(String id) => throw UnimplementedError();
  @override
  Future<List<TemplatePublishAudit>> audits(String id) =>
      throw UnimplementedError();
}
