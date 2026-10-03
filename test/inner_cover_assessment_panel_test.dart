import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:crm3_baf_ops/features/assets/data/furnace_stuckup_record.dart';
import 'package:crm3_baf_ops/features/assets/data/inner_cover_lifecycle.dart';
import 'package:crm3_baf_ops/features/assets/presentation/inner_cover_assessment_panel.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/data/workflow_command_record.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/presentation/screens/workflow_diagnostics_screen.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/repositories/workflow_repository.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_online_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inner_cover_lifecycle_model_test.dart' as profile_fixture;
import 'inner_cover_assessment_recovery_test.dart' as recovery_fixture;
import 'package:crm3_baf_ops/features/assets/providers/inner_cover_assessment_recovery_provider.dart';
import 'package:crm3_baf_ops/features/assets/services/inner_cover_assessment_recovery.dart';
import 'package:crm3_baf_ops/features/assets/providers/inner_cover_assessment_provider.dart';

// Host presentation tests: evidence and command boundaries are controlled here.
// Actual server admission, durable Isar replay and Android acceptance are covered
// separately; a mocked error below is never treated as backend acceptance proof.
final _reported = DateTime.utc(2026, 10, 1);
final _released = DateTime.utc(2026, 10, 2);
final _inspected = DateTime.utc(2026, 10, 3);
final _settled = DateTime.utc(2026, 10, 4);
const _reason = 'Post-event inspection resolves this exact recorded concern.';
const _instruction =
    'Explain how the post-event inspection resolves this concern (at least 20 characters).';

Map<String, dynamic> _disposition([Map<String, dynamic> delta = const {}]) => {
  'schemaVersion': 1,
  'kind': 'postEventInspectionAccepted',
  'assessorConfirmed': true,
  'caseId': 'case-1',
  'ticketId': 'case-1',
  'innerCoverId': 'cover-1',
  'innerCoverSerialNumber': 'GR-26',
  'eventLinkageId': 'link-1',
  'originalCaseVersion': 3,
  'withdrawnTicketVersion': 2,
  'inspectedAt': _inspected,
  'settledAt': _settled,
  'reason': _reason,
  'settledByName': 'Fixture SI',
  'settledByUid': 'si-1',
  'acceptedByUid': 'admin-1',
  'acceptanceReference': 'ACC-1',
  'acceptanceRequestId': 'accept-1',
  'acceptanceAuditId': 'inner_cover_accept-1',
  'withdrawalRequestId': 'withdraw-1',
  'withdrawalAuditId': 'server_maintenance_ticket_withdraw-1',
  'assuranceEpisodeId': 'repair-1',
  'commandId': 'settle-1',
  'acceptanceProfileVersion': 5,
  for (final key in [
    'withdrawalAuditSha256',
    'withdrawalReceiptSha256',
    'acceptanceAuditSha256',
    'acceptanceReceiptSha256',
  ])
    key: 'a' * 64,
  ...delta,
};

FurnaceStuckupRecord _record({Map<String, dynamic>? disposition}) =>
    FurnaceStuckupRecord.fromMap({
      'schemaVersion': 1,
      'caseId': 'case-1',
      'ticketId': 'case-1',
      'version': disposition == null ? 3 : 4,
      'obstructionStatus': 'released',
      'adjudicationStatus': 'confirmed',
      'suspectedCause': 'innerCoverBulging',
      'confirmedCause': 'innerCoverBulging',
      'furnaceAssetInstanceId': 'furnace-1',
      'furnaceAssetNumber': 1,
      'furnaceAssetClassId': 'furnace-class',
      'baseAssetInstanceId': 'base-101',
      'baseAssetNumber': 101,
      'baseAssetClassId': 'base-class',
      'innerCoverId': 'cover-1',
      'innerCoverSerialNumber': 'GR-26',
      'innerCoverLinkageId': 'link-1',
      'innerCoverAssignmentVersion': 1,
      'operatingContext': 'postAnnealingRemoval',
      'chargeNoAtEvent': 77131,
      'reportedAt': _reported,
      'reportedByName': 'Fixture Operations',
      'adjudicatedAt': _reported.add(const Duration(hours: 1)),
      'adjudicationNotes': 'Confirmed physical concern',
      'releasedAt': _released,
      'releaseNotes': 'Physical separation only',
      'conditionDeclarationId': 'declaration-1',
      'updatedAt': disposition == null ? _released : _settled,
      if (disposition != null) 'concernDisposition': disposition,
    }, 'case-1');

