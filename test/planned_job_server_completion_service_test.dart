import 'package:flutter_test/flutter_test.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/services/planned_job_server_completion_service.dart';

void main() {
  group('Issue 63 callable region targeting', () {
    test('uses stable callable name and asia-south1 region for new builds', () {
      expect(plannedJobCompletionCallableName, 'completePlannedJobExecution');
      expect(plannedJobCompletionCallableName, isNot(contains('AsiaSouth1')));
      expect(plannedJobCompletionCallableRegion, 'asia-south1');
    });
  });

  group('PlannedJobServerClosureGateException parsing', () {
    test('parses failed-precondition issues returned by callable', () {
      final error = PlannedJobServerClosureGateException.tryParse(
        code: 'failed-precondition',
        message: 'Cannot complete planned job: modules are not ready.',
        details: {
          'issues': [
            {
              'type': 'openRequiredModule',
              'count': 2,
              'message': '2 required module(s) still open',
              'moduleFirestoreIds': ['module_a', 'module_b'],
            },
            {
              'type': 'missingRequiredEvidence',
              'count': 1,
              'message': '1 required module(s) missing required evidence',
              'moduleFirestoreIds': ['module_c'],
            },
          ],
        },
      );

      expect(error, isNotNull);
      expect(error!.code, 'failed-precondition');
      expect(error.issues, hasLength(2));
      expect(error.issues.first.type, 'openRequiredModule');
      expect(error.issues.first.moduleFirestoreIds, ['module_a', 'module_b']);
      expect(error.operatorMessage, contains('Server closure gate blocked'));
      expect(error.blockingMessage, contains('module_a'));
      expect(error.blockingMessage, contains('missing required evidence'));
    });

    test(
      'does not parse non-gate failed-precondition details as module gate',
      () {
        final error = PlannedJobServerClosureGateException.tryParse(
          code: 'failed-precondition',
          message: 'Local completion version is stale.',
          details: {'currentVersion': 3, 'expectedCompletionVersion': 2},
        );

        expect(error, isNull);
      },
    );

    test('does not parse permission or auth errors as module gate', () {
      final error = PlannedJobServerClosureGateException.tryParse(
        code: 'permission-denied',
        message: 'Not authorized.',
        details: {
          'issues': [
            {'type': 'openRequiredModule', 'count': 1},
          ],
        },
      );

      expect(error, isNull);
    });
  });

  group('PlannedJobServerCompletionException operator messages', () {
    test('maps permission denial to operator-safe text', () {
      const error = PlannedJobServerCompletionException(
        code: 'permission-denied',
        message: 'raw server message',
      );

      expect(
        error.operatorMessage,
        'You are not authorized to complete this planned job.',
      );
      expect(error.toString(), error.operatorMessage);
    });

    test('maps transient server/network codes to retry guidance', () {
      const error = PlannedJobServerCompletionException(
        code: 'unavailable',
        message: 'transport unavailable',
      );

      expect(error.operatorMessage, contains('Check network connectivity'));
    });
  });
}
