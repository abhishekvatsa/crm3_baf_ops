// FILE: test/isar_schema_migrator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';

void main() {
  group('IsarSchemaMigrator', () {
    test('stamps a fresh install before Isar.open', () async {
      final store = InMemoryIsarSchemaVersionStore();

      final result = await IsarSchemaMigrator.ensureBeforeOpen(
        store: store,
        databaseDirectoryPath: '/tmp/fresh',
        hasExistingLocalStore: false,
      );

      expect(result.outcome, IsarSchemaMigrationOutcome.freshInstallStamped);
      expect(result.fromVersion, 0);
      expect(result.toVersion, IsarSchemaMigrator.currentSchemaVersion);
      expect(store.version, IsarSchemaMigrator.currentSchemaVersion);
      expect(store.fingerprint, IsarSchemaMigrator.currentSchemaFingerprint);
    });

    test(
      'baseline-stamps an existing legacy install without opening Isar',
      () async {
        final store = InMemoryIsarSchemaVersionStore();

        final result = await IsarSchemaMigrator.ensureBeforeOpen(
          store: store,
          databaseDirectoryPath: '/tmp/existing',
          hasExistingLocalStore: true,
        );

        expect(
          result.outcome,
          IsarSchemaMigrationOutcome.existingInstallBaselineStamped,
        );
        expect(result.hadExistingLocalStore, isTrue);
        expect(store.version, IsarSchemaMigrator.currentSchemaVersion);
      },
    );

    test('does nothing when the marker is already current', () async {
      final store = InMemoryIsarSchemaVersionStore(
        version: IsarSchemaMigrator.currentSchemaVersion,
        fingerprint: IsarSchemaMigrator.currentSchemaFingerprint,
      );

      final result = await IsarSchemaMigrator.ensureBeforeOpen(
        store: store,
        databaseDirectoryPath: '/tmp/current',
        hasExistingLocalStore: true,
      );

      expect(result.outcome, IsarSchemaMigrationOutcome.alreadyCurrent);
      expect(result.changed, isFalse);
    });

    test('refuses same-version schema fingerprint drift', () async {
      final store = InMemoryIsarSchemaVersionStore(
        version: IsarSchemaMigrator.currentSchemaVersion,
        fingerprint: 'unexpected-fingerprint',
      );

      expect(
        () => IsarSchemaMigrator.ensureBeforeOpen(
          store: store,
          databaseDirectoryPath: '/tmp/fingerprint-drift',
          hasExistingLocalStore: true,
        ),
        throwsA(isA<IsarSchemaMigrationException>()),
      );
      expect(store.fingerprint, 'unexpected-fingerprint');
    });

    test(
      'runs ordered migration steps and advances the marker after each step',
      () async {
        final store = InMemoryIsarSchemaVersionStore(version: 1);
        final calls = <String>[];
        final plan = IsarSchemaMigrationPlan(
          currentVersion: 3,
          schemaFingerprint: 'test:v3',
          stepsByTargetVersion: {
            2: (context) async {
              calls.add('${context.fromVersion}->${context.toVersion}');
              expect(context.hasExistingLocalStore, isTrue);
            },
            3: (context) async {
              calls.add('${context.fromVersion}->${context.toVersion}');
            },
          },
        );

        final result = await IsarSchemaMigrator.ensureBeforeOpen(
          store: store,
          databaseDirectoryPath: '/tmp/migrated',
          hasExistingLocalStore: true,
          plan: plan,
        );

        expect(result.outcome, IsarSchemaMigrationOutcome.migrated);
        expect(calls, ['1->2', '2->3']);
        expect(store.version, 3);
        expect(store.fingerprint, 'test:v3');
      },
    );

    test(
      'refuses to silently advance when a future migration step is missing',
      () async {
        final store = InMemoryIsarSchemaVersionStore(version: 1);
        const plan = IsarSchemaMigrationPlan(
          currentVersion: 2,
          schemaFingerprint: 'test:v2',
        );

        expect(
          () => IsarSchemaMigrator.ensureBeforeOpen(
            store: store,
            databaseDirectoryPath: '/tmp/missing',
            hasExistingLocalStore: true,
            plan: plan,
          ),
          throwsA(isA<MissingIsarSchemaMigrationStepException>()),
        );
        expect(store.version, 1);
      },
    );

    test('refuses to open a database created by a newer app build', () async {
      final store = InMemoryIsarSchemaVersionStore(version: 99);

      expect(
        () => IsarSchemaMigrator.ensureBeforeOpen(
          store: store,
          databaseDirectoryPath: '/tmp/newer',
          hasExistingLocalStore: true,
        ),
        throwsA(isA<IsarSchemaMigrationException>()),
      );
    });
  });
}
