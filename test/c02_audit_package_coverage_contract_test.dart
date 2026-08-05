import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('C-02 audit package coverage', () {
    final verificationBuilder =
        File('tools/release/New-VerificationArtifact.ps1').readAsStringSync();
    final verificationVerifier =
        File('tools/release/Test-ReleaseManifest.ps1').readAsStringSync();
    final productionBuilder =
        File('tools/release/New-ProductionArtifact.ps1').readAsStringSync();
    final productionVerifier =
        File(
          'tools/release/Test-ProductionReleaseManifest.ps1',
        ).readAsStringSync();

    const auditCriticalPaths = <String>[
      'release_gate.ps1',
      'jest.config.js',
      'governance/programme-ledger.json',
      'tooling/firebase-cli/package.json',
      'tooling/firebase-cli/package-lock.json',
    ];

    test(
      'both artifact builders hash-bind every audit-critical source entry',
      () {
        for (final path in auditCriticalPaths) {
          expect(verificationBuilder, contains("'$path'"), reason: path);
          expect(productionBuilder, contains("'$path'"), reason: path);
        }

        expect(
          _blockStartingAt(verificationBuilder, r'$lockfiles = [ordered]@{}'),
          contains("'tooling/firebase-cli/package-lock.json'"),
        );
        expect(
          _blockStartingAt(
            productionBuilder,
            r'$lockfileHashes = [ordered]@{}',
          ),
          contains("'tooling/firebase-cli/package-lock.json'"),
        );
      },
    );

    test('package-only verifiers fail closed when audit coverage is omitted', () {
      for (final path in auditCriticalPaths) {
        expect(verificationVerifier, contains("'$path'"), reason: path);
        expect(productionVerifier, contains("'$path'"), reason: path);
      }

      for (final verifier in <String>[
        verificationVerifier,
        productionVerifier,
      ]) {
        expect(
          verifier,
          contains(
            'Audit-critical source entry is absent from configuration custody',
          ),
        );
        expect(
          verifier,
          contains(
            'Governed Firebase CLI lockfile is absent from dependency custody',
          ),
        );
      }
    });
  });
}

String _blockStartingAt(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, greaterThanOrEqualTo(0), reason: 'Missing marker: $marker');
  final nextSection = source.indexOf('\n\n', start);
  return source.substring(start, nextSection < 0 ? source.length : nextSection);
}
