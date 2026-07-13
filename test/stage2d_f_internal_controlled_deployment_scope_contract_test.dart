import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing governed file: $path');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

String _callableOptions(String source, String exportName) {
  final pattern = RegExp(
    'export const $exportName = onCall\\(\\s*\\{([\\s\\S]*?)\\},\\s*async',
  );
  final match = pattern.firstMatch(source);
  expect(match, isNotNull, reason: 'Missing callable export: $exportName');
  return match!.group(1)!;
}

void main() {
  test('Stage 2D-F1B internal controlled deployment scope is governed', () {
    final payload = _readJson(
      'release/stage2d-f-internal-controlled-deployment-scope.json',
    );

    expect(payload['schemaVersion'], 1);
    expect(payload['gateId'], 'STAGE2D-F1B');
    expect(
      payload['declarationStatus'],
      'GOVERNED_INTERNAL_CONTROLLED_DEPLOYMENT_SCOPE',
    );
    expect(payload['effectiveTrack'], 'INTERNAL_CONTROLLED_PILOT');
    expect(payload['projectId'], 'crm3-baf-ops-b8638');

    final application = _object(payload['application']);
    expect(application['packageId'], 'in.co.sail.bsl.crm3.bafops');
    expect(application['platform'], 'android');

    final authority = _object(payload['authority']);
    expect(authority['baselineBranch'], 'main');
    expect(
      authority['baselineCommit'],
      '382fd2485fc629b5f28ae708ae87fb138888bc65',
    );
    expect(
      authority['baselineTree'],
      '6c38f5a42ccdf73e994ea7febb00e81fadf8103a',
    );

    final governanceAudit = _object(authority['governanceAudit']);
    expect(
      governanceAudit['sha256'],
      '8A128BEA2CE4AAEDFF407EAF76EBB2A7EE623C10513009107B710852F369B403',
    );

    final f1a = _object(authority['f1aDecisionCustody']);
    expect(
      f1a['sha256'],
      '5BE4A11E097DB1628BA18A20C3423539BADFA793FA7839D9E0D0CDFC8E2D0AFD',
    );
    expect(
      f1a['decision'],
      'PASS_STAGE2D_F1A_INTERNAL_CONTROLLED_DEPLOYMENT_DECISION_CUSTODY',
    );

    final ceiling = _object(payload['pilotCeiling']);
    expect(ceiling['maxApprovedUsers'], 40);
    expect(ceiling['rosterAndRolesFrozenAtHandout'], isTrue);
    expect(ceiling['liveCountEvidenceRequired'], 'LR-01');

    final distribution = _object(payload['distribution']);
    expect(_strings(distribution['authorizedPlanningModes']), <String>[
      'internal-release-signed-apk',
      'firebase-app-distribution',
    ]);
    expect(distribution['playConsole'], 'NOT_USED');
    expect(distribution['playStore'], 'NOT_USED');
    expect(distribution['webDistribution'], 'NOT_AUTHORIZED');
    expect(distribution['unrestrictedDistribution'], 'NO_GO');

    final attestation = _object(payload['attestation']);
    expect(attestation['playIntegrity'], 'DEFERRED');
    expect(attestation['appCheckClientActivation'], 'OFF_BY_GOVERNED_DEFERRAL');
    expect(
      attestation['appCheckCallableEnforcement'],
      'OFF_FOR_MUTATING_CALLABLES_BY_GOVERNED_DEFERRAL',
    );
    expect(attestation['trackASeverity'], 'DEFERRED_MEDIUM');
    expect(attestation['trackBSeverity'], 'BLOCKER');
    expect(
      attestation['severityVocabularyAuthority'],
      'governance/programme-ledger.json#severityVocabulary',
    );
    expect(attestation['reArmFindingId'], 'S-02');

    final adminPolicy = _object(payload['administrativeMutationPolicy']);
    expect(adminPolicy['atHandout'], 'ROSTER_AND_ROLES_FROZEN');
    expect(
      _strings(adminPolicy['existingClientPathPermittedDuringPilot']),
      <String>['isApproved true-to-false revocation only'],
    );
    expect(
      _strings(adminPolicy['existingClientPathProhibitedDuringPilot']),
      containsAll(<String>[
        'isApproved false-to-true approval grant',
        'role addition',
        'role removal',
        'admin-role change',
        'last-approved-admin quorum change',
      ]),
    );
    expect(adminPolicy['requiredPermanentCorrectionFindingId'], 'S-05');

    final compatibility = _object(payload['dataCompatibilityPolicy']);
    expect(
      compatibility['unknownRoleWriteSemantics'],
      'REJECT_OUTSIDE_CANONICAL_ROLE_VOCABULARY',
    );
    expect(
      compatibility['unknownRoleReadSemantics'],
      'PRESERVE_QUARANTINE_GRANT_NOTHING_EMIT_DIAGNOSTIC',
    );
    expect(
      compatibility['malformedTimestampReadSemantics'],
      'PRESERVE_PARSE_FAILURE_DO_NOT_MANUFACTURE_NOW',
    );

    final provenance = _object(payload['deviceProvenancePolicy']);
    expect(
      provenance['previouslyUsedDevice'],
      'BLOCKED_UNTIL_WIPED_OR_STRUCTURALLY_PROBED',
    );
    expect(
      provenance['beforeAnySchemaVersionIncrease'],
      'P-06_ABSOLUTE_BLOCKER',
    );

    final ledger = _object(payload['programmeLedger']);
    expect(ledger['path'], 'governance/programme-ledger.json');
    expect(ledger['statusOwner'], isTrue);
    expect(ledger['reportsMayNotInventIndependentStatus'], isTrue);
  });

  test('deferral and source configuration remain mutually consistent', () {
    final payload = _readJson(
      'release/stage2d-f-internal-controlled-deployment-scope.json',
    );
    final ledger = _readJson('governance/programme-ledger.json');
    final severityVocabulary = _strings(ledger['severityVocabulary']).toSet();
    final attestation = _object(payload['attestation']);
    expect(severityVocabulary, contains(attestation['trackASeverity']));
    expect(severityVocabulary, contains(attestation['trackBSeverity']));

    final triggerIds =
        (payload['reArmTriggers'] as List<dynamic>)
            .map((dynamic item) => _object(item)['id'] as String)
            .toSet();
    expect(triggerIds, <String>{
      'RA-01',
      'RA-02',
      'RA-03',
      'RA-04',
      'RA-05',
      'RA-06',
    });

    final appCheckSource =
        File('lib/core/security/app_check_bootstrap.dart').readAsStringSync();
    expect(appCheckSource, contains("'CRM3_APP_CHECK_ENABLED'"));
    expect(appCheckSource, contains('defaultValue: false'));

    final artifactSource =
        File('tools/release/New-ProductionArtifact.ps1').readAsStringSync();
    expect(
      artifactSource,
      isNot(contains('CRM3_APP_CHECK_ENABLED')),
      reason: 'The controlled artifact path must match the governed deferral.',
    );

    final functionsSource = File('functions/src/index.ts').readAsStringSync();
    for (final callable in <String>[
      'completePlannedJobExecution',
      'assignPublishedTemplateVersion',
      'mutateRuntimeJobModulePopulation',
    ]) {
      expect(
        _callableOptions(functionsSource, callable),
        isNot(contains('BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS')),
        reason: '$callable unexpectedly changed the declared deferral.',
      );
    }
    expect(
      _callableOptions(functionsSource, 'getBackendReleaseIdentity'),
      contains('BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS'),
    );

    final platformScope = _readJson('release/client-platform-scope.prod.json');
    expect(_strings(platformScope['currentReleasePlatforms']), <String>[
      'android',
    ]);
    expect(_strings(platformScope['futurePlatforms']), <String>['web']);
  });
}
