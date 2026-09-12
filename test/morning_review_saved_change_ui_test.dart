import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'dart:async';
import 'dart:convert';

import 'package:crm3_baf_ops/core/persistence/durable_submission.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/auth/presentation/current_actor_gate.dart';
import 'package:crm3_baf_ops/features/morning_review/domain/morning_review_models.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_editors.dart';
import 'package:crm3_baf_ops/features/morning_review/presentation/morning_review_screen.dart';
import 'package:crm3_baf_ops/features/morning_review/providers/morning_review_providers.dart';
import 'package:crm3_baf_ops/features/morning_review/services/morning_review_command_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_durable_submission_store.dart';

void main() {
  testWidgets(
    'screen restore and refresh show exact saved entries without dispatch until explicit Check',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = InMemoryDurableSubmissionStore();
      final saved = await store.prepare(
        DurableSubmissionDraft(
          submissionId: 'saved-request',
          actorUid: 'actor-a',
          requestId: 'saved-request',
          aggregateId: '2026-08-31',
          resourceKey: 'morningReview:actor-a',
          protocol: 'assetHierarchy.v2',
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': 'actor-a',
            'request': {
              'requestId': 'saved-request',
              'operation': 'ADD_MORNING_REVIEW_ENTRY',
              'sessionId': '2026-08-31',
              'entryDraft': {'text': 'The original retained plant update'},
            },
          }),
        ),
      );
      final service = _SavedService(saved);
      Widget screen() => _screen(() => service);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The original retained plant update'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Meeting: 2026-08-31', findRichText: true),
        findsOneWidget,
      );
      expect(service.checks, 0);
      await tester.tap(find.byTooltip('Refresh Morning Review'));
      await tester.pumpAndSettle();
      expect(service.checks, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(service.checks, 0);
      await tester.tap(find.text('Check saved change'));
      await tester.pumpAndSettle();
      expect(service.checks, 1);
      expect(
        find.textContaining('The original retained plant update'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'storage-open failure is shown without dispatch or unhandled provider error',
    (tester) async {
      await tester.pumpWidget(
        _screen(
          () => throw const DurableSubmissionException(
            'storage-unavailable',
            'Saved submissions could not be opened. Nothing was sent.',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Saved submissions could not be opened.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editor retains text through failed refresh and different actor before original recovery',
    (tester) async {
      final actors = StreamController<AppUser?>();
      addTearDown(actors.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => actors.stream),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showMorningReviewTextPrompt(
                    context,
                    title: 'Completion evidence',
                    label: 'Outcome',
                    actionLabel: 'Save evidence',
                    guard: (child) => CurrentActorDialogGuard(
                      originUid: 'actor-a',
                      permission: (actor) => actor.canContributeMorningReview,
                      child: child,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      actors.add(_actor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Retained completion details',
      );
      actors.addError(StateError('refresh failed'));
      await tester.pumpAndSettle();
      expect(find.text('Account verification required'), findsOneWidget);
      expect(find.text('Save evidence'), findsNothing);
      actors.add(_actor(uid: 'actor-b'));
      await tester.pumpAndSettle();
      expect(find.text('Save evidence'), findsNothing);
      actors.add(_actor());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'Retained completion details',
      );
      expect(find.text('Save evidence'), findsOneWidget);
    },
  );
}

AppUser _actor({String uid = 'actor-a'}) => AppUser(
  uid: uid,
  name: uid,
  email: '$uid@example.test',
  roles: [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);

class _SavedService extends MorningReviewCommandService {
  _SavedService(this.saved);
  DurableSubmission? saved;
  int checks = 0;
  @override
  Future<DurableSubmission?> pendingSubmission() async => saved;
  @override
  Future<MorningReviewCommandResult?> reconcilePending() async {
    checks++;
    final row = saved!;
    saved = null;
    return MorningReviewCommandResult(
      requestId: row.requestId,
      operation: MorningReviewCommand.addEntry,
      sessionId: '2026-08-31',
      entityId: row.requestId,
      status: 'recorded',
      version: 2,
      committedAt: DateTime.utc(2026, 8, 31, 3),
      idempotentReplay: true,
    );
  }
}

Widget _screen(MorningReviewCommandService Function() service) => ProviderScope(
  overrides: [
    currentAppUserProvider.overrideWith((ref) => Stream.value(_actor())),
    morningReviewCommandServiceProvider.overrideWith((ref) => service()),
    currentMorningReviewSessionProvider.overrideWith(
      (ref) => Stream<MorningReviewSession?>.value(null),
    ),
    recentMorningReviewSessionsProvider.overrideWith(
      (ref) => Stream.value(<MorningReviewSession>[]),
    ),
    activeMorningReviewActionsProvider.overrideWith(
      (ref) => Stream.value(<MorningReviewAction>[]),
    ),
    morningReviewStandingConcernsProvider.overrideWith(
      (ref) => Stream.value(<MorningReviewStandingConcern>[]),
    ),
    allAssetInstancesProvider.overrideWith(
      (ref) => Stream.value(<AssetInstanceRecord>[]),
    ),
  ],
  child: const MaterialApp(home: MorningReviewScreen()),
);
