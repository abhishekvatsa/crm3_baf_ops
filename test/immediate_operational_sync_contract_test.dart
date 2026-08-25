import 'dart:io';

import 'package:crm3_baf_ops/core/services/auto_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Immediate operational synchronization', () {
    late String automatic;
    late String live;
    late String liveRoot;
    late String coordinator;

    setUpAll(() {
      automatic =
          File('lib/core/services/auto_sync_service.dart').readAsStringSync();
      live =
          File(
            'lib/core/services/live_remote_sync_service.business.dart',
          ).readAsStringSync();
      liveRoot =
          File(
            'lib/core/services/live_remote_sync_service.dart',
          ).readAsStringSync();
      coordinator =
          File('lib/core/services/sync_coordinator.dart').readAsStringSync();
    });

    test(
      'every offline-write collection immediately wakes its server push',
      () {
        const collections = <String>[
          'maintenanceRecords',
          'jobTemplates',
          'jobExecutions',
          'jobDiaryEntrys',
          'jobModuleInstances',
          'operationalDirectives',
          'abnormalityTypes',
          'chargeAbnormalitys',
          'templatePackages',
          'templateVersions',
          'templatePublishAudits',
          'bafKnowledgeRows',
        ];
        for (final collection in collections) {
          expect(
            automatic,
            contains('database.$collection'),
            reason: collection,
          );
        }
        expect(automatic, contains('.watchLazy()'));
        expect(automatic, contains("reason: 'local_\${entityType}_changed'"));
        expect(automatic, contains('force: true'));
        expect(automatic, isNot(contains('Duration(minutes: 2)')));
        expect(automatic, isNot(contains('Duration(minutes: 5)')));
        expect(automatic, isNot(contains('Duration(minutes: 20)')));
        expect(automatic, isNot(contains('Timer.periodic')));
        expect(automatic, contains('_scheduleFailureRetry'));
        expect(automatic, contains('detail.isLikelyPermanent'));
        expect(
          coordinator,
          contains("runFullSync(reason: 'reconnected', force: true)"),
        );
      },
    );

    test(
      'every remote operational family is mirrored without waiting for a timer',
      () {
        const collections = <String>[
          'directives',
          'job_executions',
          'job_modules',
          'job_diary_entries',
          'abnormality_types',
          'charge_abnormalities',
          'job_templates',
          'template_packages',
          'template_versions',
          'template_publish_audits',
          'knowledge_base',
        ];
        for (final collection in collections) {
          expect(
            live,
            contains(".collection('$collection')"),
            reason: collection,
          );
        }
        expect(live, contains('snapshots(includeMetadataChanges: true)'));
        expect(live, contains('GetOptions(source: Source.server)'));
        expect(live, contains('local.isSynced != true'));
        expect(live, contains('!snapshot.metadata.isFromCache'));
        expect(live, contains('_reconcileInitiallyActiveBusiness'));
        expect(live, contains('_scheduleBusinessReconciliationRetry'));
        expect(live, contains(".orderBy('updatedAt', descending: true)"));
        expect(
          liveRoot,
          contains('_scheduleMaintenanceTicketReconciliationRetry'),
        );
        expect(
          liveRoot,
          contains(
            'listenerCount: listenerSpecs.length + businessSpecs.length',
          ),
        );
        expect(
          liveRoot,
          isNot(contains('listenerSpecs.length + businessSpecs.length + 1')),
        );
        expect(
          live,
          isNot(contains(".collection('pilot_record_purge_receipts')")),
        );
      },
    );

    test('only failed synchronization uses bounded recovery backoff', () {
      expect(automaticSyncFailureRetryDelay(1), const Duration(seconds: 1));
      expect(automaticSyncFailureRetryDelay(2), const Duration(seconds: 3));
      expect(automaticSyncFailureRetryDelay(3), const Duration(seconds: 10));
      expect(automaticSyncFailureRetryDelay(4), const Duration(seconds: 30));
      expect(automaticSyncFailureRetryDelay(0), isNull);
      expect(automaticSyncFailureRetryDelay(5), const Duration(seconds: 30));
      expect(automaticSyncFailureRetryDelay(100), const Duration(seconds: 30));
    });

    test(
      'local recovery pauses both synchronization and live remote listeners',
      () {
        final app = File('lib/main.dart').readAsStringSync();
        final indicator =
            File(
              'lib/core/widgets/sync_status_indicator.dart',
            ).readAsStringSync();

        expect(coordinator, contains('Future<T> runWithSyncPaused<T>'));
        expect(coordinator, contains('await activeRun.future'));
        expect(coordinator, contains('force: true'));
        expect(app, contains("pauseForLifecycle(reason: 'local_recovery')"));
        expect(app, contains('liveService.resumeAfterLifecyclePause()'));
        expect(indicator, contains('Remove my unsynced local data'));
        expect(indicator, contains('discardOwnRejectedChanges(actor: actor)'));
      },
    );

    test(
      'irreversible pilot removal stays Admin-only, receipted and bounded',
      () {
        final handler =
            File('functions/src/pilotRecordPurge.ts').readAsStringSync();
        final authority =
            File(
              'functions/src/maintenanceWorkflow/commandAuthority.ts',
            ).readAsStringSync();
        final rules = File('firestore.rules').readAsStringSync();
        final dialog =
            File(
              'lib/features/admin/presentation/admin_data_browser/admin_pilot_purge.dart',
            ).readAsStringSync();

        expect(handler, contains('PILOT_PURGE_ALLOWED_COLLECTIONS'));
        expect(handler, contains('source.data.isDeleted !== true'));
        expect(handler, contains('requireNoDependencies'));
        expect(handler, contains('pilotPurgeSourceDigest(source.data)'));
        expect(handler, contains('tx.create(receiptPath'));
        expect(handler, contains('tx.delete(sourcePath)'));
        expect(authority, contains('case "pilotRecord.purge":'));
        expect(authority, contains('if (!actor.roles.has("admin")) denied();'));
        expect(
          rules,
          isNot(contains('match /pilot_record_purge_receipts/{docId}')),
        );
        expect(dialog, contains("confirmation: 'DELETE \$documentId'"));
        expect(dialog, contains('!actor.isAdmin'));
      },
    );
  });
}
