import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/core/persistence/app_database.dart' as database;
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_command_contract.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/services/workflow_command_gateway.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/support/upgrade_saved_work.dart';
import '../tool/test_support/test_isar_core.dart';

// This host test checks the exact Android rehearsal payloads through real local
// repositories. Its preference fixtures do not establish UI, authentication,
// migration or APK replacement acceptance; those remain the DEV pair's job.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestIsarCore);

  test(
    'upgrade helper saves all five families and captures them after native reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'upgrade_helper_host_',
      );
      final gateway = _NoDispatchGateway();
      final now = DateTime.now().toUtc();
      final actor = AppUser(
        uid: 'upgrade-host-admin',
        name: 'Host admin',
        email: 'host@example.invalid',
        roles: [AppRole.admin],
        isApproved: true,
        createdAt: now,
      );
      // Explicit host fixtures, never promoted to installed-store evidence.
      const marker = IsarSchemaProvenanceMarker(
        state: IsarSchemaMarkerState.committed,
        schemaVersion: 12,
        schemaFingerprint: 'host-fixture-not-installed-provenance',
        databaseGenerationId: '77777777-7777-4777-8777-777777777777',
        origin: IsarSchemaMarkerOrigin.freshInstall,
        sourceSchemaVersion: null,
        sourceSchemaFingerprint: null,
      );
      SharedPreferences.setMockInitialValues({
        SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey: marker
            .encode(),
        'RECOVERY::host-fixture::upgrade-$upgradeRunId': jsonEncode({
          'hostFixtureOnly': true,
          'retainedText': 'composer data sentinel',
        }),
      });
      Future<Isar> open() async => Isar.open(
        [
          MaintenanceRecordSchema,
          ChargeAbnormalitySchema,
          JobDiaryEntrySchema,
          AbnormalityTypeSchema,
          JobTemplateSchema,
          DurableSubmissionRecordSchema,
          AuditEventSchema,
        ],
        directory: directory.path,
        name: 'upgrade-helper-host',
        inspector: false,
      );
      Isar? db;
      try {
        db = await open();
        database.isar = db;
        final retained = RetainedRowMutations(
          store: DurableSubmissionRepository(db),
          projectId: () => 'demo-upgrade-host-fixture',
          currentActorUid: () => actor.uid,
          gateway: gateway,
        );
        final ids = await saveUpgradeWork(actor, retainedMutations: retained);
        final first = await captureUpgradeWork(
          ids['prefix'] as String,
          actor.uid,
        );
        final business = first['business'] as Map;
        expect(business.keys.toSet(), {
          'maintenance',
          'abnormality',
          'diary',
          'catalogue',
          'template',
        });
        expect(first['durableImmutable'] as List, hasLength(2));
        expect(
          (business['catalogue'] as List).single,
          containsPair('lastEditedByUid', actor.uid),
        );
        expect(
          (business['catalogue'] as List).single,
          containsPair('lastEditedByName', actor.name),
        );
        await verifyUpgradeOwnership(first, actor.uid);
        expect(gateway.calls, 0);
        await db.close();
        db = await open();
        database.isar = db;
        final reopened = await captureUpgradeWork(
          ids['prefix'] as String,
          actor.uid,
        );
        expect(
          immutableUpgradeSnapshot(reopened),
          immutableUpgradeSnapshot(first),
        );
        await verifyUpgradeOwnership(reopened, actor.uid);
        expect(gateway.calls, 0);
      } finally {
        if (db?.isOpen ?? false) await db!.close();
        // This directory was created above exclusively for this disposable test.
        expect(directory.parent.path, Directory.systemTemp.path);
        await directory.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _NoDispatchGateway implements OriginBoundWorkflowCommandGateway {
  int calls = 0;
  @override
  Future<WorkflowCommandReceipt> executeOriginBoundEnvelope(
    String envelopeJson,
  ) async {
    calls++;
    throw StateError(
      'The local upgrade fixture must never dispatch a command.',
    );
  }
}
