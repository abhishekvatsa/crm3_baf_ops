import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

  test(
    'security readiness remains blocked after exact identity deployment',
    () {
      final security = readJson('release/backend-security-readiness.prod.json');

      expect(security['overallStatus'], 'NOT_SECURITY_READY');
      expect(security['securityReady'], isFalse);
      expect(security['openBlockerCount'], 5);

      final controls = (security['controls'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .fold<Map<String, Map<String, dynamic>>>({}, (result, item) {
            result[item['id'] as String] = item;
            return result;
          });

      for (final id in <String>[
        'runtime-service-account-least-privilege',
        'dedicated-runtime-identity-source-binding',
        'app-check-client-activation',
        'callable-app-check-enforcement',
        'high-severity-node-dependency-advisories',
      ]) {
        expect(controls[id]?['status'], 'OPEN_BLOCKER', reason: id);
      }

      final dependencies = security['dependencyAudit'] as Map<String, dynamic>;
      expect(dependencies['totalVulnerabilities'], 4);
      expect(dependencies['low'], 1);
      expect(dependencies['moderate'], 1);
      expect(dependencies['high'], 2);
      expect(dependencies['critical'], 0);
      expect(
        (dependencies['expectedHighSeverityPackages'] as List<dynamic>).toSet(),
        <String>{'form-data', 'protobufjs'},
      );
    },
  );

  test(
    'public callable transport is not misclassified as standalone defect',
    () {
      final security = readJson('release/backend-security-readiness.prod.json');
      final transport = security['transportExposure'] as Map<String, dynamic>;

      expect(transport['cloudRunInvokerMembers'], <String>['allUsers']);
      expect(
        transport['classification'],
        'INTENTIONAL_PUBLIC_TRANSPORT_FOR_FIREBASE_CALLABLE',
      );
      expect(transport['removalRequired'], isFalse);
      expect(
        transport['futureCompensatingControl'],
        'FIREBASE_APP_CHECK_ENFORCEMENT',
      );
    },
  );

  test('Stage 2D source and cloud mutations remain separately sequenced', () {
    final security = readJson('release/backend-security-readiness.prod.json');
    final sequencing = security['sequencing'] as Map<String, dynamic>;

    expect(
      sequencing['recordActivationGate'],
      'MERGE_THIS_POSTDEPLOYMENT_BASELINE_TO_MAIN',
    );
    expect(
      sequencing['nextSourceStageAfterActivation'],
      'REBUILD_STAGE2D_FROM_RECONCILED_MAIN',
    );
    expect(
      (sequencing['stage2dSourceScope'] as List<dynamic>).toSet(),
      <String>{
        'APP_CHECK_CLIENT_SOURCE',
        'CALLABLE_ENFORCE_APP_CHECK',
        'DEDICATED_RUNTIME_SERVICE_ACCOUNT_SOURCE_BINDING',
        'FORM_DATA_AND_PROTOBUFJS_ADVISORY_REMEDIATION',
      },
    );
    expect(
      (sequencing['separateCloudCampaigns'] as List<dynamic>).toSet(),
      <String>{
        'DEDICATED_SERVICE_ACCOUNT_CREATION_AND_IAM_BINDING',
        'DEFAULT_COMPUTE_ROLES_EDITOR_REMOVAL_AFTER_CUTOVER',
        'FIREBASE_APP_CHECK_PROVIDER_REGISTRATION_AND_STAGED_ENFORCEMENT',
      },
    );
  });
}
