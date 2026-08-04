import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

List<String> _strings(dynamic value) => (value as List<dynamic>).cast<String>();

String _sha256(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString().toUpperCase();

void main() {
  test('C-06 closes on exact PR and main shrinking evidence', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;
    final finding = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'C-06');

    expect(finding['authorityType'], 'SOURCE_AND_CI');
    expect(finding['transitionProfile'], 'SOURCE_AND_CI');
    expect(finding['currentStatus'], 'CLOSED');
    expect(
      _objects(
        finding['statusHistory'],
      ).map((entry) => entry['status'] as String),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );

    final ledgerEvidence = _objects(finding['evidence']).single;
    expect(ledgerEvidence['pullRequest'], 152);
    expect(
      ledgerEvidence['headCommit'],
      '6af4bd411a15611f790138c38e35f3918e9f807d',
    );
    expect(
      ledgerEvidence['sourceTree'],
      'b6c0129e14107d09ea8ffd822b305af177824691',
    );
    expect(
      ledgerEvidence['mergeCommit'],
      'cacab29a5cf79bdc723a80b9e4a33557f7a1eada',
    );
    expect(ledgerEvidence['mergeTree'], ledgerEvidence['sourceTree']);
    expect(ledgerEvidence['pullRequestWorkflowRun'], 30942169313);
    expect(ledgerEvidence['pullRequestAndroidJob'], 92103071831);
    expect(ledgerEvidence['postMergeWorkflowRun'], 30942876995);
    expect(ledgerEvidence['postMergeAndroidJob'], 92105447536);
    expect(ledgerEvidence['deviceEvidenceClaimed'], isFalse);
    expect(
      ledgerEvidence['decision'],
      'PASS_C06_ANDROID_RELEASE_SHRINKING_SOURCE_AND_CI_CLOSURE',
    );

    final evidencePath = ledgerEvidence['evidenceFile'] as String;
    expect(_sha256(evidencePath), ledgerEvidence['evidenceSha256']);
    final evidence =
        jsonDecode(File(evidencePath).readAsStringSync())
            as Map<String, dynamic>;
    expect(evidence['findingId'], 'C-06');
    expect(
      evidence['decision'],
      'PASS_C06_ANDROID_RELEASE_SHRINKING_SOURCE_AND_CI_CLOSURE',
    );

    final sourceControls = _object(evidence['sourceControls']);
    for (final key in <String>[
      'androidReleaseBuild',
      'proguardRules',
      'packageProof',
      'contractTest',
    ]) {
      final control = _object(sourceControls[key]);
      expect(_sha256(control['path'] as String), control['sha256']);
    }

    final pullRequestCi = _object(evidence['pullRequestCi']);
    expect(pullRequestCi['runId'], 30942169313);
    expect(pullRequestCi['event'], 'pull_request');
    expect(
      pullRequestCi['headSha'],
      '6af4bd411a15611f790138c38e35f3918e9f807d',
    );
    expect(pullRequestCi['conclusion'], 'success');

    final postMergeCi = _object(evidence['postMergeCi']);
    expect(postMergeCi['runId'], 30942876995);
    expect(postMergeCi['event'], 'push');
    expect(postMergeCi['headSha'], 'cacab29a5cf79bdc723a80b9e4a33557f7a1eada');
    expect(postMergeCi['conclusion'], 'success');

    for (final section in <Map<String, dynamic>>[pullRequestCi, postMergeCi]) {
      final jobs = _objects(section['jobs']);
      expect(jobs, hasLength(4));
      expect(jobs.map((job) => job['conclusion']).toSet(), <String>{'success'});

      final markers = _object(section['androidProofMarkers']);
      expect(markers['decision'], 'PASS_C06_ANDROID_RELEASE_SHRINKING_PROOF');
      expect(markers['applicationId'], 'in.co.sail.bsl.crm3.bafops');
      expect(
        markers['r8MappingSha256'],
        '21832BEEC5CD7E812C3559B4CBCDE950A3B9B760A2986217EDAE5B17CEF1E39F',
      );
      expect(markers['resourceShrinkReportSha256'], hasLength(64));
      expect(markers['productionCertificateUsed'], isFalse);
      expect(markers['productionSecretsReferenced'], isFalse);
      expect(markers['artifactUploadPerformed'], isFalse);
    }

    for (final key in <String>['nonProductionBoundary', 'runtimeBoundary']) {
      final boundary = _object(evidence[key]);
      expect(boundary, isNotEmpty);
      for (final value in boundary.values) {
        expect(value, isFalse);
      }
    }

    expect(_strings(finding['requiredExitEvidence']), hasLength(4));
    expect(_strings(finding['reArmTriggers']).length, greaterThanOrEqualTo(8));
    expect(
      _strings(finding['notes']).join('\n'),
      contains('does not mutate Build 8'),
    );

    final decision =
        File(
          'docs/v4_2_r1/C06_ANDROID_RELEASE_SHRINKING.md',
        ).readAsStringSync();
    expect(decision, contains('Status: CLOSED'));
    expect(decision, contains('PR #152'));
    expect(decision, contains('30942169313'));
    expect(decision, contains('30942876995'));
    expect(
      decision,
      contains('PASS_C06_ANDROID_RELEASE_SHRINKING_SOURCE_AND_CI_CLOSURE'),
    );
    expect(decision, contains('pilot handout:'));
    expect(decision, contains('prohibited'));
  });
}
