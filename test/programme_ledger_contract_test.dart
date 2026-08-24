import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing governed file: $path');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

String _sha256(String path) {
  return sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();
}

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

List<Map<String, dynamic>> _objects(dynamic value) {
  return (value as List<dynamic>).map(_object).toList(growable: false);
}

Set<String> _allowedNextStatuses(
  Map<String, dynamic> item,
  String previous,
  Map<String, dynamic> transitionPolicy,
) {
  final reArmOverlay = _object(transitionPolicy['reArmOverlay']);
  final overlayTransitions = _object(reArmOverlay['allowedTransitions']);

  if (previous == 'DEFERRED' || previous == 'RE_ARMED') {
    return _strings(overlayTransitions[previous]).toSet();
  }

  final profiles = _object(transitionPolicy['transitionProfiles']);
  final profile = _object(profiles[item['transitionProfile']]);
  final allowedTransitions = _object(profile['allowedTransitions']);
  final raw = allowedTransitions[previous];
  if (raw == null) {
    return <String>{};
  }
  return _strings(raw).toSet();
}

bool _transitionIsAllowed(
  Map<String, dynamic> item,
  String previous,
  String next,
  Map<String, dynamic> transitionPolicy,
) {
  if (next == 'DEFERRED') {
    final reArmOverlay = _object(transitionPolicy['reArmOverlay']);
    return _strings(reArmOverlay['entryAllowedFrom']).contains(previous);
  }
  return _allowedNextStatuses(item, previous, transitionPolicy).contains(next);
}

void _validateHistory(
  Map<String, dynamic> item,
  Set<String> statusVocabulary,
  Map<String, dynamic> transitionPolicy,
) {
  final currentStatus = item['currentStatus'] as String;
  expect(statusVocabulary, contains(currentStatus));

  final history = _objects(item['statusHistory']);
  expect(history, isNotEmpty);
  expect(history.last['status'], currentStatus);

  for (var index = 0; index < history.length; index++) {
    final status = history[index]['status'] as String;
    expect(statusVocabulary, contains(status));

    if (index > 0) {
      final previous = history[index - 1]['status'] as String;
      expect(
        _transitionIsAllowed(item, previous, status, transitionPolicy),
        isTrue,
        reason:
            'Invalid ${item['transitionProfile']} transition for '
            '${item['recordId']}: $previous -> $status',
      );
    }

    if (status == 'RE_ARMED') {
      expect(
        index,
        greaterThan(0),
        reason: 'RE_ARMED must be immediately preceded by DEFERRED.',
      );
      expect(history[index - 1]['status'], 'DEFERRED');

      final triggerId = history[index]['triggerId'];
      final detectedAt = history[index]['detectedAt'];
      final evidenceReference = history[index]['evidenceReference'];

      expect(triggerId, isA<String>());
      expect((triggerId as String).trim(), isNotEmpty);
      expect(detectedAt, isA<String>());
      expect((detectedAt as String).trim(), isNotEmpty);
      expect(DateTime.tryParse(detectedAt), isNotNull);
      expect(evidenceReference, isA<String>());
      expect((evidenceReference as String).trim(), isNotEmpty);

      if (index + 1 < history.length) {
        expect(
          history[index + 1]['status'],
          'OPEN',
          reason: 'A historical RE_ARMED entry must be followed by OPEN.',
        );
      }
    }
  }

  if (currentStatus == 'DEFERRED') {
    expect(
      _strings(item['reArmTriggers']),
      isNotEmpty,
      reason: 'A deferred record must name at least one re-arm trigger.',
    );
  }
}

void _validateMandatoryRecord(
  Map<String, dynamic> item,
  Set<String> mandatoryFields,
  Set<String> trackVocabulary,
  Set<String> authorityTypeVocabulary,
  Set<String> transitionProfileVocabulary,
  Map<String, dynamic> authorityDefaults,
  Set<String> statusVocabulary,
  Map<String, dynamic> transitionPolicy,
) {
  for (final field in mandatoryFields) {
    expect(
      item.containsKey(field),
      isTrue,
      reason: '${item['recordId']} is missing mandatory field $field',
    );
  }

  final recordId = item['recordId'];
  expect(recordId, isA<String>());
  expect((recordId as String).trim(), isNotEmpty);

  expect(trackVocabulary, contains(item['track']));
  expect(authorityTypeVocabulary, contains(item['authorityType']));
  expect(transitionProfileVocabulary, contains(item['transitionProfile']));
  expect(
    item['transitionProfile'],
    authorityDefaults[item['authorityType']],
    reason:
        '${item['recordId']} does not use the canonical transition profile '
        'for ${item['authorityType']}',
  );

  final baselineCommit = item['baselineCommit'];
  expect(baselineCommit, isA<String>());
  expect(RegExp(r'^[0-9a-f]{40}$').hasMatch(baselineCommit as String), isTrue);

  expect(item['supersedes'], isA<List<dynamic>>());
  expect(item['supersededBy'], anyOf(isNull, isA<String>()));
  expect(item['evidence'], isA<List<dynamic>>());
  expect(item['requiredExitEvidence'], isA<List<dynamic>>());
  expect(item['reArmTriggers'], isA<List<dynamic>>());
  expect(item['notes'], isA<List<dynamic>>());
  expect(item['statusHistory'], isA<List<dynamic>>());

  _validateHistory(item, statusVocabulary, transitionPolicy);
}

