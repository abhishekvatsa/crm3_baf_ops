import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all workflow Isar schemas are registered in main', () {
    final source = File('lib/main.dart').readAsStringSync();
    for (final schema in [
      'WorkflowAggregateRecordSchema',
      'JobLaneRecordSchema',
      'ComplianceRequestRecordSchema',
      'ComplianceAttemptRecordSchema',
      'EquipmentStatusRecordSchema',
      'EquipmentPromptRecordSchema',
      'WorkflowEventRecordSchema',
      'WorkflowCommandRecordSchema',
      'WorkflowCommandReceiptRecordSchema',
    ]) {
      expect(source, contains(schema));
    }
  });
}
