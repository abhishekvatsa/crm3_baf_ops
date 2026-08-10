import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(Object? value) => value as Map<String, dynamic>;

List<Map<String, dynamic>> _objects(Object? value) =>
    (value as List<dynamic>).cast<Map<String, dynamic>>();

List<String> _strings(Object? value) => (value as List<dynamic>).cast<String>();

Map<String, dynamic> _readJson(String path) =>
    _object(jsonDecode(File(path).readAsStringSync()));

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  const adjudicationPath =
      'release/evidence/build-8-f4-authority-negative-adjudication.json';
  const adjudicationSha =
      '9FF79718C48C3B169C512433FED292FA69EA1A6BDBF9183EA7036E8EC9B78461';

  test(
    'authority-negative adjudication binds the complete receipt lineage',
    () {
      final adjudication = _readJson(adjudicationPath);

      expect(_sha256(adjudicationPath), adjudicationSha);
      expect(
        adjudication['decision'],
        'PASS_BUILD8_F4_AND_P07_DEVICE_EVIDENCE_CLOSURE',
      );

      final source = _object(adjudication['sourceAuthority']);
      expect(
        source['campaignSourceCommit'],
        '56dfe3b5c3c5a9903a13008f1836d819a93422bf',
      );
      expect(
        source['promotionSha256'],
        '32246DD50AAA790AC89FAFE26F687C18BAB9F7A28B4E76C3BE8213B3B9A6BCBE',
      );
      expect(
        source['collectorSha256'],
        'F3E4F998C086442696BE859A33247CDDAFDD761AB4619AB471E015086452970D',
      );
      expect(source['externalEvidencePathRetained'], isFalse);
      expect(source['externalEvidenceDirectoryRetained'], isFalse);

      final prerequisites = _objects(
        adjudication['priorCriterionAdjudications'],
      );
      expect(prerequisites, hasLength(3));
      expect(prerequisites.map((record) => record['sha256']).toSet(), <String>{
        'A165DFD44ED2B2BE9DDC27F20D4D982585EA7C0DC5749915BEE1C545DFAB5F5C',
        '95A5B0C0524B98104E47A69EDA1EFC7D827D9A5E8125042F83C20A742D7A0394',
        '45B90B3F0C3D711FEA82B3514669B0C25FEDD2EF320AF4872EC8B102535678F6',
      });

      final campaign = _object(adjudication['successfulCampaign']);
      expect(campaign['attempt'], 9);
      expect(campaign['receiptCount'], 5);
      final receipts = _objects(campaign['receipts']);
      expect(receipts.map((record) => record['phase']).toList(), <String>[
        'Preflight',
        'CaptureRevoked',
        'CaptureRevocationRestored',
        'CaptureWrongRole',
        'CaptureFinalRestoration',
      ]);
      expect(receipts.map((record) => record['sha256']).toList(), <String>[
        'EB1CB909ADC2FA9700D76F377FC73FF5C14D204FB8F130C3E6ACAEF05248141F',
        '53C986827A331B29E95AD8C120AB88EE6951D694011696652F728D051F2D33DA',
        'E389AF6C6A2364151A2079A279A320560205D606C939E7F06824089D167D0D27',
        '6C676003484A2BF0F13A4C1FB62C29864D3BBA83776C274F27130DE6BF3D0B5A',
        '14DBA5CDE999B16DDD2491D56ABA646D6264FA0CB18047403A60C325601B53A1',
      ]);
      final chain = _object(campaign['chainAdjudication']);
      for (final value in chain.values) {
        expect(value, isTrue);
      }

      final failures = _object(adjudication['failedClosedLineage']);
      expect(failures['receiptCount'], 8);
      expect(failures['failedAttemptsRelabelledPass'], isFalse);
      final failedReceipts = _objects(failures['receipts']);
      expect(failedReceipts, hasLength(8));
      expect(failedReceipts.map((record) => record['sha256']).toSet(), <String>{
        '12DC4B94BCA3B2E85967DC746113BE1CC4F38AE8D635742EAFE33607998AFC5D',
        'ABE688E35F98C931A2E72A4258D2EF038ABB9FD1682E73192836EF50FC6A91CD',
        '5B6A8199DEC253FD32DF126FD569DF3067A1D7707F6F4C83896D5883746F4CDF',
        '07305CFFFE2D401426742C3B3DF6F526EC53B28D865CDA629D9E54D38B81A74E',
        'F6211984C1CEA1680722C5730B5D933CA6FE573988C12FE3D8A8AAA5924038A5',
        '051247161A46A3902CBA11048C6036D6E7E7FB9CEB3BAC29D8E2C8240F14F151',
        '64E1F7FC95D27C5ECBDF72F9DA3E3C692FDDA6823BA737880F968F9F0B3C39A2',
        '00A4572B4B729B16CD4F687B58FEEA6C50159F527327D1E5B84FC88B814F4016',
      });
      final attempt7 = failedReceipts.singleWhere(
        (record) => record['attempt'] == 7,
      );
      expect(attempt7['authorityMutationOccurred'], isTrue);
      expect(attempt7['restorationRequired'], isTrue);
      expect(attempt7['restorationVerifiedBeforeNextMutation'], isTrue);
      expect(failures['successfulAttemptStartedFromRestoredPreimage'], isTrue);
    },
  );

  test('all six F4 criteria close only F4 and P-07', () {
    final adjudication = _readJson(adjudicationPath);
    final criteria = _objects(adjudication['criterionAdjudication']);
    expect(criteria, hasLength(6));
    expect(criteria.map((record) => record['criterion']).toList(), <String>[
      'approved sign-in',
      'sync marker',
      'offline/reconnect',
      'weak-network',
      'revocation next-operation denial',
      'wrong-role denials',
    ]);
    expect(criteria.every((record) => record['status'] == 'PROVED'), isTrue);

    final authority = _object(adjudication['authorityTransitionAdjudication']);
    expect(_strings(authority['initialRoleProfile']), <String>['si']);
    expect(authority['revocationDeniedNextOperation'], isTrue);
    expect(authority['revocationRestoredExactlyBeforeContinuation'], isTrue);
    expect(_strings(authority['wrongRoleProfile']), <String>['operations']);
    expect(authority['siOnlyAndAdminSurfacesAbsentUnderWrongRole'], isTrue);
    expect(authority['livePhysicalMutationDenialClaimed'], isFalse);
    expect(authority['syntheticProductionMutationAttempted'], isFalse);
    expect(authority['finalApprovalRestored'], isTrue);
    expect(_strings(authority['finalRoleProfile']), <String>['si']);
    expect(authority['sameProcessAcrossEntireCampaign'], isTrue);
    expect(authority['operatorRemainedApprovedAdmin'], isTrue);

    final transition = _object(adjudication['programmeTransition']);
    expect(transition['stage2dF4'], 'OPEN_TO_CLOSED');
    expect(transition['p07'], 'OPEN_TO_CLOSED');
    expect(transition['completedCriteria'], 6);
    expect(transition['requiredCriteria'], 6);
    expect(transition['nextMutation'], 'STAGE2D-F5');
    expect(transition['stage2dF5Status'], 'OPEN');
    expect(transition['pilotHandout'], 'NOT_AUTHORIZED');

    final ledger = _readJson('governance/programme-ledger.json');
    final decision = _object(ledger['programmeDecision']);
    final gates = _objects(ledger['programmeGates']);
    final findings = _objects(ledger['technicalFindings']);
    final f4 = gates.singleWhere((record) => record['gateId'] == 'STAGE2D-F4');
    final f5 = gates.singleWhere((record) => record['gateId'] == 'STAGE2D-F5');
    final p07 = findings.singleWhere((record) => record['findingId'] == 'P-07');

    expect(decision['nextMutation'], 'STAGE2D-F5');
    expect(decision['pilotHandout'], 'NOT_AUTHORIZED');
    expect(f4['currentStatus'], 'CLOSED');
    expect(f4['authorization'], 'CLOSED_PASS');
    expect(_objects(f4['evidence']), hasLength(4));
    expect(
      _objects(f4['evidence']).map((record) => record['sha256']),
      contains(adjudicationSha),
    );
    expect(_strings(f4['reArmTriggers']), hasLength(6));
    expect(
      _objects(f4['statusHistory']).map((record) => record['status']).toList(),
      <String>['OPEN', 'CLOSED'],
    );

    expect(f5['currentStatus'], 'OPEN');
    expect(f5['authorization'], 'BLOCKS_PILOT_HANDOUT');
    expect(p07['currentStatus'], 'CLOSED');
    expect(_objects(p07['evidence']), hasLength(1));
    expect(_objects(p07['evidence']).single['sha256'], adjudicationSha);
    expect(_strings(p07['requiredExitEvidence']), hasLength(6));
    expect(_strings(p07['reArmTriggers']), hasLength(6));
    expect(
      _objects(p07['statusHistory']).map((record) => record['status']).toList(),
      <String>['OPEN', 'CLOSED'],
    );

    final result =
        File(
          'docs/v4_2_r1/BUILD8_F4_AUTHORITY_NEGATIVE_RESULT.md',
        ).readAsStringSync();
    expect(result, contains('F4 AND P-07 DEVICE EVIDENCE CLOSED'));
    expect(result, contains('all eight failed-closed receipts'));
    expect(result, contains('Pilot handout remains `NOT_AUTHORIZED`'));
    expect(result, contains('`STAGE2D-F5`, which remains open'));
  });
}