void _validateSupersessionGraph(List<Map<String, dynamic>> records) {
  final byId = <String, Map<String, dynamic>>{
    for (final record in records) record['recordId'] as String: record,
  };
  expect(
    byId.length,
    records.length,
    reason: 'recordId values must be unique.',
  );

  for (final record in records) {
    final recordId = record['recordId'] as String;
    final supersedes = _strings(record['supersedes']);
    final supersededBy = record['supersededBy'];

    expect(
      supersedes.toSet().length,
      supersedes.length,
      reason: '$recordId contains duplicate supersedes references.',
    );
    expect(
      supersedes,
      isNot(contains(recordId)),
      reason: '$recordId may not supersede itself.',
    );

    for (final target in supersedes) {
      expect(
        byId.containsKey(target),
        isTrue,
        reason: '$recordId references $target.',
      );
      expect(
        byId[target]!['supersededBy'],
        recordId,
        reason: '$target must reciprocally name $recordId as supersededBy.',
      );
    }

    if (supersededBy != null) {
      expect(supersededBy, isA<String>());
      expect(byId.containsKey(supersededBy), isTrue);
      expect(
        _strings(byId[supersededBy]!['supersedes']),
        contains(recordId),
        reason: '$recordId has a non-reciprocal supersededBy reference.',
      );
    }
  }

  final visiting = <String>{};
  final visited = <String>{};

  void visit(String recordId) {
    if (visited.contains(recordId)) {
      return;
    }
    if (!visiting.add(recordId)) {
      fail('Circular supersession detected at $recordId.');
    }

    for (final target in _strings(byId[recordId]!['supersedes'])) {
      visit(target);
    }

    visiting.remove(recordId);
    visited.add(recordId);
  }

  for (final recordId in byId.keys) {
    visit(recordId);
  }
}