InnerCoverProfile _profile({bool invalidated = false}) =>
    InnerCoverProfile.fromMap({
      ...profile_fixture.profileMap(),
      'acceptedAt': _inspected,
      'updatedAt': _settled,
      if (invalidated) ...{
        'assuranceInvalidatedAt': _settled,
        'assuranceInvalidatedRecordedAt': _settled,
        'assuranceInvalidatedByUid': 'admin-1',
        'assuranceInvalidatedByName': 'Fixture Admin',
        'assuranceInvalidationReason': 'Later repair requires reacceptance',
        'assuranceEpisodeId': 'repair-2',
      },
    }, 'cover-1');

InnerCoverAssessmentEvidence _evidence(
  FurnaceStuckupRecord record, {
  bool withdrawn = true,
  int ticketVersion = 2,
  bool invalidated = false,
}) => InnerCoverAssessmentEvidence(
  withdrawn: withdrawn,
  ticketVersion: ticketVersion,
  profile: _profile(invalidated: invalidated),
  currentRecord: record,
);

AppUser _actor(String id, {AppRole role = AppRole.admin}) => AppUser(
  uid: id,
  name: 'Fixture $id',
  email: '$id@example.invalid',
  roles: [role],
  isApproved: true,
  createdAt: _reported,
);
final _actorProvider = StateProvider<AppUser>((ref) => _actor('admin-1'));

class _Journal implements WorkflowRepository, WorkflowCommandJournalReader {
  final Map<String, WorkflowCommandRecord> rows = {};
  bool unreadable = false;
  List<WorkflowCommandRecord>? retainedRows;
  int reads = 0;
  @override
  Future<List<WorkflowCommandRecord>> getPendingCommands() async {
    reads++;
    if (unreadable) throw StateError('Private native journal error');
    return rows.values
        .where((row) => row.stateKey != 'applied' && row.stateKey != 'rejected')
        .toList();
  }

  @override
  Future<List<WorkflowCommandRecord>> readUnsettledCommands({
    required String aggregateId,
    required String commandTypeKey,
  }) async {
    reads++;
    if (unreadable) throw StateError('Private native journal error');
    if (retainedRows != null) return retainedRows!;
    return rows.values
        .where(
          (row) =>
              row.aggregateId == aggregateId &&
              row.commandTypeKey == commandTypeKey &&
              row.stateKey != 'applied',
        )
        .toList();
  }

  @override
  Future<WorkflowCommandRecord?> getRetryCommand(String commandId) async =>
      rows[commandId];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

WorkflowCommandRecord _saved(
  String id, {
  String state = 'manualReview',
  String aggregate = 'case-1',
  String type = 'settleInnerCoverAssessment',
}) => WorkflowCommandRecord()
  ..commandId = id
  ..aggregateId = aggregate
  ..commandTypeKey = type
  ..expectedVersion = 3
  ..stateKey = state
  ..payloadJson = '{"original":"immutable fixture envelope"}';

class _Executor implements WorkflowOnlineExecutor {
  _Executor(this.journal);
  final _Journal journal;
  final List<WorkflowCommand> calls = [];
  String state = 'manualReview';
  @override
  Future<WorkflowCommandReceipt> execute(
    WorkflowCommand command, {
    DateTime? claimedAt,
    void Function(WorkflowCommandReceipt)? validateReceipt,
  }) async {
    calls.add(command);
    journal.rows[command.commandId] = _saved(command.commandId, state: state)
      ..payloadJson = jsonEncode(command.payload);
    throw StateError('Private backend diagnostic should not appear in UI');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness(this.record) : evidence = _evidence(record) {
    executor = _Executor(journal);
    container = ProviderContainer(
      overrides: [
        currentAppUserProvider.overrideWith(
          (ref) => Stream.value(ref.watch(_actorProvider)),
        ),
        innerCoverAssessmentEvidenceProvider(record).overrideWith((ref) async {
          evidenceReads++;
          if (evidenceError) throw StateError('Private evidence diagnostic');
          return awaiting?.future ?? evidence;
        }),
        innerCoverAssessmentActorReaderProvider.overrideWith((ref) {
          ref.watch(_actorProvider);
          return () => accountReady ? ref.read(_actorProvider) : null;
        }),
        workflowRepositoryProvider.overrideWithValue(journal),
        workflowOnlineExecutorProvider.overrideWithValue(executor),
        innerCoverAssessmentRecoveryProvider.overrideWith(
          (ref) =>
              recovery ??
              (throw StateError('No authoritative review fixture supplied.')),
        ),
      ],
    );
  }
  final FurnaceStuckupRecord record;
  final journal = _Journal();
  InnerCoverAssessmentRecovery? recovery;
  late final _Executor executor;
  late final ProviderContainer container;
  InnerCoverAssessmentEvidence evidence;
  bool evidenceError = false;
  bool accountReady = true;
  int evidenceReads = 0;
  Completer<InnerCoverAssessmentEvidence>? awaiting;
  Widget app() => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: InnerCoverAssessmentPanel(record: record),
        ),
      ),
    ),
  );
  void refresh() =>
      container.invalidate(innerCoverAssessmentEvidenceProvider(record));
}

