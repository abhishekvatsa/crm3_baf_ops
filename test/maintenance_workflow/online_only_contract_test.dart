import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('workflow provider uses online executor rather than direct Firestore writes', () {
    final source = File('lib/features/maintenance_workflow/providers/workflow_providers.dart').readAsStringSync();
    expect(source, contains('WorkflowOnlineExecutor'));
    expect(source, isNot(contains("collection('job_lanes').doc")));
  });
}
