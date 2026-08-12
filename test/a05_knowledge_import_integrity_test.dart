import 'dart:convert';

import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_governance_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('knowledge JSON import rejects a mixed object/scalar bundle', () {
    final summary = KnowledgeGovernanceExport.parse(
      body: jsonEncode({
        'rows': [
          {
            'rowCode': 'VALID-01',
            'taskText': 'Inspect the valid row.',
            'changeSummary': 'A sufficiently detailed import reason.',
          },
          7,
        ],
      }),
      format: KnowledgeBundleFormat.json,
    );

    expect(summary.rowsAccepted, 0);
    expect(summary.rowsRejected, 1);
    expect(summary.rejected.single.rowCode, '<bundle>');
    expect(summary.rejected.single.messages.single, contains('item #2'));
  });
}
