import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as app;
import 'package:crm3_baf_ops/core/services/sync_service.dart';
import 'package:crm3_baf_ops/features/assets/data/asset_hierarchy_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/maintenance_component_identification.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/frequent_issue_selection.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_component_identification_command.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_issue_create_command.dart';
import 'package:crm3_baf_ops/features/maintenance/validation/maintenance_input_validator.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/quality/domain/issue_quality_intent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../tool/test_support/test_isar_core.dart';

final _at = DateTime.utc(2026, 9, 26, 6);
AssetHierarchyReference _reference({
  bool component = false,
  String asset = 'furnace-7',
}) => AssetHierarchyReference(
  scope: component
      ? AssetHierarchyReferenceScope.componentDefinitionOnAsset
      : AssetHierarchyReferenceScope.physicalAsset,
  assetClassId: 'furnace',
  assetClassCode: 'FR',
  assetClassName: 'Furnace',
  assetInstanceId: asset,
  assetInstanceVersion: 4,
  assetNumber: 7,
  assetInstanceName: 'Furnace 7',
  nodeId: component ? 'seal' : asset,
  nodeVersion: component ? 2 : 4,
  nodeName: component ? 'Furnace seal' : 'Furnace 7',
  hierarchyPath: component
      ? ['Sealing', 'Furnace seal']
      : ['Furnace', 'Furnace 7'],
  ownershipStatus: AssetOwnershipStatus.confirmed,
  ownerDiscipline: 'Mechanical',
  accountableRoleKeys: const ['seniorMechanical'],
);

MaintenanceRecord _ticket() => MaintenanceRecord()
  ..firestoreId = 'ticket-1'
  ..version = 3
  ..assetType = AssetType.furnace
  ..assetNumber = 7
  ..assetHierarchyRefJson = _reference().encode()
  ..component = null
  ..description = 'Noise from Furnace.'
  ..startDate = _at
  ..createdAt = _at
  ..updatedAt = _at
  ..maintenanceType = MaintenanceType.breakdown
  ..routedTo = RoutedTo.mechanical
  ..status = TicketStatus.open
  ..isSynced = true
  ..qualityIntent = const IssueQualityIntent(
    assessment: IssueQualityAssessment.notSuspected,
  )
  ..componentIntakeState = ComponentIntakeState.unidentified;

MaintenanceComponentIdentification _identified({String asset = 'furnace-7'}) =>
    MaintenanceComponentIdentification(
      version: 1,
      originalTicketVersion: 3,
      targetReferenceJson: _reference(component: true, asset: asset).encode(),
      basis: 'Visual inspection found the damaged seal.',
      identifiedAt: _at,
      identifiedByUid: 'supervisor',
      identifiedByName: 'Shift supervisor',
    );

