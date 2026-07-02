import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test(
    'postdeployment attestation preserves immutable authority semantics',
    () {
      final authority = readJson('release/backend-authority.prod.json');
      final attestation = readJson(
        'release/backend-identity-deployment-attestation.prod.json',
      );
      final currentState = readJson('release/backend-current-state.prod.json');

      expect(
        authority['authorityDigest'],
        '59474B02385322F948B8EFB26361F293F1F2A4E9841B7005DAC43BE5664FC525',
      );
      expect(attestation['status'], 'IDENTITY_FUNCTION_DEPLOYED_EXACT');

      final definition =
          attestation['authorityDefinition'] as Map<String, dynamic>;
      expect(definition['authorityDigest'], authority['authorityDigest']);
      expect(definition['immutableDeploymentBoundDefinition'], isTrue);
      expect(definition['runtimeBindingStatus'], 'SCHEMA_V2_DEPLOYED_EXACT');

      final deployment = attestation['deployment'] as Map<String, dynamic>;
      expect(
        deployment['sourceCommit'],
        '08afc4f3020359fcdfeed472d7f4ba6b01084d44',
      );
      expect(
        deployment['sourceTree'],
        'e831d1ac4c78c787430fa712a0f053aea7c7bc73',
      );
      expect(
        deployment['currentRevision'],
        'getbackendreleaseidentity-00002-wud',
      );
      expect(deployment['currentSourceGeneration'], '1782928076881189');
      expect(
        deployment['deployedArchiveSha256'],
        '692E41AAD6755B362D391736947434FD0BAFBE4F78F57C0D49056BE452FE158D',
      );
      expect(deployment['trafficPercentToCurrentRevision'], 100);

      final derived = currentState['derivedState'] as Map<String, dynamic>;
      expect(
        derived['identityFunctionDeploymentStatus'],
        'SCHEMA_V2_DEPLOYED_EXACT',
      );
      expect(derived['securityStatus'], 'NOT_SECURITY_READY');
      expect(derived['overallStatus'], 'DEPLOYED_EXACT_SECURITY_GATES_OPEN');
    },
  );

  test(
    'private deployed source archive remains excluded from safe evidence',
    () {
      final attestation = readJson(
        'release/backend-identity-deployment-attestation.prod.json',
      );
      final evidence = attestation['evidence'] as Map<String, dynamic>;
      final custody = evidence['privateArchiveCustody'] as Map<String, dynamic>;

      expect(custody['archiveIncludedInSafeEvidence'], isFalse);
      expect(custody['containsProjectEnvironmentFile'], isTrue);
      expect(custody['projectEnvironmentFilename'], '.env.crm3-baf-ops-b8638');
      expect(custody['handlingRequirement'], 'KEEP_PRIVATE_DO_NOT_UPLOAD');
    },
  );
}
