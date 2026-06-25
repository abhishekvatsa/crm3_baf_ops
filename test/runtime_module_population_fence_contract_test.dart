import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ND-1/ND-2 complete runtime-module population fence contract', () {
    test(
      'local-first authoring routes create and soft delete through governed callable',
      () {
        final service = _read(
          'lib/features/planned_maintenance/services/'
          'runtime_job_module_population_service.dart',
        );
        final provider = _read(
          'lib/features/planned_maintenance/providers/job_module_provider.dart',
        );

        expect(service, contains("'mutateRuntimeJobModulePopulation'"));
        expect(service, contains("'asia-south1'"));
        expect(service, contains("'operation': operation"));
        expect(service, contains("'module': module.toMap()"));
        expect(service, contains('acceptedAtPopulationVersion'));
        expect(service, contains('currentParentPopulationVersion'));

        expect(provider, contains('_populationService.acceptModule(module)'));
        expect(
          provider,
          contains('_populationService.softDeleteModule(tombstone)'),
        );
        expect(
          provider,
          contains('await _populationService.acceptModule(record);'),
        );
        expect(
          provider,
          contains(
            'Deleting a never-synchronized local module is already remotely',
          ),
        );
        expect(
          provider.indexOf(
            'final accepted = await _populationService.acceptModule(module);',
          ),
          lessThan(
            provider.indexOf(
              'module.isSynced = true;',
              provider.indexOf(
                'final accepted = await _populationService.acceptModule(module);',
              ),
            ),
          ),
          reason:
              'web/in-memory state may be marked synced only after server success',
        );
        expect(
          provider,
          contains(
            'jobModuleClientSnapshotsEquivalentForSync(record, existing)',
          ),
        );
        expect(
          provider,
          contains('callable committed but the response was lost'),
          reason:
              'first-create lost-response replay must be an explicit no-op boundary',
        );
        expect(
          provider,
          contains('never a duplicate create record'),
          reason: 'server-governed create must have one authoritative audit',
        );
        expect(
          provider,
          contains('Do not create a second client-side audit'),
          reason:
              'server-governed soft delete must have one authoritative audit',
        );
      },
    );

    test(
      'rules deny direct population mutations and require an open parent for all ordinary updates',
      () {
        final rules = _read('firestore.rules');
        final matchBlock = _blockStartingAt(
          rules,
          'match /job_modules/{docId}',
        );
        final deleteBlock = _blockStartingAt(
          rules,
          'function validJobModuleSoftDelete',
        );
        final updateBlock = _blockStartingAt(
          rules,
          'function validJobModuleUpdatePayload',
        );

        expect(matchBlock, contains('allow create: if false;'));
        expect(deleteBlock, contains('return false;'));
        expect(updateBlock, contains('jobModuleParentExistsAndIsOpen()'));
        expect(rules, contains(".data.get('isCompleted', false) == false"));
        expect(rules, contains(".data.get('isDeleted', false) == false"));
        expect(
          rules,
          contains("resource.data.get('isDeleted', false) == false"),
        );
        expect(
          rules,
          contains("request.resource.data.get('isDeleted', false) == false"),
        );
        expect(rules, contains("'jobExecutionFirestoreId'"));
        expect(rules, contains("'parentPopulationVersionAtAcceptance'"));
        expect(rules, contains("'parentPopulationVersionAtMutation'"));
      },
    );

    test(
      'assignment, population mutation and closure share a dedicated server-only population authority',
      () {
        final assignment = _read(
          'functions/src/publishedTemplateAssignment.ts',
        );
        final closure = _read('functions/src/plannedJobClosure.ts');
        final clientPreview = _read(
          'lib/features/planned_maintenance/domain/'
          'planned_job_closure_attestation.dart',
        );
        final mutation = _read('functions/src/runtimeJobModulePopulation.ts');

        expect(assignment, contains('modulePopulationVersion: 1'));
        expect(assignment, contains('modulePopulationSchemaVersion'));
        expect(closure, contains('CLOSURE_ATTESTATION_SCHEMA_VERSION = 2'));
        expect(clientPreview, contains('static const int schemaVersion = 1'));
        expect(
          clientPreview,
          isNot(contains('modulePopulationVersionAtCompletion')),
          reason:
              'local preview must not pretend to own remote population authority',
        );
        expect(closure, contains('modulePopulationVersionAtCompletion'));
        expect(closure, contains('modulePopulationSchemaVersionAtCompletion'));
        expect(
          mutation,
          contains('modulePopulationVersion: nextPopulationVersion'),
        );
        expect(mutation, contains('transaction.update(executionRef'));
        expect(
          mutation,
          isNot(contains('version: nextPopulationVersion')),
          reason:
              'population revision must not overload execution freshness version',
        );
      },
    );

    test(
      'callable validates identity, provenance, lifecycle, idempotency and immutable audit',
      () {
        final mutation = _read('functions/src/runtimeJobModulePopulation.ts');
        final index = _read('functions/src/index.ts');
        final callable = _read(
          'functions/src/runtimeJobModulePopulationCallable.ts',
        );

        for (final marker in [
          'CLIENT_MODULE_FIELDS',
          'unexpected-module-fields',
          'runtime-module-classification-required',
          'module-actor-preservation-role-required',
          'module-actor-preservation-reason-required',
          'parent-asset-mismatch',
          'parent-charge-mismatch',
          'populationCreateFingerprint',
          'populationSoftDeleteFingerprint',
          'acceptedAtPopulationVersion',
          'currentParentPopulationVersion',
          'audit_logs',
          'population-audit-missing',
          'population-audit-mismatch',
          'population-audit-preexisting',
          'beforeMutationWritesForTest',
        ]) {
          expect(mutation, contains(marker));
        }
        expect(
          index,
          contains('timestampFromDate: admin.firestore.Timestamp.fromDate'),
        );
        expect(callable, contains('throw new HttpsError(error.code'));
      },
    );

    test(
      'real emulator matrix is mandatory in PR/main CI with governed tooling',
      () {
        final workflow = _read('.github/workflows/release-gate.yml');
        final rootPackage = _read('package.json');
        final functionsPackage = _read('functions/package.json');

        expect(workflow, contains('pull_request:'));
        expect(workflow, contains('push:'));
        expect(workflow, contains('npm run emulator:test:governed'));
        final actionRefs = RegExp(r'uses:\s+[^@\s]+@([0-9a-fA-F]+)')
            .allMatches(workflow)
            .map((match) => match.group(1)!)
            .toList(growable: false);
        expect(actionRefs, isNotEmpty);
        expect(
          actionRefs.every((sha) => RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(sha)),
          isTrue,
          reason:
              'normal CI actions must use valid full 40-character commit pins',
        );
        expect(
          rootPackage,
          contains('tooling/firebase-cli/node_modules/firebase-tools'),
        );
        for (final suite in [
          'plannedJobClosure.firestoreEmulator.test.js',
          'runtimeJobModulePopulation.firestoreEmulator.test.js',
          'publishedTemplateAssignment.firestoreEmulator.test.js',
        ]) {
          expect(functionsPackage, contains(suite));
        }
      },
    );

    test(
      'durable population rejection is awaited, preserved and excluded from synced snapshots',
      () {
        final sync = _read(
          'lib/core/services/sync_service.push_infrastructure.dart',
        );
        final jobSync = _read(
          'lib/core/services/sync_service.job_modules.dart',
        );
        final behavioral = _read(
          'test/runtime_module_population_no_loss_test.dart',
        );

        expect(sync, contains('RuntimeJobModulePopulationException'));
        expect(
          sync,
          contains('await _upsertSyncRejection(detail, failClosed: true);'),
        );
        expect(sync, contains('if (failClosed) rethrow;'));
        expect(sync, contains('_recordJobModulePopulationFailure'));
        expect(jobSync, contains('error.shouldRetryImmediately'));
        expect(jobSync, contains('await _recordJobModulePopulationFailure'));
        expect(jobSync, contains('markModulesSyncedIfUnchanged'));
        expect(
          jobSync,
          contains('A different authoritative remote tombstone already won'),
        );
        expect(
          jobSync,
          contains('RemoteTombstoneApplyOutcome.localDirtyPreserved'),
        );
        expect(behavioral, contains('expect(preserved!.isSynced, isFalse)'));
        expect(behavioral, contains('expect(rejections, hasLength(1))'));
      },
    );
  });
}

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path must exist.');
  return file.readAsStringSync();
}

String _blockStartingAt(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: 'Missing marker: $marker');
  final nextFunction = source.indexOf('\n    function ', start + marker.length);
  final nextMatch = source.indexOf('\n    match /', start + marker.length);
  final candidates = <int>[
    if (nextFunction >= 0) nextFunction,
    if (nextMatch >= 0) nextMatch,
  ]..sort();
  if (candidates.isEmpty) return source.substring(start);
  return source.substring(start, candidates.first);
}
