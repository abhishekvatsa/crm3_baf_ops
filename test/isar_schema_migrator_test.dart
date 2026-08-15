// FILE: test/isar_schema_migrator_test.dart

import 'dart:convert';

import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _generationA = '11111111-1111-4111-8111-111111111111';
const _generationB = '22222222-2222-4222-8222-222222222222';

IsarSchemaProvenanceMarker _marker({
  IsarSchemaMarkerState state = IsarSchemaMarkerState.committed,
  int schemaVersion = IsarSchemaMigrator.currentSchemaVersion,
  String schemaFingerprint = IsarSchemaMigrator.currentSchemaFingerprint,
  String databaseGenerationId = _generationA,
  IsarSchemaMarkerOrigin origin = IsarSchemaMarkerOrigin.freshInstall,
  int? sourceSchemaVersion,
  String? sourceSchemaFingerprint,
}) {
  return IsarSchemaProvenanceMarker(
    state: state,
    schemaVersion: schemaVersion,
    schemaFingerprint: schemaFingerprint,
    databaseGenerationId: databaseGenerationId,
    origin: origin,
    sourceSchemaVersion: sourceSchemaVersion,
    sourceSchemaFingerprint: sourceSchemaFingerprint,
  );
}

Future<IsarSchemaOpenPreparation> _prepare({
  required InMemoryIsarSchemaProvenanceStore store,
  required bool hasExistingLocalStore,
  IsarSchemaMigrationPlan plan = IsarSchemaMigrator.defaultPlan,
  String generation = _generationA,
}) {
  return IsarSchemaMigrator.prepareBeforeOpen(
    store: store,
    databaseDirectoryPath: '/tmp/isar-provenance',
    hasExistingLocalStore: hasExistingLocalStore,
    plan: plan,
    databaseGenerationIdFactory: () => generation,
  );
}

