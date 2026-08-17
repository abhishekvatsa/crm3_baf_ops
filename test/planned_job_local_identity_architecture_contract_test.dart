import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/testing/dart_library_source.dart';

void main() {
  group('planned-job local identity architecture contract', () {
    test('Firestore serializers do not transport Isar relation ids', () {
      final moduleModel =
          File(
            'lib/features/planned_maintenance/data/job_module_model.dart',
          ).readAsStringSync();
      final diaryModel =
          File(
            'lib/features/planned_maintenance/data/job_diary_model.dart',
          ).readAsStringSync();
      expect(
        RegExp(r"'jobExecutionLocalId'\s*:").hasMatch(moduleModel),
        isFalse,
      );
      expect(
        RegExp(r"'jobExecutionLocalId'\s*:").hasMatch(diaryModel),
        isFalse,
      );
      expect(
        RegExp(r"'moduleInstanceLocalId'\s*:").hasMatch(diaryModel),
        isFalse,
      );
    });

    test('both UI repository and completion use the shared resolver', () {
      final moduleProvider = readDartLibrarySource(
        'lib/features/planned_maintenance/providers/job_module_provider.dart',
      );
      final plannedProvider = readDartLibrarySource(
        'lib/features/planned_maintenance/providers/planned_maintenance_provider.dart',
      );

      expect(
        'PlannedJobModuleSetResolver.resolve'.allMatches(moduleProvider).length,
        greaterThanOrEqualTo(3),
      );
      expect(plannedProvider, contains('PlannedJobModuleSetResolver.resolve'));
      expect(moduleProvider, contains('_assertNoIdentityAmbiguity'));
      expect(moduleProvider, contains('duplicateCanonicalModules'));
      expect(plannedProvider, contains('unresolved local parent identity'));
    });

    test(
      'background completion preflight supplies both canonical and local parent ids',
      () {
        final syncExecutions =
            File(
              'lib/core/services/sync_service.executions.dart',
            ).readAsStringSync();

        expect(
          syncExecutions,
          contains('jobExecutionFirestoreId: firestoreId'),
        );
        expect(syncExecutions, contains('jobExecutionLocalId: local.id'));
        final completionStart = syncExecutions.indexOf(
          'Future<bool> _syncCompletedExecutionThroughServer',
        );
        expect(completionStart, greaterThanOrEqualTo(0));

        final completionEnd = syncExecutions.indexOf(
          'bool _shouldRebaseRejectedExecutionTombstone',
          completionStart,
        );
        expect(completionEnd, greaterThan(completionStart));

        final completionSource = syncExecutions.substring(
          completionStart,
          completionEnd,
        );

        expect(
          completionSource,
          contains('jobExecutionFirestoreId: firestoreId'),
        );
        expect(completionSource, contains('jobExecutionLocalId: local.id'));
        expect(completionSource, contains('catch (error, stackTrace)'));
        expect(completionSource, contains('_recordPushFailureDetail('));
        expect(completionSource, contains('return false;'));
      },
    );

    test('startup closes Isar if the local-link repair cannot complete', () {
      final mainSource = File('lib/main.dart').readAsStringSync();

      expect(mainSource, contains('await localIsar.close();'));
      expect(mainSource, contains('repairPlannedJobLocalLinks(localIsar)'));
    });

    test('local editable clone explicitly preserves the local-only relation', () {
      final detailScreen =
          File(
            'lib/features/planned_maintenance/presentation/job_module_detail_screen.dart',
          ).readAsStringSync();

      expect(
        detailScreen,
        contains('..jobExecutionLocalId = _module.jobExecutionLocalId'),
      );
    });
  });
}
