import 'dart:async';
import 'dart:convert';

import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_event_amendment_controls.dart';
import 'package:crm3_baf_ops/features/operational_events/presentation/operational_events_screen.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_amendment_provider.dart';
import 'package:crm3_baf_ops/features/operational_events/providers/operational_event_provider.dart';
import 'package:crm3_baf_ops/features/operational_events/repositories/operational_event_amendment_repository.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_amendment_service.dart';
import 'package:crm3_baf_ops/features/operational_events/services/operational_event_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../tool/test_support/in_memory_durable_submission_store.dart';
import '../tool/test_support/operational_event_amendment_fixtures.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _Service service,
    required _Repository repository,
    Stream<AppUser?>? actors,
    bool fullScreen = false,
  }) async {
    final event = amendmentReview(reopened: true, amended: true).event;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => actors ?? Stream.value(amendmentActor()),
          ),
          operationalEventAmendmentServiceProvider.overrideWithValue(service),
          operationalEventAmendmentRepositoryProvider.overrideWithValue(
            repository,
          ),
          operationalEventsProvider.overrideWith(
            (ref, _) => Stream.value([event]),
          ),
          operationalEventsForReportsProvider.overrideWith(
            (ref, _) => Stream.value([event]),
          ),
          assetClassesProvider.overrideWith((ref) => Stream.value([])),
          allAssetInstancesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: fullScreen
              ? const OperationalEventsScreen()
              : Scaffold(
                  body: OperationalEventAmendmentControls(
                    event: event,
                    occurrenceIndex: 0,
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('Amend closure time'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, DateTime value) async {
    await tester.tap(find.textContaining('Correct time:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(TimePickerDialog));
    await tester.tap(
      find.byTooltip(
        MaterialLocalizations.of(context).inputTimeModeButtonLabel,
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '${value.toLocal().hour}');
    await tester.enterText(fields.at(1), '${value.toLocal().minute}');
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();
  }

  testWidgets('only approved Admin and SI have closure amendment action', (
    tester,
  ) async {
    for (final role in [
      AppRole.operations,
      AppRole.seniorInstrumentation,
      AppRole.admin,
      AppRole.si,
    ]) {
      await pump(
        tester,
        service: _Service(),
        repository: _Repository(),
        actors: Stream.value(amendmentActor('reviewer', role)),
      );
      expect(
        find.text('Amend closure time'),
        role == AppRole.admin || role == AppRole.si
            ? findsOneWidget
            : findsNothing,
      );
      expect(find.textContaining('Reviewed closure:'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets(
    'real event card exposes archived amendment while latest recurrence is open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        service: _Service(),
        repository: _Repository(),
        fullScreen: true,
      );
      await tester.tap(find.text('1 prior restoration'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('amend-event-$amendmentEventId-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('amend-event-$amendmentEventId-1')),
        findsNothing,
      );
      expect(
        find.textContaining('Resolved by Operations: Restored supply.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'definitive refusal refreshes review and retains corrected time and reason',
    (tester) async {
      final service = _Service()..refuse = true;
      final repository = _Repository();
      await pump(tester, service: service, repository: repository);
      await open(tester);
      final selected = amendmentTime(11).add(const Duration(minutes: 5));
      await choose(tester, selected);
      await tester.enterText(
        find.byType(TextField),
        'Verified operator log after review.',
      );
      await tester.tap(find.text('Save amendment'));
      await tester.pumpAndSettle();
      expect(service.submitted, selected);
      expect(service.reason, 'Verified operator log after review.');
      expect(repository.reads, 2);
      expect(
        find.textContaining('Review changed; draft retained.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Correct time: ${DateFormat('dd MMM yyyy, HH:mm').format(selected.toLocal())}',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        service.reason,
      );
      expect(find.text('Save amendment'), findsOneWidget);
    },
  );

  testWidgets(
    'review window shows retained amendment history with reason and reviewer',
    (tester) async {
      await pump(tester, service: _Service(), repository: _Repository());
      await open(tester);
      await tester.tap(find.text('Amendment history'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Effective closure:'), findsNWidgets(2));
      expect(find.textContaining('Reviewed by Admin A'), findsWidgets);
      expect(find.textContaining('Verified actual restoration.'), findsWidgets);
    },
  );
  testWidgets(
    'saved request is recovered with same identity and no fresh form',
    (tester) async {
      final review = amendmentReview(reopened: true, amended: true);
      final request = <String, dynamic>{
        'requestId': previousAmendmentId,
        'eventId': amendmentEventId,
        'operation': operationalEventAmendmentOperation,
        'expectedVersion': 4,
        'reason': 'Retained original reason.',
        'intervalAmendment': {
          'occurrenceIndex': 0,
          'expectedEffectiveResolvedAt': amendmentTime(11).toIso8601String(),
          'correctedResolvedAt': amendmentTime(12).toIso8601String(),
          'supersedesAmendmentId': amendmentId,
        },
      };
      final store = InMemoryDurableSubmissionStore();
      final pending = await store.prepare(
        DurableSubmissionDraft(
          submissionId: previousAmendmentId,
          actorUid: 'admin-a',
          requestId: previousAmendmentId,
          aggregateId: amendmentEventId,
          resourceKey: OperationalEventAmendmentService.resource(
            amendmentEventId,
            0,
          ),
          protocol: 'assetHierarchy.v2',
          envelopeJson: jsonEncode({
            'protocolVersion': 2,
            'originActorUid': 'admin-a',
            'request': request,
          }),
          displayMetadataJson: jsonEncode({
            'schemaVersion': 1,
            'originalIntervalJson': review.originalIntervalJson,
          }),
        ),
      );
      final service = _Service()..saved = pending;
      final repository = _Repository();
      await pump(tester, service: service, repository: repository);
      await open(tester);
      expect(repository.reads, 0);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Save amendment'), findsNothing);
      await tester.tap(find.text('Check saved amendment'));
      await tester.pumpAndSettle();
      expect(service.resumed, previousAmendmentId);
      expect(service.submitted, isNull);
    },
  );

  testWidgets(
    'account switch hides the original closure evidence and draft actions',
    (tester) async {
      final actors = StreamController<AppUser?>.broadcast();
      addTearDown(actors.close);
      final service = _Service();
      await pump(
        tester,
        service: service,
        repository: _Repository(),
        actors: actors.stream,
      );
      actors.add(amendmentActor());
      await tester.pumpAndSettle();
      await open(tester);
      expect(find.text('Save amendment'), findsOneWidget);
      actors.add(amendmentActor('admin-b'));
      await tester.pumpAndSettle();
      expect(find.text('Save amendment'), findsNothing);
      expect(find.textContaining('Originally recorded closure:'), findsNothing);
      expect(
        find.textContaining('Return to the approved original account'),
        findsOneWidget,
      );
      expect(service.submitted, isNull);
    },
  );
}

class _Repository implements OperationalEventAmendmentRepository {
  int reads = 0;
  @override
  Future<OperationalEventAmendmentReview> review(
    String eventId,
    int index,
  ) async {
    reads++;
    final review = amendmentReview(reopened: true, amended: true);
    return OperationalEventAmendmentReview(
      event: review.event,
      occurrenceIndex: 0,
      originalIntervalJson: review.originalIntervalJson,
      history: [review.amendment!],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service implements OperationalEventAmendmentService {
  DurableSubmission? saved;
  DateTime? submitted;
  String? reason, resumed;
  bool refuse = false;
  @override
  Future<DurableSubmission?> pending(String eventId, int index) async => saved;
  @override
  Future<OperationalEventAmendmentReceipt> submit({
    required OperationalEventAmendmentReview review,
    required DateTime correctedResolvedAt,
    required String reason,
  }) async {
    submitted = correctedResolvedAt;
    this.reason = reason;
    if (refuse) {
      throw const OperationalEventCommandException(
        'Review changed; draft retained.',
        code: 'failed-precondition',
      );
    }
    return receipt;
  }

  @override
  Future<OperationalEventAmendmentReceipt> resume(String id) async {
    resumed = id;
    return receipt;
  }

  OperationalEventAmendmentReceipt get receipt =>
      OperationalEventAmendmentReceipt(
        OperationalEventCommandResult(
          requestId: previousAmendmentId,
          operation: OperationalEventCommand.amendInterval,
          eventId: amendmentEventId,
          status: amendmentReview().event.status,
          version: 5,
          auditId: 'operational_event_$previousAmendmentId',
          committedAt: amendmentTime(16),
          idempotentReplay: false,
        ),
        {'amendmentId': previousAmendmentId},
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
