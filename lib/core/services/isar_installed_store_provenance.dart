// FILE: lib/core/services/isar_installed_store_provenance.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'isar_schema_migration.dart';

enum IsarCanonicalMarkerDisposition {
  absent('ABSENT'),
  malformed('MALFORMED'),
  prepared('PREPARED'),
  committed('COMMITTED');

  final String wireName;
  const IsarCanonicalMarkerDisposition(this.wireName);
}

enum IsarLegacyMarkerDisposition {
  absent('ABSENT'),
  partial('PARTIAL'),
  malformed('MALFORMED'),
  complete('COMPLETE');

  final String wireName;
  const IsarLegacyMarkerDisposition(this.wireName);
}

/// Privacy-safe, non-mutating classification of an installed local store.
///
/// Raw marker JSON and database-generation identifiers are deliberately not
/// retained. The generation digest permits continuity comparisons without
/// exporting the identifier itself.
class IsarInstalledStoreProvenanceInventory {
  final bool captureSupported;
  final bool hasDurableStore;
  final IsarCanonicalMarkerDisposition canonicalDisposition;
  final IsarLegacyMarkerDisposition legacyDisposition;
  final String overallDisposition;
  final int? canonicalSchemaVersion;
  final String? canonicalState;
  final String? canonicalOrigin;
  final bool canonicalFingerprintRecognized;
  final bool canonicalSourceFingerprintRecognized;
  final int? legacySchemaVersion;
  final bool legacyFingerprintRecognized;
  final String? databaseGenerationSha256;
  final bool requiresGovernedRecovery;
  final String? reasonCode;

  const IsarInstalledStoreProvenanceInventory({
    required this.captureSupported,
    required this.hasDurableStore,
    required this.canonicalDisposition,
    required this.legacyDisposition,
    required this.overallDisposition,
    required this.canonicalSchemaVersion,
    required this.canonicalState,
    required this.canonicalOrigin,
    required this.canonicalFingerprintRecognized,
    required this.canonicalSourceFingerprintRecognized,
    required this.legacySchemaVersion,
    required this.legacyFingerprintRecognized,
    required this.databaseGenerationSha256,
    required this.requiresGovernedRecovery,
    required this.reasonCode,
  });

  factory IsarInstalledStoreProvenanceInventory.unsupported() {
    return const IsarInstalledStoreProvenanceInventory(
      captureSupported: false,
      hasDurableStore: false,
      canonicalDisposition: IsarCanonicalMarkerDisposition.absent,
      legacyDisposition: IsarLegacyMarkerDisposition.absent,
      overallDisposition: 'UNSUPPORTED_PLATFORM',
      canonicalSchemaVersion: null,
      canonicalState: null,
      canonicalOrigin: null,
      canonicalFingerprintRecognized: false,
      canonicalSourceFingerprintRecognized: false,
      legacySchemaVersion: null,
      legacyFingerprintRecognized: false,
      databaseGenerationSha256: null,
      requiresGovernedRecovery: false,
      reasonCode: 'installed-store-inventory-unsupported',
    );
  }

