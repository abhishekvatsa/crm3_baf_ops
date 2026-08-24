import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/audit/providers/audit_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/issue_lane_plan.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_correction_dialog.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/maintenance_ticket_detail_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets('resolved issue dossier is readable on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final closedAt = DateTime.utc(2026, 8, 23, 12);
    final reopenedAt = closedAt.subtract(const Duration(days: 1));
    final startedAt = closedAt.subtract(const Duration(days: 3));
    final raisedAt = startedAt.add(const Duration(hours: 6));
    final earlierAction = buildBurnerComponentAction(
      ticketId: 'ticket-closed-1',
      furnaceNumber: 7,
      burnerPosition: 3,
      code: BurnerActionCode.uvDetectorReplacement,
      outcome: BurnerResolutionOutcome.returnedToService,
      microampReading: 2.875,
      performedBy: 'I&A Two',
      performedAt: closedAt.subtract(const Duration(days: 2)),
      remarks: 'UV lens cleaned and flame signal checked.',
    );
    final currentAction = ComponentAction(
      asset: 'Furnace 7',
      component: 'Burner control relay',
      hierarchyPath: const ['Electrical supply', 'Burner relay circuit'],
      system: 'Electrical supply',
      subsystem: 'Burner relay circuit',
      subComponent: 'Relay K5',
      tag: 'FR-07-BE5-RLY',
      instance: 'Installed relay 5',
      actionType: ActionType.replacement,
      replacement: ReplacementType.newPart,
      resolution: 'Relay contacts restored and tested.',
      performedBy: 'Electrical One',
      createdAt: closedAt.subtract(const Duration(hours: 2)),
      updatedAt: closedAt.subtract(const Duration(minutes: 90)),
    );
    final currentBurnerAction = buildBurnerComponentAction(
      ticketId: 'ticket-closed-1',
      furnaceNumber: 7,
      burnerPosition: 5,
      code: BurnerActionCode.feedbackReset,
      outcome: BurnerResolutionOutcome.returnedToService,
      microampReading: 3.125,
      performedBy: 'I&A One',
      performedAt: closedAt.subtract(const Duration(hours: 1)),
    );
    final ticket =
        MaintenanceRecord()
          ..firestoreId = 'ticket-closed-1'
          ..version = 8
          ..isSynced = true
          ..assetType = AssetType.furnace
          ..assetNumber = 7
          ..maintenanceType = MaintenanceType.breakdown
          ..classification = 'burnerPressureInstability'
          ..description = 'Burner pressure instability was investigated.'
          ..routedTo = RoutedTo.instrumentation
          ..component = 'Burner system'
          ..subsystem = 'Combustion control'
          ..status = TicketStatus.resolved
          ..isResolved = true
          ..loggedByUid = 'operator-1'
          ..loggedByName = 'Operator One'
          ..acknowledgedByUid = 'ia-1'
          ..acknowledgedByName = 'I&A One'
          ..acknowledgedAt = closedAt.subtract(const Duration(hours: 3))
          ..closedByUid = 'si-1'
          ..closedByName = 'SI One'
          ..reopenedByUid = 'operations-2'
          ..reopenedByName = 'Operations Two'
          ..reopenedAt = reopenedAt
          ..reopenReason = 'Lockout recurred during the next firing cycle.'
          ..startDate = startedAt
          ..endDate = closedAt
          ..createdAt = raisedAt
          ..updatedAt = closedAt
          ..remarks = 'Flame signal stabilized after attendance.'
          ..actionsJson = ComponentAction.encode([
            currentAction,
            currentBurnerAction,
          ])
          ..resolutionHistory = [
            ResolutionHistory(
              resolvedByUid: 'si-previous',
              resolvedByName: 'SI Previous',
              resolvedAt: closedAt.subtract(const Duration(days: 2)),
              actionsJson: ComponentAction.encode([earlierAction]),
              remarks: 'Reopened after the lockout recurred.',
              downtimeHours: 1.5,
              teamsInvolved: const ['I&A', 'Electrical'],
              reopenedByUid: 'operations-1',
              reopenedByName: 'Operations One',
              reopenedAt: closedAt.subtract(
                const Duration(days: 2, minutes: -20),
              ),
              reopenReason: 'The first lockout recurred after restart.',
            ),
          ]
          ..issueLanePlan = IssueLanePlan.initial([
                RoutedTo.instrumentation.name,
              ])
              .acknowledge(RoutedTo.instrumentation.name)
              .complete(RoutedTo.instrumentation.name);
    expect(
      ticket.actionsReadResult.entries
          .singleWhere((action) => action.component == 'Burner control relay')
          .replacement,
      ReplacementType.newPart,
    );
    final correction =
        AuditEvent(
            entityType: 'maintenance',
            entityId: 'ticket-closed-1',
            action: AuditAction.update,
            performedByUid: 'admin-1',
            performedByName: 'Admin One',
            reason: AuditReason.manualOverride,
            reasonNotes:
                'Corrected the issue description after checking the shift log.',
            summary: 'Maintenance ticket corrected: description',
            severity: AuditSeverity.medium,
            before: const <String, dynamic>{
              'description': 'Burner pressure was reported as normal.',
              'issueAssignedLanes': <String>['electrical', 'mechanical'],
            },
            after: const <String, dynamic>{
              'description': 'Burner pressure instability was investigated.',
              'issueAssignedLanes': <String>['instrumentation', 'mechanical'],
            },
          )
          ..timestamp = closedAt.subtract(const Duration(minutes: 20))
          ..isSynced = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          maintenanceTicketCorrectionAuditProvider.overrideWith((ref, id) {
            expect(id, 'ticket-closed-1');
            return Future<List<AuditEvent>>.value(<AuditEvent>[correction]);
          }),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: MaintenanceTicketDetailScreen(ticket: ticket, onCorrect: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Issue context'), findsOneWidget);
    expect(find.text('Accountability'), findsOneWidget);
    expect(find.text('Timeline and people'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Issue started'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Issue started'), findsOneWidget);
    expect(
      find.text(DateFormat('dd MMM yyyy, HH:mm').format(startedAt.toLocal())),
      findsOneWidget,
    );
    expect(
      find.text(
        '${DateFormat('dd MMM yyyy, HH:mm').format(raisedAt.toLocal())} · Operator One',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Lockout recurred during the next firing cycle.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reopened'), findsOneWidget);
    expect(
      find.text(
        '${DateFormat('dd MMM yyyy, HH:mm').format(reopenedAt.toLocal())} · Operations Two',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Lockout recurred during the next firing cycle.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Work recorded'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Work recorded'), findsOneWidget);
    final replacementChip = find.text(
      'Replacement: New Part',
      skipOffstage: false,
    );
    for (
      var attempt = 0;
      attempt < 6 && replacementChip.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pump();
    }
    expect(replacementChip, findsOneWidget);
    await tester.ensureVisible(replacementChip);
    await tester.pumpAndSettle();
    expect(find.text('Replacement: New Part'), findsOneWidget);
    expect(find.text('Asset: Furnace 7'), findsAtLeastNWidgets(1));
    expect(
      find.text('Hierarchy: Electrical supply / Burner relay circuit'),
      findsOneWidget,
    );
    expect(find.text('System: Electrical supply'), findsOneWidget);
    expect(find.text('Subsystem: Burner relay circuit'), findsOneWidget);
    expect(find.text('Subcomponent: Relay K5'), findsOneWidget);
    expect(find.text('Tag: FR-07-BE5-RLY'), findsOneWidget);
    expect(find.text('Instance: Installed relay 5'), findsOneWidget);
    expect(
      find.text(
        'Action time ${DateFormat('dd MMM yyyy, HH:mm').format(currentAction.createdAt.toLocal())}',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Updated ${DateFormat('dd MMM yyyy, HH:mm').format(currentAction.updatedAt!.toLocal())}',
      ),
      findsOneWidget,
    );
    expect(find.text('Burner 5'), findsOneWidget);
    expect(find.text('Feedback Reset'), findsOneWidget);
    expect(find.text('Returned To Service'), findsOneWidget);
    expect(find.text('3.125 µA'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Closure evidence'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Closure evidence'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('earlier-closure-1')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Earlier closure 1'), findsOneWidget);
    expect(find.text('1.50 hours'), findsOneWidget);
    expect(find.text('I&A, Electrical'), findsOneWidget);
    expect(find.textContaining('Burner 3'), findsOneWidget);
    expect(find.textContaining('2.875 µA'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('earlier-closure-1')),
        matching: find.text('The first lockout recurred after restart.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('earlier-closure-1')),
        matching: find.textContaining('Replacement: New Part'),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Action time ${DateFormat('dd MMM yyyy, HH:mm').format(earlierAction.createdAt.toLocal())}',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reopened after the lockout recurred.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Audited corrections'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Audited corrections'), findsOneWidget);
    final correctionCard = find.byKey(const ValueKey('ticket-correction-1'));
    await tester.scrollUntilVisible(
      correctionCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(correctionCard, findsOneWidget);
    expect(
      find.descendant(of: correctionCard, matching: find.text('Admin One')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: correctionCard,
        matching: find.text(
          'Corrected the issue description after checking the shift log.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: correctionCard,
        matching: find.text('Burner pressure was reported as normal.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: correctionCard,
        matching: find.text('Burner pressure instability was investigated.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: correctionCard,
        matching: find.text('Accountable lanes'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: correctionCard,
        matching: find.text('Electrical, Mechanical'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: correctionCard,
        matching: find.text('Instrumentation, Mechanical'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ticket-detail-correct')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('terminal correction warns the actor and locks accountability', (
    tester,
  ) async {
    final closedAt = DateTime.utc(2026, 8, 23, 12);
    final ticket =
        MaintenanceRecord()
          ..firestoreId = 'ticket-closed-2'
          ..version = 4
          ..isSynced = true
          ..assetType = AssetType.base
          ..assetNumber = 201
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Cold leak test failed after the operating cycle.'
          ..routedTo = RoutedTo.mechanical
          ..status = TicketStatus.resolved
          ..isResolved = true
          ..startDate = closedAt.subtract(const Duration(hours: 3))
          ..endDate = closedAt
          ..createdAt = closedAt.subtract(const Duration(hours: 3))
          ..updatedAt = closedAt
          ..actionsJson = '[]'
          ..resolutionHistoryJson = '[]'
          ..issueLanePlan = IssueLanePlan.initial([RoutedTo.mechanical.name])
              .acknowledge(RoutedTo.mechanical.name)
              .complete(RoutedTo.mechanical.name);

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(body: MaintenanceTicketCorrectionDialog(ticket: ticket)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Do not invent, erase, or alter evidence'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Status, asset identity, closure authority'),
      findsOneWidget,
    );
    final route = tester.widget<DropdownButtonFormField<RoutedTo>>(
      find.byKey(const ValueKey('ticket-correction-route')),
    );
    expect(route.onChanged, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'correction retains the form when Others has no department name',
    (tester) async {
      final now = DateTime.utc(2026, 8, 24, 6);
      final ticket =
          MaintenanceRecord()
            ..firestoreId = 'ticket-open-other-correction'
            ..version = 3
            ..isSynced = true
            ..assetType = AssetType.base
            ..assetNumber = 201
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Cold leak test failed after the operating cycle.'
            ..routedTo = RoutedTo.mechanical
            ..status = TicketStatus.open
            ..isResolved = false
            ..startDate = now.subtract(const Duration(hours: 2))
            ..createdAt = now.subtract(const Duration(hours: 2))
            ..updatedAt = now
            ..actionsJson = '[]'
            ..resolutionHistoryJson = '[]'
            ..issueLanePlan = IssueLanePlan.initial([RoutedTo.mechanical.name]);

      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          home: Scaffold(
            body: MaintenanceTicketCorrectionDialog(ticket: ticket),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('ticket-correction-route')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other department').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('ticket-correction-other-department')),
        findsOneWidget,
      );

      final reason = find.byKey(const ValueKey('ticket-correction-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(
        reason,
        'Verified routing correction for accountable ownership.',
      );
      await tester.tap(find.text('Record correction'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the accountable department'), findsOneWidget);
      expect(
        find.text('Verified routing correction for accountable ownership.'),
        findsOneWidget,
      );
      expect(find.text('Correct issue record'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('primary-route correction retains a secondary Other team', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 25, 6);
    final ticket =
        MaintenanceRecord()
          ..firestoreId = 'ticket-secondary-other-correction'
          ..version = 3
          ..isSynced = true
          ..assetType = AssetType.base
          ..assetNumber = 117
          ..maintenanceType = MaintenanceType.breakdown
          ..description = 'Electrical and contractor attendance required.'
          ..routedTo = RoutedTo.electrical
          ..otherDepartment = 'Hydraulics contractor'
          ..status = TicketStatus.open
          ..isResolved = false
          ..startDate = now.subtract(const Duration(hours: 2))
          ..createdAt = now.subtract(const Duration(hours: 2))
          ..updatedAt = now
          ..actionsJson = '[]'
          ..resolutionHistoryJson = '[]'
          ..issueLanePlan = IssueLanePlan.initial(const <String>[
            'electrical',
            'others',
          ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: BafAppTheme.light,
        home: Scaffold(body: MaintenanceTicketCorrectionDialog(ticket: ticket)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hydraulics contractor'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ticket-correction-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mechanical').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ticket-correction-other-department')),
      findsOneWidget,
    );
    expect(find.text('Hydraulics contractor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
