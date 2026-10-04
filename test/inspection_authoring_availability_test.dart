import 'dart:async';
import 'package:crm3_baf_ops/features/assets/data/asset_registry_model.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/inspection_reading_contract_editor.dart';

import 'package:crm3_baf_ops/core/persistence/durable_submission.dart';
import 'package:crm3_baf_ops/features/inspections/services/inspection_campaign_submission_controller.dart';
import 'package:crm3_baf_ops/core/release/command_capability_service.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/assets/providers/asset_hierarchy_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_campaign.dart';
import 'package:crm3_baf_ops/features/inspections/data/inspection_evidence_snapshot.dart';
import 'package:crm3_baf_ops/features/inspections/presentation/inspection_programmes_screen.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_authoring_provider.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_campaign_submission_provider.dart';
import 'package:crm3_baf_ops/features/inspections/providers/inspection_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser actor([String uid = 'admin']) => AppUser(
  uid: uid,
  name: 'Admin',
  email: 'admin@example.invalid',
  roles: const [AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026),
);
Map<String, Object?> response([bool enabled = true]) => {
  'schemaVersion': 1,
  'protocolVersion': 2,
  'callableName': 'executeMaintenanceWorkflowCommandV2',
  'capabilityRevision': 'maintenanceWorkflow.v2.20260913',
  'capabilities': [
    'maintenanceWorkflow.v2',
    if (enabled) inspectionV2AuthoringCapability,
  ],
};
InspectionDefinition definition({
  bool multi = true,
  String id = 'definition',
  String title = 'Existing labelled inspection',
  List<InspectionReadingField>? fields,
}) => InspectionDefinition(
  id: id,
  version: 1,
  status: InspectionDefinitionStatus.active,
  updatedAt: DateTime.utc(2026),
  frozen: FrozenInspectionDefinition(
    id: id,
    version: 1,
    schemaVersion: multi ? 2 : 1,
    code: 'CHECK',
    title: title,
    description: 'Check the furnace.',
    assetTypeKeys: const ['furnace'],
    assetClassIds: const ['class-furnace'],
    componentNodeIds: const [],
    valueType: multi ? null : InspectionValueType.boolean,
    unit: null,
    choiceValues: const [],
    minimumValue: null,
    maximumValue: null,
    preconditions: const [],
    requiresChargeNo: false,
    readingFields: multi
        ? fields ??
              const [
                InspectionReadingField(
                  id: 'checked',
                  label: 'Checked?',
                  valueType: InspectionValueType.boolean,
                ),
              ]
        : const [],
  ),
);

class NoSavedCampaign extends Fake
    implements InspectionCampaignSubmissionController {
  @override
  Future<DurableSubmission?> restore() async => null;
}

AssetInstanceRecord asset(int number) => AssetInstanceRecord(
  id: 'furnace-$number',
  assetClassId: 'class-furnace',
  assetClassCode: 'FURNACE',
  assetClassName: 'Furnaces',
  assetNumber: number,
  name: 'Furnace $number',
  serviceState: AssetServiceState.values.first,
  ownershipStatus: AssetOwnershipStatus.confirmed,
  status: AssetHierarchyStatus.active,
  activeComponentCount: 0,
  version: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  lastMutationId: 'seed',
);

class CaptureCampaign extends NoSavedCampaign {
  CaptureCampaign(this.prepared);
  final List<Map<String, Object?>> prepared;
  @override
  Future<DurableSubmission> prepare({
    required String originActorUid,
    required Map<String, Object?> payload,
    required String definitionCode,
    required String definitionTitle,
    String? commandId,
    String? campaignId,
  }) async {
    expect(originActorUid, 'admin');
    expect(definitionCode, 'CHECK');
    prepared.add(payload);
    // Observe the real editor boundary without a durable store or backend call.
    throw StateError('Captured at the durable preparation boundary');
  }
}

