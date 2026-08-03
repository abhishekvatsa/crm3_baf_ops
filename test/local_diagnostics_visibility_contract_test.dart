import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('66D local diagnostics visibility contract', () {
    test('More exposes support diagnostics directly for authorized users', () {
      final source = File('lib/home_screen.dart').readAsStringSync();

      expect(source, contains('local_diagnostics_screen.dart'));
      expect(source, contains('onLocalDiagnostics'));
      expect(source, contains('const LocalDiagnosticsScreen()'));
      expect(source, contains("title: 'Administration and support'"));
      expect(source, contains("title: 'Support diagnostics'"));
      expect(source, contains('appUser.canViewMaintenanceWorkflowDiagnostics'));
    });

    test(
      'Local diagnostics reports runtime support and governance context',
      () {
        final source =
            File(
              'lib/features/admin/presentation/local_diagnostics_screen.dart',
            ).readAsStringSync();

        expect(source, contains('LocalDiagnosticsSupportSnapshot'));
        expect(source, contains('syncRunHealthProvider'));
        expect(source, contains('syncStatusProvider'));
        expect(source, contains('plannedJobCompletionCallableName'));
        expect(source, contains('plannedJobCompletionCallableRegion'));
        expect(
          source,
          contains('DefaultFirebaseOptions.currentPlatform.projectId'),
        );
        expect(
          source,
          contains('DefaultFirebaseOptions.currentPlatform.storageBucket'),
        );
        expect(source, contains('firebaseStorageBucket'));
        expect(source, contains('syncSkippedSummary'));
        expect(source, contains('syncRunCounterSummary'));
        expect(source, contains('syncFailureDetailSummary'));
        expect(source, contains("title: 'Runtime support context'"));
        expect(source, contains("label: 'Storage bucket'"));
        expect(source, contains("label: 'Failure details'"));
        expect(source, contains("title: 'Template governance inventory'"));
        expect(source, contains('LocalGovernanceDiagnosticsSummary'));
        expect(source, contains('Firestore-only governance source'));
      },
    );

    test('Diagnostics remains read-only and Admin/SI-gated', () {
      final source =
          File(
            'lib/features/admin/presentation/local_diagnostics_screen.dart',
          ).readAsStringSync();

      expect(source, contains('actor.canManageTemplateGovernance'));
      expect(source, contains('Admin/SI access required'));
      expect(
        source,
        contains(
          'This screen does not sync, reset, delete, or mark anything clean.',
        ),
      );
      expect(source, contains('Create recovery package'));
      expect(source, contains('Copy diagnostics'));
      expect(source, isNot(contains('runFullSync(')));
    });
  });
}
