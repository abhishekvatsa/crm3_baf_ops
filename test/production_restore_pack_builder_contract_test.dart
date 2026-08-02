import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production restore collector is exact and read-only', () {
    final script =
        File('tools/release/New-ProductionRestorePack.ps1').readAsStringSync();

    for (final required in <String>[
      '[Parameter(Mandatory = \$true)]',
      "[ValidatePattern('^[0-9a-f]{40}\$')]",
      "'crm3-baf-ops-b8638'",
      'gs://crm3-baf-ops-b8638-firestore-restore/pre-live/',
      "'https://github.com/abhishekvatsa/crm3_baf_ops.git'",
      "'E36C39E40C4B92B0721DAD916F050F439644FDF7FC40A36C1EB579571EBD074E'",
      "'fetch', '--quiet', 'origin', 'main'",
      "'status', '--porcelain', '--untracked-files=no'",
      "'rev-parse', 'origin/main'",
      "'archive'",
      "'bundle'",
      "'run', 'view'",
      "\$run.workflowName -cne 'release-gate'",
      'CI run \$runId job inventory',
      "'functions:list'",
      "'functions', 'describe'",
      "'firestore', 'operations', 'describe'",
      "'firestore', 'indexes', 'composite', 'list'",
      "'storage', 'buckets', 'describe'",
      "'storage', 'ls'",
      "'storage', 'objects', 'describe'",
      "'storage', 'cp'",
      "\$ErrorActionPreference = 'Continue'",
      '\$exitCode = \$LASTEXITCODE',
      '\$ErrorActionPreference = \$nativeErrorActionPreference',
      "'--no-user-output-enabled'",
      'generation-pinned source custody',
      'Managed Firestore export is not a successful exact-prefix operation.',
      'Managed Firestore export object inventory',
      'Governed Build 6 sidecar does not bind the admitted package.',
      'source download failed byte verification',
      'Export object failed byte verification',
      'public_access_prevention',
      'uniform_bucket_level_access',
      'versioning_enabled',
      'retentionPeriod',
      'PASS_PRIVATE_PRODUCTION_RESTORE_PACK_SEALED',
      'STOP_AND_ROLLBACK.md',
      'MANIFEST.json',
      'firestoreDocumentMutationPerformed = \$false',
      'firestoreImportPerformed = \$false',
      'rulesMutationPerformed = \$false',
      'functionsMutationPerformed = \$false',
      'iamMutationPerformed = \$false',
    ]) {
      expect(script, contains(required), reason: required);
    }

    for (final forbidden in <String>[
      "'firestore', 'export'",
      "'firestore', 'import'",
      "'storage', 'buckets', 'create'",
      "'storage', 'buckets', 'update'",
      "'add-iam-policy-binding'",
      "'functions', 'delete'",
      'firebase deploy',
      'Remove-Item',
    ]) {
      expect(script, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test(
    'restore policy keeps private data and live rollback separately gated',
    () {
      final policy =
          File(
            'docs/v4_2_r1/PRODUCTION_PRELIVE_RESTORE_PACK.md',
          ).readAsStringSync();
      final normalizedPolicy = policy.replaceAll(RegExp(r'\s+'), ' ');

      for (final required in <String>[
        'PRIVATE PACK SEALED AND INDEPENDENTLY VERIFIED; LIVE MUTATION NOT AUTHORIZED',
        'must never be committed',
        'did not mutate Firestore documents or application controls',
        'readback and download only',
        'privacy-safe receipt',
        'production-prelive-restore-pack-seal.json',
        'An independent verification recalculated both hashes',
        'separate live rollback decision',
        'import-rehearsed in an isolated recovery target',
        '`STAGE2D-F4`, `P-07` and pilot handout remain open',
      ]) {
        expect(normalizedPolicy, contains(required), reason: required);
      }
    },
  );
}
