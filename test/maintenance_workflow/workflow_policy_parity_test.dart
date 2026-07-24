import 'dart:convert';
import 'dart:io';

import 'package:crm3_baf_ops/features/maintenance_workflow/domain/workflow_policy_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated Dart policy matches canonical JSON manifest', () {
    final file = File('governance/maintenance_workflow_policy_v1.json');
    if (!file.existsSync()) return;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(json['schemaVersion'], WorkflowPolicyGenerated.schemaVersion);
    expect(Set<String>.from(json['redApplicableAssetTypes'] as List), WorkflowPolicyGenerated.redApplicableAssetTypes);
    expect((json['lanes'] as List).length, WorkflowPolicyGenerated.lanes.length);
  });
}
