import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<Map<String, dynamic>> _objects(dynamic value) {
  return (value as List<dynamic>).cast<Map<String, dynamic>>();
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

String _sha256(String path) {
  return sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();
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
  test('S-02 additive source policy preserves immutable pilot authority', () {
    final policy = _readJson(
      'release/s02-callable-app-check-source-policy.json',
    );
    expect(policy['schemaVersion'], 1);
    expect(policy['findingId'], 'S-02');
    expect(
      policy['declarationStatus'],
      'SOURCE_POLICY_IMPLEMENTED_GOVERNED_DEFERRAL',
    );

    final authority = _object(policy['immutablePilotScopeAuthority']);
    final authorityPath = authority['path'] as String;
    expect(
      authorityPath,
      'release/stage2d-f-internal-controlled-deployment-scope.json',
    );
    expect(_sha256(authorityPath), authority['sha256']);

    final nonClaims = _strings(policy['nonClaims']);
    expect(
      nonClaims,
      contains('This policy does not activate App Check or Play Integrity.'),
    );
    expect(nonClaims, contains('This policy does not close S-02.'));
  });

  test(
    'all exported callable classes have exact governed security options',
    () {
      final policy = _readJson(
        'release/s02-callable-app-check-source-policy.json',
      );
      final callablePolicy = _object(policy['callableAppCheckPolicy']);
      expect(callablePolicy['activationAuthorized'], isFalse);
      expect(callablePolicy['sourceDefault'], isFalse);
      expect(
        callablePolicy['activationParameter'],
        'CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK',
      );

      final mutating = _strings(callablePolicy['mutatingCallables']).toSet();
      expect(mutating, <String>{
        'assignPublishedTemplateVersion',
        'completePlannedJobExecution',
        'executeMaintenanceWorkflowCommand',
        'mutateChargeAbnormality',
        'mutateAssetHierarchy',
        'mutateRuntimeJobModulePopulation',
        'mutateUserAuthority',
      });
      final readOnly = _object(
        callablePolicy['readOnlySecurityOptionsByCallable'],
      );
      expect(readOnly.keys.toSet(), <String>{
        'beginGlobalPullRun',
        'getBackendReleaseIdentity',
      });
      expect(
        readOnly['beginGlobalPullRun'],
        'GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS',
      );
      expect(
        readOnly['getBackendReleaseIdentity'],
        'BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS',
      );

      final indexSource = File('functions/src/index.ts').readAsStringSync();
      for (final callable in mutating.where(
        (name) => name != 'executeMaintenanceWorkflowCommand',
      )) {
        expect(
          _callableOptions(indexSource, callable),
          contains('MUTATING_CALLABLE_SECURITY_OPTIONS'),
        );
      }
      final workflowSource =
          File(
            'functions/src/maintenanceWorkflow/callable.ts',
          ).readAsStringSync();
      expect(
        _callableOptions(workflowSource, 'executeMaintenanceWorkflowCommand'),
        contains('MUTATING_CALLABLE_SECURITY_OPTIONS'),
      );
      expect(
        _callableOptions(indexSource, 'beginGlobalPullRun'),
        contains('GLOBAL_PULL_CALLABLE_SECURITY_OPTIONS'),
      );
      expect(
        _callableOptions(indexSource, 'getBackendReleaseIdentity'),
        contains('BACKEND_IDENTITY_CALLABLE_SECURITY_OPTIONS'),
      );

      final securitySource =
          File('functions/src/callableSecurityConfig.ts').readAsStringSync();
      expect(
        securitySource,
        contains('CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK'),
      );
      expect(securitySource, contains('default: false'));

      final globalPullSecuritySource =
          File('functions/src/globalPullSecurityConfig.ts').readAsStringSync();
      expect(
        globalPullSecuritySource,
        contains('...READ_ONLY_CALLABLE_SECURITY_OPTIONS'),
      );
      expect(
        globalPullSecuritySource,
        contains('GLOBAL_PULL_READER_RUNTIME_SERVICE_ACCOUNT'),
      );
      final functionFleetRuntimeSource =
          File(
            'functions/src/functionFleetRuntimeIdentity.ts',
          ).readAsStringSync();
      expect(
        functionFleetRuntimeSource,
        contains('import {expr, projectID} from "firebase-functions/params"'),
      );
      expect(functionFleetRuntimeSource, contains(r'@${projectID}'));
      expect(
        functionFleetRuntimeSource,
        isNot(contains('@crm3-baf-ops-b8638.iam.gserviceaccount.com')),
      );
    },
  );

  test('RA-07 is source-detectable and ledger-owned without closing S-02', () {
    final policy = _readJson(
      'release/s02-callable-app-check-source-policy.json',
    );
    final trigger = _objects(
      policy['sourceReArmTriggers'],
    ).singleWhere((item) => item['id'] == 'RA-07');
    expect(trigger['sourceDetectable'], isTrue);
    expect(
      trigger['sourceProbe'],
      'npm --prefix functions run audit:callable-inventory',
    );

    final ledger = _readJson('governance/programme-ledger.json');
    final s02 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'S-02');
    expect(s02['currentStatus'], 'DEFERRED');
    expect(_strings(s02['reArmTriggers']), contains('RA-07'));
    expect(_strings(s02['requiredExitEvidence']), isNotEmpty);
    expect(
      _strings(s02['notes']).join('\n'),
      contains('does not activate App Check'),
    );
  });
}
