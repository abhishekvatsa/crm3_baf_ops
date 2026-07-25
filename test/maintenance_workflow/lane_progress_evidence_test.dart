import 'package:crm3_baf_ops/features/maintenance_workflow/domain/lane_progress_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acknowledgement alone does not protect a lane', () {
    const evidence = LaneProgressEvidence(acknowledged: true);
    expect(evidence.mayRemove, isTrue);
  });

  test('any substantive evidence requires termination', () {
    expect(const LaneProgressEvidence(hasModuleWork: true).mustTerminate, isTrue);
    expect(const LaneProgressEvidence(hasDiaryEntry: true).mustTerminate, isTrue);
    expect(const LaneProgressEvidence(hasComplianceLink: true).mustTerminate, isTrue);
  });
}
