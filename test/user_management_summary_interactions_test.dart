import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/admin/presentation/user_management_screen.dart';
import 'package:crm3_baf_ops/features/admin/providers/user_authority_durable_command_provider.dart';
import 'package:crm3_baf_ops/features/admin/providers/user_directory_provider.dart';
import 'package:crm3_baf_ops/features/admin/repositories/user_directory_repository.dart';
import 'package:crm3_baf_ops/features/admin/services/user_authority_durable_command_controller.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
  for (final filter in ['all', 'pending', 'approved', 'withdrawn']) {
    testWidgets('$filter count selects exactly that directory population', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      try {
        await _open(tester);
        final chip = find.byKey(ValueKey('user-summary-$filter'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        for (final kind in ['pending', 'approved', 'withdrawn']) {
          expect(
            find.text('$kind person'),
            filter == 'all' || filter == kind ? findsOneWidget : findsNothing,
          );
        }
        expect(tester.widget<FilterChip>(chip).selected, isTrue);
        expect(
          tester
              .getSemantics(chip)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets(
    'zero directory filter stays actionable and preserves incomplete warnings at large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _open(
        tester,
        scale: 2,
        users: UserDirectoryPopulation(
          [_user('approved', approved: true)],
          ['unreadable-profile'],
          fromCache: true,
          hasPendingWrites: false,
        ),
      );
      final chip = find.byKey(const ValueKey('user-summary-withdrawn'));
      await tester.scrollUntilVisible(
        chip,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('0 Withdrawn'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No withdrawn users'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No withdrawn users'), findsOneWidget);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.textContaining('Incomplete directory:'), findsOneWidget);
      expect(find.textContaining('not server-confirmed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('non-admin cannot read the directory through count filters', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(_user('operator', approved: true)),
          ),
          allUsersProvider.overrideWith((ref) {
            reads++;
            throw StateError('Forbidden roster read');
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: UserManagementScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 0);
    expect(find.text('Admin access required'), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets(
    'authority refresh hides the directory even with retained Admin data',
    (tester) async {
      final actors = StreamController<AppUser?>.broadcast();
      addTearDown(actors.close);
      await _open(tester, actors: actors.stream);
      actors.add(_admin());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('user-summary-all')), findsOneWidget);
      ProviderScope.containerOf(
        tester.element(find.byType(UserManagementScreen)),
      ).invalidate(currentAppUserProvider);
      await tester.pump();
      await tester.pump();
      expect(find.text('Checking user-management authority'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  List<AppUser>? users,
  double scale = 1,
  Stream<AppUser?>? actors,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => actors ?? Stream.value(_admin()),
        ),
        allUsersProvider.overrideWith(
          (ref) => Stream.value(
            users ??
                [
                  _user('pending', approved: false),
                  _user('approved', approved: true),
                  _user('withdrawn', approved: false),
                ],
          ),
        ),
        userAuthorityDurableCommandControllerProvider.overrideWithValue(
          _SavedDecisions(),
        ),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: UserManagementScreen()),
      ),
    ),
  );
  await tester.pump();
  if (actors == null) await tester.pumpAndSettle();
}

AppUser _admin() => AppUser(
  uid: 'admin',
  name: 'Admin',
  email: 'admin@example.invalid',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
AppUser _user(String kind, {required bool approved}) => AppUser(
  uid: kind,
  name: '$kind person',
  email: '$kind@example.invalid',
  roles: [AppRole.operations],
  isApproved: approved,
  accessDisposition: kind == 'pending'
      ? 'pending'
      : kind == 'withdrawn'
      ? 'withdrawn'
      : 'approved',
  createdAt: DateTime.utc(2026),
);

class _SavedStore extends Fake implements DurableSubmissionRepository {
  @override
  Stream<List<DurableSubmission>> watchForActor(String uid) =>
      Stream.value(const []);
}

class _SavedDecisions extends Fake
    implements UserAuthorityDurableCommandController {
  @override
  DurableSubmissionRepository get store => _SavedStore();
  @override
  Future<List<DurableSubmission>> listForCurrentActor() async => const [];
}
