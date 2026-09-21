import 'dart:convert';

import 'package:crm3_baf_ops/core/persistence/durable_submission.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/audit/providers/audit_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/furnace_stuckup_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/maintenance_creation_successor_review.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/maintenance_ticket_correction.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_creation_successor_review_panel.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_correction_dialog.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_detail_screen.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_creation_successor_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_creation_successor_service.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _actorState = StateProvider<AppUser?>((ref) => _actor());
final _at = DateTime.utc(2026, 9, 21, 8);

AppUser _actor({
  AppRole role = AppRole.si,
  String uid = 'reviewer',
  bool approved = true,
}) => AppUser(
  uid: uid,
  name: 'Reviewer',
  email: 'reviewer@example.test',
  roles: [role],
  isApproved: approved,
  createdAt: _at,
);

MaintenanceRecord _ticket({
  String description = 'Original observation',
  bool synced = false,
  String? remarks,
}) => MaintenanceRecord()
  ..firestoreId = 'issue-review'
  ..loggedByUid = 'reporter'
  ..loggedByName = 'Reporter'
  ..version = synced ? 3 : 1
  ..isSynced = synced
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..maintenanceType = MaintenanceType.breakdown
  ..routedTo = RoutedTo.mechanical
  ..description = description
  ..plantConditionEffect = MaintenanceIssuePlantConditionEffect.unfit
  ..remarks = remarks
  ..startDate = _at.subtract(const Duration(hours: 1))
  ..createdAt = _at
  ..updatedAt = _at.add(const Duration(minutes: 1))
  ..actionsJson = '[]'
  ..resolutionHistoryJson = '[]'
  ..issueLanePlan = IssueLanePlan.initial(['mechanical']);

MaintenanceCreationSuccessorReview _review({
  bool equal = false,
  bool unsupported = false,
  bool registered = false,
  void Function(
    MaintenanceRecord original,
    MaintenanceRecord local,
    MaintenanceRecord server,
  )?
  configure,
}) {
  final original = _ticket();
  final local = _ticket(description: 'Retained device observation');
  final server = _ticket(
    synced: true,
    description: equal
        ? 'Retained device observation'
        : 'Current server observation',
    remarks: equal ? null : 'Server-only attendance note',
  );
  if (unsupported) local.assetNumber = 8;
  if (registered) {
    final reference = const AssetHierarchyReference(
      scope: AssetHierarchyReferenceScope.installedComponent,
      assetClassId: 'furnace',
      assetClassCode: 'FURNACE',
      assetClassName: 'Furnace',
      nodeId: 'sensor',
      nodeVersion: 1,
      nodeName: 'Server governed component',
      assetInstanceId: 'furnace-7',
      assetInstanceVersion: 1,
      assetNumber: 7,
      assetInstanceName: 'Furnace 7',
      componentInstanceId: 'sensor-7',
      componentInstanceVersion: 1,
      componentTag: 'SERVER-TAG',
      hierarchyPath: ['Server subsystem', 'Server governed component'],
      ownershipStatus: AssetOwnershipStatus.confirmed,
      ownerDiscipline: 'Mechanical',
      accountableRoleKeys: ['seniorMechanical'],
    ).encode();
    for (final row in [original, server, local]) {
      row.assetHierarchyRefJson = reference;
    }
    for (final row in [original, server]) {
      row.component = 'Server governed component';
      row.subsystem = 'Server subsystem';
      row.tag = 'SERVER-TAG';
    }
    local.component = 'Unreviewed device component';
    local.subsystem = 'Unreviewed device subsystem';
    local.tag = 'DEVICE-TAG';
  }
  configure?.call(original, local, server);
  final command = WorkflowCommand(
    commandId: 'createMaintenanceTicket_issue-review',
    type: WorkflowCommandType.createMaintenanceTicket,
    aggregateId: 'issue-review',
    expectedVersion: 0,
    payload: {
      'ticket': {
        'schemaVersion': 1,
        'version': 1,
        ...maintenanceCorrectionValues(original),
        'assetType': original.assetType.name,
        'assetNumber': original.assetNumber,
        'assetHierarchyRefJson': original.assetHierarchyRefJson,
        'startDate': original.startDate.toUtc().toIso8601String(),
      },
    },
  );
  return MaintenanceCreationSuccessorReview(
    acceptance: MaintenanceCreationAcceptance(
      envelopeJson: jsonEncode({
        'protocolVersion': 2,
        'originActorUid': 'reporter',
        'command': command.toMap(),
      }),
      actorUid: 'reporter',
      command: command,
      receipt: WorkflowCommandReceipt(
        commandId: command.commandId,
        resultKey: 'maintenance-ticket-created',
        aggregateVersion: 1,
        result: {
          'ticketId': 'issue-review',
          'auditId': 'server_maintenance_ticket_${command.commandId}',
        },
        appliedAt: _at,
      ),
    ),
    local: local,
    server: server,
    localSnapshotJson: '{"fixture":"retained-device-row"}',
  );
}