void main() {
  group('canonical Isar provenance marker', () {
    test('round-trips the exact marker envelope', () {
      final marker = _marker();

      final decoded = IsarSchemaProvenanceMarker.decode(marker.encode());

      expect(decoded.toJson(), marker.toJson());
      expect(decoded.state, IsarSchemaMarkerState.committed);
      expect(decoded.databaseGenerationId, _generationA);
    });

    test('rejects unknown fields and inconsistent source evidence', () {
      final withUnknown = Map<String, Object?>.from(_marker().toJson())
        ..['unexpected'] = true;
      expect(
        () => IsarSchemaProvenanceMarker.decode(jsonEncode(withUnknown)),
        throwsA(
          isA<IsarSchemaMarkerFormatException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'canonical-marker-invalid-shape',
          ),
        ),
      );

      final inconsistent = Map<String, Object?>.from(_marker().toJson())
        ..['sourceSchemaVersion'] = 1;
      expect(
        () => IsarSchemaProvenanceMarker.decode(jsonEncode(inconsistent)),
        throwsA(
          isA<IsarSchemaMarkerFormatException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'canonical-marker-source-inconsistent',
          ),
        ),
      );
    });
  });

  group('SharedPreferences Isar provenance storage', () {
    test('rejects a wrong-typed canonical marker value', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesIsarSchemaProvenanceStore.canonicalMarkerKey: 3,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesIsarSchemaProvenanceStore(preferences);

      await expectLater(
        store.readCanonicalMarkerJson(),
        throwsA(
          isA<IsarSchemaMarkerFormatException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'canonical-marker-storage-type-invalid',
          ),
        ),
      );
    });

    test('rejects wrong-typed legacy marker values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesIsarSchemaProvenanceStore.legacySchemaVersionKey: '3',
        SharedPreferencesIsarSchemaProvenanceStore.legacySchemaFingerprintKey:
            3,
      });
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesIsarSchemaProvenanceStore(preferences);

      await expectLater(
        store.readLegacySchemaVersion(),
        throwsA(
          isA<IsarSchemaMarkerFormatException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'legacy-marker-version-type-invalid',
          ),
        ),
      );
      await expectLater(
        store.readLegacySchemaFingerprint(),
        throwsA(
          isA<IsarSchemaMarkerFormatException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'legacy-marker-fingerprint-type-invalid',
          ),
        ),
      );
    });
  });

  group('IsarSchemaMigrator preparation and commit', () {
    test(
      'fresh install is prepared then committed after successful open',
      () async {
        final store = InMemoryIsarSchemaProvenanceStore();

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: false,
        );

        expect(
          preparation.result.outcome,
          IsarSchemaMigrationOutcome.freshInstallInitialized,
        );
        expect(preparation.marker.state, IsarSchemaMarkerState.prepared);
        expect(preparation.marker.databaseGenerationId, _generationA);
        expect(store.canonicalWriteCount, 1);

        final committed = await preparation.commitAfterSuccessfulOpen();

        expect(committed.state, IsarSchemaMarkerState.committed);
        expect(store.canonicalWriteCount, 2);
        expect(
          IsarSchemaProvenanceMarker.decode(store.canonicalMarkerJson!).state,
          IsarSchemaMarkerState.committed,
        );
      },
    );

    test(
      'existing store without any marker fails closed without a write',
      () async {
        final store = InMemoryIsarSchemaProvenanceStore();

        await expectLater(
          _prepare(store: store, hasExistingLocalStore: true),
          throwsA(
            isA<IsarSchemaMigrationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'existing-store-unmarked',
            ),
          ),
        );

        expect(store.canonicalMarkerJson, isNull);
        expect(store.canonicalWriteCount, 0);
      },
    );

    test('partial legacy marker fails closed in either direction', () async {
      for (final store in <InMemoryIsarSchemaProvenanceStore>[
        InMemoryIsarSchemaProvenanceStore(legacyVersion: 4),
        InMemoryIsarSchemaProvenanceStore(
          legacyFingerprint: IsarSchemaMigrator.currentSchemaFingerprint,
        ),
      ]) {
        await expectLater(
          _prepare(store: store, hasExistingLocalStore: true),
          throwsA(
            isA<IsarSchemaMigrationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'legacy-marker-incomplete',
            ),
          ),
        );
        expect(store.canonicalWriteCount, 0);
      }
    });

    test(
      'complete current legacy marker receives canonical provenance',
      () async {
        final store = InMemoryIsarSchemaProvenanceStore(
          legacyVersion: IsarSchemaMigrator.currentSchemaVersion,
          legacyFingerprint: IsarSchemaMigrator.currentSchemaFingerprint,
        );

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: true,
        );

        expect(
          preparation.result.outcome,
          IsarSchemaMigrationOutcome.legacyMarkerMigrated,
        );
        expect(
          preparation.marker.origin,
          IsarSchemaMarkerOrigin.legacyCompleteMarker,
        );
        expect(
          preparation.marker.sourceSchemaVersion,
          IsarSchemaMigrator.currentSchemaVersion,
        );
        expect(store.legacyVersion, IsarSchemaMigrator.currentSchemaVersion);

        await preparation.commitAfterSuccessfulOpen();

        expect(store.legacyVersion, isNull);
        expect(store.legacyFingerprint, isNull);
        expect(
          IsarSchemaProvenanceMarker.decode(store.canonicalMarkerJson!).state,
          IsarSchemaMarkerState.committed,
        );
      },
    );

    test('repository-unproved v2 legacy fingerprint is not guessed', () async {
      final store = InMemoryIsarSchemaProvenanceStore(
        legacyVersion: 2,
        legacyFingerprint: 'v2:legacy-workflow-persistence',
      );

      await expectLater(
        _prepare(store: store, hasExistingLocalStore: true),
        throwsA(
          isA<IsarSchemaMigrationException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'stored-schema-fingerprint-unrecognized',
          ),
        ),
      );

      expect(store.canonicalWriteCount, 0);
    });

    test('repository-proven v1 legacy marker reaches prepared v6', () async {
      final store = InMemoryIsarSchemaProvenanceStore(
        legacyVersion: 1,
        legacyFingerprint: IsarSchemaMigrator.v1SchemaFingerprint,
      );

      final preparation = await _prepare(
        store: store,
        hasExistingLocalStore: true,
      );

      expect(preparation.result.fromVersion, 1);
      expect(preparation.result.toVersion, 6);
      expect(preparation.marker.sourceSchemaVersion, 1);
      expect(preparation.marker.state, IsarSchemaMarkerState.prepared);
      await preparation.commitAfterSuccessfulOpen();
    });

    test(
      'current committed marker opens without rewriting its generation',
      () async {
        final marker = _marker();
        final store = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson: marker.encode(),
        );

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: true,
          generation: _generationB,
        );

        expect(
          preparation.result.outcome,
          IsarSchemaMigrationOutcome.alreadyCurrent,
        );
        expect(preparation.marker.databaseGenerationId, _generationA);
        expect(store.canonicalWriteCount, 0);
        expect(
          await preparation.commitAfterSuccessfulOpen(),
          same(preparation.marker),
        );
        expect(store.canonicalWriteCount, 0);
      },
    );

    test('same-version fingerprint drift fails before open', () async {
      final store = InMemoryIsarSchemaProvenanceStore(
        canonicalMarkerJson:
            _marker(schemaFingerprint: 'unexpected-fingerprint').encode(),
      );

      await expectLater(
        _prepare(store: store, hasExistingLocalStore: true),
        throwsA(
          isA<IsarSchemaMigrationException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'stored-schema-fingerprint-unrecognized',
          ),
        ),
      );
    });

    test(
      'repository-proven v3 marker advances through v4, v5, and v6 steps',
      () async {
        final store = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson:
              _marker(
                schemaVersion: 3,
                schemaFingerprint: IsarSchemaMigrator.v3SchemaFingerprint,
              ).encode(),
        );

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: true,
        );

        expect(preparation.result.fromVersion, 3);
        expect(preparation.result.toVersion, 6);
        expect(preparation.marker.state, IsarSchemaMarkerState.prepared);
        expect(preparation.marker.sourceSchemaVersion, 3);
        expect(
          preparation.marker.sourceSchemaFingerprint,
          IsarSchemaMigrator.v3SchemaFingerprint,
        );
        await preparation.commitAfterSuccessfulOpen();
      },
    );

    test('committed migration source evidence must also be proven', () async {
      final store = InMemoryIsarSchemaProvenanceStore(
        canonicalMarkerJson:
            _marker(
              state: IsarSchemaMarkerState.committed,
              schemaVersion: 4,
              schemaFingerprint: IsarSchemaMigrator.v4SchemaFingerprint,
              origin: IsarSchemaMarkerOrigin.schemaMigration,
              sourceSchemaVersion: 3,
              sourceSchemaFingerprint: 'unproved-v3',
            ).encode(),
      );

      await expectLater(
        _prepare(store: store, hasExistingLocalStore: true),
        throwsA(
          isA<IsarSchemaMigrationException>()
              .having(
                (error) => error.reasonCode,
                'reasonCode',
                'stored-schema-fingerprint-unrecognized',
              )
              .having(
                (error) => error.markerDisposition,
                'markerDisposition',
                'canonical-committed-source',
              ),
        ),
      );
    });

    test('malformed canonical marker fails when durable data exists', () async {
      final store = InMemoryIsarSchemaProvenanceStore(
        canonicalMarkerJson: '{"state":"COMMITTED"}',
      );

      await expectLater(
        _prepare(store: store, hasExistingLocalStore: true),
        throwsA(
          isA<IsarSchemaMigrationException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'canonical-marker-invalid-shape',
          ),
        ),
      );

      expect(store.canonicalWriteCount, 0);
    });

    test('prepared fresh open resumes the same database generation', () async {
      final prepared = _marker(
        state: IsarSchemaMarkerState.prepared,
        origin: IsarSchemaMarkerOrigin.freshInstall,
      );
      final store = InMemoryIsarSchemaProvenanceStore(
        canonicalMarkerJson: prepared.encode(),
      );

      final preparation = await _prepare(
        store: store,
        hasExistingLocalStore: true,
        generation: _generationB,
      );

      expect(
        preparation.result.outcome,
        IsarSchemaMigrationOutcome.preparedOpenResumed,
      );
      expect(preparation.marker.databaseGenerationId, _generationA);
      await preparation.commitAfterSuccessfulOpen();
      expect(
        IsarSchemaProvenanceMarker.decode(
          store.canonicalMarkerJson!,
        ).databaseGenerationId,
        _generationA,
      );
    });

    test(
      'prepared fresh marker can resume before the store is created',
      () async {
        final prepared = _marker(
          state: IsarSchemaMarkerState.prepared,
          origin: IsarSchemaMarkerOrigin.freshInstall,
        );
        final store = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson: prepared.encode(),
        );

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: false,
          generation: _generationB,
        );

        expect(
          preparation.result.outcome,
          IsarSchemaMigrationOutcome.preparedOpenResumed,
        );
        expect(preparation.marker.databaseGenerationId, _generationA);
      },
    );

    test(
      'committed marker without a store rotates database generation',
      () async {
        final store = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson: _marker().encode(),
        );

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: false,
          generation: _generationB,
        );

        expect(
          preparation.result.outcome,
          IsarSchemaMigrationOutcome.storeReplacementInitialized,
        );
        expect(preparation.marker.databaseGenerationId, _generationB);
        expect(
          preparation.marker.origin,
          IsarSchemaMarkerOrigin.storeReplacement,
        );
      },
    );

    test(
      'prepared migration without its source store rotates generation',
      () async {
        final preparedMigration = _marker(
          state: IsarSchemaMarkerState.prepared,
          origin: IsarSchemaMarkerOrigin.schemaMigration,
          sourceSchemaVersion: 1,
          sourceSchemaFingerprint: IsarSchemaMigrator.v1SchemaFingerprint,
        );
        final store = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson: preparedMigration.encode(),
        );

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: false,
          generation: _generationB,
        );

        expect(
          preparation.result.outcome,
          IsarSchemaMigrationOutcome.storeReplacementInitialized,
        );
        expect(preparation.marker.databaseGenerationId, _generationB);
      },
    );

    test(
      'canonical marker write and readback failure stops preparation',
      () async {
        final store = InMemoryIsarSchemaProvenanceStore(
          failCanonicalWrites: true,
        );

        await expectLater(
          _prepare(store: store, hasExistingLocalStore: false),
          throwsA(
            isA<IsarSchemaMigrationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'canonical-marker-write-failed',
            ),
          ),
        );
      },
    );

    test('commit failure leaves PREPARED evidence for a safe retry', () async {
      final store = InMemoryIsarSchemaProvenanceStore();
      final preparation = await _prepare(
        store: store,
        hasExistingLocalStore: false,
      );
      store.failCanonicalWrites = true;

      await expectLater(
        preparation.commitAfterSuccessfulOpen(),
        throwsA(
          isA<IsarSchemaMigrationException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'canonical-marker-write-failed',
          ),
        ),
      );

      expect(
        IsarSchemaProvenanceMarker.decode(store.canonicalMarkerJson!).state,
        IsarSchemaMarkerState.prepared,
      );
    });

    test(
      'canonical migration preserves generation and runs ordered steps',
      () async {
        final calls = <String>[];
        final plan = IsarSchemaMigrationPlan(
          currentVersion: 3,
          schemaFingerprint: 'test:v3',
          acceptedFingerprintsByVersion: const <int, Set<String>>{
            1: <String>{'test:v1'},
            3: <String>{'test:v3'},
          },
          stepsByTargetVersion: <int, IsarSchemaMigrationStep>{
            2: (context) async {
              calls.add('${context.fromVersion}->${context.toVersion}');
              expect(context.databaseGenerationId, _generationA);
            },
            3: (context) async {
              calls.add('${context.fromVersion}->${context.toVersion}');
            },
          },
        );
        final store = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson:
              _marker(schemaVersion: 1, schemaFingerprint: 'test:v1').encode(),
        );

        final preparation = await _prepare(
          store: store,
          hasExistingLocalStore: true,
          plan: plan,
          generation: _generationB,
        );

        expect(calls, <String>['1->2', '2->3']);
        expect(preparation.marker.databaseGenerationId, _generationA);
        expect(preparation.marker.state, IsarSchemaMarkerState.prepared);
        expect(
          preparation.marker.origin,
          IsarSchemaMarkerOrigin.schemaMigration,
        );
        await preparation.commitAfterSuccessfulOpen();
      },
    );

    test(
      'missing migration step leaves explicit PREPARED recovery state',
      () async {
        const plan = IsarSchemaMigrationPlan(
          currentVersion: 2,
          schemaFingerprint: 'test:v2',
          acceptedFingerprintsByVersion: <int, Set<String>>{
            1: <String>{'test:v1'},
            2: <String>{'test:v2'},
          },
        );
        final store = InMemoryIsarSchemaProvenanceStore(
          canonicalMarkerJson:
              _marker(schemaVersion: 1, schemaFingerprint: 'test:v1').encode(),
        );

        await expectLater(
          _prepare(store: store, hasExistingLocalStore: true, plan: plan),
          throwsA(isA<MissingIsarSchemaMigrationStepException>()),
        );

        final prepared = IsarSchemaProvenanceMarker.decode(
          store.canonicalMarkerJson!,
        );
        expect(prepared.state, IsarSchemaMarkerState.prepared);
        expect(prepared.sourceSchemaVersion, 1);
      },
    );

    test('legacy cleanup failure is explicit after canonical commit', () async {
      final store = InMemoryIsarSchemaProvenanceStore(
        legacyVersion: IsarSchemaMigrator.currentSchemaVersion,
        legacyFingerprint: IsarSchemaMigrator.currentSchemaFingerprint,
        failLegacyClear: true,
      );
      final preparation = await _prepare(
        store: store,
        hasExistingLocalStore: true,
      );

      await expectLater(
        preparation.commitAfterSuccessfulOpen(),
        throwsA(
          isA<IsarSchemaMigrationException>().having(
            (error) => error.reasonCode,
            'reasonCode',
            'legacy-marker-clear-failed',
          ),
        ),
      );

      expect(
        IsarSchemaProvenanceMarker.decode(store.canonicalMarkerJson!).state,
        IsarSchemaMarkerState.committed,
      );
      expect(store.legacyVersion, IsarSchemaMigrator.currentSchemaVersion);
    });

    test(
      'invalid generated database identity fails before marker write',
      () async {
        final store = InMemoryIsarSchemaProvenanceStore();

        await expectLater(
          _prepare(
            store: store,
            hasExistingLocalStore: false,
            generation: 'not-a-generation-id',
          ),
          throwsA(
            isA<IsarSchemaMigrationException>().having(
              (error) => error.reasonCode,
              'reasonCode',
              'database-generation-invalid',
            ),
          ),
        );
        expect(store.canonicalWriteCount, 0);
      },
    );
  });
}
