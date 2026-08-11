import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:crm3_baf_ops/core/services/isar_installed_store_provenance.dart';
import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';
import 'package:flutter_test/flutter_test.dart';

const _generationId = '123e4567-e89b-42d3-a456-426614174000';

String _canonicalMarker({
  IsarSchemaMarkerState state = IsarSchemaMarkerState.committed,
  int schemaVersion = IsarSchemaMigrator.currentSchemaVersion,
  String schemaFingerprint = IsarSchemaMigrator.currentSchemaFingerprint,
  IsarSchemaMarkerOrigin origin = IsarSchemaMarkerOrigin.freshInstall,
  int? sourceSchemaVersion,
  String? sourceSchemaFingerprint,
}) {
  return IsarSchemaProvenanceMarker(
    state: state,
    schemaVersion: schemaVersion,
    schemaFingerprint: schemaFingerprint,
    databaseGenerationId: _generationId,
    origin: origin,
    sourceSchemaVersion:
        origin.requiresSource ? sourceSchemaVersion ?? 1 : null,
    sourceSchemaFingerprint:
        origin.requiresSource
            ? sourceSchemaFingerprint ?? IsarSchemaMigrator.v1SchemaFingerprint
            : null,
  ).encode();
}

void main() {
  group('privacy-safe installed Isar provenance inventory', () {
    test('classifies a fresh install without creating provenance', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: false,
        canonicalMarkerValue: null,
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );

      expect(inventory.overallDisposition, 'EMPTY_STORE_AND_MARKERS_ABSENT');
      expect(inventory.requiresGovernedRecovery, isFalse);
      expect(inventory.databaseGenerationSha256, isNull);
    });

    test('fails closed in its classification of an unmarked store', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: null,
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );

      expect(inventory.overallDisposition, 'EXISTING_STORE_UNMARKED_BLOCKED');
      expect(inventory.requiresGovernedRecovery, isTrue);
      expect(inventory.reasonCode, 'existing-store-unmarked');
    });

    test('distinguishes partial and malformed legacy markers', () {
      final partial = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: null,
        legacySchemaVersionValue: 1,
        legacySchemaFingerprintValue: null,
      );
      final malformed = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: null,
        legacySchemaVersionValue: '1',
        legacySchemaFingerprintValue: IsarSchemaMigrator.v1SchemaFingerprint,
      );

      expect(partial.legacyDisposition, IsarLegacyMarkerDisposition.partial);
      expect(
        partial.overallDisposition,
        'EXISTING_STORE_LEGACY_PARTIAL_BLOCKED',
      );
      expect(
        malformed.legacyDisposition,
        IsarLegacyMarkerDisposition.malformed,
      );
      expect(malformed.overallDisposition, 'LEGACY_MARKER_MALFORMED_BLOCKED');
    });

    test('requires governed review for a recognized complete v1 marker', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: null,
        legacySchemaVersionValue: 1,
        legacySchemaFingerprintValue: IsarSchemaMigrator.v1SchemaFingerprint,
      );

      expect(inventory.legacyDisposition, IsarLegacyMarkerDisposition.complete);
      expect(inventory.legacyFingerprintRecognized, isTrue);
      expect(
        inventory.overallDisposition,
        'EXISTING_STORE_LEGACY_REVIEW_REQUIRED',
      );
      expect(inventory.requiresGovernedRecovery, isTrue);
    });

    test('reports current committed provenance without raw generation ID', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: _canonicalMarker(),
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );
      final expectedDigest =
          sha256.convert(utf8.encode(_generationId)).toString().toUpperCase();
      final encoded = jsonEncode(inventory.toMap());

      expect(
        inventory.canonicalDisposition,
        IsarCanonicalMarkerDisposition.committed,
      );
      expect(inventory.overallDisposition, 'EXISTING_STORE_CANONICAL_CURRENT');
      expect(inventory.databaseGenerationSha256, expectedDigest);
      expect(inventory.requiresGovernedRecovery, isFalse);
      expect(encoded, isNot(contains(_generationId)));
      expect(encoded, contains('"rawMarkerValuesIncluded":false'));
    });

    test('requires restart review for PREPARED provenance', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: _canonicalMarker(
          state: IsarSchemaMarkerState.prepared,
        ),
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );

      expect(
        inventory.canonicalDisposition,
        IsarCanonicalMarkerDisposition.prepared,
      );
      expect(
        inventory.overallDisposition,
        'EXISTING_STORE_PREPARED_RESTART_REQUIRED',
      );
      expect(inventory.requiresGovernedRecovery, isTrue);
    });

    test('blocks malformed and unsupported canonical provenance', () {
      final malformed = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: <String, Object?>{'not': 'a stored string'},
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );
      final unsupported = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: _canonicalMarker(
          schemaFingerprint: 'v3:unrecognized',
        ),
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );

      expect(
        malformed.overallDisposition,
        'CANONICAL_MARKER_MALFORMED_BLOCKED',
      );
      expect(
        unsupported.overallDisposition,
        'EXISTING_STORE_CANONICAL_UNSUPPORTED_BLOCKED',
      );
      expect(malformed.requiresGovernedRecovery, isTrue);
      expect(unsupported.requiresGovernedRecovery, isTrue);
    });

    test('blocks a current target with unsupported migration ancestry', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: _canonicalMarker(
          origin: IsarSchemaMarkerOrigin.schemaMigration,
          sourceSchemaFingerprint: 'v1:unrecognized',
        ),
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );

      expect(
        inventory.overallDisposition,
        'EXISTING_STORE_CANONICAL_UNSUPPORTED_BLOCKED',
      );
      expect(inventory.canonicalFingerprintRecognized, isFalse);
      expect(inventory.canonicalSourceFingerprintRecognized, isFalse);
      expect(inventory.reasonCode, 'stored-schema-fingerprint-unrecognized');
      expect(inventory.requiresGovernedRecovery, isTrue);
    });

    test('preserves the startup pre-open inventory for later reporting', () {
      final preOpen = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: null,
        legacySchemaVersionValue: 1,
        legacySchemaFingerprintValue: IsarSchemaMigrator.v1SchemaFingerprint,
      );

      preserveStartupPreOpenIsarProvenanceInventory(preOpen);

      expect(readStartupPreOpenIsarProvenanceInventory(), same(preOpen));
      expect(
        readStartupPreOpenIsarProvenanceInventory()!.overallDisposition,
        'EXISTING_STORE_LEGACY_REVIEW_REQUIRED',
      );
    });

    test('malformed legacy storage blocks even beside a current marker', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: true,
        canonicalMarkerValue: _canonicalMarker(),
        legacySchemaVersionValue: '3',
        legacySchemaFingerprintValue:
            IsarSchemaMigrator.currentSchemaFingerprint,
      );

      expect(inventory.overallDisposition, 'LEGACY_MARKER_MALFORMED_BLOCKED');
      expect(inventory.requiresGovernedRecovery, isTrue);
      expect(inventory.reasonCode, 'legacy-marker-version-type-invalid');
    });

    test(
      'malformed canonical storage blocks even when the store is absent',
      () {
        final inventory = IsarInstalledStoreProvenanceInventory.classify(
          hasDurableStore: false,
          canonicalMarkerValue: 7,
          legacySchemaVersionValue: null,
          legacySchemaFingerprintValue: null,
        );

        expect(
          inventory.overallDisposition,
          'CANONICAL_MARKER_MALFORMED_BLOCKED',
        );
        expect(inventory.requiresGovernedRecovery, isTrue);
      },
    );

    test('requires generation rotation when the durable store disappeared', () {
      final inventory = IsarInstalledStoreProvenanceInventory.classify(
        hasDurableStore: false,
        canonicalMarkerValue: _canonicalMarker(),
        legacySchemaVersionValue: null,
        legacySchemaFingerprintValue: null,
      );

      expect(
        inventory.overallDisposition,
        'STORE_ABSENT_GENERATION_ROTATION_REQUIRED',
      );
      expect(inventory.requiresGovernedRecovery, isFalse);
    });
  });
}
