import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing governed file: $path');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
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
    expect(decision['internalControlledPilot'], 'GO_WITH_GATES');
    expect(decision['pilotHandout'], 'NOT_AUTHORIZED');
    expect(decision['playIntegrityAndAppCheck'], 'GOVERNED_DEFERRAL');
    expect(decision['leastPrivilegeIam'], 'ACTIVE_INDEPENDENT_TRACK');
    expect(decision['broadFeatureExpansion'], 'HOLD');
    expect(decision['unrestrictedDistribution'], 'NO_GO');
    expect(decision['nextMutation'], 'STAGE2D-F3');

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

  test('scope severity, deferral and ledger ownership stay aligned', () {
    final ledger = _readJson('governance/programme-ledger.json');
    final scope = _readJson(
      'release/stage2d-f-internal-controlled-deployment-scope.json',
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
    final s02 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'S-02');
    expect(s02['currentStatus'], 'DEFERRED');
    expect(_strings(s02['reArmTriggers']).toSet(), scopeTriggerIds);

    final scopeLedger = _object(scope['programmeLedger']);
    expect(scopeLedger['path'], 'governance/programme-ledger.json');
    expect(scopeLedger['statusOwner'], isTrue);
  });
}
