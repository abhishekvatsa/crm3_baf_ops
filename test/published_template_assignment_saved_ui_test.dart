import 'dart:async';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/domain/current_actor_access.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/saved_published_assignment_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_idempotency_store.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_server_service.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/published_template_assignment_submission_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/test_support/in_memory_durable_submission_store.dart';

void main() {
  late InMemoryDurableSubmissionStore store;
  late PublishedTemplateAssignmentSubmissionController controller;
  late ProviderContainer container;
  late StreamController<AppUser?> accounts;
  late _UncertainServer server;
  late DurableSubmission saved;
  AppUser manager([String uid = 'assigner-1']) => AppUser(
    uid: uid,
    name: 'Manager',
    email: '$uid@example.test',
    roles: const [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = InMemoryDurableSubmissionStore();
    server = _UncertainServer();
    accounts = StreamController<AppUser?>();
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith((ref) => accounts.stream),
        publishedTemplateAssignmentSubmissionControllerProvider.overrideWith(
          (ref) => controller,
        ),
      ],
    );
    controller = PublishedTemplateAssignmentSubmissionController(
      store: store,
      server: server,
      legacy: PublishedTemplateAssignmentIdempotencyStore(),
      requireActor: () {
        final access = CurrentActorAccess.resolve(
          container.read(currentAppUserProvider),
        );
        if (!access.isReady) throw StateError('Account unverified');
        return access.actor!;
      },
      requireCapability: (_) async {},
    );
    container.listen(currentAppUserProvider, (_, _) {});
    accounts.add(manager());
    await container.read(currentAppUserProvider.future);
    saved = await controller.prepare(
      originActorUid: 'assigner-1',
      request: const PublishedTemplateAssignmentRequest(
        requestId: '11111111-1111-4111-8111-111111111111',
        packageFirestoreId: 'package-1',
        versionFirestoreId: 'version-1',
        expectedVersionNumber: 1,
        expectedContentHash: 'hash-1',
        assetType: AssetType.base,
        assetNumber: 101,
        remarks: 'Original shift inspection',
      ),
    );
  });
  tearDown(() async {
    container.dispose();
    await accounts.close();
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SavedPublishedAssignmentScreen(submission: saved),
                    ),
                  ),
                  child: const Text('Open saved assignment'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open saved assignment'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'reopening saved entries does not send; explicit retry preserves the same envelope',
    (tester) async {
      await show(tester);
      expect(find.text('Remarks: Original shift inspection'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(server.envelopes, isEmpty);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open saved assignment'));
      await tester.pumpAndSettle();
      expect(server.envelopes, isEmpty);
      await tester.tap(find.text('Check saved assignment'));
      await tester.pumpAndSettle();
      expect(server.envelopes, [saved.envelopeJson]);
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.uncertain,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      saved = (await store.read(saved.submissionId))!;
      await tester.tap(find.text('Open saved assignment'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel unsent assignment'), findsNothing);
      expect(find.text('Remarks: Original shift inspection'), findsOneWidget);
      await tester.tap(find.text('Check saved assignment'));
      await tester.pumpAndSettle();
      expect(server.envelopes, [saved.envelopeJson, saved.envelopeJson]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unverified or changed account hides saved entries and actions', (
    tester,
  ) async {
    await show(tester);
    accounts.addError(StateError('Account read unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Remarks: Original shift inspection'), findsNothing);
    expect(find.text('Check saved assignment'), findsNothing);
    accounts.add(manager('assigner-2'));
    await tester.pumpAndSettle();
    expect(find.text('Remarks: Original shift inspection'), findsNothing);
    expect(find.text('Check saved assignment'), findsNothing);
    accounts.add(manager());
    await tester.pumpAndSettle();
    expect(find.text('Remarks: Original shift inspection'), findsOneWidget);
    expect(server.envelopes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving during a response retains uncertainty without disposed widget access',
    (tester) async {
      await show(tester);
      server.gate = Completer<void>();
      await tester.tap(find.text('Check saved assignment'));
      await tester.pump();
      await tester.pageBack();
      await tester.pump();
      server.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        (await store.read(saved.submissionId))!.state,
        DurableSubmissionState.uncertain,
      );
      expect(server.envelopes, [saved.envelopeJson]);
      expect(tester.takeException(), isNull);
    },
  );
}

// UI-only transport uncertainty double. Native atomic adoption is exercised in
// published_template_assignment_submission_test.dart, using real Isar.
class _UncertainServer extends PublishedTemplateAssignmentServerService {
  final List<String> envelopes = [];
  Completer<void>? gate;
  @override
  Future<Map<String, dynamic>> assignFrozenEnvelope(String envelopeJson) async {
    envelopes.add(envelopeJson);
    await gate?.future;
    throw StateError('Response unavailable');
  }
}