void main() {
  test(
    'loading, failed, retained or other-actor capability cannot enable controls',
    () {
      final ready = AsyncData<AppUser?>(actor());
      const available = AsyncData<String?>('admin');
      expect(inspectionV2AuthoringAvailable(available, ready), isTrue);
      for (final state in <AsyncValue<String?>>[
        const AsyncLoading<String?>(),
        const AsyncData(null),
        const AsyncData('other'),
        AsyncError(Exception('offline'), StackTrace.current),
        const AsyncLoading<String?>().copyWithPrevious(available),
        AsyncError<String?>(
          Exception('offline'),
          StackTrace.current,
        ).copyWithPrevious(available),
      ]) {
        expect(inspectionV2AuthoringAvailable(state, ready), isFalse);
      }
      for (final account in <AsyncValue<AppUser?>>[
        const AsyncLoading<AppUser?>().copyWithPrevious(ready),
        AsyncError<AppUser?>(
          Exception('unverified'),
          StackTrace.current,
        ).copyWithPrevious(ready),
        const AsyncData(null),
        AsyncData(actor('other')),
      ]) {
        expect(inspectionV2AuthoringAvailable(available, account), isFalse);
      }
    },
  );

  test(
    'checking and network failure are not described as a known disabled deployment',
    () {
      expect(
        inspectionV2AuthoringStatusMessage(const AsyncLoading()),
        contains('Checking whether'),
      );
      expect(
        inspectionV2AuthoringStatusMessage(
          AsyncError(Exception('offline'), StackTrace.current),
        ),
        contains('could not be checked'),
      );
      expect(
        inspectionV2AuthoringStatusMessage(
          AsyncError(
            const CommandCapabilityException(
              'inspection-v2-authoring-unavailable',
              'closed',
            ),
            StackTrace.current,
          ),
        ),
        inspectionV2AuthoringUnavailableMessage,
      );
    },
  );

  for (final mode in [
    'enabled',
    'missing',
    'malformed',
    'offline',
    'changed-session',
  ]) {
    test(
      'fresh executable probe $mode, optional capability never changes general readiness',
      () async {
        var uid = 'admin';
        var calls = 0;
        final service = CommandCapabilityService(
          currentActorUid: () => uid,
          invoke: (name, payload) async {
            calls++;
            expect(payload, {
              'protocolVersion': 2,
              'originActorUid': 'admin',
              'probe': 'capabilities',
            });
            if (mode == 'offline') {
              throw const CommandCapabilityException('unavailable', 'Offline');
            }
            if (mode == 'changed-session') uid = 'other';
            return mode == 'malformed'
                ? <String, Object?>{}
                : response(mode != 'missing');
          },
        );
        final container = ProviderContainer(
          overrides: [
            currentAppUserProvider.overrideWith((ref) => Stream.value(actor())),
            inspectionAuthoringCapabilityServiceProvider.overrideWithValue(
              service,
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(currentAppUserProvider.future);
        final check = container.read(inspectionV2AuthoringCapabilityProvider);
        if (mode == 'enabled') {
          await check('admin');
          await check('admin');
          expect(calls, 2);
        } else {
          await expectLater(
            check('admin'),
            throwsA(isA<CommandCapabilityException>()),
          );
          expect(calls, 1);
        }
        if (mode == 'missing') {
          // A backend that only advertises the original capability remains v1-compatible.
          await service.requireCapabilities(
            callableName: 'executeMaintenanceWorkflowCommandV2',
            originActorUid: 'admin',
            requiredCapabilities: {'maintenanceWorkflow.v2'},
          );
        }
      },
    );
  }

  Future<void> mount(
    WidgetTester tester, {
    required Future<void> Function(String) check,
    List<InspectionDefinition> definitions = const [],
    List<WorkflowCommand>? sent,
    List<Map<String, Object?>>? prepared,
    List<AssetInstanceRecord> assets = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cls = AssetClassRecord(
      id: 'class-furnace',
      code: 'FURNACE',
      name: 'Furnaces',
      majorArea: 'Plant',
      legacyAssetTypeKey: 'furnace',
      status: AssetHierarchyStatus.active,
      version: 1,
      createdAt: DateTime.utc(2026),
      createdByUid: 'admin',
      updatedAt: DateTime.utc(2026),
      updatedByUid: 'admin',
      lastMutationId: 'seed',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith((ref) => Stream.value(actor())),
          inspectionV2AuthoringCapabilityProvider.overrideWithValue(check),
          inspectionDefinitionsProvider.overrideWith(
            (ref) => Stream.value(definitions),
          ),
          inspectionCampaignsProvider.overrideWith(
            (ref) => Stream.value(
              const InspectionEvidenceSnapshot(
                records: <InspectionCampaign>[],
                isServerVerified: true,
              ),
            ),
          ),
          inspectionCampaignSubmissionControllerProvider.overrideWith(
            (ref) => prepared == null
                ? NoSavedCampaign()
                : CaptureCampaign(prepared),
          ),
          pendingInspectionCampaignSubmissionProvider.overrideWith(
            (ref) async => null,
          ),
          allAssetInstancesProvider.overrideWith((ref) => Stream.value(assets)),
          assetClassesProvider.overrideWith((ref) => Stream.value([cls])),
          assetHierarchyNodesProvider(
            'class-furnace',
          ).overrideWith((ref) => Stream.value(const [])),
          workflowCommandControllerProvider.overrideWith(
            (ref) => WorkflowCommandController.forTesting(
              executeCommand: (command) async {
                sent?.add(command);
                return WorkflowCommandReceipt(
                  commandId: command.commandId,
                  resultKey: 'accepted',
                  aggregateVersion: 1,
                  result: const {},
                  appliedAt: DateTime.utc(2026),
                );
              },
              pullProjections: () async {},
            ),
          ),
        ],
        child: const MaterialApp(home: InspectionProgrammesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Definitions'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }

  testWidgets(
    'unavailable new contract keeps Date/add disabled but scalar save works',
    (tester) async {
      final sent = <WorkflowCommand>[];
      await mount(
        tester,
        sent: sent,
        check: (_) async => throw const CommandCapabilityException(
          'inspection-v2-authoring-unavailable',
          inspectionV2AuthoringUnavailableMessage,
        ),
      );
      await tap(
        tester,
        find.byKey(const ValueKey('inspection-add-definition')),
      );
      expect(
        find.text(inspectionV2AuthoringUnavailableMessage),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Add another reading'),
            )
            .onPressed,
        isNull,
      );
      final segments = tester.widget<SegmentedButton<InspectionValueType>>(
        find.byType(SegmentedButton<InspectionValueType>),
      );
      expect(
        segments.segments
            .singleWhere((s) => s.value == InspectionValueType.date)
            .enabled,
        isFalse,
      );
      await fill(tester, 'Definition code', 'LEGACY');
      await fill(tester, 'Field-facing title', 'Scalar remains usable');
      await fill(
        tester,
        'What this inspection establishes',
        'Check a single scalar reading.',
      );
      await tap(tester, find.text('Yes/No'));
      await tap(tester, find.text('Save version'));
      expect(sent, hasLength(1));
      expect((sent.single.payload['definition'] as Map)['schemaVersion'], 1);
      expect(
        (sent.single.payload['definition'] as Map).containsKey('readingFields'),
        isFalse,
      );
    },
  );

  testWidgets('existing v2 remains visible; closed save preserves its form', (
    tester,
  ) async {
    final sent = <WorkflowCommand>[];
    await mount(
      tester,
      definitions: [definition()],
      sent: sent,
      check: (_) async => throw const CommandCapabilityException(
        'inspection-v2-authoring-unavailable',
        inspectionV2AuthoringUnavailableMessage,
      ),
    );
    expect(find.text('Existing labelled inspection'), findsOneWidget);
    await tap(tester, find.byTooltip('Definition actions'));
    await tap(tester, find.text('Edit as new version'));
    expect(find.text('Checked?'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save version'),
          )
          .onPressed,
      isNull,
    );
    expect(sent, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'fresh save refusal after successful hint retains every edited value',
    (tester) async {
      var calls = 0;
      final sent = <WorkflowCommand>[];
      await mount(
        tester,
        definitions: [definition()],
        sent: sent,
        check: (_) async {
          calls++;
          if (calls > 1) {
            throw const CommandCapabilityException(
              'inspection-v2-authoring-unavailable',
              inspectionV2AuthoringUnavailableMessage,
            );
          }
        },
      );
      await tap(tester, find.byTooltip('Definition actions'));
      await tap(tester, find.text('Edit as new version'));
      await fill(tester, 'Field-facing title', 'Retain this unsent title');
      await tap(tester, find.text('Save version'));
      expect(calls, greaterThanOrEqualTo(2));
      expect(sent, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Retain this unsent title'), findsOneWidget);
      expect(find.text('Checked?'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save version'),
            )
            .onPressed,
        isNull,
      );
    },
  );
  for (final multi in [false, true]) {
    testWidgets(
      'closed capability preserves v$multi definition selection and campaign action state',
      (tester) async {
        await mount(
          tester,
          definitions: [definition(multi: multi)],
          check: (_) async {
            throw const CommandCapabilityException(
              'inspection-v2-authoring-unavailable',
              inspectionV2AuthoringUnavailableMessage,
            );
          },
        );
        await tap(tester, find.text('Active'));
        await tap(tester, find.widgetWithText(FilledButton, 'New'));
        expect(find.text('Existing labelled inspection'), findsOneWidget);
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Open programme'),
        );
        expect(button.onPressed == null, multi);
        expect(
          find.text(inspectionV2AuthoringUnavailableMessage),
          multi ? findsOneWidget : findsNothing,
        );
      },
    );
  }
  testWidgets(
    'enabled v2 save probes again and submits the full existing contract',
    (tester) async {
      var calls = 0;
      final sent = <WorkflowCommand>[];
      await mount(
        tester,
        definitions: [definition()],
        sent: sent,
        check: (_) async {
          calls++;
        },
      );
      await tap(tester, find.byTooltip('Definition actions'));
      await tap(tester, find.text('Edit as new version'));
      await fill(tester, 'Field-facing title', 'Reviewed labelled inspection');
      await tap(tester, find.text('Save version'));
      expect(calls, 2);
      expect(sent, hasLength(1));
      final contract = sent.single.payload['definition'] as Map;
      expect(contract['schemaVersion'], 2);
      expect(contract['title'], 'Reviewed labelled inspection');
      expect(
        contract['readingFields'],
        definition().frozen.readingFields.map((f) => f.toMap()).toList(),
      );
      expect(contract.containsKey('valueType'), isFalse);
    },
  );
  TextEditingController controller(WidgetTester tester, String label) => tester
      .widget<TextFormField>(find.widgetWithText(TextFormField, label))
      .controller!;

  Future<void> openDefinition(WidgetTester tester) async {
    await tap(tester, find.byTooltip('Definition actions'));
    await tap(tester, find.text('Edit as new version'));
  }

  Future<void> openCampaign(WidgetTester tester) async {
    await tap(tester, find.text('Active'));
    await tap(tester, find.widgetWithText(FilledButton, 'New'));
    await fill(tester, 'Purpose of this programme', 'Original purpose');
    await fill(tester, 'Physical positions (optional)', 'Left, Right');
    await fill(tester, 'Opening reason', 'Original opening reason');
  }

  testWidgets('deferred definition save submits one complete snapshot', (
    tester,
  ) async {
    final gate = Completer<void>();
    var calls = 0;
    final sent = <WorkflowCommand>[];
    final choices = ['Pass', 'Fail'];
    await mount(
      tester,
      definitions: [
        definition(
          fields: [
            InspectionReadingField(
              id: 'result',
              label: 'Result',
              valueType: InspectionValueType.choice,
              choiceValues: choices,
            ),
          ],
        ),
      ],
      sent: sent,
      check: (_) async {
        if (++calls > 1) await gate.future;
      },
    );
    await openDefinition(tester);
    await fill(tester, 'Field-facing title', 'Captured title');
    await fill(tester, 'Preconditions · one per line', 'Isolated\nCooled');
    await fill(tester, 'Governance reason', 'Captured reason');
    await tap(tester, find.text('Save version'));
    expect(calls, 2);
    expect(sent, isEmpty);
    // Deliberate controller/model mutation also tests snapshot isolation even
    // when a callback already retained by another widget is invoked directly.
    controller(tester, 'Field-facing title').text = 'Later title';
    controller(tester, 'Preconditions · one per line').text =
        'Later prerequisite';
    controller(tester, 'Governance reason').text = 'Later reason';
    choices[0] = 'Changed choice';
    tester
        .widget<InspectionReadingContractEditor>(
          find.byType(InspectionReadingContractEditor),
        )
        .onChanged(const [
          InspectionReadingField(
            id: 'other',
            label: 'Different reading',
            valueType: InspectionValueType.date,
          ),
        ]);
    gate.complete();
    await tester.pumpAndSettle();
    expect(sent, hasLength(1));
    expect(sent.single.payload['reason'], 'Captured reason');
    final payload = sent.single.payload['definition'] as Map;
    expect(payload['title'], 'Captured title');
    expect(payload['preconditions'], ['Isolated', 'Cooled']);
    expect(payload['readingFields'], [
      const InspectionReadingField(
        id: 'result',
        label: 'Result',
        valueType: InspectionValueType.choice,
        choiceValues: ['Pass', 'Fail'],
      ).toMap(),
    ]);
    expect(payload['assetClassIds'], ['class-furnace']);
    expect(payload['schemaVersion'], 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deferred campaign save submits one complete snapshot', (
    tester,
  ) async {
    final gate = Completer<void>();
    var calls = 0;
    final prepared = <Map<String, Object?>>[];
    final original = definition();
    final other = definition(id: 'other', title: 'Other contract');
    await mount(
      tester,
      definitions: [original, other],
      prepared: prepared,
      assets: [asset(101), asset(102)],
      check: (_) async {
        if (++calls > 1) await gate.future;
      },
    );
    await openCampaign(tester);
    await tap(tester, find.text('Open programme'));
    expect(calls, 2);
    expect(prepared, isEmpty);
    controller(tester, 'Purpose of this programme').text = 'Later purpose';
    controller(tester, 'Opening reason').text = 'Later reason';
    tester
        .widget<DropdownButtonFormField<InspectionDefinition>>(
          find.byType(DropdownButtonFormField<InspectionDefinition>),
        )
        .onChanged!(other);
    tester
        .widget<FilterChip>(find.widgetWithText(FilterChip, 'Operations'))
        .onSelected!(false);
    gate.complete();
    await tester.pumpAndSettle();
    expect(prepared, hasLength(1));
    expect(prepared.single, {
      'definitionId': 'definition',
      'definitionVersion': 1,
      'purpose': 'Original purpose',
      'assetTypeKey': 'furnace',
      'assetClassId': 'class-furnace',
      'populationMode': 'assetInstances',
      'hostAssetClassId': null,
      'targetAssetNumbers': [101, 102],
      'expectedPopulation': 4,
      'physicalPositionLabels': ['Left', 'Right'],
      'baselineCampaignId': null,
      'observerRoleKeys': [
        'operations',
        'refractory',
        'seniorElectrical',
        'seniorInstrumentation',
        'seniorMechanical',
      ],
      'reason': 'Original opening reason',
    });
    expect(tester.takeException(), isNull);
  });

  for (final campaign in [false, true]) {
    testWidgets(
      'pending ${campaign ? 'campaign' : 'definition'} blocks editing and duplicate save; denial retains draft',
      (tester) async {
        final gate = Completer<void>();
        var calls = 0;
        final sent = <WorkflowCommand>[];
        final prepared = <Map<String, Object?>>[];
        await mount(
          tester,
          definitions: [definition()],
          sent: sent,
          prepared: prepared,
          assets: [asset(101)],
          check: (_) async {
            if (++calls == 2) await gate.future;
          },
        );
        if (campaign) {
          await openCampaign(tester);
        } else {
          await openDefinition(tester);
        }
        final fieldLabel = campaign
            ? 'Purpose of this programme'
            : 'Field-facing title';
        await fill(tester, fieldLabel, 'Preserve this draft');
        final action = find.widgetWithText(
          FilledButton,
          campaign ? 'Open programme' : 'Save version',
        );
        final savedCallback = tester.widget<FilledButton>(action).onPressed!;
        await tap(tester, action);
        savedCallback();
        await tester.pump();
        expect(calls, 2, reason: 'The in-flight guard is synchronous.');
        final editable = find.descendant(
          of: find.widgetWithText(TextFormField, fieldLabel),
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(editable).focusNode.canRequestFocus,
          isFalse,
        );
        final nested = campaign
            ? find.widgetWithText(TextButton, 'Choose')
            : find.byKey(const ValueKey('inspection-contract-edit-checked'));
        await tester.ensureVisible(nested);
        await tester.tap(nested, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        gate.completeError(
          const CommandCapabilityException('unavailable', 'Check failed'),
        );
        await tester.pumpAndSettle();
        expect(sent, isEmpty);
        expect(prepared, isEmpty);
        expect(controller(tester, fieldLabel).text, 'Preserve this draft');
        expect(
          tester.widget<EditableText>(editable).focusNode.canRequestFocus,
          isTrue,
        );
        expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
        await fill(tester, fieldLabel, 'Reviewed retry');
        await tap(tester, action);
        expect(campaign ? prepared.length : sent.length, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'cancel pending ${campaign ? 'campaign' : 'definition'} does not submit after capability returns',
      (tester) async {
        final gate = Completer<void>();
        var calls = 0;
        final sent = <WorkflowCommand>[];
        final prepared = <Map<String, Object?>>[];
        await mount(
          tester,
          definitions: [definition()],
          sent: sent,
          prepared: prepared,
          assets: [asset(101)],
          check: (_) async {
            if (++calls > 1) await gate.future;
          },
        );
        if (campaign) {
          await openCampaign(tester);
        } else {
          await openDefinition(tester);
        }
        await tap(
          tester,
          find.text(campaign ? 'Open programme' : 'Save version'),
        );
        await tap(tester, find.widgetWithText(TextButton, 'Cancel'));
        gate.complete();
        await tester.pumpAndSettle();
        expect(sent, isEmpty);
        expect(prepared, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(InspectionProgrammesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('capability completion cannot pop a different current route', (
    tester,
  ) async {
    final gate = Completer<void>();
    var calls = 0;
    final sent = <WorkflowCommand>[];
    await mount(
      tester,
      definitions: [definition()],
      sent: sent,
      check: (_) async {
        if (++calls == 2) await gate.future;
      },
    );
    await openDefinition(tester);
    await tap(tester, find.text('Save version'));
    final context = tester.element(find.byType(AlertDialog));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unrelated dialog'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss unrelated'),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Unrelated dialog'), findsOneWidget);
    expect(sent, isEmpty);
    await tap(tester, find.text('Dismiss unrelated'));
    expect(find.text('Save version'), findsOneWidget);
    await tap(tester, find.text('Save version'));
    expect(sent, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