void _specialize(MaintenanceRecord row, String classification) {
  row.classification = classification;
  if (classification == burnerLockoutClassification) {
    row.routedTo = RoutedTo.instrumentation;
    row.component = 'Burner system';
    row.isCritical = true;
    row.burnerLockoutCase = BurnerLockoutCase(
      positions: [1],
      commonMode: false,
      cycleStage: BurnerCycleStage.firing,
      flameObservation: BurnerObservation.seen,
      sparkObservation: BurnerObservation.notChecked,
      relightAttempts: 0,
      remainsLockedOut: true,
      redHotPositions: [1],
    );
  } else if (classification == furnaceStuckupClassification) {
    row.component = 'Furnace / Inner Cover interface';
    row.plantConditionEffect = MaintenanceIssuePlantConditionEffect.stuckUp;
  } else {
    row.assetType = AssetType.base;
    row.component = baseInnerCoverAvailabilityComponent;
    row.subsystem = baseInnerCoverAvailabilitySubsystem;
    row.plantConditionEffect = MaintenanceIssuePlantConditionEffect.unavailable;
  }
  row.issueLanePlan = IssueLanePlan.initial([row.routedTo.name]);
}

class _Service implements MaintenanceCreationSuccessorService {
  DurableSubmission? saved;
  DurableSubmission? savedOnSubmit;
  int pendingReads = 0;
  int submissions = 0;
  int keeps = 0;
  String? resumed;
  MaintenanceTicketCorrectionDraft? submitted;
  MaintenanceCreationSuccessorReview? submittedReview;
  bool? acknowledged;
  String? keptReason;
  Object? submitError;
  Object? keepError;
  Object? resumeError;
  bool clearSavedOnResume = false;
  @override
  Future<DurableSubmission?> pending(String ticketId) async {
    pendingReads++;
    return saved;
  }

  @override
  Future<void> submit({
    required MaintenanceCreationSuccessorReview review,
    required MaintenanceTicketCorrectionDraft draft,
    required bool acknowledgeRetainedDifferences,
  }) async {
    submissions++;
    submitted = draft;
    submittedReview = review;
    acknowledged = acknowledgeRetainedDifferences;
    saved ??= savedOnSubmit;
    if (submitError != null) throw submitError!;
  }

  @override
  Future<void> keepServer({
    required MaintenanceCreationSuccessorReview review,
    required String reason,
    required bool acknowledgeRetainedDifferences,
  }) async {
    keeps++;
    keptReason = reason;
    acknowledged = acknowledgeRetainedDifferences;
    if (keepError != null) throw keepError!;
  }

