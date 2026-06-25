import 'package:flutter_test/flutter_test.dart';

import 'package:crm3_baf_ops/features/planned_maintenance/services/runtime_job_module_population_service.dart';

void main() {
  group('runtime module population rejection policy', () {
    test('missing remote parent is deferred, not permanently quarantined', () {
      const error = RuntimeJobModulePopulationException(
        code: 'not-found',
        message: 'Parent not found.',
        reasonCode: 'parent-execution-missing',
      );

      expect(error.isDurableRejection, isFalse);
      expect(error.shouldRetryImmediately, isFalse);
      expect(error.operatorMessage, contains('preserved locally'));
    });

    test('completed parent is a durable operator-resolution boundary', () {
      const error = RuntimeJobModulePopulationException(
        code: 'failed-precondition',
        message: 'Parent complete.',
        reasonCode: 'parent-execution-completed',
      );

      expect(error.isDurableRejection, isTrue);
      expect(error.shouldRetryImmediately, isFalse);
      expect(error.operatorMessage, contains('already completed remotely'));
    });

    test('transport outage retries now without becoming a permanent hold', () {
      const error = RuntimeJobModulePopulationException(
        code: 'unavailable',
        message: 'Service unavailable.',
      );

      expect(error.isDurableRejection, isFalse);
      expect(error.shouldRetryImmediately, isTrue);
      expect(error.operatorMessage, contains('Check connectivity'));
    });

    test('local identity defect is a durable rejection', () {
      const error = RuntimeJobModulePopulationException(
        code: 'invalid-argument',
        message: 'Module identity missing.',
        reasonCode: 'local-module-identity-missing',
      );

      expect(error.isDurableRejection, isTrue);
      expect(error.shouldRetryImmediately, isFalse);
      expect(error.operatorMessage, contains('no remote identity'));
    });

    test('invalid server envelope is held instead of retried', () {
      const error = RuntimeJobModulePopulationException(
        code: 'internal',
        message: 'Malformed response.',
        reasonCode: 'invalid-server-response',
      );

      expect(error.isDurableRejection, isTrue);
      expect(error.shouldRetryImmediately, isFalse);
      expect(
        error.operatorMessage,
        contains('invalid population-mutation response'),
      );
    });

    test('population metadata corruption is surfaced as controlled repair', () {
      const error = RuntimeJobModulePopulationException(
        code: 'data-loss',
        message: 'Population schema invalid.',
        reasonCode: 'module-population-schema-version-invalid',
      );

      expect(error.isDurableRejection, isTrue);
      expect(error.operatorMessage, contains('controlled repair'));
    });

    test(
      'parent population-version regression is a durable controlled-repair boundary',
      () {
        const error = RuntimeJobModulePopulationException(
          code: 'data-loss',
          message: 'Parent revision regressed.',
          reasonCode: 'parent-population-version-regressed',
        );

        expect(error.isDurableRejection, isTrue);
        expect(error.shouldRetryImmediately, isFalse);
        expect(error.operatorMessage, contains('controlled repair'));
      },
    );

    test(
      'actor provenance mismatch is explained as controlled preservation',
      () {
        const error = RuntimeJobModulePopulationException(
          code: 'permission-denied',
          message: 'Actor mismatch.',
          reasonCode: 'module-actor-preservation-role-required',
        );

        expect(error.isDurableRejection, isTrue);
        expect(
          error.operatorMessage,
          contains('controlled supervisor preservation'),
        );
      },
    );
  });
}
