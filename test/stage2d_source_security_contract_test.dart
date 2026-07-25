import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _canonicalJson(dynamic value) {
  if (value is List<dynamic>) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:'
    '${_canonicalJson(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}

String _digest(Map<String, dynamic> document, String field) {
  final clone = jsonDecode(jsonEncode(document)) as Map<String, dynamic>;
  clone.remove(field);
  return sha256
      .convert(utf8.encode(_canonicalJson(clone)))
      .toString()
      .toUpperCase();
}

void _validateExactSchema(
  dynamic instance,
  Map<String, dynamic> schema, [
  String location = r'$',
]) {
  if (schema.containsKey('const')) {
    expect(instance, schema['const'], reason: '$location const mismatch');
  }

  switch (schema['type']) {
    case 'object':
      expect(instance, isA<Map<String, dynamic>>(), reason: location);
      expect(schema['additionalProperties'], isFalse, reason: location);
      final properties = schema['properties'] as Map<String, dynamic>;
      final required =
          (schema['required'] as List<dynamic>).cast<String>()..sort();
      final propertyKeys = properties.keys.toList()..sort();
      expect(required, propertyKeys, reason: '$location required mismatch');
      final instanceKeys =
          (instance as Map<String, dynamic>).keys.toList()..sort();
      expect(instanceKeys, propertyKeys, reason: '$location key mismatch');
      for (final key in propertyKeys) {
        _validateExactSchema(
          instance[key],
          properties[key] as Map<String, dynamic>,
          '$location.$key',
        );
      }
    case 'array':
      expect(instance, isA<List<dynamic>>(), reason: location);
      expect(schema.containsKey('const'), isTrue, reason: location);
    case 'string':
      expect(instance, isA<String>(), reason: location);
    case 'integer':
      expect(instance, isA<int>(), reason: location);
    case 'boolean':
      expect(instance, isA<bool>(), reason: location);
    case 'null':
      expect(instance, isNull, reason: location);
    default:
      fail('Unsupported schema type at $location: ${schema['type']}');
  }
}

void main() {
  group('Stage 2D source security readiness contract', () {
    final readiness = _readJson(
      'release/stage2d-source-security-readiness-candidate.json',
    );
    final schema = _readJson(
      'release/stage2d-source-security-readiness-v1.schema.json',
    );
    final production = _readJson(
      'release/backend-security-readiness.prod.json',
    );

    test('candidate is exact, digest-bound and not production-ready', () {
      _validateExactSchema(readiness, schema);
      expect(
        _digest(readiness, 'sourceReadinessDigest'),
        readiness['sourceReadinessDigest'],
      );
      expect(
        readiness['sourceReadinessDigest'],
        '5AB77DD5FF479064CC11AE7D1165682ACE00503F601D9B11C5B19F43C820F547',
      );
      expect(readiness['sourceImplementationComplete'], isTrue);
      expect(readiness['securityReady'], isFalse);
      expect(readiness['currentProductionStateChanged'], isFalse);
    });

    test('production security ledger remains unchanged and truthful', () {
      expect(production['securityReady'], isFalse);
      expect(production['openBlockerCount'], 5);
      expect(production['overallStatus'], 'NOT_SECURITY_READY');

      final audit = production['dependencyAudit'] as Map<String, dynamic>;
      expect(audit['high'], 2);
      expect(audit['expectedHighSeverityPackages'], <String>[
        'form-data',
        'protobufjs',
      ]);
    });

    test(
      'client source is staged disabled by default and platform explicit',
      () {
        final controls =
            (readiness['controls'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
        final client = controls.singleWhere(
          (control) => control['id'] == 'app-check-client-activation',
        );

        expect(
          client['sourceStatus'],
          'IMPLEMENTED_STAGED_DISABLED_BY_DEFAULT',
        );
        expect(client['activationDefine'], 'CRM3_APP_CHECK_ENABLED');
        expect(client['activationDefineDefault'], isFalse);
        expect(
          client['webSiteKeyDefine'],
          'CRM3_APP_CHECK_WEB_RECAPTCHA_V3_SITE_KEY',
        );
        expect(client['releaseUnsupportedPlatforms'], <String>[
          'windows',
          'linux',
          'fuchsia',
        ]);
      },
    );

    test('callable source is enforced without replay-token consumption', () {
      final controls =
          (readiness['controls'] as List<dynamic>).cast<Map<String, dynamic>>();
      final callable = controls.singleWhere(
        (control) => control['id'] == 'callable-app-check-enforcement',
      );

      expect(callable['targetFunction'], 'getBackendReleaseIdentity');
      expect(callable['enforceAppCheck'], isTrue);
      expect(callable['consumeAppCheckToken'], isFalse);
      expect(callable['productionStatus'], 'OPEN_BLOCKER');
    });

    test('dedicated source identity is deterministic but not yet created', () {
      final controls =
          (readiness['controls'] as List<dynamic>).cast<Map<String, dynamic>>();
      final identity = controls.singleWhere(
        (control) =>
            control['id'] == 'dedicated-runtime-identity-source-binding',
      );

      expect(
        identity['serviceAccountEmail'],
        'crm3-backend-identity-runtime@'
        'crm3-baf-ops-b8638.iam.gserviceaccount.com',
      );
      expect(identity['accountPresentAtCollectedBaseline'], isFalse);
      expect(identity['productionStatus'], 'OPEN_BLOCKER');
    });

    test(
      'root tooling removes the protobufjs high finding without claiming zero total',
      () {
        final rootPackage = _readJson('package.json');
        final rootLock = _readJson('package-lock.json');
        final overrides = rootPackage['overrides'] as Map<String, dynamic>;
        final packages = rootLock['packages'] as Map<String, dynamic>;

        expect(overrides['protobufjs'], '7.6.5');
        expect(
          (packages['node_modules/protobufjs']
              as Map<String, dynamic>)['version'],
          '7.6.5',
        );
        expect(
          packages.containsKey('node_modules/@protobufjs/inquire'),
          isFalse,
        );

        final controls =
            (readiness['controls'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
        final dependency = controls.singleWhere(
          (control) =>
              control['id'] == 'high-severity-node-dependency-advisories',
        );
        final rootAudit =
            dependency['rootCandidateAudit'] as Map<String, dynamic>;
        expect(rootAudit['high'], 0);
        expect(rootAudit['total'], 2);
        expect(rootAudit['remainingPackages'], <String>[
          '@babel/core',
          'js-yaml',
        ]);
      },
    );

    test('source record authorizes no cloud mutation', () {
      expect(readiness['mutationAuthorization'], <String, dynamic>{
        'sourceBranchCommitPushDraftPrAuthorizedByCampaign': true,
        'firebaseDeploymentAuthorized': false,
        'iamMutationAuthorized': false,
        'appCheckControlPlaneMutationAuthorized': false,
        'firestoreWriteAuthorized': false,
        'productionFunctionInvocationAuthorized': false,
      });
    });

    test('source files contain no embedded App Check token or site key', () {
      final bootstrap =
          File('lib/core/security/app_check_bootstrap.dart').readAsStringSync();

      expect(bootstrap, contains("'CRM3_APP_CHECK_WEB_RECAPTCHA_V3_SITE_KEY'"));
      expect(bootstrap, contains("'CRM3_APP_CHECK_DEBUG_TOKEN'"));
      expect(
        bootstrap,
        contains(
          "const String crm3AppCheckDebugToken = String.fromEnvironment(",
        ),
      );
    });
  });
}
