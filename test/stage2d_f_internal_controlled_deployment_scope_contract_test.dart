import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

    final triggerIds = (payload['reArmTriggers'] as List<dynamic>)
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

    final appCheckSource = File(
      'lib/core/security/app_check_bootstrap.dart',
    ).readAsStringSync();
    expect(appCheckSource, contains("'CRM3_APP_CHECK_ENABLED'"));
    expect(appCheckSource, contains('defaultValue: false'));

    final artifactSource = File(
      'tools/release/New-ProductionArtifact.ps1',
    ).readAsStringSync();
    final appCheckBuildSource = File(
      'tools/release/Production-AppCheckPolicy.ps1',
    ).readAsStringSync();
    expect(
      artifactSource,
      contains(r'if ($ExpectedBuildNumber -ge 30)'),
      reason: 'Historical Build29 retains its default-false client deferral.',
    );
    expect(
      artifactSource,
      contains(
        r"$identityDefines['CRM3_APP_CHECK_ENABLED'] = $appCheckEvidence.dartDefine",
      ),
    );
    expect(
      appCheckBuildSource,
      contains(r'if ($build -ge 1 -and $build -le 29) { return $null }'),
    );
    expect(
      appCheckBuildSource,
      contains(
        'Build30 requires an explicit governed App Check client choice.',
      ),
    );
    expect(
      appCheckBuildSource,
      contains(
        'App Check client choice and pinned backend enforcement evidence disagree.',
      ),
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

  test('the signed Build29 policy retains its absent App Check choice', () {
    // Use the immutable policy that produced Build29, not the moving candidate.
    final historical = Process.runSync('git', <String>[
      '--no-replace-objects',
      'show',
      '770f1745f7f4440e92ad5ff409e124a48baa107e:'
          'release/production-release-policy.json',
    ], stdoutEncoding: null);
    expect(historical.exitCode, 0, reason: '${historical.stderr}');
    final bytes = historical.stdout as List<int>;
    expect(
      sha256.convert(bytes).toString().toUpperCase(),
      '8061338763C4E6A80E241C844733576F6F867D45577B7AE3FA8EB93AFC7B1088',
    );
    final policy = _object(jsonDecode(utf8.decode(bytes)));
    expect(_object(policy['release'])['buildNumber'], 29);
    expect(policy.containsKey('appCheckBuild'), isFalse);
  });

  test('signed Build30 retains its historical App Check deferral', () {
    final historical = Process.runSync('git', <String>[
      'show',
      '7ed87824447f1349cb0481c448e0b21c3fa5856f:'
          'release/production-release-policy.json',
    ]);
    expect(historical.exitCode, 0, reason: '${historical.stderr}');
    final policy = _object(jsonDecode(historical.stdout as String));
    expect(_object(policy['release'])['buildNumber'], 30);
    final choice = _object(policy['appCheckBuild']);
    expect(choice['clientEnabled'], isFalse);
    expect(choice['androidProvider'], 'disabled');
    expect(
      choice['approvalFile'],
      'release/approvals/build30-app-check-client-approval.json',
    );
  });

  test(
    'current candidate binds its explicit generation-specific App Check choice',
    () {
      final policy = _readJson('release/production-release-policy.json');
      final release = _object(policy['release']);
      final build = release['buildNumber'] as int;
      expect(build, isIn(<int>[30, 31]));
      final choice = _object(policy['appCheckBuild']);
      expect(choice['clientEnabled'], build == 31);
      expect(
        choice['androidProvider'],
        build == 31 ? 'playIntegrity' : 'disabled',
      );
      expect(
        choice['approvalFile'],
        'release/approvals/build$build-app-check-client-approval.json',
      );
      final approvalFile = choice['approvalFile'] as String;
      expect(
        sha256
            .convert(File(approvalFile).readAsBytesSync())
            .toString()
            .toUpperCase(),
        choice['approvalSha256'],
      );
      final approval = _readJson(approvalFile);
      expect(approval['approved'], isTrue);
      expect(
        approval['documentType'],
        'governed-app-check-client-build-approval',
      );
      if (build == 30) {
        expect(
          approval['approvalReference'],
          'BUILD30-APP-CHECK-DISABLED-20260928',
        );
      } else {
        expect(
          approval['approvalReference'],
          isA<String>().having(
            (value) => value.trim(),
            'nonempty reference',
            isNotEmpty,
          ),
        );
        final scopes = _object(approval['serverEnforcementScopesAtBuild']);
        expect(scopes['defaultMutatingEnforced'], isFalse);
        expect(scopes['identityCallable'], 'getBackendReleaseIdentity');
        expect(scopes['identityCallableEnforced'], isTrue);
        expect(
          scopes['identitySourceFile'],
          'functions/src/stage2dSecurityConfig.ts',
        );
        expect(
          scopes['identitySourceSha256'],
          sha256
              .convert(
                File(scopes['identitySourceFile'] as String).readAsBytesSync(),
              )
              .toString()
              .toUpperCase(),
        );
      }
      expect(approval['intendedBuildNumber'], release['buildNumber']);
      expect(approval['releaseId'], release['releaseId']);
      expect(
        approval['reservationId'],
        _object(policy['versionPolicy'])['reservationId'],
      );
      expect(approval['applicationId'], policy['permanentApplicationId']);
      expect(approval['firebaseProjectId'], policy['firebaseProjectId']);
      expect(approval['clientEnabled'], choice['clientEnabled']);
      expect(approval['androidProvider'], choice['androidProvider']);
      expect(approval['enforcementChangeAuthorized'], isFalse);

      final finalization = _object(policy['finalization']);
      final backendFile =
          finalization['exactFunctionFleetDeploymentReceiptFile'] as String;
      final backendHash = sha256
          .convert(File(backendFile).readAsBytesSync())
          .toString()
          .toUpperCase();
      expect(
        backendHash,
        finalization['exactFunctionFleetDeploymentReceiptSha256'],
      );
      expect(approval['backendReceiptSha256'], backendHash);
      final backend = _readJson(backendFile);
      expect(
        approval['backendSourceCommit'],
        _object(backend['sourceAuthority'])['commit'],
      );
      expect(approval['serverEnforcementAtBuild'], isFalse);
      expect(
        approval['serverEnforcementAtBuild'],
        _object(backend['deployment'])['appCheckEnforcement'],
      );
    },
  );
}
