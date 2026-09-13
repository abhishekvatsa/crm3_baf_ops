import 'dart:async';

import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_evidence_snapshot.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/inspection_programmes_screen.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_provider.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_target_context_provider.dart';
import 'package:crm3_baf_ops/features/inspections/repositories/inspection_repository.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_types.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'inspection_campaign_model_test.dart'
    show innerCoverCampaignMap, observationMap, findingMap;

void main() {
  testWidgets(
    'corrected-away finding shows review decision and disables technical verification',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final (campaign, observation) = _relocatedCorrectionFixture();
      final finding = InspectionFinding.fromMap({
        ...findingMap(),
        'campaignId': campaign.id,
        'targetKey': observation.targetKey,
        'assetTypeKey': observation.assetTypeKey,
        'assetClassId': observation.assetClassId,
        'assetInstanceId': observation.assetInstanceId,
        'assetNumber': observation.assetNumber,
        'hostAssetNumber': observation.hostAssetNumber,
        'subjectSerialNumber': observation.subjectSerialNumber,
        'componentNodeId': observation.componentNodeId,
        'componentName': observation.componentName,
        'physicalPosition': observation.physicalPosition,
        'currentObservationId': observation.id,
        'latestObservedAt': observation.observedAt.toUtc().toIso8601String(),
        'firstObservedAt': observation.observedAt
            .subtract(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
        'effectiveAdverseObservationCount': 0,
        'evidenceReviewRequired': true,
        'evidenceReviewReason': 'inspection-episode-adverse-basis-corrected',
      }, 'finding-1');
      await tester.pumpWidget(
        _testApp(campaign, observations: [observation], findings: [finding]),
      );
      await tester.pumpAndSettle();
      final actions = find.byTooltip('Finding actions');
      await tester.scrollUntilVisible(
        actions,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('0 effective abnormal readings'), findsOneWidget);
      expect(
        find.textContaining('record a decision before closing'),
        findsOneWidget,
      );
      await tester.tap(actions);
      await tester.pumpAndSettle();
      final verify = find.widgetWithText(
        PopupMenuItem<String>,
        'Verify from later reading',
      );
      expect(tester.widget<PopupMenuItem<String>>(verify).enabled, isFalse);
      expect(find.text('Invalidate with reason'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final currentComponentAvailable in [true, false]) {
    testWidgets(
      'correction retains historical location, time and component with live component $currentComponentAvailable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final (campaign, observation) = _relocatedCorrectionFixture();
        final sent = <WorkflowCommand>[];
        await tester.pumpWidget(
          _testApp(
            campaign,
            observations: [observation],
            nodes: currentComponentAvailable ? [_shellNode()] : [],
            executeCommand: (command) async {
              sent.add(command);
              return WorkflowCommandReceipt(
                commandId: command.commandId,
                resultKey: 'inspection-observation-recorded',
                aggregateVersion: campaign.version + 1,
                result: const {},
                appliedAt: DateTime.utc(2026, 9, 13),
              );
            },
          ),
        );
        await tester.pumpAndSettle();
        final cell = find.byKey(
          ValueKey(
            'inspection-audit-cell-${campaign.targets.single.targetKey}',
          ),
        );
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Correct current reading'));
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text('Base 206 (N4) · Original shell label · Shell'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.textContaining('Base 207'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(
              DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format(observation.observedAt.toLocal()),
            ),
          ),
          findsOneWidget,
        );
        final submit = find.widgetWithText(FilledButton, 'Record correction');
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(sent, hasLength(1));
        final command = sent.single;
        expect(command.expectedVersion, campaign.version);
        expect(command.payload['targetContextRevision'], 2);
        expect(command.payload['supersedesObservationId'], observation.id);
        expect(
          command.payload['observedAt'],
          observation.observedAt.toUtc().toIso8601String(),
        );
        expect(command.payload['componentNodeId'], observation.componentNodeId);
        expect(command.payload['componentNodeVersion'], 2);
        expect(command.payload['componentName'], 'Original shell label');
        expect(command.payload['hierarchyPath'], observation.hierarchyPath);
        expect(
          command.payload['physicalPosition'],
          observation.physicalPosition,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'context review hides retained evidence on account switch or error and restores it only for its origin',
    (tester) async {
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
      );
      final accounts = StreamController<AppUser?>();
      final capability = Completer<void>();
      final repository = _ContextRepository(campaign.targets.first)
        ..paused = Completer<Map<String, Object?>>();
      final sent = <WorkflowCommand>[];
      await tester.pumpWidget(
        _testApp(
          campaign,
          accounts: accounts.stream,
          contextRepository: repository,
          contextCapability: (_) => capability.future,
          executeCommand: (command) async {
            sent.add(command);
            return WorkflowCommandReceipt(
              commandId: command.commandId,
              resultKey: 'inspection-target-context-revalidated',
              aggregateVersion: campaign.version + 1,
              result: const {},
              appliedAt: DateTime.utc(2026, 9, 13),
            );
          },
        ),
      );
      accounts.add(_admin());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Campaign actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review target after repair or relocation'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inspection-context-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Furnace 22 ·').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check current physical context'));
      await tester.pump();
      accounts.add(
        AppUser(
          uid: 'admin-2',
          name: 'Other admin',
          email: 'other@example.invalid',
          roles: const [AppRole.admin],
          isApproved: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await tester.pump();
      repository.paused!.complete({
        ...campaign.targets.first.contextIdentity,
        'assetInstanceVersion': 2,
      });
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspection-context-reason')),
        findsNothing,
      );
      expect(sent, isEmpty);
      repository.paused = null;
      accounts.add(_admin());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check current physical context'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('inspection-context-reason')),
        'Original manager reviewed the same Furnace.',
      );
      expect(find.text('Current: Furnace 22 · revision 2'), findsOneWidget);
      accounts.add(
        AppUser(
          uid: 'admin-2',
          name: 'Other admin',
          email: 'other@example.invalid',
          roles: const [AppRole.admin],
          isApproved: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspection-context-target')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('inspection-context-reason')),
        findsNothing,
      );
      expect(find.textContaining('Original: Furnace 22'), findsNothing);
      expect(find.textContaining('Current: Furnace 22'), findsNothing);
      expect(find.textContaining('Same physical ID:'), findsNothing);
      expect(
        find.text('Original manager reviewed the same Furnace.'),
        findsNothing,
      );
      expect(sent, isEmpty);
      accounts.add(_admin());
      await tester.pumpAndSettle();
      expect(find.text('Current: Furnace 22 · revision 2'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('inspection-context-reason')),
            )
            .controller!
            .text,
        'Original manager reviewed the same Furnace.',
      );
      accounts.addError(StateError('Account service unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('inspection-context-target')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('inspection-context-reason')),
        findsNothing,
      );
      expect(find.textContaining('Original: Furnace 22'), findsNothing);
      expect(find.textContaining('Current: Furnace 22'), findsNothing);
      expect(find.textContaining('Same physical ID:'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(
                FilledButton,
                'Approve same-target follow-up',
              ),
            )
            .onPressed,
        isNull,
      );
      accounts.add(_admin());
      await tester.pumpAndSettle();
      expect(find.text('Current: Furnace 22 · revision 2'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byKey(const ValueKey('inspection-context-target')),
            )
            .initialValue,
        campaign.targets.first.targetKey,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('inspection-context-reason')),
            )
            .controller!
            .text,
        'Original manager reviewed the same Furnace.',
      );
      await tester.ensureVisible(find.text('Approve same-target follow-up'));
      await tester.tap(find.text('Approve same-target follow-up'));
      await tester.pump();
      accounts.add(
        AppUser(
          uid: 'admin-2',
          name: 'Other admin',
          email: 'other@example.invalid',
          roles: const [AppRole.admin],
          isApproved: true,
          createdAt: DateTime.utc(2026),
        ),
      );
      await tester.pump();
      capability.complete();
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      accounts.add(_admin());
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Retry same review'));
      await tester.tap(find.text('Retry same review'));
      await tester.pumpAndSettle();
      expect(
        sent.single.payload['reason'],
        'Original manager reviewed the same Furnace.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(accounts.close);
    },
  );

  testWidgets(
    'same-target review requires fresh capability and retains its original command after an ambiguous response',
    (tester) async {
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
      );
      final sent = <WorkflowCommand>[];
      var capabilityChecks = 0;
      await tester.pumpWidget(
        _testApp(
          campaign,
          contextRepository: _ContextRepository(campaign.targets.first),
          contextCapability: (uid) async {
            expect(uid, 'admin-1');
            capabilityChecks += 1;
            if (capabilityChecks == 1) {
              throw StateError('Server does not support context reviews yet.');
            }
          },
          executeCommand: (command) async {
            sent.add(command);
            if (sent.length == 1) throw TimeoutException('Response lost');
            return WorkflowCommandReceipt(
              commandId: command.commandId,
              resultKey: 'inspection-target-context-revalidated',
              aggregateVersion: campaign.version + 1,
              result: const {},
              appliedAt: DateTime.utc(2026, 9, 13),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Campaign actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review target after repair or relocation'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inspection-context-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Furnace 22 ·').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check current physical context'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve same-target follow-up'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(find.textContaining('Explain why'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('inspection-context-reason')),
        'Same Furnace inspected after repair.',
      );
      await tester.ensureVisible(find.text('Approve same-target follow-up'));
      await tester.tap(find.text('Approve same-target follow-up'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      await tester.ensureVisible(find.text('Retry same review'));
      await tester.tap(find.text('Retry same review'));
      await tester.pumpAndSettle();
      expect(
        sent.single.payload['targetKey'],
        campaign.targets.first.targetKey,
      );
      expect(sent.single.payload['expectedContextRevision'], 0);
      expect(
        (sent.single.payload['reviewedContext'] as Map)['assetInstanceVersion'],
        2,
      );
      expect(
        find.byKey(const ValueKey('inspection-context-reason')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('inspection-context-reason')),
            )
            .readOnly,
        isTrue,
      );
      await tester.ensureVisible(find.text('Retry same review'));
      await tester.tap(find.text('Retry same review'));
      await tester.pumpAndSettle();
      expect(sent.length, 2);
      expect(capabilityChecks, 3);
      expect(sent.first.payload['reviewerUid'], 'admin-1');
      expect(sent.last.toMap(), sent.first.toMap());
      expect(find.text('Review the same physical target'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closed campaign reopening requires a reason and preserves its identity',
    (tester) async {
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
        status: InspectionCampaignStatus.closed,
      );
      WorkflowCommand? submitted;
      await tester.pumpWidget(
        _testApp(
          campaign,
          executeCommand: (command) async {
            submitted = command;
            return WorkflowCommandReceipt(
              commandId: command.commandId,
              resultKey: 'inspection-campaign-open',
              aggregateVersion: campaign.version + 1,
              result: {'campaignId': campaign.id, 'status': 'open'},
              appliedAt: DateTime.utc(2026, 9, 12, 12),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Reopen for verification'));
      await tester.pumpAndSettle();
      expect(find.textContaining('original closure'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Reopen campaign'),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason'),
        'Verify the completed corrective maintenance.',
      );
      await tester.pump();
      await tester.tap(find.text('Reopen campaign'));
      await tester.pumpAndSettle();
      expect(submitted?.type, WorkflowCommandType.setInspectionCampaignStatus);
      expect(submitted?.aggregateId, campaign.id);
      expect(submitted?.expectedVersion, campaign.version);
      expect(submitted?.payload, {
        'status': 'open',
        'reason': 'Verify the completed corrective maintenance.',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a cached closed campaign cannot request reopening', (
    tester,
  ) async {
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
      status: InspectionCampaignStatus.closed,
    );
    await tester.pumpWidget(_testApp(campaign, campaignServerVerified: false));
    await tester.pumpAndSettle();
    final action = tester.widget<IconButton>(
      find.byKey(const ValueKey('reopen-inspection-campaign-action')),
    );
    expect(action.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  test('report evidence revision detects an observation-set change', () {
    final observedAt = DateTime.utc(2026, 9, 5, 10);
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
      disposition: InspectionTargetDisposition.observed,
      lastObservationId: 'reading-1',
      lastObservedAt: observedAt,
    );
    final observation = _observation(
      campaign: campaign,
      target: campaign.targets.single,
      id: 'reading-1',
      observedAt: observedAt,
      recordedAt: observedAt,
      value: true,
    );
    final first = InspectionCampaignReportEvidence(
      campaign: campaign,
      observations: <InspectionObservation>[observation],
      findings: const <InspectionFinding>[],
    );
    final same = InspectionCampaignReportEvidence(
      campaign: campaign,
      observations: <InspectionObservation>[observation],
      findings: const <InspectionFinding>[],
    );
    final changed = InspectionCampaignReportEvidence(
      campaign: campaign,
      observations: const <InspectionObservation>[],
      findings: const <InspectionFinding>[],
    );

    expect(first.hasSameRevisionAs(same), isTrue);
    expect(first.hasSameRevisionAs(changed), isFalse);
    expect(first.isInternallyComplete, isTrue);
    expect(changed.isInternallyComplete, isFalse);
  });

  testWidgets('audit PDF action stays hidden for an empty campaign', (
    tester,
  ) async {
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
    );

    await tester.pumpWidget(_testApp(campaign));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inspection-campaign-pdf-action')),
      findsNothing,
    );
  });

  testWidgets('admin can request deletion of a server-verified unused audit', (
    tester,
  ) async {
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
    );
    WorkflowCommand? submitted;

    await tester.pumpWidget(
      _testApp(
        campaign,
        executeCommand: (command) async {
          submitted = command;
          return WorkflowCommandReceipt(
            commandId: command.commandId,
            resultKey: 'inspection-campaign-unused-deleted',
            aggregateVersion: campaign.version,
            result: <String, Object?>{
              'campaignId': campaign.id,
              'auditId': command.commandId,
            },
            appliedAt: DateTime.utc(2026, 9, 7, 16),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Campaign actions'));
    await tester.pumpAndSettle();
    final item = tester.widget<PopupMenuItem<String>>(
      find.byKey(const ValueKey('delete-unused-inspection-campaign-action')),
    );
    expect(item.enabled, isTrue);

    await tester.tap(find.text('Delete unused audit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Reason'),
      'Remove a mistakenly opened trial audit.',
    );
    await tester.pump();
    await tester.tap(find.text('Delete audit'));
    await tester.pumpAndSettle();

    expect(submitted?.type, WorkflowCommandType.deleteUnusedInspectionCampaign);
    expect(submitted?.aggregateId, campaign.id);
    expect(submitted?.expectedVersion, campaign.version);
    expect(submitted?.payload, {
      'confirmation': 'DELETE ${campaign.id}',
      'reason': 'Remove a mistakenly opened trial audit.',
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('audit PDF action appears after a reading exists', (
    tester,
  ) async {
    final observedAt = DateTime.utc(2026, 9, 5, 10);
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
      disposition: InspectionTargetDisposition.observed,
      lastObservationId: 'reading-1',
      lastObservedAt: observedAt,
    );

    await tester.pumpWidget(
      _testApp(
        campaign,
        observations: <InspectionObservation>[
          _observation(
            campaign: campaign,
            target: campaign.targets.single,
            id: 'reading-1',
            observedAt: observedAt,
            recordedAt: observedAt,
            value: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inspection-campaign-pdf-action')),
      findsOneWidget,
    );
    expect(find.byTooltip('Create audit PDF'), findsOneWidget);
  });

  testWidgets('audit PDF action requests fresh authoritative evidence', (
    tester,
  ) async {
    final observedAt = DateTime.utc(2026, 9, 5, 10);
    final campaign = _assetCampaign(
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
      disposition: InspectionTargetDisposition.observed,
      lastObservationId: 'reading-1',
      lastObservedAt: observedAt,
    );
    final observation = _observation(
      campaign: campaign,
      target: campaign.targets.single,
      id: 'reading-1',
      observedAt: observedAt,
      recordedAt: observedAt,
      value: true,
    );
    final pendingRead = Completer<InspectionCampaignReportEvidence>();
    var authoritativeReadRequested = false;

    await tester.pumpWidget(
      _testApp(
        campaign,
        observations: <InspectionObservation>[observation],
        reportEvidenceLoader: () {
          authoritativeReadRequested = true;
          return pendingRead.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('inspection-campaign-pdf-action')),
    );
    await tester.pump();

    expect(authoritativeReadRequested, isTrue);
  });

  for (final unverifiedSource in ['campaign', 'observations', 'findings']) {
    testWidgets('audit PDF stays disabled for cached $unverifiedSource', (
      tester,
    ) async {
      final observedAt = DateTime.utc(2026, 9, 5, 10);
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
        disposition: InspectionTargetDisposition.observed,
        lastObservationId: 'reading-1',
        lastObservedAt: observedAt,
      );

      await tester.pumpWidget(
        _testApp(
          campaign,
          observations: <InspectionObservation>[
            _observation(
              campaign: campaign,
              target: campaign.targets.single,
              id: 'reading-1',
              observedAt: observedAt,
              recordedAt: observedAt,
              value: true,
            ),
          ],
          campaignServerVerified: unverifiedSource != 'campaign',
          observationsServerVerified: unverifiedSource != 'observations',
          findingsServerVerified: unverifiedSource != 'findings',
        ),
      );
      await tester.pumpAndSettle();

      final action = tester.widget<IconButton>(
        find.byKey(const ValueKey('inspection-campaign-pdf-action')),
      );
      expect(action.onPressed, isNull);
      expect(
        find.byTooltip('Reconnect to verify complete audit data'),
        findsOneWidget,
      );
    });
  }

  testWidgets(
    'Inner Cover audit keeps Base identity and headings visible deep in the grid',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final campaign = _innerCoverCampaign();

      await tester.pumpWidget(_testApp(campaign));
      await tester.pumpAndSettle();

      final corner = find.byKey(
        const ValueKey('inspection-audit-fixed-corner'),
      );
      final base222 = find.byKey(
        const ValueKey(
          'inspection-audit-row-base-222|link-inner-cover-n22-base-222',
        ),
      );
      final verticalPane = find.byKey(
        const ValueKey('inspection-audit-vertical-scroll'),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pumpAndSettle();
      final cornerTop = tester.getTopLeft(corner).dy;

      await tester.drag(verticalPane, const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(find.text('Base 222 (N22)').hitTestable(), findsOneWidget);
      expect(tester.getTopLeft(corner).dy, moreOrLessEquals(cornerTop));
      expect(find.text('Base (Inner Cover)'), findsOneWidget);

      final rowLeft = tester.getTopLeft(base222).dx;
      final header = find.byKey(
        const ValueKey('inspection-audit-header-inner-cover-shell|Check 8'),
      );
      final scrollCell = find.byKey(
        const ValueKey(
          'inspection-audit-cell-class-inner-cover:inner-cover-n22|inner-cover-shell|Check 1|link:link-inner-cover-n22-base-222',
        ),
      );
      final cell = find.byKey(
        const ValueKey(
          'inspection-audit-cell-class-inner-cover:inner-cover-n22|inner-cover-shell|Check 8|link:link-inner-cover-n22-base-222',
        ),
      );
      final headerBefore = tester.getTopLeft(header).dx;

      await tester.drag(scrollCell, const Offset(-900, 0));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(base222).dx, moreOrLessEquals(rowLeft));
      expect(tester.getTopLeft(header).dx, lessThan(headerBefore));
      expect(header.hitTestable(), findsOneWidget);
      expect(cell.hitTestable(), findsOneWidget);
      expect(
        tester.getCenter(header).dx,
        moreOrLessEquals(tester.getCenter(cell).dx),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final subject in [
    (
      assetTypeKey: 'furnace',
      assetClassId: 'class-furnace',
      assetInstanceId: 'furnace-22',
      assetNumber: 22,
      label: 'Furnace 22',
      heading: 'Furnace',
    ),
    (
      assetTypeKey: 'base',
      assetClassId: 'class-base',
      assetInstanceId: 'base-205',
      assetNumber: 205,
      label: 'Base 205',
      heading: 'Base',
    ),
  ]) {
    testWidgets(
      '${subject.heading} campaign uses its governed asset identity',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final campaign = _assetCampaign(
          assetTypeKey: subject.assetTypeKey,
          assetClassId: subject.assetClassId,
          assetInstanceId: subject.assetInstanceId,
          assetNumber: subject.assetNumber,
          label: subject.label,
        );

        await tester.pumpWidget(_testApp(campaign));
        await tester.pumpAndSettle();
        for (
          var attempt = 0;
          attempt < 4 &&
              find
                  .byKey(const ValueKey('inspection-audit-fixed-corner'))
                  .evaluate()
                  .isEmpty;
          attempt += 1
        ) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -240));
          await tester.pumpAndSettle();
        }

        final row = find.byKey(
          ValueKey('inspection-audit-row-${subject.assetInstanceId}'),
        );
        expect(find.text(subject.heading), findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text(subject.label)),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final viewport in [
    (size: const Size(320, 720), scale: 2.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(900, 800), scale: 1.0),
  ]) {
    testWidgets('reusable audit board remains usable at $viewport', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(viewport.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _testApp(_innerCoverCampaign(), textScale: viewport.scale),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (
        var attempt = 0;
        attempt < 4 &&
            find
                .byKey(const ValueKey('inspection-audit-fixed-corner'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const ValueKey('inspection-audit-fixed-corner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('inspection-audit-scrollable-grid')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('adding governed targets inherits the campaign audit columns', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_testApp(_innerCoverCampaign(), textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Campaign actions'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Add governed targets'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Check 1, Check 2, Check 3, Check 4, Check 5, Check 6, Check 7, Check 8',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'audit board follows the server-certified current observation identity',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final laterOccurrence = DateTime.utc(2026, 9, 5, 10);
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
        disposition: InspectionTargetDisposition.observed,
        lastObservationId: 'backdated-follow-up',
        lastObservedAt: laterOccurrence.subtract(const Duration(hours: 1)),
      );
      final target = campaign.targets.single;
      final observations = <InspectionObservation>[
        _observation(
          campaign: campaign,
          target: target,
          id: 'later-occurrence',
          observedAt: laterOccurrence,
          recordedAt: laterOccurrence,
          value: true,
        ),
        _observation(
          campaign: campaign,
          target: target,
          id: 'backdated-follow-up',
          observedAt: laterOccurrence.subtract(const Duration(hours: 1)),
          recordedAt: laterOccurrence.add(const Duration(hours: 1)),
          value: false,
        ),
      ];

      await tester.pumpWidget(_testApp(campaign, observations: observations));
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 4 &&
            find
                .byKey(const ValueKey('inspection-audit-fixed-corner'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pumpAndSettle();
      }

      final cell = find.byKey(
        ValueKey('inspection-audit-cell-${target.targetKey}'),
      );
      expect(
        find.descendant(of: cell, matching: find.text('No')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('Yes')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'audit board uses the latest occurrence when no certified receipt exists',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final latest = DateTime.utc(2026, 9, 5, 10);
      final campaign = _assetCampaign(
        assetTypeKey: 'furnace',
        assetClassId: 'class-furnace',
        assetInstanceId: 'furnace-22',
        assetNumber: 22,
        label: 'Furnace 22',
      );
      final target = campaign.targets.single;
      final observations = <InspectionObservation>[
        _observation(
          campaign: campaign,
          target: target,
          id: 'older-reading',
          observedAt: latest.subtract(const Duration(hours: 1)),
          recordedAt: latest.subtract(const Duration(hours: 1)),
          value: false,
        ),
        _observation(
          campaign: campaign,
          target: target,
          id: 'latest-reading',
          observedAt: latest,
          recordedAt: latest,
          value: true,
        ),
      ];

      await tester.pumpWidget(_testApp(campaign, observations: observations));
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 4 &&
            find
                .byKey(const ValueKey('inspection-audit-fixed-corner'))
                .evaluate()
                .isEmpty;
        attempt += 1
      ) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -240));
        await tester.pumpAndSettle();
      }

      final cell = find.byKey(
        ValueKey('inspection-audit-cell-${target.targetKey}'),
      );
      expect(
        find.descendant(of: cell, matching: find.text('Yes')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('No')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _testApp(
  InspectionCampaign campaign, {
  double textScale = 1,
  List<InspectionObservation> observations = const <InspectionObservation>[],
  List<InspectionFinding> findings = const <InspectionFinding>[],
  bool campaignServerVerified = true,
  bool observationsServerVerified = true,
  bool findingsServerVerified = true,
  Future<InspectionCampaignReportEvidence> Function()? reportEvidenceLoader,
  Future<WorkflowCommandReceipt> Function(WorkflowCommand)? executeCommand,
  InspectionRepository? contextRepository,
  Stream<AppUser?>? accounts,
  Future<void> Function(String)? contextCapability,
  List<AssetHierarchyNode>? nodes,
}) => ProviderScope(
  overrides: [
    currentAppUserProvider.overrideWith(
      (_) => accounts ?? Stream<AppUser?>.value(_admin()),
    ),
    if (contextRepository != null)
      inspectionRepositoryProvider.overrideWith((_) => contextRepository),
    if (contextRepository != null)
      inspectionTargetContextCapabilityProvider.overrideWith(
        (_) => contextCapability ?? (_) async {},
      ),
    inspectionCampaignsProvider.overrideWith(
      (_) => Stream.value(
        InspectionEvidenceSnapshot<InspectionCampaign>(
          records: <InspectionCampaign>[campaign],
          isServerVerified: campaignServerVerified,
        ),
      ),
    ),
    inspectionObservationsProvider(campaign.id).overrideWith(
      (_) => Stream.value(
        InspectionEvidenceSnapshot<InspectionObservation>(
          records: observations,
          isServerVerified: observationsServerVerified,
        ),
      ),
    ),
    inspectionFindingsProvider(campaign.id).overrideWith(
      (_) => Stream.value(
        InspectionEvidenceSnapshot<InspectionFinding>(
          records: findings,
          isServerVerified: findingsServerVerified,
        ),
      ),
    ),
    inspectionCampaignReportEvidenceProvider(campaign.id).overrideWith((_) {
      if (reportEvidenceLoader != null) return reportEvidenceLoader();
      return Future<InspectionCampaignReportEvidence>.value(
        InspectionCampaignReportEvidence(
          campaign: campaign,
          observations: observations,
          findings: findings,
        ),
      );
    }),
    assetHierarchyNodesProvider(campaign.assetClassId).overrideWith(
      (_) => Stream.value(
        nodes ??
            (campaign.assetTypeKey == 'innerCover'
                ? <AssetHierarchyNode>[_shellNode()]
                : const <AssetHierarchyNode>[]),
      ),
    ),
    allAssetInstancesProvider.overrideWith((_) => Stream.value(const [])),
    innerCoverProfilesProvider.overrideWith((_) => Stream.value(const [])),
    innerCoverAssignmentsProvider.overrideWith((_) => Stream.value(const [])),
    if (executeCommand != null)
      workflowCommandControllerProvider.overrideWith(
        (_) => WorkflowCommandController.forTesting(
          executeCommand: executeCommand,
          pullProjections: () async {},
        ),
      ),
  ],
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: InspectionCampaignDetailScreen(campaignId: campaign.id),
  ),
);

(InspectionCampaign, InspectionObservation) _relocatedCorrectionFixture() {
  final map = innerCoverCampaignMap();
  final original =
      (map['targetPopulation'] as List).single as Map<String, dynamic>;
  Map<String, dynamic> relocated(int base) => {
    ...original,
    'targetKey':
        'class-inner-cover:inner-cover-n4|inner-cover-shell|Shell|link:link-n4-base-$base',
    'assetNumber': base,
    'assetInstanceVersion': base - 198,
    'hostAssetInstanceId': 'base-$base',
    'hostAssetNumber': base,
    'hostAssetInstanceName': 'Base $base',
    'linkageId': 'link-n4-base-$base',
    'linkedAt': '2026-08-${base - 184}T04:00:00.000Z',
  };
  const observedAt = '2026-08-22T05:17:36.123456Z';
  final current = {
    ...original,
    'contextReview': {
      'schemaVersion': 1,
      'revision': 2,
      'auditId': 'review-2',
      'reviewedAt': '2026-08-23T04:00:00.000Z',
      'reviewedByUid': 'admin-1',
      'reviewedByName': 'Admin One',
      'reason': 'Verified relocation of the same serial.',
      'context': relocated(207),
    },
    'disposition': 'observed',
    'lastObservationId': 'historical-reading',
    'lastObservedAt': observedAt,
  };
  map.addAll({
    'version': 6,
    'targetPopulation': [current],
    'targetDispositionCounts': {
      'pending': 0,
      'observed': 1,
      'deferred': 0,
      'unavailable': 0,
      'excludedWithReason': 0,
      'requiresReaudit': 0,
    },
    'observationCount': 1,
    'distinctTargetKeys': [original['targetKey']],
    'latestObservationAt': observedAt,
  });
  final observation = InspectionObservation.fromMap({
    ...observationMap(),
    ...relocated(206),
    'observationId': 'historical-reading',
    'campaignId': map['campaignId'],
    'definition': map['definition'],
    'targetKey': original['targetKey'],
    'targetContextRevision': 1,
    'targetContextAuditId': 'review-1',
    'targetContextOriginalLinkageId': original['linkageId'],
    'componentNodeVersion': 2,
    'componentName': 'Original shell label',
    'hierarchyPath': ['Inner Cover', 'Original shell label'],
    'observedAt': observedAt,
    'recordedAt': '2026-08-22T05:18:00.000Z',
  }, 'historical-reading');
  return (
    InspectionCampaign.fromMap(map, map['campaignId'] as String),
    observation,
  );
}

AppUser _admin() => AppUser(
  uid: 'admin-1',
  name: 'Admin One',
  email: 'admin@example.invalid',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 1, 1),
);

class _ContextRepository extends Fake implements InspectionRepository {
  _ContextRepository(this.target);
  final InspectionCampaignTarget target;
  Completer<Map<String, Object?>>? paused;
  @override
  Future<Map<String, Object?>> readTargetContext(
    InspectionCampaignTarget original,
  ) async => paused == null
      ? {...target.contextIdentity, 'assetInstanceVersion': 2}
      : paused!.future;
}

AssetHierarchyNode _shellNode() => AssetHierarchyNode(
  id: 'inner-cover-shell',
  assetClassId: 'class-inner-cover',
  nodeType: AssetHierarchyNodeType.component,
  name: 'Shell condition',
  contactArrangement: ElectricalContactArrangement.notStated,
  ownershipStatus: AssetOwnershipStatus.unassigned,
  sortOrder: 1,
  ancestorNodeIds: const [],
  hierarchyPath: const ['Inner Cover', 'Shell condition'],
  activeChildCount: 0,
  status: AssetHierarchyStatus.active,
  version: 3,
  createdAt: DateTime.utc(2026, 1, 1),
  createdByUid: 'admin-1',
  updatedAt: DateTime.utc(2026, 1, 1),
  updatedByUid: 'admin-1',
  lastMutationId: 'seed-node',
);

InspectionCampaign _innerCoverCampaign() {
  final now = DateTime.utc(2026, 9, 5, 4);
  final positions = List<String>.generate(8, (index) => 'Check ${index + 1}');
  final targets = <InspectionCampaignTarget>[
    for (var index = 0; index < 22; index++)
      for (final position in positions)
        InspectionCampaignTarget(
          targetKey:
              'class-inner-cover:inner-cover-n${index + 1}|inner-cover-shell|$position|link:link-inner-cover-n${index + 1}-base-${index + 201}',
          assetTypeKey: 'innerCover',
          assetClassId: 'class-inner-cover',
          assetNumber: index + 201,
          assetInstanceId: 'inner-cover-n${index + 1}',
          assetInstanceVersion: 1,
          assetInstanceName: 'Inner Cover N${index + 1}',
          hostAssetClassId: 'class-base',
          hostAssetInstanceId: 'base-${index + 201}',
          hostAssetInstanceVersion: 1,
          hostAssetNumber: index + 201,
          hostAssetInstanceName: 'Base ${index + 201}',
          subjectSerialNumber: 'N${index + 1}',
          linkageId: 'link-inner-cover-n${index + 1}-base-${index + 201}',
          linkageVersion: 1,
          linkedAt: now,
          componentNodeId: 'inner-cover-shell',
          physicalPosition: position,
          disposition: InspectionTargetDisposition.pending,
          dispositionReason: null,
          dispositionAt: now,
          dispositionByUid: 'admin-1',
          dispositionByName: 'Admin One',
          addedLater: false,
          lastObservationId: null,
          lastObservedAt: null,
        ),
  ];
  return InspectionCampaign(
    id: 'campaign-inner-covers',
    version: 1,
    status: InspectionCampaignStatus.open,
    definition: const FrozenInspectionDefinition(
      id: 'definition-inner-cover-shell',
      version: 1,
      code: 'INNER_COVER_SHELL',
      title: 'Inner Cover shell audit',
      description: 'Inspect installed Inner Covers by governed Base position.',
      assetTypeKeys: ['innerCover'],
      assetClassIds: ['class-inner-cover'],
      componentNodeIds: ['inner-cover-shell'],
      valueType: InspectionValueType.boolean,
      unit: null,
      choiceValues: [],
      minimumValue: null,
      maximumValue: null,
      preconditions: [],
      requiresChargeNo: false,
    ),
    purpose: 'Verify all currently installed Inner Covers.',
    assetTypeKey: 'innerCover',
    assetClassId: 'class-inner-cover',
    populationMode: InspectionCampaignPopulationMode.installedInnerCoversByBase,
    hostAssetClassId: 'class-base',
    targetAssetNumbers: List<int>.generate(22, (index) => index + 201),
    physicalPositionLabels: positions,
    targets: targets,
    expectedPopulation: targets.length,
    baselineCampaignId: null,
    observerRoleKeys: const ['seniorMechanical'],
    observationCount: 0,
    distinctTargetKeys: const [],
    latestObservationAt: null,
    createdAt: now,
  );
}

InspectionCampaign _assetCampaign({
  InspectionCampaignStatus status = InspectionCampaignStatus.open,
  required String assetTypeKey,
  required String assetClassId,
  required String assetInstanceId,
  required int assetNumber,
  required String label,
  InspectionTargetDisposition disposition = InspectionTargetDisposition.pending,
  String? lastObservationId,
  DateTime? lastObservedAt,
}) {
  final now = DateTime.utc(2026, 9, 5, 4);
  final target = InspectionCampaignTarget(
    targetKey: '$assetClassId:$assetInstanceId|asset|-',
    assetTypeKey: assetTypeKey,
    assetClassId: assetClassId,
    assetNumber: assetNumber,
    assetInstanceId: assetInstanceId,
    assetInstanceVersion: 2,
    assetInstanceName: label,
    hostAssetClassId: null,
    hostAssetInstanceId: null,
    hostAssetInstanceVersion: null,
    hostAssetNumber: null,
    hostAssetInstanceName: null,
    subjectSerialNumber: null,
    linkageId: null,
    linkageVersion: null,
    linkedAt: null,
    componentNodeId: null,
    physicalPosition: null,
    disposition: disposition,
    dispositionReason: null,
    dispositionAt: now,
    dispositionByUid: 'admin-1',
    dispositionByName: 'Admin One',
    addedLater: false,
    lastObservationId: lastObservationId,
    lastObservedAt: lastObservedAt,
  );
  return InspectionCampaign(
    id: 'campaign-$assetInstanceId',
    version: 1,
    status: status,
    definition: FrozenInspectionDefinition(
      id: 'definition-$assetTypeKey',
      version: 1,
      code: '${assetTypeKey.toUpperCase()}_AUDIT',
      title: '$label audit',
      description: 'Governed asset inspection.',
      assetTypeKeys: [assetTypeKey],
      assetClassIds: [assetClassId],
      componentNodeIds: const [],
      valueType: InspectionValueType.boolean,
      unit: null,
      choiceValues: const [],
      minimumValue: null,
      maximumValue: null,
      preconditions: const [],
      requiresChargeNo: false,
    ),
    purpose: 'Inspect $label.',
    assetTypeKey: assetTypeKey,
    assetClassId: assetClassId,
    populationMode: InspectionCampaignPopulationMode.assetInstances,
    hostAssetClassId: null,
    targetAssetNumbers: [assetNumber],
    physicalPositionLabels: const [],
    targets: [target],
    expectedPopulation: 1,
    baselineCampaignId: null,
    observerRoleKeys: const ['operations'],
    observationCount: lastObservationId == null ? 0 : 1,
    distinctTargetKeys: lastObservationId == null
        ? const []
        : <String>[target.targetKey],
    latestObservationAt: lastObservedAt,
    createdAt: now,
  );
}

InspectionObservation _observation({
  required InspectionCampaign campaign,
  required InspectionCampaignTarget target,
  required String id,
  required DateTime observedAt,
  required DateTime recordedAt,
  required bool value,
}) => InspectionObservation(
  id: id,
  campaignId: campaign.id,
  definition: campaign.definition,
  assetTypeKey: target.assetTypeKey,
  assetNumber: target.assetNumber,
  assetClassId: target.assetClassId,
  assetInstanceId: target.assetInstanceId,
  hostAssetClassId: target.hostAssetClassId,
  hostAssetInstanceId: target.hostAssetInstanceId,
  hostAssetInstanceVersion: target.hostAssetInstanceVersion,
  hostAssetNumber: target.hostAssetNumber,
  hostAssetInstanceName: target.hostAssetInstanceName,
  subjectSerialNumber: target.subjectSerialNumber,
  linkageId: target.linkageId,
  linkageVersion: target.linkageVersion,
  linkedAt: target.linkedAt,
  componentNodeId: target.componentNodeId,
  componentNodeVersion: null,
  componentName: null,
  hierarchyPath: const <String>[],
  physicalPosition: target.physicalPosition,
  targetKey: target.targetKey,
  observedAt: observedAt,
  observerUid: 'admin-1',
  observerName: 'Admin One',
  numericValue: null,
  booleanValue: value,
  textValue: null,
  choiceValue: null,
  unit: null,
  outOfRange: !value,
  operatingConditions: const <String, String>{},
  chargeNo: null,
  note: null,
  evidenceUrls: const <String>[],
  supersedesObservationId: null,
  baselineCampaignId: null,
  baselineObservationId: null,
  comparisonOutcome: null,
  recordedAt: recordedAt,
);