void main() {
  test('ledger defines canonical vocabularies and transition profiles', () {
    final payload = _readJson('governance/programme-ledger.json');

    expect(payload['schemaVersion'], 1);
    expect(
      payload['declarationStatus'],
      'CANONICAL_SUPERSESSION_AWARE_PROGRAMME_LEDGER',
    );

    final decision = _object(payload['programmeDecision']);
    expect(decision['controlledEngineering'], 'GO');
    expect(decision['internalControlledPilot'], 'GO');
    expect(decision['pilotHandout'], 'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER');
    expect(decision['playIntegrityAndAppCheck'], 'GOVERNED_DEFERRAL');
    expect(decision['leastPrivilegeIam'], 'CLOSED_PASS');
    expect(decision['broadFeatureExpansion'], 'HOLD');
    expect(decision['unrestrictedDistribution'], 'NO_GO');
    expect(decision['nextMutation'], 'NONE_ALL_PROGRAMME_GATES_CLOSED');

    expect(_strings(payload['severityVocabulary']).toSet(), <String>{
      'BLOCKER',
      'CONDITIONAL_BLOCKER',
      'HIGH',
      'MEDIUM',
      'LOW_MEDIUM',
      'LOW',
      'DEFERRED_MEDIUM',
    });

    expect(_strings(payload['trackVocabulary']).toSet(), <String>{
      'INTERNAL_PILOT',
      'UNRESTRICTED_DISTRIBUTION',
      'BOTH_TRACKS',
      'INDEPENDENT_SECURITY',
      'RECOVERABILITY',
      'LIVE_READBACK',
    });

    expect(_strings(payload['authorityTypeVocabulary']).toSet(), <String>{
      'DECISION_CUSTODY',
      'SOURCE_AND_CI',
      'DEPLOYED_RUNTIME',
      'LIVE_READBACK',
      'DEVICE_EVIDENCE',
      'PILOT_AUTHORIZATION',
      'GOVERNANCE_LEDGER',
    });

    expect(_strings(payload['transitionProfileVocabulary']).toSet(), <String>{
      'DECISION_CUSTODY',
      'SOURCE_AND_CI',
      'DEPLOYED_CONTROL',
      'LIVE_READBACK',
      'DEVICE_EVIDENCE',
      'PILOT_AUTHORIZATION',
    });

    final transitionPolicy = _object(payload['transitionPolicy']);
    expect(transitionPolicy['historyMode'], 'APPEND_ONLY');
    expect(transitionPolicy['profileMode'], 'PER_RECORD');

    final profiles = _object(transitionPolicy['transitionProfiles']);
    for (final profile in _strings(payload['transitionProfileVocabulary'])) {
      expect(profiles.containsKey(profile), isTrue);
      expect(
        _object(profiles[profile]).containsKey('allowedTransitions'),
        isTrue,
      );
    }

    final authorityDefaults = _object(
      payload['authorityTypeDefaultTransitionProfile'],
    );
    for (final authority in _strings(payload['authorityTypeVocabulary'])) {
      expect(authorityDefaults.containsKey(authority), isTrue);
      expect(
        _strings(payload['transitionProfileVocabulary']),
        contains(authorityDefaults[authority]),
      );
    }

    final overlay = _object(transitionPolicy['reArmOverlay']);
    final overlayTransitions = _object(overlay['allowedTransitions']);
    expect(_strings(overlayTransitions['RE_ARMED']), <String>['OPEN']);
    expect(_strings(overlayTransitions['DEFERRED']), contains('RE_ARMED'));

    final reArmRule = _object(transitionPolicy['reArmRule']);
    expect(_strings(reArmRule['requiredSequence']), <String>[
      'DEFERRED',
      'RE_ARMED',
      'OPEN',
    ]);
    expect(_strings(reArmRule['reArmedMayTransitionOnlyTo']), <String>['OPEN']);

    final liveReadback = _object(profiles['LIVE_READBACK']);
    expect(
      _strings(_object(liveReadback['allowedTransitions'])['OPEN']),
      contains('LIVE_READBACK_PROVED'),
    );

    final deviceEvidence = _object(profiles['DEVICE_EVIDENCE']);
    expect(
      _strings(_object(deviceEvidence['allowedTransitions'])['OPEN']),
      contains('DEVICE_PROVED'),
    );

    final pilotAuthorization = _object(profiles['PILOT_AUTHORIZATION']);
    expect(
      _strings(_object(pilotAuthorization['allowedTransitions'])['OPEN']),
      contains('PILOT_AUTHORIZED'),
    );
  });

  test('every gate and finding obeys canonical record schema', () {
    final payload = _readJson('governance/programme-ledger.json');
    final statusVocabulary = _strings(payload['statusVocabulary']).toSet();
    final trackVocabulary = _strings(payload['trackVocabulary']).toSet();
    final authorityTypeVocabulary =
        _strings(payload['authorityTypeVocabulary']).toSet();
    final transitionProfileVocabulary =
        _strings(payload['transitionProfileVocabulary']).toSet();
    final authorityDefaults = _object(
      payload['authorityTypeDefaultTransitionProfile'],
    );
    final mandatoryFields = _strings(payload['mandatoryRecordFields']).toSet();
    final transitionPolicy = _object(payload['transitionPolicy']);

    final gates = _objects(payload['programmeGates']);
    final findings = _objects(payload['technicalFindings']);
    final allRecords = <Map<String, dynamic>>[...gates, ...findings];

    for (final record in allRecords) {
      _validateMandatoryRecord(
        record,
        mandatoryFields,
        trackVocabulary,
        authorityTypeVocabulary,
        transitionProfileVocabulary,
        authorityDefaults,
        statusVocabulary,
        transitionPolicy,
      );
    }

    _validateSupersessionGraph(allRecords);

    final gateIds = gates.map((item) => item['gateId'] as String).toSet();
    expect(
      gateIds,
      containsAll(<String>{
        'STAGE2D-F1A',
        'STAGE2D-F1B',
        'G-01',
        'STAGE2D-F2',
        'STAGE2D-F3',
        'STAGE2D-F4',
        'STAGE2D-F5',
        'STAGE2D-F6',
        'H2-IAM',
        '70K-RECOVERY',
        'LR-01',
        'LR-02',
        'LR-03',
        'LR-04',
        'LR-05',
        'LR-06',
        'LR-07',
      }),
    );

    for (final id in <String>[
      'LR-01',
      'LR-02',
      'LR-03',
      'LR-04',
      'LR-05',
      'LR-06',
      'LR-07',
    ]) {
      final gate = gates.singleWhere((item) => item['gateId'] == id);
      expect(gate['authorityType'], 'LIVE_READBACK');
      expect(gate['transitionProfile'], 'LIVE_READBACK');
      expect(
        _allowedNextStatuses(gate, 'OPEN', transitionPolicy),
        contains('LIVE_READBACK_PROVED'),
      );
    }

    final f4 = gates.singleWhere((item) => item['gateId'] == 'STAGE2D-F4');
    expect(f4['authorityType'], 'DEVICE_EVIDENCE');
    expect(
      _allowedNextStatuses(f4, 'OPEN', transitionPolicy),
      contains('DEVICE_PROVED'),
    );

    final f6 = gates.singleWhere((item) => item['gateId'] == 'STAGE2D-F6');
    expect(f6['authorityType'], 'PILOT_AUTHORIZATION');
    expect(
      _allowedNextStatuses(f6, 'OPEN', transitionPolicy),
      contains('PILOT_AUTHORIZED'),
    );

    final f1a = gates.singleWhere((item) => item['gateId'] == 'STAGE2D-F1A');
    expect(f1a['currentStatus'], 'CLOSED');
    final f1aEvidence = _objects(f1a['evidence']).single;
    expect(
      f1aEvidence['sha256'],
      '5BE4A11E097DB1628BA18A20C3423539BADFA793FA7839D9E0D0CDFC8E2D0AFD',
    );

    const closureEvidenceSha =
        '5BCC68A4E560CD73AF1CE02C20C62525A48AD8E5CFCFAA2D25B3750C577EDD44';
    const mergeEvidenceSha =
        '7BF206D198105EA3984AAD6564B8A26F26880A6BAC7D23FE74AE3D2C59D64DB4';

    for (final id in <String>['STAGE2D-F1B', 'G-01']) {
      final gate = gates.singleWhere((item) => item['gateId'] == id);
      expect(gate['currentStatus'], 'CLOSED');
      expect(gate['authorization'], 'CLOSED_PASS');

      final statuses = _objects(
        gate['statusHistory'],
      ).map((entry) => entry['status'] as String).toList(growable: false);
      expect(statuses.sublist(statuses.length - 3), <String>[
        'SOURCE_IMPLEMENTED',
        'MERGED',
        'CLOSED',
      ]);

      final evidenceShas =
          _objects(
            gate['evidence'],
          ).map((entry) => entry['sha256'] as String).toSet();
      expect(evidenceShas, contains(mergeEvidenceSha));
      expect(evidenceShas, contains(closureEvidenceSha));
    }

    final findingIds =
        findings.map((item) => item['findingId'] as String).toSet();
    expect(findingIds, <String>{
      'P-01',
      'P-02',
      'P-03',
      'P-04',
      'P-05',
      'P-06',
      'P-07',
      'S-01',
      'S-02',
      'S-03',
      'S-04',
      'S-05',
      'S-06',
      'S-07',
      'S-08',
      'S-09',
      'R-01',
      'R-02',
      'R-03',
      'R-04',
      'R-05',
      'R-06',
      'A-01',
      'A-02',
      'A-03',
      'A-04',
      'A-05',
      'C-01',
      'C-02',
      'C-03',
      'C-04',
      'C-05',
      'C-06',
      'D-01',
      'G-01',
    });

    final severityVocabulary = _strings(payload['severityVocabulary']).toSet();
    for (final finding in findings) {
      expect(severityVocabulary, contains(finding['pilotSeverity']));
      expect(severityVocabulary, contains(finding['unrestrictedSeverity']));
    }

    for (final id in <String>['P-03', 'G-01']) {
      final finding = findings.singleWhere((item) => item['findingId'] == id);
      expect(finding['pilotSeverity'], 'BLOCKER');
      expect(finding['currentStatus'], 'CLOSED');
      expect(_strings(finding['requiredExitEvidence']), isNotEmpty);

      final statuses = _objects(
        finding['statusHistory'],
      ).map((entry) => entry['status'] as String).toList(growable: false);
      expect(statuses.sublist(statuses.length - 3), <String>[
        'SOURCE_IMPLEMENTED',
        'MERGED',
        'CLOSED',
      ]);

      final evidenceShas =
          _objects(
            finding['evidence'],
          ).map((entry) => entry['sha256'] as String).toSet();
      expect(evidenceShas, contains(mergeEvidenceSha));
      expect(evidenceShas, contains(closureEvidenceSha));
    }
  });

  test('architecture findings preserve their exact evidence states', () {
    final payload = _readJson('governance/programme-ledger.json');
    final findings = _objects(payload['technicalFindings']);
    final architecture = <String, Map<String, dynamic>>{
      for (final finding in findings)
        if (<String>{
          'A-01',
          'A-02',
          'A-03',
          'A-04',
          'A-05',
        }.contains(finding['findingId']))
          finding['findingId'] as String: finding,
    };

    expect(architecture.keys, <String>{'A-01', 'A-02', 'A-03', 'A-04', 'A-05'});
    final a01 = architecture['A-01']!;
    expect(a01['currentStatus'], 'CLOSED');
    expect(_objects(a01['evidence']), hasLength(1));
    expect(_strings(a01['requiredExitEvidence']), hasLength(5));
    expect(_strings(a01['reArmTriggers']), hasLength(3));
    expect(_strings(a01['notes']), isNotEmpty);
    expect(
      _objects(
        a01['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );
    final a01Evidence = _objects(a01['evidence']).single;
    expect(
      a01Evidence['decision'],
      'PASS_A01_DART_IMPORT_CYCLE_SOURCE_AND_CI_CLOSURE',
    );
    expect(a01Evidence['pullRequest'], 214);
    expect(a01Evidence['pullRequestWorkflowRun'], 31863973925);
    expect(a01Evidence['postMergeWorkflowRun'], 31864544804);
    final a01Closure = _readJson(
      'release/evidence/a01-dart-import-cycle-source-and-ci-closure.json',
    );
    expect(a01Closure['findingId'], 'A-01');
    expect(
      a01Closure['decision'],
      'PASS_A01_DART_IMPORT_CYCLE_SOURCE_AND_CI_CLOSURE',
    );
    expect(
      _object(a01Closure['sourceAuthority'])['sourceTree'],
      '99deeb6966cc1b694f861a6154d9a4ddef3c7af0',
    );
    expect(_object(a01Closure['importGraphProof'])['mainDartImporterCount'], 0);
    expect(
      _object(
        a01Closure['importGraphProof'],
      )['stronglyConnectedComponentCount'],
      0,
    );
    expect(_object(a01Closure['pullRequestCi'])['conclusion'], 'success');
    expect(_object(a01Closure['postMergeCi'])['conclusion'], 'success');
    final a02 = architecture['A-02']!;
    expect(a02['currentStatus'], 'CLOSED');
    expect(_objects(a02['evidence']), hasLength(1));
    expect(_strings(a02['requiredExitEvidence']), hasLength(5));
    expect(_strings(a02['reArmTriggers']), hasLength(3));
    expect(
      _objects(
        a02['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );
    final a02Evidence = _objects(a02['evidence']).single;
    expect(
      a02Evidence['decision'],
      'PASS_A02_ARCHITECTURE_RESPONSIBILITY_SOURCE_AND_CI_CLOSURE',
    );
    expect(a02Evidence['pullRequest'], 232);
    expect(a02Evidence['pullRequestWorkflowRun'], 32036713473);
    expect(a02Evidence['postMergeWorkflowRun'], 32037634060);
    final a02Closure = _readJson(
      'release/evidence/a02-architecture-responsibility-source-and-ci-closure.json',
    );
    expect(a02Closure['findingId'], 'A-02');
    expect(
      a02Closure['decision'],
      'PASS_A02_ARCHITECTURE_RESPONSIBILITY_SOURCE_AND_CI_CLOSURE',
    );
    expect(
      _object(a02Closure['sourceAuthority'])['sourceTree'],
      'a6ffe16758711d587a213a85f95bea3f6f1730ad',
    );
    final a02Inventory = _object(a02Closure['inventoryProof']);
    expect(a02Inventory['hotspotCount'], 40);
    expect(a02Inventory['decomposedSurfaceCount'], 16);
    expect(a02Inventory['boundedExceptionCount'], 24);
    expect(a02Inventory['a03PresentationPersistenceCarryoverCount'], 3);
    expect(_object(a02Closure['pullRequestCi'])['conclusion'], 'success');
    expect(_object(a02Closure['postMergeCi'])['conclusion'], 'success');
    expect(_object(a02Closure['boundaries'])['a03CarryoversClosed'], isFalse);

    final a03 = architecture['A-03']!;
    expect(a03['currentStatus'], 'CLOSED');
    expect(_objects(a03['evidence']), hasLength(1));
    expect(_strings(a03['requiredExitEvidence']), hasLength(5));
    expect(_strings(a03['reArmTriggers']), hasLength(3));
    expect(_strings(a03['notes']), hasLength(4));
    expect(
      _objects(
        a03['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );
    final a03Evidence = _objects(a03['evidence']).single;
    expect(
      a03Evidence['decision'],
      'PASS_A03_PERSISTENCE_BOUNDARY_SOURCE_AND_CI_CLOSURE',
    );
    expect(a03Evidence['pullRequest'], 234);
    expect(a03Evidence['pullRequestWorkflowRun'], 32042648071);
    expect(a03Evidence['postMergeWorkflowRun'], 32043979797);
    final a03Closure = _readJson(
      'release/evidence/a03-persistence-boundary-source-and-ci-closure.json',
    );
    expect(a03Closure['findingId'], 'A-03');
    expect(
      a03Closure['decision'],
      'PASS_A03_PERSISTENCE_BOUNDARY_SOURCE_AND_CI_CLOSURE',
    );
    expect(
      _object(a03Closure['sourceAuthority'])['sourceTree'],
      '0ccc46eedec7c88c9c2e2df0e8bc5f498e2a1eff',
    );
    final a03Inventory = _object(a03Closure['inventoryProof']);
    expect(a03Inventory['operationCount'], 484);
    expect(a03Inventory['siteCount'], 1548);
    expect(a03Inventory['surfaceCount'], 44);
    expect(a03Inventory['presentationPersistenceCount'], 0);
    expect(_object(a03Closure['pullRequestCi'])['conclusion'], 'success');
    expect(_object(a03Closure['postMergeCi'])['conclusion'], 'success');
    final a03Manifest = _readJson(
      'governance/a03-persistence-boundaries-v1.json',
    );
    expect(a03Manifest['findingId'], 'A-03');
    expect(
      a03Manifest['inventoryDigest'],
      '6262F1D34F8C2C0A5BDCFABB81B9F1085F9E35225DD0F49E996F470E208CC95C',
    );
    expect(_objects(a03Manifest['surfaces']), hasLength(49));

    final a04 = architecture['A-04']!;
    expect(a04['currentStatus'], 'CLOSED');
    expect(_objects(a04['evidence']), hasLength(1));
    expect(_strings(a04['requiredExitEvidence']), hasLength(5));
    expect(_strings(a04['reArmTriggers']), hasLength(3));
    expect(_strings(a04['notes']), hasLength(5));
    expect(
      _objects(
        a04['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );
    final a04Evidence = _objects(a04['evidence']).single;
    expect(
      a04Evidence['decision'],
      'PASS_A04_PERSISTED_SCHEMA_SOURCE_CI_AND_RECONCILIATION_CLOSURE',
    );
    expect(a04Evidence['pullRequest'], 235);
    expect(a04Evidence['pullRequestWorkflowRun'], 32050533628);
    expect(a04Evidence['postMergeWorkflowRun'], 32051729235);
    final a04Closure = _readJson(
      'release/evidence/a04-persisted-schema-source-ci-and-reconciliation-closure.json',
    );
    expect(a04Closure['findingId'], 'A-04');
    expect(
      a04Closure['decision'],
      'PASS_A04_PERSISTED_SCHEMA_SOURCE_CI_AND_RECONCILIATION_CLOSURE',
    );
    expect(
      _object(a04Closure['sourceAuthority'])['sourceTree'],
      '55c73664ce7cc2f8f60142d92e8920a4686a385f',
    );
    final a04Inventory = _object(a04Closure['inventoryProof']);
    expect(a04Inventory['fieldCount'], 53);
    expect(a04Inventory['inheritedDecoderSurfaceCount'], 54);
    final a04Production = _object(a04Closure['productionReconciliation']);
    expect(a04Production['cleanFetchedMain'], isTrue);
    expect(a04Production['readOnly'], isTrue);
    expect(a04Production['cloudMutationCapability'], 'NONE');
    expect(a04Production['blockingFindingCount'], 0);
    expect(a04Production['warningCount'], 0);
    expect(a04Production['strictReaderAttemptedCount'], 9);
    expect(a04Production['strictReaderPassedCount'], 9);
    expect(a04Production['strictReaderFailedCount'], 0);
    final a04Local = _object(a04Closure['supportedLocalGenerationAuthority']);
    expect(_strings(a04Local['testFiles']), hasLength(4));
    expect(a04Local['passedCount'], 27);
    expect(a04Local['failedCount'], 0);
    expect(_strings(a04Local['dispositions']), hasLength(5));
    expect(a04Local['repairDisposition'], 'PRESERVE_AND_BLOCK_PENDING_REPAIR');
    expect(a04Local['silentRewritePerformed'], isFalse);
    expect(_object(a04Closure['pullRequestCi'])['conclusion'], 'success');
    expect(_object(a04Closure['postMergeCi'])['conclusion'], 'success');
    final a04Manifest = _readJson('governance/a04-persisted-schema-v1.json');
    expect(a04Manifest['findingId'], 'A-04');
    expect(
      a04Manifest['inventoryDigest'],
      'DF8FEDBDC04994401AD4713D3AF22472DAB2F75571399C81EB2D745EBEE5D547',
    );
    expect(_objects(a04Manifest['fields']), hasLength(53));
    expect(_objects(a04Manifest['inheritedDecoderSurfaces']), hasLength(70));

    final a05 = architecture['A-05']!;
    expect(a05['currentStatus'], 'CLOSED');
    expect(_objects(a05['evidence']), hasLength(1));
    expect(_strings(a05['requiredExitEvidence']), hasLength(5));
    expect(_strings(a05['reArmTriggers']), hasLength(3));
    expect(
      _objects(
        a05['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );
    expect(
      _objects(a05['evidence']).single['decision'],
      'PASS_A05_PERSISTED_STATE_INTEGRITY_CLOSURE',
    );
    final a05Closure = _readJson(
      'release/evidence/a05-persisted-state-integrity-closure.json',
    );
    final localGeneration = _object(
      a05Closure['supportedLocalGenerationAuthority'],
    );
    final currentSource = _object(localGeneration['currentSourceRevalidation']);
    expect(currentSource['pullRequest'], 206);
    expect(
      currentSource['sourceCommit'],
      'ed8b8fb0655d2fb5396f10daecb3e6ab49966342',
    );
    expect(
      currentSource['sourceTree'],
      '98af51decc0c4b2fe9257d66dcb4de4766aa1cfd',
    );
    expect(currentSource['workflowRun'], 31628102225);
    expect(currentSource['workflowJob'], 94219670718);
    expect(currentSource['conclusion'], 'success');
    expect(currentSource['sameCheckout'], isTrue);
    expect(currentSource['remediatedA05RegressionFileCount'], 18);
    expect(currentSource['remediatedA05RegressionPassedCount'], 137);
    expect(currentSource['supportedLocalGenerationFixturePassedCount'], 4);
    expect(currentSource['supportedLocalGenerationFixtureFailedCount'], 0);
    expect(_strings(currentSource['fixtureDispositions']), hasLength(4));
    final repairDisposition = _object(
      currentSource['integratedRepairDisposition'],
    );
    expect(
      repairDisposition['disposition'],
      'PRESERVE_AND_BLOCK_PENDING_REPAIR',
    );
    expect(repairDisposition['malformedField'], 'asset');
    expect(repairDisposition['rawPayloadPreserved'], isTrue);
    expect(repairDisposition['repairStateExposed'], isTrue);
    expect(repairDisposition['authoritativeReadRejected'], isTrue);
    expect(repairDisposition['silentRewritePerformed'], isFalse);

    expect(
      _strings(architecture['A-02']!['requiredExitEvidence']).join(' '),
      contains('machine-generated inventory'),
    );
    expect(
      _strings(architecture['A-03']!['requiredExitEvidence']).join(' '),
      contains('read-only diagnostic adapters'),
    );
    expect(
      _strings(architecture['A-04']!['requiredExitEvidence']).join(' '),
      contains('supported-local-generation inventory'),
    );
    expect(
      _strings(architecture['A-05']!['requiredExitEvidence']).join(' '),
      contains('without advancing a synchronization cursor'),
    );
    expect(
      _strings(architecture['A-05']!['reArmTriggers']).join(' '),
      contains('DateTime.now'),
    );
  });

  test('H2, S-01 and D-01 close only on sealed final authority', () {
    const evidencePath =
        'release/evidence/s01-d01-h2-runtime-identity-live-finalization.json';
    const evidenceSha =
        'B9862804EA98080FC4BCD74DC92717C0D47A3DEE8A8DD5B17F20A23E584FC5FA';

    final payload = _readJson('governance/programme-ledger.json');
    final evidence = _readJson(evidencePath);
    final gates = _objects(payload['programmeGates']);
    final findings = _objects(payload['technicalFindings']);
    final h2 = gates.singleWhere((item) => item['gateId'] == 'H2-IAM');
    final f4 = gates.singleWhere((item) => item['gateId'] == 'STAGE2D-F4');
    final s01 = findings.singleWhere((item) => item['findingId'] == 'S-01');
    final d01 = findings.singleWhere((item) => item['findingId'] == 'D-01');

    expect(_sha256(evidencePath), evidenceSha);
    expect(
      evidence['decision'],
      'PASS_H2_S01_D01_RUNTIME_IDENTITY_AND_DEPENDENCY_CLOSURE',
    );
    expect(
      _object(evidence['sourceAndCiAdjudication'])['status'],
      'PASS_EXACT_HEAD_PULL_REQUEST_CI',
    );

    expect(
      _object(payload['programmeDecision'])['leastPrivilegeIam'],
      'CLOSED_PASS',
    );
    expect(
      _object(payload['programmeDecision'])['nextMutation'],
      'NONE_ALL_PROGRAMME_GATES_CLOSED',
    );
    expect(f4['currentStatus'], 'CLOSED');
    expect(f4['authorization'], 'CLOSED_PASS');
    expect(
      _object(payload['programmeDecision'])['pilotHandout'],
      'AUTHORIZED_EXACT_BUILD11_SEALED_ROSTER',
    );

    for (final record in <Map<String, dynamic>>[h2, s01, d01]) {
      expect(record['currentStatus'], 'CLOSED');
      expect(
        _objects(record['evidence']).map((entry) => entry['sha256']),
        contains(evidenceSha),
      );
    }
    expect(h2['authorization'], 'CLOSED_PASS');
    expect(
      _objects(h2['statusHistory']).map((entry) => entry['status']).toList(),
      <String>['OPEN', 'CLOSED'],
    );
    expect(
      _objects(s01['statusHistory']).map((entry) => entry['status']).toList(),
      <String>['OPEN', 'CLOSED'],
    );
    expect(
      _objects(d01['statusHistory']).map((entry) => entry['status']).toList(),
      <String>['OPEN', 'LIVE_READBACK_PROVED', 'CLOSED'],
    );
  });

  test('Build 5 runtime adjudication closes only P-01 and F3', () {
    const receiptPath = 'release/evidence/build-5-programme-adjudication.json';
    const receiptSha =
        '09031647BA40635350C3E36548CA6030CB0E0672C15C4CDBE538D44E988DC97B';
    const runtimeAdjudicationPath =
        'release/evidence/build-5-runtime-validation-adjudication.json';
    const runtimeAdjudicationSha =
        '5401E163E7B0942B3B4FAFD810A2BE45492666CB8E750ABB54FC0741091FE551';
    const closurePackageSha =
        '4AEBDFC8B1FE378FA8CAB26B6C05CB745250A52CC7CE095CA5987605030A6679';

    expect(_sha256(receiptPath), receiptSha);
    expect(_sha256(runtimeAdjudicationPath), runtimeAdjudicationSha);

    final ledger = _readJson('governance/programme-ledger.json');
    final receipt = _readJson(receiptPath);
    final runtimeAdjudication = _readJson(runtimeAdjudicationPath);
    final gates = _objects(ledger['programmeGates']);
    final findings = _objects(ledger['technicalFindings']);

    final buildAuthority = _object(receipt['build5Authority']);
    expect(
      buildAuthority['sourceCommit'],
      '60dc4688fbbc7127e84c63d7955dab4210555e0d',
    );
    expect(
      _object(buildAuthority['apk'])['sha256'],
      '1A39F9F375D785817862AA86BF3810FB5D99545E1E8BFFB7BA4F3CA69253774C',
    );
    expect(
      _object(buildAuthority['productionSigner'])['certificateSha256'],
      '6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C',
    );
    final releaseBoundary = _object(buildAuthority['releaseBoundary']);
    expect(releaseBoundary['controlledDistributionChannelApproved'], isFalse);
    expect(releaseBoundary['distributionPerformed'], isFalse);

    final p01 = findings.singleWhere((item) => item['findingId'] == 'P-01');
    expect(p01['currentStatus'], 'CLOSED');
    expect(_strings(p01['requiredExitEvidence']), hasLength(4));
    final p01Evidence = _objects(p01['evidence']);
    final p01SourceEvidence = p01Evidence.singleWhere(
      (entry) => entry['sha256'] == receiptSha,
    );
    expect(
      p01SourceEvidence['productionSignedRuntimeGoogleSignInProved'],
      isFalse,
    );
    final p01RuntimeEvidence = p01Evidence.singleWhere(
      (entry) => entry['sha256'] == runtimeAdjudicationSha,
    );
    expect(
      p01RuntimeEvidence['productionSignedRuntimeGoogleSignInProved'],
      isTrue,
    );
    expect(p01RuntimeEvidence['approvedOwnUserRecordProved'], isTrue);
    expect(p01RuntimeEvidence['sourceRemediationMerged'], isTrue);
    expect(
      p01RuntimeEvidence['futurePilotArtifactMustContainRemediation'],
      isTrue,
    );
    expect(
      _objects(
        p01['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>[
        'OPEN',
        'SOURCE_IMPLEMENTED',
        'MERGED',
        'DEPLOYED',
        'DEVICE_PROVED',
        'CLOSED',
      ],
    );
    final p01Adjudication = _object(receipt['p01Adjudication']);
    expect(p01Adjudication['adjudicatedStatus'], 'SOURCE_IMPLEMENTED');
    expect(p01Adjudication['pilotBlockerRemains'], isTrue);
    final runtimeP01Adjudication = _object(
      runtimeAdjudication['p01Adjudication'],
    );
    expect(runtimeP01Adjudication['adjudicatedStatus'], 'CLOSED');
    expect(runtimeP01Adjudication['pilotBlockerRemains'], isFalse);
    expect(_strings(runtimeP01Adjudication['transitionSequence']), <String>[
      'MERGED',
      'DEPLOYED',
      'DEVICE_PROVED',
      'CLOSED',
    ]);

    final f3 = gates.singleWhere((item) => item['gateId'] == 'STAGE2D-F3');
    expect(f3['currentStatus'], 'CLOSED');
    expect(f3['authorization'], 'CLOSED_PASS');
    final f3Evidence = _objects(f3['evidence']);
    final f3SourceEvidence = f3Evidence.singleWhere(
      (entry) => entry['sha256'] == receiptSha,
    );
    expect(f3SourceEvidence['completedExitDimensions'], 2);
    expect(f3SourceEvidence['requiredExitDimensions'], 3);
    expect(f3SourceEvidence['distributionPerformed'], isFalse);
    final f3RuntimeEvidence = f3Evidence.singleWhere(
      (entry) => entry['sha256'] == runtimeAdjudicationSha,
    );
    expect(f3RuntimeEvidence['completedExitDimensions'], 3);
    expect(f3RuntimeEvidence['requiredExitDimensions'], 3);
    expect(f3RuntimeEvidence['controlledDistributionPerformed'], isTrue);
    expect(f3RuntimeEvidence['externalDistributionPerformed'], isFalse);
    expect(f3RuntimeEvidence['pilotHandoutPerformed'], isFalse);
    final f3Adjudication = _object(receipt['stage2dF3Adjudication']);
    final f3Dimensions = _object(f3Adjudication['dimensions']);
    expect(_object(f3Dimensions['signedApkHash'])['status'], 'passed');
    expect(
      _object(f3Dimensions['packageVersionSourceCertificateBinding'])['status'],
      'passed',
    );
    expect(
      _object(f3Dimensions['controlledDistributionChannel'])['status'],
      'open',
    );
    expect(f3Adjudication['pilotHandoutAuthorized'], isFalse);
    final runtimeF3Adjudication = _object(
      runtimeAdjudication['stage2dF3Adjudication'],
    );
    expect(runtimeF3Adjudication['adjudicatedStatus'], 'CLOSED');
    expect(runtimeF3Adjudication['authorization'], 'CLOSED_PASS');
    expect(runtimeF3Adjudication['completedExitDimensions'], 3);
    expect(runtimeF3Adjudication['requiredExitDimensions'], 3);
    expect(runtimeF3Adjudication['controlledDistributionPerformed'], isTrue);
    expect(runtimeF3Adjudication['externalDistributionPerformed'], isFalse);
    expect(runtimeF3Adjudication['pilotHandoutAuthorized'], isFalse);
    expect(
      _object(runtimeF3Adjudication['dimensions']).values.toSet(),
      <String>{'passed'},
    );
    expect(
      _object(runtimeAdjudication['programmeDecision'])['nextMutation'],
      'STAGE2D-F4',
    );
    expect(
      _object(runtimeAdjudication['programmeDecision'])['pilotHandout'],
      'NOT_AUTHORIZED',
    );

    final lr05 = gates.singleWhere((item) => item['gateId'] == 'LR-05');
    expect(lr05['currentStatus'], 'CLOSED');
    expect(lr05['authorization'], 'CLOSED_PASS');
    expect(
      _objects(
        lr05['statusHistory'],
      ).map((entry) => entry['status']).toList(growable: false),
      <String>['OPEN', 'CLOSED'],
    );
    expect(
      _objects(lr05['evidence']).map((entry) => entry['sha256']).toSet(),
      <String>{receiptSha, closurePackageSha},
    );

    final lr05Adjudication = _object(receipt['lr05Adjudication']);
    expect(lr05Adjudication['adjudicatedStatus'], 'CLOSED');
    final approvalOutput = _objects(lr05Adjudication['outputs']).singleWhere(
      (item) => item['file'] == 'github-environment-approvals.json',
    );
    expect(approvalOutput['validJson'], isFalse);
    expect(approvalOutput['authoritativeDerivedCount'], 0);
    final mutationBoundary = _object(lr05Adjudication['mutationBoundary']);
    for (final field in <String>[
      'githubEnvironmentMutationPerformed',
      'githubSecretMutationPerformed',
      'firebaseMutationPerformed',
      'deploymentPerformed',
      'distributionPerformed',
    ]) {
      expect(mutationBoundary[field], isFalse, reason: field);
    }

    final f4 = gates.singleWhere((item) => item['gateId'] == 'STAGE2D-F4');
    expect(f4['currentStatus'], 'CLOSED');
    expect(f4['authorization'], 'CLOSED_PASS');
    expect(_objects(f4['evidence']), hasLength(4));
    expect(
      _objects(f4['statusHistory']).map((entry) => entry['status']),
      <String>['OPEN', 'CLOSED'],
    );
  });

  test('scope severity, deferral and ledger ownership stay aligned', () {
    final ledger = _readJson('governance/programme-ledger.json');
    final scope = _readJson(
      'release/stage2d-f-internal-controlled-deployment-scope.json',
    );
    final s02SourcePolicy = _readJson(
      'release/s02-callable-app-check-source-policy.json',
    );

    final ledgerAuthority = _object(ledger['authority']);
    final scopeAuthority = _object(scope['authority']);
    expect(ledgerAuthority['baselineCommit'], scopeAuthority['baselineCommit']);
    expect(
      ledgerAuthority['scopeDeclarationPath'],
      'release/stage2d-f-internal-controlled-deployment-scope.json',
    );

    final severityVocabulary = _strings(ledger['severityVocabulary']).toSet();
    final attestation = _object(scope['attestation']);
    expect(attestation['trackASeverity'], 'DEFERRED_MEDIUM');
    expect(attestation['trackBSeverity'], 'BLOCKER');
    expect(severityVocabulary, contains(attestation['trackASeverity']));
    expect(severityVocabulary, contains(attestation['trackBSeverity']));

    final scopeTriggerIds =
        _objects(
          scope['reArmTriggers'],
        ).map((item) => item['id'] as String).toSet();
    final sourceTriggerIds =
        _objects(
          s02SourcePolicy['sourceReArmTriggers'],
        ).map((item) => item['id'] as String).toSet();
    final s02 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'S-02');
    expect(s02['currentStatus'], 'DEFERRED');
    expect(
      _strings(s02['reArmTriggers']).toSet(),
      scopeTriggerIds.union(sourceTriggerIds),
    );

    final scopeLedger = _object(scope['programmeLedger']);
    expect(scopeLedger['path'], 'governance/programme-ledger.json');
    expect(scopeLedger['statusOwner'], isTrue);
  });
}
