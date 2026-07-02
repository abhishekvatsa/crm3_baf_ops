import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'five security blockers remain open with explicit mutation dimensions',
    () {
      final security = _readJson(
        'release/backend-security-readiness.prod.json',
      );

      expect(security['overallStatus'], 'NOT_SECURITY_READY');
      expect(security['securityReady'], isFalse);
      expect(security['openBlockerCount'], 5);

      final controls =
          (security['controls'] as List<dynamic>).cast<Map<String, dynamic>>();
      final expectedCloudControlPlane = <String, bool>{
        'runtime-service-account-least-privilege': true,
        'dedicated-runtime-identity-source-binding': true,
        'app-check-client-activation': true,
        'callable-app-check-enforcement': false,
        'high-severity-node-dependency-advisories': false,
      };

      expect(controls.length, 5);
      for (final control in controls) {
        final id = control['id'] as String;
        expect(control['status'], 'OPEN_BLOCKER', reason: id);
        expect(control['stage2dSourceChangeRequired'], isTrue, reason: id);
        expect(
          control['separateCloudControlPlaneCampaignRequired'],
          expectedCloudControlPlane[id],
          reason: id,
        );
        expect(
          control['futureDeploymentOrClientReleaseRequired'],
          isTrue,
          reason: id,
        );
        expect(
          control.containsKey('cloudMutationRequired'),
          isFalse,
          reason: id,
        );
        expect(
          control.containsKey('separateGovernedCloudCampaignRequired'),
          isFalse,
          reason: id,
        );
      }
    },
  );

  test('this record authorizes no deployment, IAM or App Check mutation', () {
    final security = _readJson('release/backend-security-readiness.prod.json');
    expect(security['mutationAuthorization'], <String, dynamic>{
      'thisRecordCampaignSourceOnly': true,
      'thisRecordCampaignDeploymentAuthorized': false,
      'thisRecordCampaignIamMutationAuthorized': false,
      'thisRecordCampaignAppCheckControlPlaneMutationAuthorized': false,
      'futureSecurityStageMutationsAuthorizedByThisRecord': false,
    });

    final sequencing = security['sequencing'] as Map<String, dynamic>;
    expect(sequencing['sourceMergeDoesNotAuthorizeCloudMutation'], isTrue);
    expect(
      sequencing['stage2dSourceMergeDoesNotActivateProductionControls'],
      isTrue,
    );
    expect(
      (sequencing['separateCloudControlPlaneCampaigns'] as List<dynamic>)
          .toSet(),
      <String>{
        'DEDICATED_SERVICE_ACCOUNT_CREATION_AND_IAM_BINDING',
        'DEFAULT_COMPUTE_ROLES_EDITOR_REMOVAL_AFTER_CUTOVER',
        'FIREBASE_APP_CHECK_PROVIDER_REGISTRATION_AND_STAGED_ENFORCEMENT',
      },
    );
  });

  test('transport and dependency findings remain truthfully unresolved', () {
    final security = _readJson('release/backend-security-readiness.prod.json');
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

    final dependencies = security['dependencyAudit'] as Map<String, dynamic>;
    expect(dependencies['totalVulnerabilities'], 4);
    expect(dependencies['high'], 2);
    expect(dependencies['expectedHighSeverityPackages'], <String>[
      'form-data',
      'protobufjs',
    ]);
  });
}