void main() {
  setUpAll(initializeTestIsarCore);

  for (final throughCommandReadback in [true, false]) {
    test(
      'identification survives Isar ${throughCommandReadback ? 'command readback' : 'live pull'} without replacing the original report',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'component_identification_',
        );
        final isar = await Isar.open([
          MaintenanceRecordSchema,
        ], directory: directory.path);
        app.isar = isar;
        try {
          final local = _ticket();
          await isar.writeTxn(() => isar.maintenanceRecords.put(local));
          final remote = _ticket()
            ..version = 4
            ..updatedAt = _at.add(const Duration(minutes: 1))
            ..metadataJson = mergeMaintenanceComponentContext(
              local.metadataJson,
              intakeState: ComponentIntakeState.unidentified,
              identification: _identified(),
            );
          final repository = IsarMaintenanceRepository();
          if (throughCommandReadback) {
            expect(
              await repository.applyMaintenanceIssueCommandReadback(
                remote: remote,
                expectedLocalVersion: local.version,
                expectedLocalUpdatedAt: local.updatedAt,
              ),
              isTrue,
            );
          } else {
            await repository.applyMaintenanceRecordFromRemote(remote);
          }
          final stored = (await isar.maintenanceRecords.get(local.id))!;
          expect(stored.version, 4);
          expect(stored.isSynced, isTrue);
          expect(stored.component, isNull);
          expect(stored.description, local.description);
          expect(stored.assetHierarchyRefJson, local.assetHierarchyRefJson);
          expect(
            stored.qualityIntent!.assessment,
            IssueQualityAssessment.notSuspected,
          );
          expect(
            stored.componentIdentification!.toMap(),
            _identified().toMap(),
          );
        } finally {
          await isar.close(deleteFromDisk: true);
          if (await directory.exists()) await directory.delete(recursive: true);
        }
      },
    );
  }

  test(
    'lifecycle replay pins component identification evidence while ignoring lane progress',
    () {
      final local = _ticket();
      final remote = _ticket()
        ..metadataJson = mergeMaintenanceComponentContext(
          local.metadataJson,
          intakeState: ComponentIntakeState.unidentified,
          identification: _identified(),
        );
      expect(
        maintenanceLifecycleReplayPinnedFieldDiff(local, remote),
        'metadataJson',
      );
      local.metadataJson = remote.metadataJson;
      expect(maintenanceLifecycleReplayPinnedFieldDiff(local, remote), 'none');
      local
        ..status = TicketStatus.acknowledged
        ..acknowledgedByUid = 'supervisor'
        ..acknowledgedByName = 'Shift supervisor'
        ..acknowledgedAt = _at;
      local.issueLanePlan = local.issueLanePlan.acknowledge('mechanical');
      expect(maintenanceLifecycleReplayPinnedFieldDiff(local, remote), 'none');
    },
  );

  test(
    'blank legacy component permits later identification without invented intake state',
    () {
      final legacy = _ticket()..componentIntakeState = null;
      expect(legacy.componentIntakeLabel, 'Not recorded');
      expect(legacy.awaitsComponentIdentification, isTrue);
      buildMaintenanceComponentIdentificationCommand(
        ticket: legacy,
        target: _reference(component: true),
        basis: 'Inspected now',
      );
      final metadata =
          mergeRemoteMaintenanceComponentContext(legacy.metadataJson, {
            'component': null,
            'tag': null,
            'assetNumber': 7,
            'assetHierarchyRefJson': legacy.assetHierarchyRefJson,
            'componentIdentification': _identified().toMap(),
          });
      legacy.metadataJson = metadata;
      expect(legacy.componentIntakeState, isNull);
      expect(legacy.component, isNull);
      expect(legacy.componentIdentification!.component, 'Furnace seal');
      expect(legacy.componentIntakeLabel, 'Not recorded');
      expect(legacy.awaitsComponentIdentification, isFalse);
      final known = _ticket()
        ..componentIntakeState = null
        ..component = 'Historical component';
      expect(known.awaitsComponentIdentification, isFalse);
      final tagged = _ticket()
        ..componentIntakeState = null
        ..tag = 'OLD-TAG';
      expect(tagged.awaitsComponentIdentification, isFalse);
    },
  );

  test(
    'unknown intake command sends null component and keeps Quality assessment',
    () {
      final ticket = _ticket();
      final request =
          buildMaintenanceIssueCreateCommand(
                ticket,
                createVersion: 1,
              ).payload['ticket']
              as Map;
      expect(request['component'], isNull);
      expect(request['componentIntakeState'], 'unidentified');
      expect(request['qualityImpactAssessment'], 'notSuspected');
      for (final state in [
        ComponentIntakeState.unidentified,
        ComponentIntakeState.wholeAsset,
      ]) {
        expect(
          MaintenanceInputValidator.validateCreate(
            MaintenanceCreateInput(
              assetType: AssetType.furnace,
              assetNumberText: '7',
              component: '',
              componentIntakeState: state,
              description: 'Observed noise',
              startDate: _at,
              routedTo: RoutedTo.mechanical,
              hasGovernedAssetIdentity: true,
            ),
          ).isValid,
          isTrue,
        );
      }
      expect(MaintenanceInputValidator.validateComponent('').isValid, isFalse);
    },
  );

  test(
    'catalogue description supplies observation without mandatory repeated comments',
    () {
      expect(
        maintenanceIssueDescription(
          catalogueDescription: 'Noise from Furnace.',
          observations: ' ',
        ),
        'Noise from Furnace.',
      );
      expect(
        maintenanceIssueDescription(
          catalogueDescription: 'Noise from Furnace.',
          observations: 'At rear.',
        ),
        'Noise from Furnace.\nAdditional observations: At rear.',
      );
      expect(
        FrequentIssueSelection.unlisted('x' * 2000).unlistedReason!.length,
        2000,
      );
      expect(
        () => FrequentIssueSelection.unlisted('x' * 2001),
        throwsFormatException,
      );
      expect(
        MaintenanceInputValidator.validateDescription(
          maintenanceIssueDescription(
            catalogueDescription: 'x' * 1990,
            observations: 'too long',
          ),
        ).isValid,
        isFalse,
      );
    },
  );

  test(
    'identification roundtrip preserves original report and other metadata',
    () {
      final original = _ticket();
      final metadata =
          mergeRemoteMaintenanceComponentContext(original.metadataJson, {
            'componentIntakeState': 'unidentified',
            'assetNumber': 7,
            'assetHierarchyRefJson': original.assetHierarchyRefJson,
            'componentIdentification': _identified().toMap(),
          });
      final read = _ticket()..metadataJson = metadata;
      expect(read.component, isNull);
      expect(read.componentIntakeLabel, 'Not yet identified');
      expect(read.effectiveComponentLabel, 'Furnace seal');
      expect(read.componentIdentification!.basis, _identified().basis);
      expect(
        read.qualityIntent!.assessment,
        IssueQualityAssessment.notSuspected,
      );
      expect(read.assetHierarchyRefJson, original.assetHierarchyRefJson);
      expect(read.awaitsComponentIdentification, isFalse);
      expect(
        jsonDecode(
          metadata!,
        )['componentContext']['identification']['originalTicketVersion'],
        3,
      );
    },
  );

  test(
    'legacy metadata is preserved and cross-asset persisted identification fails closed',
    () {
      expect(mergeRemoteMaintenanceComponentContext(null, {}), isNull);
      expect(
        mergeRemoteMaintenanceComponentContext('legacy note', {}),
        'legacy note',
      );
      expect(
        (MaintenanceRecord()..metadataJson = 'legacy note')
            .componentIntakeState,
        isNull,
      );
      expect(
        () => mergeRemoteMaintenanceComponentContext(null, {
          'componentIntakeState': 'unidentified',
          'assetNumber': 7,
          'assetHierarchyRefJson': _reference().encode(),
          'componentIdentification': _identified(
            asset: 'other-furnace',
          ).toMap(),
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'identification allowed after closure but rejects different asset and empty basis',
    () {
      final ticket = _ticket()
        ..status = TicketStatus.resolved
        ..isResolved = true
        ..endDate = _at;
      final command = buildMaintenanceComponentIdentificationCommand(
        ticket: ticket,
        target: _reference(component: true),
        basis: '  Verified by inspection.  ',
      );
      expect(command.payload['basis'], 'Verified by inspection.');
      expect(ticket.component, isNull);
      expect(ticket.isResolved, isTrue);
      expect(
        () => buildMaintenanceComponentIdentificationCommand(
          ticket: ticket,
          target: _reference(component: true, asset: 'another'),
          basis: 'Inspection',
        ),
        throwsStateError,
      );
      expect(
        () => buildMaintenanceComponentIdentificationCommand(
          ticket: ticket,
          target: _reference(component: true),
          basis: ' ',
        ),
        throwsStateError,
      );
    },
  );

  test(
    'receipt binds actor, exact target, command, original version and time',
    () {
      final command = buildMaintenanceComponentIdentificationCommand(
        ticket: _ticket(),
        target: _reference(component: true),
        basis: _identified().basis,
      );
      WorkflowCommandReceipt receipt({
        String actor = 'supervisor',
        String asset = 'furnace-7',
      }) => WorkflowCommandReceipt(
        commandId: command.commandId,
        resultKey: 'maintenance-ticket-component-identified',
        aggregateVersion: 4,
        result: {
          'ticketId': 'ticket-1',
          'auditId': 'server_maintenance_ticket_${command.commandId}',
          'componentIdentification': {
            ..._identified(asset: asset).toMap(),
            'identifiedByUid': actor,
          },
        },
        appliedAt: _at,
      );
      expect(
        validateMaintenanceComponentIdentificationReceipt(
          command: command,
          receipt: receipt(),
          actorUid: 'supervisor',
        ).component,
        'Furnace seal',
      );
      expect(
        () => validateMaintenanceComponentIdentificationReceipt(
          command: command,
          receipt: receipt(actor: 'other'),
          actorUid: 'supervisor',
        ),
        throwsStateError,
      );
      expect(
        () => validateMaintenanceComponentIdentificationReceipt(
          command: command,
          receipt: receipt(asset: 'other'),
          actorUid: 'supervisor',
        ),
        throwsStateError,
      );
    },
  );

  test(
    'only the four approved supervisor roles may identify; no register authority added',
    () {
      for (final role in AppRole.values) {
        final user = AppUser(
          uid: 'actor',
          name: 'Actor',
          email: 'actor@example.invalid',
          roles: [role],
          isApproved: true,
          createdAt: _at,
        );
        expect(
          user.canIdentifyMaintenanceComponent,
          {
            AppRole.admin,
            AppRole.si,
            AppRole.contractSupervisor,
            AppRole.shiftSupervisor,
          }.contains(role),
          reason: role.name,
        );
        final pending = user.copyWith(isApproved: false);
        expect(pending.canIdentifyMaintenanceComponent, isFalse);
        if ({
          AppRole.contractSupervisor,
          AppRole.shiftSupervisor,
        }.contains(role)) {
          expect(user.canManageAssetHierarchy, isFalse);
          expect(user.canCorrectMaintenanceTicket, isFalse);
        }
      }
    },
  );
}