Future<_Harness> _mount(
  WidgetTester tester, {
  FurnaceStuckupRecord? record,
  void Function(_Harness)? configure,
}) async {
  final h = _Harness(record ?? _record());
  configure?.call(h);
  addTearDown(h.container.dispose);
  await tester.pumpWidget(h.app());
  await tester.pumpAndSettle();
  return h;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  final field = find.byKey(const ValueKey('ic-assessment-reason'));
  await tester.ensureVisible(field);
  await tester.enterText(field, _reason);
  await tester.pumpAndSettle();
  await _tap(tester, find.byType(Checkbox));
  await _tap(tester, find.byKey(const ValueKey('ic-assessment-submit')));
}

void main() {
  Map<String, Object?> recoveryRequest() => {
    'originActorUid': 'admin-1',
    'recovery': {
      'requestId': 'settle-1',
      'evidenceSha256': 'a' * 64,
      'assessmentEvidence': {'aggregateId': 'case-1'},
    },
  };

  for (final refusal in [
    ('invalid-argument', 'submission-recovery-request-invalid'),
    ('failed-precondition', 'submission-recovery-finalization-not-activated'),
  ]) {
    test('exact server refusal ${refusal.$2} is scoped unavailable', () {
      final error = innerCoverRecoveryFailure(
        FirebaseFunctionsException(
          message: 'Fixture refusal',
          code: refusal.$1,
          details: {'reasonCode': refusal.$2},
        ),
        recoveryRequest(),
      );
      expect(error, isA<InnerCoverRecoveryUnavailable>());
      final unavailable = error as InnerCoverRecoveryUnavailable;
      expect(unavailable.appliesTo('admin-1', 'case-1'), isTrue);
      expect(unavailable.appliesTo('admin-2', 'case-1'), isFalse);
      expect(unavailable.appliesTo('admin-1', 'case-2'), isFalse);
      expect(unavailable.requestId, 'settle-1');
      expect(unavailable.evidenceSha256, 'a' * 64);
      expect(error.message, contains('not available in this version'));
      expect(error.message, contains('restriction remain saved'));
      expect(error.message, contains('Ask an Admin'));
      expect(error.message, isNot(contains('try again')));
      expect(error.message, isNot(contains('while connected')));
    });

    testWidgets(
      'unsupported status ${refusal.$2} disables recovery without changing work',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final fixture = recovery_fixture.Harness();
        final saved = fixture.journal.row!;
        final bytes = saved.payloadJson;
        final phases = <String>[];
        final h = await _mount(
          tester,
          configure: (h) {
            h.journal.rows[saved.commandId] = saved;
            h.recovery = InnerCoverAssessmentRecovery(
              repository: h.journal,
              actor: () => h.container.read(_actorProvider),
              requireCapability: (_) async {},
              invoke: (request) async {
                phases.add((request['recovery'] as Map)['phase'] as String);
                throw innerCoverRecoveryFailure(
                  FirebaseFunctionsException(
                    message: 'Fixture refusal',
                    code: refusal.$1,
                    details: {'reasonCode': refusal.$2},
                  ),
                  request,
                );
              },
            );
          },
        );
        await _tap(tester, find.text('Review assessment'));
        final button = find.byKey(
          const ValueKey('ic-assessment-saved-review-case-1'),
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(find.text('Saved-request recovery unavailable'), findsOneWidget);
        expect(
          find.textContaining('not available in this version'),
          findsOneWidget,
        );
        expect(find.text('Review assessment'), findsNothing);
        expect(find.byType(InnerCoverAssessmentDialog), findsNothing);
        expect(phases, ['status']);
        await _tap(tester, find.text('Check current assessment'));
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(phases, ['status']);
        expect(h.journal.rows[saved.commandId], same(saved));
        expect(saved.payloadJson, bytes);
        expect(saved.stateKey, 'manualReview');
        expect(h.executor.calls, isEmpty);
        expect(find.text('Open Inner Cover records'), findsOneWidget);
        expect(find.text('Review saved workflow action'), findsOneWidget);
        expect(tester.takeException(), isNull);
        h.container.read(_actorProvider.notifier).state = _actor('admin-2');
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(
          find.textContaining('not available in this version'),
          findsNothing,
        );
        expect(phases, ['status']);
      },
    );
  }

  testWidgets(
    'transient status failure leaves inspection retryable and journal retained',
    (tester) async {
      final fixture = recovery_fixture.Harness();
      final saved = fixture.journal.row!;
      final phases = <String>[];
      final h = await _mount(
        tester,
        configure: (h) {
          h.journal.rows[saved.commandId] = saved;
          h.recovery = InnerCoverAssessmentRecovery(
            repository: h.journal,
            actor: () => h.container.read(_actorProvider),
            requireCapability: (_) async {},
            invoke: (request) async {
              phases.add((request['recovery'] as Map)['phase'] as String);
              throw innerCoverRecoveryFailure(
                FirebaseFunctionsException(
                  code: 'unavailable',
                  message: 'Fixture offline',
                ),
                request,
              );
            },
          );
        },
      );
      await _tap(tester, find.text('Review assessment'));
      final button = find.byKey(
        const ValueKey('ic-assessment-saved-review-case-1'),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await _tap(tester, button);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(phases, ['status', 'status']);
      expect(find.text('Saved-request recovery unavailable'), findsNothing);
      expect(h.journal.rows[saved.commandId], same(saved));
      expect(h.executor.calls, isEmpty);
    },
  );

  test('network/unknown errors do not become a server-version verdict', () {
    for (final error in [
      FirebaseFunctionsException(
        code: 'unavailable',
        message: 'Fixture offline',
      ),
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Fixture refusal',
      ),
      FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'submission-recovery-request-invalid',
      ),
      FirebaseFunctionsException(
        message: 'Fixture refusal',
        code: 'permission-denied',
        details: const {'reasonCode': 'submission-recovery-request-invalid'},
      ),
    ]) {
      expect(
        innerCoverRecoveryFailure(error, recoveryRequest()),
        isNot(isA<InnerCoverRecoveryUnavailable>()),
      );
    }
  });

  testWidgets(
    'disposed failing preflight exits before a subsequent saved row',
    (tester) async {
      final first = recovery_fixture.saved();
      final second = recovery_fixture.saved()..commandId = 'settle-2';
      final rows = _ObservedRows([first, second]);
      final response = Completer<Object?>();
      var statusCalls = 0;
      final h = await _mount(
        tester,
        configure: (h) {
          h.journal.rows[first.commandId] = first;
          h.journal.rows[second.commandId] = second;
          h.journal.retainedRows = rows;
          h.recovery = InnerCoverAssessmentRecovery(
            repository: h.journal,
            actor: () => _actor('admin-1'),
            requireCapability: (_) async {},
            invoke: (_) async {
              statusCalls++;
              return response.future;
            },
          );
        },
      );
      await tester.ensureVisible(find.text('Review assessment'));
      await tester.tap(find.text('Review assessment'));
      await tester.pump();
      expect(statusCalls, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      rows.disposed = true;
      response.completeError(
        StateError('Delayed status failure after disposal'),
      );
      await tester.pumpAndSettle();
      expect(rows.readsAfterDisposal, 0);
      expect(statusCalls, 1);
      expect(h.executor.calls, isEmpty);
      expect(h.journal.rows.values, containsAllInOrder([first, second]));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unverified account during open form prevents command submission',
    (tester) async {
      final h = await _mount(tester);
      await _tap(tester, find.text('Review assessment'));
      h.accountReady = false;
      await _confirm(tester);
      expect(h.executor.calls, isEmpty);
      expect(
        find.textContaining('account changed during review'),
        findsOneWidget,
      );
    },
  );
  testWidgets('disposed saved-status review does not read ref or show dialog', (
    tester,
  ) async {
    final fixture = recovery_fixture.Harness();
    final saved = fixture.journal.row!;
    final pending = Completer<Object?>();
    var calls = 0;
    final h = await _mount(
      tester,
      configure: (h) {
        h.journal.rows[saved.commandId] = saved;
        h.recovery = InnerCoverAssessmentRecovery(
          repository: h.journal,
          actor: () => _actor('admin-1'),
          requireCapability: (_) async {},
          invoke: (_) async {
            calls++;
            return calls == 1
                ? fixture.response(reviewer: 'admin-1')
                : pending.future;
          },
        );
      },
    );
    await _tap(tester, find.text('Review assessment'));
    final button = find.byKey(
      const ValueKey('ic-assessment-saved-review-case-1'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(
      fixture.response(
        outcome: 'reviewedExisting',
        receipt: true,
        reviewer: 'admin-1',
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(h.executor.calls, isEmpty);
    expect(h.journal.rows[saved.commandId], same(saved));
  });

  testWidgets(
    'Admin explicit review requires two confirmations and retains original row',
    (tester) async {
      final fixture = recovery_fixture.Harness();
      final saved = fixture.journal.row!;
      final bytes = saved.payloadJson;
      var closed = false;
      final phases = <String>[];
      final h = await _mount(
        tester,
        configure: (h) {
          h.journal.rows[saved.commandId] = saved;
          h.recovery = InnerCoverAssessmentRecovery(
            repository: h.journal,
            actor: () => h.container.read(_actorProvider),
            requireCapability: (_) async {},
            invoke: (request) async {
              final data = request['recovery'] as Map;
              final phase = data['phase'] as String;
              phases.add(phase);
              if (phase == 'finalize') closed = true;
              final response = fixture.response(
                outcome: closed ? 'cancelled' : null,
                inspected: phase == 'inspect',
                reviewer: 'admin-1',
              );
              if (response.containsKey('outcome')) {
                response['reason'] =
                    'Checked original assessment and saved request.';
              }
              return response;
            },
          );
        },
      );
      await _tap(tester, find.text('Review assessment'));
      expect(h.executor.calls, isEmpty);
      await _tap(
        tester,
        find.byKey(const ValueKey('ic-assessment-saved-review-case-1')),
      );
      expect(find.byType(InnerCoverSavedRequestReviewDialog), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('ic-saved-review-reason')),
        'Checked original assessment and saved request.',
      );
      await _tap(tester, find.byKey(const ValueKey('ic-saved-review-inspect')));
      expect(phases.where((phase) => phase == 'finalize'), isEmpty);
      expect(find.text('Close this saved request?'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('ic-saved-review-confirm')));
      expect(phases.where((phase) => phase == 'finalize'), hasLength(1));
      expect(h.executor.calls, isEmpty);
      expect(h.journal.rows[saved.commandId], same(saved));
      expect(saved.payloadJson, bytes);
      expect(saved.stateKey, 'manualReview');
      expect(find.text('Review assessment'), findsOneWidget);
      await _tap(tester, find.text('Review assessment'));
      expect(find.byType(InnerCoverAssessmentDialog), findsOneWidget);
      expect(
        h.executor.calls,
        isEmpty,
      ); // User must make a new assessment explicitly.
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unavailable recovery service leaves hold and actionable explanation',
    (tester) async {
      final fixture = recovery_fixture.Harness();
      final saved = fixture.journal.row!;
      final h = await _mount(
        tester,
        configure: (h) {
          h.journal.rows[saved.commandId] = saved;
          h.recovery = InnerCoverAssessmentRecovery(
            repository: h.journal,
            actor: () => h.container.read(_actorProvider),
            requireCapability: (_) async {},
            invoke: (request) async {
              if ((request['recovery'] as Map)['phase'] == 'inspect') {
                throw innerCoverRecoveryFailure(
                  FirebaseFunctionsException(
                    message: 'Fixture refusal',
                    code: 'failed-precondition',
                    details: const {
                      'reasonCode':
                          'submission-recovery-finalization-not-activated',
                    },
                  ),
                  request,
                );
              }
              return fixture.response(reviewer: 'admin-1');
            },
          );
        },
      );
      await _tap(tester, find.text('Review assessment'));
      await _tap(
        tester,
        find.byKey(const ValueKey('ic-assessment-saved-review-case-1')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('ic-saved-review-reason')),
        'Checked the original request.',
      );
      await _tap(tester, find.byKey(const ValueKey('ic-saved-review-inspect')));
      expect(
        find.textContaining('not available in this version'),
        findsOneWidget,
      );
      expect(find.text('Review assessment'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('ic-assessment-saved-review-case-1')),
            )
            .onPressed,
        isNull,
      );
      expect(h.journal.rows[saved.commandId], same(saved));
      expect(h.executor.calls, isEmpty);
    },
  );
  testWidgets(
    '320dp large text saved-request reason dialog remains scrollable with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.5)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (_) => const InnerCoverSavedRequestReviewDialog(
                      commandId: 'retained-request-1',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await _tap(tester, find.text('Open'));
      expect(tester.takeException(), isNull);
      final field = find.byKey(const ValueKey('ic-saved-review-reason'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Checked the original request.');
      await tester.pumpAndSettle();
      final inspect = find.byKey(const ValueKey('ic-saved-review-inspect'));
      await tester.ensureVisible(inspect);
      await tester.pumpAndSettle();
      expect(tester.getSize(inspect).height, greaterThanOrEqualTo(48));
      await _tap(tester, inspect);
      expect(result, 'Checked the original request.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cached settled record cannot outrank current unresolved case', (
    tester,
  ) async {
    final cached = _record(disposition: _disposition());
    await _mount(
      tester,
      record: cached,
      configure: (h) => h.evidence = _evidence(_record()),
    );
    expect(find.text('This assessment was settled'), findsNothing);
    expect(
      find.text('Withdrawn issue · assessment still required'),
      findsOneWidget,
    );
    expect(find.text('Review assessment'), findsOneWidget);
  });

  testWidgets(
    'only current exact disposition and ticket version show settled',
    (tester) async {
      final h = await _mount(
        tester,
        configure: (h) =>
            h.evidence = _evidence(_record(disposition: _disposition())),
      );
      expect(find.text('This assessment was settled'), findsOneWidget);
      expect(find.text('Review assessment'), findsNothing);
      h.evidence = _evidence(
        _record(disposition: _disposition()),
        ticketVersion: 3,
      );
      h.refresh();
      await tester.pumpAndSettle();
      expect(find.text('This assessment was settled'), findsNothing);
      expect(
        find.textContaining('does not match this concern'),
        findsOneWidget,
      );
    },
  );

  for (final delta in <Map<String, dynamic>>[
    {'caseId': 'other-case'},
    {'innerCoverId': 'other-cover'},
    {'eventLinkageId': 'other-link'},
  ]) {
    testWidgets(
      'cross-bound disposition ${delta.keys.single} stays unresolved',
      (tester) async {
        await _mount(
          tester,
          configure: (h) =>
              h.evidence = _evidence(_record(disposition: _disposition(delta))),
        );
        expect(find.text('This assessment was settled'), findsNothing);
        expect(find.textContaining('has not been cleared'), findsOneWidget);
        expect(find.text('Review assessment'), findsNothing);
      },
    );
  }

  testWidgets('server error and refresh never reuse stale settled display', (
    tester,
  ) async {
    final h = await _mount(
      tester,
      configure: (h) =>
          h.evidence = _evidence(_record(disposition: _disposition())),
    );
    expect(find.text('This assessment was settled'), findsOneWidget);
    h.awaiting = Completer<InnerCoverAssessmentEvidence>();
    h.refresh();
    await tester.pump();
    await tester.pump();
    expect(find.text('This assessment was settled'), findsNothing);
    expect(find.text('Checking the retained assessment…'), findsOneWidget);
    h.awaiting!.completeError(StateError('Private evidence diagnostic'));
    await tester.pumpAndSettle();
    expect(find.textContaining('The concern remains in place'), findsOneWidget);
    expect(find.textContaining('Private evidence'), findsNothing);
    h.awaiting = null;
    h.evidence = _evidence(_record());
    await _tap(tester, find.text('Check assessment again'));
    expect(find.text('Review assessment'), findsOneWidget);
    expect(h.evidenceReads, 3);
  });

  testWidgets('invalidated acceptance does not offer a known doomed review', (
    tester,
  ) async {
    final h = await _mount(
      tester,
      configure: (h) => h.evidence = _evidence(_record(), invalidated: true),
    );
    expect(h.evidence.profile.requiresReacceptance, isTrue);
    expect(find.text('Review assessment'), findsNothing);
    expect(
      find.textContaining('post-event acceptance is required'),
      findsOneWidget,
    );
  });

  testWidgets('unauthorized role retains concern without disposition control', (
    tester,
  ) async {
    await _mount(
      tester,
      configure: (h) => h.container.read(_actorProvider.notifier).state =
          _actor('operations', role: AppRole.operations),
    );
    expect(find.textContaining('assessment still required'), findsOneWidget);
    expect(find.text('Review assessment'), findsNothing);
  });

  for (final state in ['manualReview', 'rejected']) {
    testWidgets('terminal $state has review route without dispatch loop', (
      tester,
    ) async {
      final h = await _mount(
        tester,
        configure: (h) => h.executor.state = state,
      );
      await _tap(tester, find.text('Review assessment'));
      await _confirm(tester);
      expect(h.executor.calls, hasLength(1));
      expect(
        h.executor.calls.single.type,
        WorkflowCommandType.settleInnerCoverAssessment,
      );
      expect(h.journal.rows.values.single.stateKey, state);
      expect(find.text('Check saved assessment'), findsNothing);
      expect(find.text('Review saved workflow action'), findsOneWidget);
      expect(find.text('Check current assessment'), findsOneWidget);
      expect(find.textContaining('Private backend diagnostic'), findsNothing);
      await _tap(tester, find.text('Check current assessment'));
      expect(h.executor.calls, hasLength(1));
      expect(h.journal.rows, hasLength(1));
    });
  }

  testWidgets(
    'uncertain outcome repeats exact identity and preserves origin actor',
    (tester) async {
      final h = await _mount(
        tester,
        configure: (h) => h.executor.state = 'uncertainOutcome',
      );
      await _tap(tester, find.text('Review assessment'));
      await _confirm(tester);
      final original = h.executor.calls.single;
      await _tap(tester, find.text('Check saved assessment'));
      expect(h.executor.calls, hasLength(2));
      expect(h.executor.calls.last.commandId, original.commandId);
      expect(h.executor.calls.last.payload, original.payload);
      h.container.read(_actorProvider.notifier).state = _actor('admin-2');
      await tester.pumpAndSettle();
      expect(find.text('Check saved assessment'), findsNothing);
      expect(
        find.textContaining('Return to the approved account'),
        findsOneWidget,
      );
      expect(h.journal.rows, hasLength(1));
      expect(h.executor.calls, hasLength(2));
    },
  );

  testWidgets('actor change while dialog is open sends nothing', (
    tester,
  ) async {
    final h = await _mount(tester);
    await _tap(tester, find.text('Review assessment'));
    h.container.read(_actorProvider.notifier).state = _actor('admin-2');
    await tester.pumpAndSettle();
    await _confirm(tester);
    expect(h.executor.calls, isEmpty);
    expect(h.journal.rows, isEmpty);
    expect(
      find.textContaining('account changed during review. Nothing was sent'),
      findsOneWidget,
    );
  });

  testWidgets(
    'reopened panel preserves existing saved decision without replacement',
    (tester) async {
      final saved = _saved('prior-decision');
      final h = await _mount(
        tester,
        configure: (h) => h.journal.rows[saved.commandId] = saved,
      );
      await _tap(tester, find.text('Review assessment'));
      expect(find.byType(InnerCoverAssessmentDialog), findsNothing);
      expect(
        find.textContaining('replacement decision has not been created'),
        findsOneWidget,
      );
      expect(find.text('Review saved workflow action'), findsOneWidget);
      expect(h.executor.calls, isEmpty);
      expect(h.journal.rows.values.single, same(saved));
      expect(saved.payloadJson, '{"original":"immutable fixture envelope"}');
    },
  );

  testWidgets('reopened rejected decision is preserved without replacement', (
    tester,
  ) async {
    final saved = _saved('prior-rejection', state: 'rejected');
    final h = await _mount(
      tester,
      configure: (h) => h.journal.rows[saved.commandId] = saved,
    );
    expect(await h.journal.getPendingCommands(), isEmpty);
    await _tap(tester, find.text('Review assessment'));
    expect(find.byType(InnerCoverAssessmentDialog), findsNothing);
    expect(
      find.textContaining('replacement decision has not been created'),
      findsOneWidget,
    );
    expect(h.executor.calls, isEmpty);
    expect(h.journal.rows.values.single, same(saved));
  });

  testWidgets('saved rejected action opens exact read-only diagnostic scope', (
    tester,
  ) async {
    final saved = _saved('prior-rejection', state: 'rejected');
    final unrelated = _saved('other-concern', aggregate: 'case-2');
    final otherType = _saved('other-action', type: 'adjudicateFurnaceStuckup');
    final h = await _mount(
      tester,
      configure: (h) {
        for (final row in [saved, unrelated, otherType]) {
          h.journal.rows[row.commandId] = row;
        }
      },
    );
    await _tap(tester, find.text('Review assessment'));
    await _tap(tester, find.text('Review saved workflow action'));
    final screen = tester.widget<WorkflowDiagnosticsScreen>(
      find.byType(WorkflowDiagnosticsScreen),
    );
    expect(screen.aggregateId, 'case-1');
    expect(screen.commandTypeKey, 'settleInnerCoverAssessment');
    expect(
      find.byKey(const ValueKey('saved-assessment-prior-rejection')),
      findsOneWidget,
    );
    expect(find.textContaining('Recorded status: rejected'), findsOneWidget);
    expect(find.textContaining('other-concern'), findsNothing);
    expect(find.textContaining('other-action'), findsNothing);
    expect(find.text('Clear local log'), findsNothing);
    expect(h.executor.calls, isEmpty);
    expect(h.journal.rows, hasLength(3));
    expect(h.journal.rows[saved.commandId], same(saved));
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved request appearing during dialog prevents new identity', (
    tester,
  ) async {
    final h = await _mount(tester);
    await _tap(tester, find.text('Review assessment'));
    final saved = _saved('concurrent-prior-decision');
    h.journal.rows[saved.commandId] = saved;
    await _confirm(tester);
    expect(h.executor.calls, isEmpty);
    expect(h.journal.rows.values.single, same(saved));
    expect(
      find.textContaining('replacement decision has not been created'),
      findsOneWidget,
    );
  });

  testWidgets('unreadable journal establishes no safe new submission', (
    tester,
  ) async {
    final h = await _mount(
      tester,
      configure: (h) => h.journal.unreadable = true,
    );
    await _tap(tester, find.text('Review assessment'));
    expect(find.byType(InnerCoverAssessmentDialog), findsNothing);
    expect(find.textContaining('Nothing new was sent'), findsOneWidget);
    expect(find.textContaining('Private native journal error'), findsNothing);
    expect(h.executor.calls, isEmpty);
  });

  for (final keyboard in [0.0, 300.0]) {
    testWidgets(
      '320dp 2.5x dialog independently exposes all controls, keyboard $keyboard',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result = await showDialog<String>(
                    context: context,
                    builder: (_) => InnerCoverAssessmentDialog(
                      record: _record(),
                      acceptanceReference: 'ACC-1',
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await _tap(tester, find.text('Open'));
        expect(tester.takeException(), isNull);
        final instruction = find.text(_instruction);
        await tester.ensureVisible(instruction);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(instruction);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.maxLines, isNull);
        final field = find.byKey(const ValueKey('ic-assessment-reason'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, _reason);
        await tester.pumpAndSettle();
        await _tap(tester, find.byType(Checkbox));
        final submit = find.byKey(const ValueKey('ic-assessment-submit'));
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
        expect(submit.hitTestable(), findsOneWidget);
        await _tap(tester, submit);
        expect(result, _reason);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

/// Records iteration independently of provider access, so swallowing a disposed
/// ref error on the next row cannot make this lifecycle regression pass.
class _ObservedRows extends ListBase<WorkflowCommandRecord> {
  _ObservedRows(this.rows);
  final List<WorkflowCommandRecord> rows;
  bool disposed = false;
  int readsAfterDisposal = 0;
  @override
  int get length => rows.length;
  @override
  set length(int value) => throw UnsupportedError('Read-only journal view');
  @override
  WorkflowCommandRecord operator [](int index) {
    if (disposed) readsAfterDisposal++;
    return rows[index];
  }

  @override
  void operator []=(int index, WorkflowCommandRecord value) =>
      throw UnsupportedError('Read-only journal view');
}
