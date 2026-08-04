import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) {
  return value as Map<String, dynamic>;
}

List<Map<String, dynamic>> _objects(dynamic value) {
  return (value as List<dynamic>).map(_object).toList(growable: false);
}

List<String> _strings(dynamic value) {
  return (value as List<dynamic>).cast<String>();
}

void main() {
  test('R-03 source and CI closure is exact without runtime overclaim', () {
    final ledger =
        jsonDecode(File('governance/programme-ledger.json').readAsStringSync())
            as Map<String, dynamic>;

    final r03 = _objects(
      ledger['technicalFindings'],
    ).singleWhere((item) => item['findingId'] == 'R-03');

    expect(r03['authorityType'], 'SOURCE_AND_CI');
    expect(r03['transitionProfile'], 'SOURCE_AND_CI');
    expect(r03['currentStatus'], 'CLOSED');
    final evidence = _objects(r03['evidence']).single;
    expect(evidence['pullRequest'], 117);
    expect(evidence['headCommit'], '946c414fee7605f590253dc630a0205095f3b44d');
    expect(evidence['mergeCommit'], '45ebd9c853798f88fedd2e4d72d6022dc389097f');
    expect(evidence['pullRequestWorkflowRun'], 30795773566);
    expect(evidence['postMergeWorkflowRun'], 30796250694);
    expect(
      evidence['decision'],
      'PASS_R03_R05_RELIABILITY_SOURCE_AND_CI_CLOSURE',
    );
    expect(evidence['productionDeploymentPerformed'], isFalse);
    expect(evidence['deviceEvidenceClaimed'], isFalse);
    expect(evidence['pilotAuthorizationCreated'], isFalse);
    expect(
      _objects(r03['statusHistory']).map((entry) => entry['status'] as String),
      <String>['OPEN', 'SOURCE_IMPLEMENTED', 'MERGED', 'CLOSED'],
    );

    final receipt =
        jsonDecode(
              File(
                'release/evidence/r03-r05-source-and-ci-closure.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(_strings(receipt['findingIds']), <String>['R-03', 'R-05']);
    expect(receipt['decision'], evidence['decision']);
    expect(_object(receipt['pullRequestCi'])['runId'], 30795773566);
    expect(_object(receipt['pullRequestCi'])['conclusion'], 'success');
    expect(_object(receipt['postMergeCi'])['runId'], 30796250694);
    expect(_object(receipt['postMergeCi'])['conclusion'], 'success');
    final boundary = _object(receipt['closureBoundary']);
    expect(boundary.values, everyElement(isFalse));

    final exitEvidence = _strings(r03['requiredExitEvidence']).join('\n');
    expect(
      exitEvidence,
      contains('distinct succeeded, failed, queued and throttled outcomes'),
    );
    expect(
      exitEvidence,
      contains('exact-head pull-request CI and post-merge CI pass'),
    );

    final notes = _strings(r03['notes']).join('\n');
    expect(
      notes,
      contains(
        'Deferred admission remains non-successful for startup, retry '
        'cancellation and governed publish confirmation',
      ),
    );
    expect(notes, contains('Source-and-CI closure is bound to PR #117'));
  });
}