  @override
  Future<void> resume(String submissionId) async {
    resumed = submissionId;
    if (clearSavedOnResume) saved = null;
    if (resumeError != null) throw resumeError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Saved implements DurableSubmission {
  @override
  String get submissionId => 'saved-correction-identity';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Service service;
  late int reviewReads;
  setUp(() {
    service = _Service();
    reviewReads = 0;
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    MaintenanceCreationSuccessorReview? review,
    AppUser? actor,
    Object? reviewError,
    bool detail = false,
    bool synced = false,
  }) async {
    final value = review ?? _review();
    final ticket = synced ? _ticket(synced: true) : value.local;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          _actorState.overrideWith((ref) => actor ?? _actor()),
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(ref.watch(_actorState)),
          ),
          maintenanceCreationSuccessorServiceProvider.overrideWithValue(
            service,
          ),
          maintenanceCreationSuccessorReviewProvider.overrideWith((
            ref,
            id,
          ) async {
            expect(id, 'issue-review');
            reviewReads++;
            if (reviewError != null) throw reviewError;
            return value;
          }),
          maintenanceTicketCorrectionAuditProvider.overrideWith(
            (ref, id) async => [],
          ),
        ],
        child: MaterialApp(
          home: detail
              ? MaintenanceTicketDetailScreen(ticket: ticket)
              : Scaffold(
                  body: SingleChildScrollView(
                    child: MaintenanceCreationSuccessorReviewPanel(
                      ticket: ticket,
                    ),
                  ),
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) =>
      tap(tester, 'maintenance-successor-open');

  testWidgets(
    'actual unsynced detail exposes lazy review to SI without ordinary correction',
    (tester) async {
      await pump(tester, detail: true);
      expect(find.byKey(const ValueKey('ticket-detail-correct')), findsNothing);
      expect(service.pendingReads, 0);
      expect(reviewReads, 0);
      await open(tester);
      expect(service.pendingReads, 1);
      expect(reviewReads, 1);
      expect(find.text('A · Original observation'), findsOneWidget);
      expect(find.text('B · Retained device observation'), findsOneWidget);
      expect(find.text('C · Current server observation'), findsOneWidget);
      expect(find.text('C · Server-only attendance note'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('maintenance-successor-select-remarks')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'unreadable local closure keeps reviewed reconciliation reachable from detail',
    (tester) async {
      final review = _review(
        configure: (original, local, server) {
          local
            ..status = TicketStatus.closedWithoutResolution
            ..isResolved = true
            ..metadataJson = '{retained malformed closure';
        },
      );
      await pump(tester, detail: true, review: review);
      expect(
        find.textContaining('Closure evidence needs review.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('ticket-detail-pdf')))
            .onPressed,
        isNull,
      );
      await open(tester);
      expect(find.text('A · Original observation'), findsOneWidget);
      expect(find.text('C · Current server observation'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('maintenance-successor-retained-metadataJson'),
        ),
        findsOneWidget,
      );
      await tap(tester, 'maintenance-successor-retain');
      final reason = find.byKey(
        const ValueKey('maintenance-successor-keep-reason'),
      );
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'Retain the unreadable device closure and keep the verified server issue',
      );
      await tap(tester, 'maintenance-successor-keep');
      expect(service.keeps, 1);
      expect(service.acknowledged, isTrue);
      expect(service.keptReason, contains('unreadable device closure'));
      expect(service.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'synced rows and unrelated operators do not enter successor review',
    (tester) async {
      await pump(tester, synced: true);
      expect(
        find.byKey(const ValueKey('maintenance-successor-open')),
        findsNothing,
      );
      await pump(
        tester,
        actor: _actor(role: AppRole.operations, uid: 'other'),
      );
      expect(find.text('Pending device changes'), findsNothing);
      expect(service.pendingReads, 0);
      expect(reviewReads, 0);
    },
  );

  testWidgets(
    'original reporter sees recovery guidance without supervisor mutation controls',
    (tester) async {
      await pump(
        tester,
        actor: _actor(role: AppRole.operations, uid: 'reporter'),
      );
      expect(
        find.textContaining('original reporter must recover it first'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-successor-open')),
        findsNothing,
      );
      expect(service.pendingReads, 0);
    },
  );

  testWidgets(
    'selected B values use C as correction source and preserve server-only fields after refusal',
    (tester) async {
      service.submitError = StateError(
        'The server changed. Reload the comparison.',
      );
      await pump(tester, actor: _actor(role: AppRole.admin));
      await open(tester);
      final choice = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('maintenance-successor-select-description')),
      );
      expect(choice.value, isFalse);
      await tap(tester, 'maintenance-successor-select-description');
      await tap(tester, 'maintenance-successor-retain');
      await tap(tester, 'maintenance-successor-correct');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('ticket-correction-description')),
            )
            .controller!
            .text,
        'Retained device observation',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('ticket-correction-remarks')),
            )
            .controller!
            .text,
        'Server-only attendance note',
      );
      final reason = find.byKey(const ValueKey('ticket-correction-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'Confirmed observation from retained notes',
      );
      await tester.tap(find.text('Record correction'));
      await tester.pumpAndSettle();
      expect(service.submitted!.corrections, {
        'description': 'Retained device observation',
      });
      expect(service.submittedReview!.server.version, 3);
      expect(find.textContaining('server changed'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(reason).controller!.text,
        'Confirmed observation from retained notes',
      );
      expect(find.text('Correct issue record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported physical changes require explicit retention and keep-server failure retains reason',
    (tester) async {
      service.keepError = StateError('A newer device edit was retained.');
      await pump(tester, review: _review(unsupported: true));
      await open(tester);
      expect(find.textContaining('Physical asset number'), findsOneWidget);
      final difference = find.byKey(
        const ValueKey('maintenance-successor-retained-assetNumber'),
      );
      expect(
        find.descendant(of: difference, matching: find.text('B · 8')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: difference, matching: find.text('C · 7')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('maintenance-successor-correct')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('maintenance-successor-keep')),
            )
            .onPressed,
        isNull,
      );
      await tap(tester, 'maintenance-successor-retain');
      final reason = find.byKey(
        const ValueKey('maintenance-successor-keep-reason'),
      );
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Current physical asset was verified');
      await tap(tester, 'maintenance-successor-keep');
      expect(service.keeps, 1);
      expect(service.acknowledged, isTrue);
      expect(service.keptReason, 'Current physical asset was verified');
      expect(
        tester.widget<TextField>(reason).controller!.text,
        'Current physical asset was verified',
      );
      expect(find.textContaining('newer device edit'), findsOneWidget);
    },
  );

  testWidgets(
    'registered target labels require the governed picker and never seed raw device labels',
    (tester) async {
      await pump(tester, review: _review(registered: true));
      await open(tester);
      for (final field in ['component', 'subsystem', 'tag']) {
        expect(
          find.byKey(ValueKey('maintenance-successor-select-$field')),
          findsNothing,
        );
      }
      expect(
        find.textContaining('Review a registered target'),
        findsNWidgets(3),
      );
      await tap(tester, 'maintenance-successor-select-description');
      await tap(tester, 'maintenance-successor-retain');
      await tap(tester, 'maintenance-successor-correct');
      for (final entry in {
        'component': 'Server governed component',
        'subsystem': 'Server subsystem',
        'tag': 'SERVER-TAG',
      }.entries) {
        final field = tester.widget<TextFormField>(
          find.byKey(ValueKey('ticket-correction-${entry.key}')),
        );
        expect(field.controller!.text, entry.value);
        expect(field.enabled, isFalse);
      }
      expect(
        find.text('Review registered target on this asset'),
        findsOneWidget,
      );
      expect(service.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  final targetBlockers = <String, void Function(MaintenanceRecord)>{
    'continued issue': (ticket) => ticket.continuesIssueId = 'earlier-issue',
    'linked workflow': (ticket) =>
        ticket.workflowAggregateId = 'linked-workflow',
    'quality warning': (ticket) =>
        ticket.qualityIntent = const IssueQualityIntent(
          assessment: IssueQualityAssessment.suspected,
          warningReason: 'Observed quality concern',
          abnormalityTypeId: 'quality-concern',
        ),
    'operational event evidence': (ticket) =>
        ticket.operationalEventIssueLinkIds = ['event-link'],
    'recorded work': (ticket) => ticket.actions = [
      ComponentAction(
        asset: 'Furnace 7',
        component: 'Server governed component',
        actionType: ActionType.inspection,
        createdAt: _at,
      ),
    ],
    'unreadable work': (ticket) => ticket.actionsJson = '[',
    'unreadable team evidence': (ticket) =>
        ticket.metadataJson = '{"issueLanePlan":false}',
    'unreadable quality evidence': (ticket) =>
        ticket.metadataJson = '{"qualityIntent":false}',
    'malformed metadata': (ticket) => ticket.metadataJson = '{',
    'non-object metadata': (ticket) => ticket.metadataJson = '[]',
    'null team evidence': (ticket) =>
        ticket.metadataJson = '{"issueLanePlan":null}',
    'resolved state': (ticket) => ticket.isResolved = true,
    'acknowledged issue': (ticket) => ticket
      ..status = TicketStatus.acknowledged
      ..acknowledgedByUid = 'reviewer'
      ..acknowledgedByName = 'Reviewer'
      ..acknowledgedAt = _at
      ..issueLanePlan = IssueLanePlan.initial([
        'mechanical',
      ]).acknowledge('mechanical'),
    for (final classification in [
      burnerLockoutClassification,
      furnaceStuckupClassification,
      baseInnerCoverUnavailableClassification,
    ])
      classification: (ticket) => _specialize(ticket, classification),
  };
  for (final blocker in targetBlockers.entries) {
    testWidgets(
      '${blocker.key} removes target guidance and picker from both correction entry paths',
      (tester) async {
        final review = _review(
          registered: true,
          configure: (original, local, server) => blocker.value(server),
        );
        await pump(tester, review: review);
        await open(tester);
        expect(find.textContaining('Review a registered target'), findsNothing);
        for (final field in ['component', 'subsystem', 'tag']) {
          expect(
            find.byKey(ValueKey('maintenance-successor-select-$field')),
            findsNothing,
          );
        }
        await tap(tester, 'maintenance-successor-select-description');
        await tap(tester, 'maintenance-successor-retain');
        await tap(tester, 'maintenance-successor-correct');
        expect(
          find.byKey(const ValueKey('ticket-correction-target')),
          findsNothing,
        );
        expect(
          find.text('Review registered target on this asset'),
          findsNothing,
        );
        expect(
          find.textContaining(
            'Device labels are retained without being copied',
          ),
          findsNothing,
        );
        if (const {
          'continued issue',
          'linked workflow',
        }.contains(blocker.key)) {
          final reason = find.byKey(const ValueKey('ticket-correction-reason'));
          await tester.ensureVisible(reason);
          await tester.enterText(
            reason,
            'Confirm the narrative while preserving linked equipment scope',
          );
          await tester.tap(find.text('Record correction'));
          await tester.pumpAndSettle();
          expect(service.submitted?.corrections, {
            'description': 'Retained device observation',
          });
          expect(service.submitted?.targetReferenceJson, isNull);
          expect(service.acknowledged, isTrue);
          expect(find.text('Compare saved issue changes'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MaintenanceTicketCorrectionDialog(ticket: review.server),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ticket-correction-target')),
          findsNothing,
        );
        expect(
          find.text('Review registered target on this asset'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final metadata in [null, '', '{}']) {
    testWidgets(
      'ordinary open unworked unlinked issue with legacy metadata $metadata retains a target review option',
      (tester) async {
        final ticket = _review(registered: true).server
          ..metadataJson = metadata;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MaintenanceTicketCorrectionDialog(ticket: ticket),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('ticket-correction-target')),
          findsOneWidget,
        );
        expect(
          find.textContaining('server checks related records'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'acknowledged route is retained while narrative correction remains available',
    (tester) async {
      final review = _review(
        configure: (original, local, server) {
          local.routedTo = RoutedTo.electrical;
          server
            ..status = TicketStatus.acknowledged
            ..acknowledgedByUid = 'mechanical-reviewer'
            ..acknowledgedByName = 'Mechanical reviewer'
            ..acknowledgedAt = _at
            ..issueLanePlan = IssueLanePlan.initial([
              'mechanical',
            ]).acknowledge('mechanical');
        },
      );
      await pump(tester, review: review);
      await open(tester);
      expect(
        find.byKey(const ValueKey('maintenance-successor-select-routedTo')),
        findsNothing,
      );
      expect(
        find.textContaining('Accountability is locked after acknowledgement'),
        findsOneWidget,
      );
      await tap(tester, 'maintenance-successor-select-description');
      await tap(tester, 'maintenance-successor-retain');
      await tap(tester, 'maintenance-successor-correct');
      final route = tester.widget<DropdownButtonFormField<RoutedTo>>(
        find.byKey(const ValueKey('ticket-correction-route')),
      );
      expect(route.initialValue, RoutedTo.mechanical);
      expect(route.onChanged, isNull);
      final reason = find.byKey(const ValueKey('ticket-correction-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'Verified narrative; retain earlier device routing',
      );
      await tester.tap(find.text('Record correction'));
      await tester.pumpAndSettle();
      expect(service.submitted!.corrections, {
        'description': 'Retained device observation',
      });
      expect(service.acknowledged, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final classification in [
    burnerLockoutClassification,
    furnaceStuckupClassification,
    baseInnerCoverUnavailableClassification,
  ]) {
    testWidgets(
      '$classification locked values stay retained while narrative can be corrected',
      (tester) async {
        final locked = <String>{
          'component',
          'subsystem',
          'tag',
          'classification',
          if (classification != baseInnerCoverUnavailableClassification) ...[
            'routedTo',
            'maintenanceType',
          ],
          if (classification == burnerLockoutClassification) 'isCritical',
          if (classification != burnerLockoutClassification)
            'plantConditionEffect',
        };
        final review = _review(
          configure: (original, local, server) {
            for (final row in [original, local, server]) {
              _specialize(row, classification);
            }
            local
              ..component = 'Device component'
              ..subsystem = 'Device subsystem'
              ..tag = 'DEVICE'
              ..classification = 'Device classification';
            if (locked.contains('routedTo')) {
              local.routedTo = RoutedTo.electrical;
            }
            if (locked.contains('maintenanceType')) {
              local.maintenanceType = MaintenanceType.scheduled;
            }
            if (locked.contains('isCritical')) local.isCritical = false;
            if (locked.contains('plantConditionEffect')) {
              local.plantConditionEffect =
                  MaintenanceIssuePlantConditionEffect.unfit;
            }
          },
        );
        await pump(tester, review: review);
        await open(tester);
        for (final field in locked) {
          expect(
            find.byKey(ValueKey('maintenance-successor-select-$field')),
            findsNothing,
            reason: '$field is fixed by the accepted issue',
          );
        }
        expect(
          find.textContaining('fixed by the specialized issue'),
          findsWidgets,
        );
        await tap(tester, 'maintenance-successor-select-description');
        await tap(tester, 'maintenance-successor-retain');
        await tap(tester, 'maintenance-successor-correct');
        final reason = find.byKey(const ValueKey('ticket-correction-reason'));
        await tester.ensureVisible(reason);
        await tester.enterText(
          reason,
          'Retain specialized identity and confirm narrative',
        );
        await tester.tap(find.text('Record correction'));
        await tester.pumpAndSettle();
        expect(service.submitted!.corrections, {
          'description': 'Retained device observation',
        });
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'programmatic defaults cannot override locked correction controls',
    (tester) async {
      for (final classification in [
        null,
        burnerLockoutClassification,
        furnaceStuckupClassification,
        baseInnerCoverUnavailableClassification,
      ]) {
        final ticket = _ticket(synced: true);
        if (classification != null) {
          _specialize(ticket, classification);
        } else {
          ticket
            ..status = TicketStatus.acknowledged
            ..acknowledgedByUid = 'reviewer'
            ..acknowledgedByName = 'Reviewer'
            ..acknowledgedAt = _at
            ..issueLanePlan = IssueLanePlan.initial([
              'mechanical',
            ]).acknowledge('mechanical');
        }
        MaintenanceTicketCorrectionDraft? submitted;
        final defaults = {
          'description': 'Reviewed narrative',
          'routedTo': RoutedTo.electrical.name,
          if (classification != null) ...{
            'component': 'Device component',
            'subsystem': 'Device subsystem',
            'tag': 'DEVICE',
            'classification': 'Device classification',
            if (classification != baseInnerCoverUnavailableClassification)
              'maintenanceType': MaintenanceType.scheduled.name,
            if (classification == burnerLockoutClassification)
              'isCritical': false,
            if (classification != burnerLockoutClassification)
              'plantConditionEffect': 'unfit',
          },
        };
        if (classification == baseInnerCoverUnavailableClassification) {
          defaults.remove('routedTo');
        }
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MaintenanceTicketCorrectionDialog(
                  key: ValueKey(classification),
                  ticket: ticket,
                  initialValues: defaults,
                  onSubmit: (draft) async {
                    submitted = draft;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final reason = find.byKey(const ValueKey('ticket-correction-reason'));
        await tester.ensureVisible(reason);
        await tester.enterText(
          reason,
          'Reviewed narrative with server identity retained',
        );
        await tester.tap(find.text('Record correction'));
        await tester.pumpAndSettle();
        expect(
          submitted?.corrections,
          {'description': 'Reviewed narrative'},
          reason: 'Disabled fields must preserve C even for direct callers',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'acknowledged other department is retained without blocking narrative',
    (tester) async {
      final review = _review(
        configure: (original, local, server) {
          for (final row in [original, local, server]) {
            row
              ..routedTo = RoutedTo.others
              ..otherDepartment = 'Accepted team'
              ..issueLanePlan = IssueLanePlan.initial(['others']);
          }
          local.otherDepartment = 'Device team';
          server
            ..status = TicketStatus.acknowledged
            ..acknowledgedByUid = 'team-reviewer'
            ..acknowledgedByName = 'Team reviewer'
            ..acknowledgedAt = _at
            ..issueLanePlan = IssueLanePlan.initial([
              'others',
            ]).acknowledge('others');
        },
      );
      await pump(tester, review: review);
      await open(tester);
      expect(
        find.byKey(
          const ValueKey('maintenance-successor-select-otherDepartment'),
        ),
        findsNothing,
      );
      expect(
        find.textContaining('team has already acknowledged'),
        findsOneWidget,
      );
      await tap(tester, 'maintenance-successor-select-description');
      await tap(tester, 'maintenance-successor-retain');
      await tap(tester, 'maintenance-successor-correct');
      final department = tester.widget<TextFormField>(
        find.byKey(const ValueKey('ticket-correction-other-department')),
      );
      expect(department.controller!.text, 'Accepted team');
      expect(department.enabled, isFalse);
      final reason = find.byKey(const ValueKey('ticket-correction-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'Confirm observation and retain acknowledged team',
      );
      await tester.tap(find.text('Record correction'));
      await tester.pumpAndSettle();
      expect(service.submitted!.corrections, {
        'description': 'Retained device observation',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported provenance and workflow values show complete B and C disposition',
    (tester) async {
      final review = _review(
        configure: (original, local, server) {
          local
            ..reportedBy = 'Device reporter'
            ..performedBy = 'Device worker'
            ..teamsInvolved = ['Device team']
            ..chargeNoAtEvent = 41
            ..metadataJson = '{"reviewNote":"Retained device evidence"}';
          server
            ..reportedBy = 'Server reporter'
            ..performedBy = 'Server worker'
            ..teamsInvolved = ['Server team']
            ..chargeNoAtEvent = 42
            ..workflowAggregateId = 'current-workflow'
            ..metadataJson = '{"reviewNote":"Current server evidence"}';
        },
      );
      await pump(tester, review: review);
      await open(tester);
      expect(
        find.text('Device/server differences retained, not applied'),
        findsOneWidget,
      );
      for (final entry in {
        'reportedBy': ['Device reporter', 'Server reporter'],
        'performedBy': ['Device worker', 'Server worker'],
        'teamsInvolved': ['Device team', 'Server team'],
        'chargeNoAtEvent': ['41', '42'],
        'workflowAggregateId': ['Not recorded', 'current-workflow'],
      }.entries) {
        final difference = find.byKey(
          ValueKey('maintenance-successor-retained-${entry.key}'),
        );
        expect(difference, findsOneWidget);
        expect(
          find.descendant(
            of: difference,
            matching: find.text('B · ${entry.value[0]}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: difference,
            matching: find.text('C · ${entry.value[1]}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: difference,
            matching: find.text(
              'Retain device evidence and keep the server value.',
            ),
          ),
          findsOneWidget,
        );
      }
      await tap(tester, 'maintenance-successor-evidence-B-metadataJson');
      expect(
        find.text('{"reviewNote":"Retained device evidence"}'),
        findsOneWidget,
      );
      await tap(tester, 'maintenance-successor-evidence-C-metadataJson');
      expect(
        find.text('{"reviewNote":"Current server evidence"}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uncertain original acceptance cannot be replayed by the reviewing SI',
    (tester) async {
      await pump(
        tester,
        reviewError: StateError(
          'The original reporter must recover the original submission first.',
        ),
      );
      await open(tester);
      expect(
        find.textContaining(
          'original reporter must recover the original submission',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-successor-correct')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('maintenance-successor-resume')),
        findsNothing,
      );
      expect(service.submissions, 0);
      expect(service.resumed, isNull);
    },
  );

  testWidgets(
    'saved correction resumes exact identity without loading another comparison',
    (tester) async {
      service.saved = _Saved();
      service.resumeError = StateError('Confirmation is still pending.');
      await pump(tester);
      await open(tester);
      expect(reviewReads, 0);
      expect(
        find.byKey(const ValueKey('maintenance-successor-correct')),
        findsNothing,
      );
      await tap(tester, 'maintenance-successor-resume');
      expect(service.resumed, 'saved-correction-identity');
      expect(service.submissions, 0);
      expect(find.textContaining('still pending'), findsOneWidget);
    },
  );

  testWidgets(
    'account switch blocks the retained correction form and restores its entries',
    (tester) async {
      final container = await pump(tester);
      await open(tester);
      await tap(tester, 'maintenance-successor-select-description');
      await tap(tester, 'maintenance-successor-retain');
      await tap(tester, 'maintenance-successor-correct');
      final reason = find.byKey(const ValueKey('ticket-correction-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'Reason retained across account verification',
      );
      container.read(_actorState.notifier).state = _actor(
        uid: 'another-admin',
        role: AppRole.admin,
      );
      await tester.pumpAndSettle();
      expect(find.text('Record correction'), findsNothing);
      expect(service.submissions, 0);
      container.read(_actorState.notifier).state = _actor();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(reason).controller!.text,
        'Reason retained across account verification',
      );
      expect(find.text('Record correction'), findsOneWidget);
    },
  );

  testWidgets(
    'uncertain correction retains its form and then resumes the saved identity',
    (tester) async {
      service.savedOnSubmit = _Saved();
      service.submitError = StateError(
        'The response was lost. Check the saved correction.',
      );
      await pump(tester);
      await open(tester);
      await tap(tester, 'maintenance-successor-select-description');
      await tap(tester, 'maintenance-successor-retain');
      await tap(tester, 'maintenance-successor-correct');
      final reason = find.byKey(const ValueKey('ticket-correction-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'Device observation confirmed during inspection',
      );
      await tester.tap(find.text('Record correction'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(reason).controller!.text,
        'Device observation confirmed during inspection',
      );
      expect(service.submissions, 1);
      await tester.tap(find.text('Record correction'));
      await tester.pumpAndSettle();
      expect(
        service.submissions,
        1,
        reason: 'The retained request owns this correction.',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('maintenance-successor-correct')),
        findsNothing,
      );
      await tap(tester, 'maintenance-successor-resume');
      expect(service.resumed, 'saved-correction-identity');
      expect(find.text('Compare saved issue changes'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'accepted saved correction with newer device work offers a fresh comparison',
    (tester) async {
      service.saved = _Saved();
      service.clearSavedOnResume = true;
      service.resumeError = MaintenanceSuccessorNewerDraftRetained();
      await pump(tester);
      await open(tester);
      await tap(tester, 'maintenance-successor-resume');
      expect(
        find.textContaining('Newer device work was kept unchanged'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-successor-resume')),
        findsNothing,
      );
      expect(find.text('Compare saved issue changes'), findsOneWidget);
      await tester.tap(find.text('Reload comparison'));
      await tester.pumpAndSettle();
      expect(reviewReads, 1);
      expect(
        find.byKey(const ValueKey('maintenance-successor-correct')),
        findsOneWidget,
      );
      expect(service.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'already-equal-server comparison describes local reconciliation truthfully on a phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, review: _review(equal: true));
      await open(tester);
      expect(
        find.textContaining('does not create a server correction'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('maintenance-successor-select-description')),
        findsNothing,
      );
      await tap(tester, 'maintenance-successor-retain');
      final reason = find.byKey(
        const ValueKey('maintenance-successor-keep-reason'),
      );
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'The server already contains these observations',
      );
      await tap(tester, 'maintenance-successor-keep');
      expect(service.keeps, 1);
      expect(service.submissions, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
