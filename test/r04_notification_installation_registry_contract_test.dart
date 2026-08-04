import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

String _fileSha256(String path) {
  return sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();
}

String _section(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'Missing $start');
  expect(
    endIndex,
    greaterThan(startIndex),
    reason: 'Missing $end after $start',
  );
  return source.substring(startIndex, endIndex);
}

void main() {
  test('R-04 client lifecycle is installation-scoped and refresh-aware', () {
    final registry =
        File(
          'lib/features/auth/services/notification_installation_registry.dart',
        ).readAsStringSync();
    final auth =
        File(
          'lib/features/auth/providers/auth_provider.dart',
        ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    for (final marker in <String>[
      "notification_installations",
      "crm3.notificationInstallationId.v1",
      "FieldValue.serverTimestamp()",
      "registerCurrentToken",
      "registerToken",
      "removeCurrentInstallation",
      "retireMessagingToken",
    ]) {
      expect(
        registry,
        contains(marker),
        reason: 'Missing registry marker $marker',
      );
    }
    expect(registry, contains('_uuid.v4()'));
    final removeBlock = _section(
      registry,
      'Future<void> remove({',
      'abstract interface class NotificationTokenSource',
    );
    expect(removeBlock, contains('transaction.delete(installationRef)'));
    expect(removeBlock, isNot(contains('transaction.get(installationRef)')));
    expect(auth, contains('registry.tokenRefreshes.listen'));
    expect(auth, contains('FCM token refresh subscription unavailable'));
    expect(auth, contains('notificationInstallationSyncProvider'));
    expect(main, contains('ref.watch(notificationInstallationSyncProvider)'));

    final signOut = _section(
      auth,
      'Future<void> signOut()',
      'Map<String, dynamic> _pendingUserPayload',
    );
    expect(
      signOut.indexOf('await _notificationRegistry.removeCurrentInstallation'),
      lessThan(signOut.indexOf('await _auth.signOut()')),
    );
    expect(
      signOut.indexOf('await _auth.signOut()'),
      lessThan(signOut.indexOf('await _googleSignIn.signOut()')),
    );

    final pendingPayload = _section(
      auth,
      'Map<String, dynamic> _pendingUserPayload',
      'String _cleanProfileText',
    );
    expect(pendingPayload, isNot(contains("'fcmToken'")));
    expect(
      File(
        'test/notification_installation_registry_test.dart',
      ).readAsStringSync(),
      contains('sign-out removes only this installation'),
    );
  });

  test('R-04 Rules keep tokens private and owner writes exact', () {
    final rules = File('firestore.rules').readAsStringSync();
    final installationRules = _section(
      rules,
      'match /notification_installations/{installationId}',
      'match /audit_logs/{docId}',
    );

    expect(rules, contains('validNotificationInstallationWrite'));
    expect(rules, contains("data.keys().hasOnly(["));
    expect(
      rules,
      contains("request.resource.data.get('updatedAt', null) == request.time"),
    );
    expect(installationRules, contains('allow read: if false;'));
    expect(installationRules, contains('allow create, update:'));
    expect(installationRules, contains('allow delete:'));

    final rulesTests = File('test/firestore.rules.test.js').readAsStringSync();
    for (final marker in <String>[
      'R-04 private notification installation registry',
      'installation tokens cannot be read',
      "one user cannot create or delete another user's installation",
      'malformed IDs and document shapes fail closed',
      'missing or malformed parent profiles',
    ]) {
      expect(rulesTests, contains(marker));
    }
  });

  test('R-04 server fan-out is bounded, migratory, and race-safe', () {
    final notifications =
        File('functions/src/notifications.ts').readAsStringSync();
    final unitTests =
        File('functions/test/notifications.test.js').readAsStringSync();

    for (final marker in <String>[
      'MAX_NOTIFICATION_INSTALLATIONS_PER_USER = 8',
      '.orderBy("updatedAt", "desc")',
      '.limit(MAX_NOTIFICATION_INSTALLATIONS_PER_USER)',
      'canonicalInstallationToken',
      'isFirestoreTimestamp',
      'getTokenLookupsForUser',
      'tokenToRegistrations',
      'txn.delete(ref)',
      'current.token !== deadToken',
    ]) {
      expect(notifications, contains(marker));
    }
    expect(unitTests, contains('legacy migration token'));
    expect(unitTests, contains('eight most recently refreshed installations'));
    expect(unitTests, contains('does not delete an installation refreshed'));
    expect(unitTests, contains('wrongTimestamp'));
  });

  test('R-04 source and CI closure is exact and does not overclaim', () {
    const closurePath =
        'release/evidence/r04-notification-installation-source-and-ci-closure.json';
    final policy = _object(
      jsonDecode(
        File(
          'release/r04-notification-installation-registry-policy.json',
        ).readAsStringSync(),
      ),
    );
    final privacy = _object(policy['privacyAndAuthority']);
    final delivery = _object(policy['delivery']);
    final boundary = _object(policy['evidenceBoundary']);
    final closure = _object(jsonDecode(File(closurePath).readAsStringSync()));
    final ledger = _object(
      jsonDecode(File('governance/programme-ledger.json').readAsStringSync()),
    );
    final record = _objects(
      ledger['technicalFindings'],
    ).singleWhere((candidate) => candidate['findingId'] == 'R-04');

    expect(policy['findingId'], 'R-04');
    expect(policy['sourceStatus'], 'SOURCE_AND_CI_CLOSED');
    expect(privacy['clientReads'], 'DENIED');
    expect(delivery['maximumInstallationsReadPerUser'], 8);
    expect(_strings(policy['reArmTriggers']), hasLength(6));
    expect(boundary['productionDeploymentPerformed'], isFalse);
    expect(boundary['deviceDeliveryEvidenceClaimed'], isFalse);
    expect(boundary['pilotAuthorizationCreated'], isFalse);

    expect(record['authorityType'], 'SOURCE_AND_CI');
    expect(record['currentStatus'], 'CLOSED');
    expect(
      _objects(record['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );
    expect(_strings(record['requiredExitEvidence']), hasLength(6));
    expect(_strings(record['reArmTriggers']), hasLength(6));
    final evidence = _objects(record['evidence']).single;
    expect(evidence['evidenceFile'], closurePath);
    expect(evidence['evidenceSha256'], _fileSha256(closurePath));
    expect(evidence['pullRequest'], 134);
    expect(evidence['headCommit'], '55869a42aa48fd18e360c499a82825a00eaacd29');
    expect(evidence['sourceTree'], evidence['mergeTree']);
    expect(evidence['pullRequestWorkflowRun'], 30880821675);
    expect(evidence['postMergeWorkflowRun'], 30881331523);
    expect(
      evidence['decision'],
      'PASS_R04_NOTIFICATION_INSTALLATION_SOURCE_AND_CI_CLOSURE',
    );
    expect(evidence['productionDeploymentPerformed'], isFalse);
    expect(evidence['deviceEvidenceClaimed'], isFalse);
    expect(evidence['notificationDeliveryClaimed'], isFalse);
    expect(evidence['pilotAuthorizationCreated'], isFalse);

    final source = _object(closure['sourceAuthority']);
    expect(closure['findingIds'], <String>['R-04']);
    expect(closure['authorityType'], 'SOURCE_AND_CI');
    expect(
      closure['decision'],
      'PASS_R04_NOTIFICATION_INSTALLATION_SOURCE_AND_CI_CLOSURE',
    );
    expect(source['repository'], 'abhishekvatsa/crm3_baf_ops');
    expect(source['pullRequest'], 134);
    expect(source['headCommit'], evidence['headCommit']);
    expect(source['sourceTree'], source['mergeTree']);
    expect(source['mergeCommit'], evidence['mergeCommit']);
    for (final ciName in <String>['pullRequestCi', 'postMergeCi']) {
      final ci = _object(closure[ciName]);
      expect(ci['conclusion'], 'success');
      expect(_objects(ci['jobs']), hasLength(4));
      expect(
        _objects(ci['jobs']).map((job) => job['conclusion']),
        everyElement('success'),
      );
    }
    expect(_object(closure['closureBoundary']).values, everyElement(isFalse));

    final decision =
        File(
          'docs/v4_2_r1/R04_NOTIFICATION_INSTALLATION_REGISTRY.md',
        ).readAsStringSync();
    expect(decision, contains('Status: CLOSED'));
    expect(decision, contains('Merge and exact-head CI evidence: PASS'));
    expect(
      decision,
      contains('PASS_R04_NOTIFICATION_INSTALLATION_SOURCE_AND_CI_CLOSURE'),
    );
    expect(decision, contains('does not claim production Rules or Functions'));
  });
}