  static IsarInstalledStoreProvenanceInventory classify({
    required bool hasDurableStore,
    required Object? canonicalMarkerValue,
    required Object? legacySchemaVersionValue,
    required Object? legacySchemaFingerprintValue,
    IsarSchemaMigrationPlan plan = IsarSchemaMigrator.defaultPlan,
  }) {
    IsarSchemaProvenanceMarker? canonicalMarker;
    var canonicalDisposition = IsarCanonicalMarkerDisposition.absent;
    String? canonicalError;

    if (canonicalMarkerValue != null) {
      if (canonicalMarkerValue is! String) {
        canonicalDisposition = IsarCanonicalMarkerDisposition.malformed;
        canonicalError = 'canonical-marker-storage-type-invalid';
      } else {
        try {
          canonicalMarker = IsarSchemaProvenanceMarker.decode(
            canonicalMarkerValue,
          );
          canonicalDisposition =
              canonicalMarker.state == IsarSchemaMarkerState.prepared
                  ? IsarCanonicalMarkerDisposition.prepared
                  : IsarCanonicalMarkerDisposition.committed;
        } on IsarSchemaMarkerFormatException catch (error) {
          canonicalDisposition = IsarCanonicalMarkerDisposition.malformed;
          canonicalError = error.reasonCode;
        }
      }
    }

    final legacyVersionPresent = legacySchemaVersionValue != null;
    final legacyFingerprintPresent = legacySchemaFingerprintValue != null;
    late final IsarLegacyMarkerDisposition legacyDisposition;
    String? legacyError;
    int? legacyVersion;
    String? legacyFingerprint;

    if (!legacyVersionPresent && !legacyFingerprintPresent) {
      legacyDisposition = IsarLegacyMarkerDisposition.absent;
    } else if (!legacyVersionPresent || !legacyFingerprintPresent) {
      legacyDisposition = IsarLegacyMarkerDisposition.partial;
      legacyError = 'legacy-marker-incomplete';
    } else if (legacySchemaVersionValue is! int ||
        legacySchemaVersionValue <= 0) {
      legacyDisposition = IsarLegacyMarkerDisposition.malformed;
      legacyError = 'legacy-marker-version-type-invalid';
    } else if (legacySchemaFingerprintValue is! String ||
        legacySchemaFingerprintValue.trim().isEmpty ||
        legacySchemaFingerprintValue.length > 4096) {
      legacyDisposition = IsarLegacyMarkerDisposition.malformed;
      legacyError = 'legacy-marker-fingerprint-type-invalid';
    } else {
      legacyDisposition = IsarLegacyMarkerDisposition.complete;
      legacyVersion = legacySchemaVersionValue;
      legacyFingerprint = legacySchemaFingerprintValue;
    }

    final canonicalTargetRecognized =
        canonicalMarker != null &&
        plan.acceptsFingerprint(
          canonicalMarker.schemaVersion,
          canonicalMarker.schemaFingerprint,
        );
    final canonicalSourceRecognized =
        canonicalMarker != null &&
        (!canonicalMarker.origin.requiresSource ||
            plan.acceptsFingerprint(
              canonicalMarker.sourceSchemaVersion!,
              canonicalMarker.sourceSchemaFingerprint!,
            ));
    final canonicalRecognized =
        canonicalTargetRecognized && canonicalSourceRecognized;
    final legacyRecognized =
        legacyVersion != null &&
        legacyFingerprint != null &&
        plan.acceptsFingerprint(legacyVersion, legacyFingerprint);

    late final String overallDisposition;
    late final bool requiresGovernedRecovery;
    String? reasonCode = canonicalError ?? legacyError;

    if (canonicalDisposition == IsarCanonicalMarkerDisposition.malformed) {
      overallDisposition = 'CANONICAL_MARKER_MALFORMED_BLOCKED';
      requiresGovernedRecovery = true;
    } else if (legacyDisposition == IsarLegacyMarkerDisposition.malformed) {
      overallDisposition = 'LEGACY_MARKER_MALFORMED_BLOCKED';
      requiresGovernedRecovery = true;
    } else if (canonicalMarker != null) {
      if (!hasDurableStore) {
        overallDisposition = 'STORE_ABSENT_GENERATION_ROTATION_REQUIRED';
        requiresGovernedRecovery = false;
        reasonCode ??= 'canonical-marker-without-durable-store';
      } else if (!canonicalRecognized) {
        overallDisposition = 'EXISTING_STORE_CANONICAL_UNSUPPORTED_BLOCKED';
        requiresGovernedRecovery = true;
        reasonCode ??=
            canonicalTargetRecognized
                ? 'stored-schema-fingerprint-unrecognized'
                : 'canonical-marker-schema-unsupported';
      } else if (canonicalMarker.state == IsarSchemaMarkerState.prepared) {
        overallDisposition = 'EXISTING_STORE_PREPARED_RESTART_REQUIRED';
        requiresGovernedRecovery = true;
        reasonCode ??= 'canonical-marker-prepared';
      } else if (canonicalMarker.schemaVersion == plan.currentVersion &&
          canonicalMarker.schemaFingerprint == plan.schemaFingerprint) {
        overallDisposition = 'EXISTING_STORE_CANONICAL_CURRENT';
        requiresGovernedRecovery = false;
      } else {
        overallDisposition = 'EXISTING_STORE_CANONICAL_MIGRATION_REQUIRED';
        requiresGovernedRecovery = true;
        reasonCode ??= 'canonical-marker-recognized-older-schema';
      }
    } else if (!hasDurableStore) {
      overallDisposition =
          legacyDisposition == IsarLegacyMarkerDisposition.absent
              ? 'EMPTY_STORE_AND_MARKERS_ABSENT'
              : 'STORE_ABSENT_LEGACY_RESIDUE';
      requiresGovernedRecovery = false;
      if (legacyDisposition != IsarLegacyMarkerDisposition.absent) {
        reasonCode ??= 'legacy-marker-without-durable-store';
      }
    } else {
      switch (legacyDisposition) {
        case IsarLegacyMarkerDisposition.absent:
          overallDisposition = 'EXISTING_STORE_UNMARKED_BLOCKED';
          reasonCode ??= 'existing-store-unmarked';
        case IsarLegacyMarkerDisposition.partial:
          overallDisposition = 'EXISTING_STORE_LEGACY_PARTIAL_BLOCKED';
        case IsarLegacyMarkerDisposition.malformed:
          overallDisposition = 'EXISTING_STORE_LEGACY_MALFORMED_BLOCKED';
        case IsarLegacyMarkerDisposition.complete:
          if (legacyRecognized) {
            overallDisposition = 'EXISTING_STORE_LEGACY_REVIEW_REQUIRED';
            reasonCode ??= 'legacy-complete-governed-review-required';
          } else {
            overallDisposition = 'EXISTING_STORE_LEGACY_UNSUPPORTED_BLOCKED';
            reasonCode ??= 'legacy-marker-schema-unsupported';
          }
      }
      requiresGovernedRecovery = true;
    }

    return IsarInstalledStoreProvenanceInventory(
      captureSupported: true,
      hasDurableStore: hasDurableStore,
      canonicalDisposition: canonicalDisposition,
      legacyDisposition: legacyDisposition,
      overallDisposition: overallDisposition,
      canonicalSchemaVersion: canonicalMarker?.schemaVersion,
      canonicalState: canonicalMarker?.state.wireName,
      canonicalOrigin: canonicalMarker?.origin.wireName,
      canonicalFingerprintRecognized: canonicalRecognized,
      canonicalSourceFingerprintRecognized: canonicalSourceRecognized,
      legacySchemaVersion: legacyVersion,
      legacyFingerprintRecognized: legacyRecognized,
      databaseGenerationSha256:
          canonicalMarker == null
              ? null
              : sha256
                  .convert(utf8.encode(canonicalMarker.databaseGenerationId))
                  .toString()
                  .toUpperCase(),
      requiresGovernedRecovery: requiresGovernedRecovery,
      reasonCode: reasonCode,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'captureFormatVersion': 1,
    'captureSupported': captureSupported,
    'readOnly': true,
    'hasDurableStore': hasDurableStore,
    'canonicalDisposition': canonicalDisposition.wireName,
    'legacyDisposition': legacyDisposition.wireName,
    'overallDisposition': overallDisposition,
    'canonicalSchemaVersion': canonicalSchemaVersion,
    'canonicalState': canonicalState,
    'canonicalOrigin': canonicalOrigin,
    'canonicalFingerprintRecognized': canonicalFingerprintRecognized,
    'canonicalSourceFingerprintRecognized':
        canonicalSourceFingerprintRecognized,
    'legacySchemaVersion': legacySchemaVersion,
    'legacyFingerprintRecognized': legacyFingerprintRecognized,
    'databaseGenerationSha256': databaseGenerationSha256,
    'requiresGovernedRecovery': requiresGovernedRecovery,
    'reasonCode': reasonCode,
    'rawMarkerValuesIncluded': false,
  };

  String toDiagnosticsText() {
    return <String>[
      'captureSupported: $captureSupported',
      'readOnly: true',
      'hasDurableStore: $hasDurableStore',
      'canonicalDisposition: ${canonicalDisposition.wireName}',
      'legacyDisposition: ${legacyDisposition.wireName}',
      'overallDisposition: $overallDisposition',
      'canonicalSchemaVersion: ${canonicalSchemaVersion ?? 'none'}',
      'canonicalState: ${canonicalState ?? 'none'}',
      'canonicalOrigin: ${canonicalOrigin ?? 'none'}',
      'canonicalFingerprintRecognized: $canonicalFingerprintRecognized',
      'legacySchemaVersion: ${legacySchemaVersion ?? 'none'}',
      'legacyFingerprintRecognized: $legacyFingerprintRecognized',
      'databaseGenerationSha256: ${databaseGenerationSha256 ?? 'none'}',
      'requiresGovernedRecovery: $requiresGovernedRecovery',
      'reasonCode: ${reasonCode ?? 'none'}',
      'rawMarkerValuesIncluded: false',
    ].join('\n');
  }
}

IsarInstalledStoreProvenanceInventory? _startupPreOpenProvenanceInventory;

/// Preserves the privacy-safe inventory captured before the startup guard can
/// migrate, commit, or reject the installed store.
void preserveStartupPreOpenIsarProvenanceInventory(
  IsarInstalledStoreProvenanceInventory inventory,
) {
  _startupPreOpenProvenanceInventory = inventory;
}

IsarInstalledStoreProvenanceInventory?
readStartupPreOpenIsarProvenanceInventory() =>
    _startupPreOpenProvenanceInventory;
