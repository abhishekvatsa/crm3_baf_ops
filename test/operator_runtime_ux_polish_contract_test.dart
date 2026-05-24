import 'dart:io';

import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/runtime_module_lineage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Operator runtime UX polish contract', () {
    test('module cards use operator-facing closure and sync labels', () {
      final source =
          File(
            'lib/features/planned_maintenance/presentation/widgets/job_module_card.dart',
          ).readAsStringSync();

      expect(source, contains("label: 'Closure-critical'"));
      expect(
        source,
        contains('Closure-critical module has no structured responses yet.'),
      );
      expect(
        source,
        contains("label: synced ? 'Remote-backed / synced' : 'Saved locally'"),
      );
      expect(source, contains("label: 'Source'"));
      expect(source, contains('RuntimeModuleLineageInfo.fromModule'));
      expect(source, isNot(contains("label: 'Required for closure'")));
      expect(
        source,
        isNot(contains('Required module has no structured responses yet')),
      );
    });

    test('module and job detail screens distinguish local save from remote sync', () {
      final moduleDetail =
          File(
            'lib/features/planned_maintenance/presentation/job_module_detail_screen.dart',
          ).readAsStringSync();
      final jobDetail =
          File(
            'lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart',
          ).readAsStringSync();
      final closedDossier =
          File(
            'lib/features/planned_maintenance/presentation/dossier/planned_job_detail_common.dart',
          ).readAsStringSync();

      for (final source in [moduleDetail, jobDetail, closedDossier]) {
        expect(source, contains('Remote-backed / synced'));
        expect(source, contains('Saved locally · pending sync'));
        expect(source, isNot(contains('Synced / remote-backed')));
      }
    });

    test('active runtime add copy separates governed and emergency sources', () {
      final jobDetail =
          File(
            'lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart',
          ).readAsStringSync();
      final dossier =
          File(
            'lib/features/planned_maintenance/presentation/dossier/planned_job_module_dossier.dart',
          ).readAsStringSync();

      expect(jobDetail, contains('Added published governed module'));
      expect(jobDetail, contains('Added Emergency/manual seed module'));
      expect(
        dossier,
        contains('Preferred source: published TemplateVersion catalogue'),
      );
      expect(dossier, contains('Use Emergency/manual seed only as fallback'));
      expect(
        dossier,
        contains('not from the published governed TemplateVersion'),
      );
      expect(dossier, contains("_InfoPair('Closure-critical'"));
    });

    test('dossier module source display reuses central runtime lineage helper', () {
      final detailSource =
          File(
            'lib/features/planned_maintenance/presentation/planned_job_detail_screen.dart',
          ).readAsStringSync();
      final dossierSource =
          File(
            'lib/features/planned_maintenance/presentation/dossier/planned_job_module_dossier.dart',
          ).readAsStringSync();

      expect(
        detailSource,
        contains("import '../domain/runtime_module_lineage.dart';"),
      );
      expect(dossierSource, contains('RuntimeModuleLineageInfo.fromModule'));
      expect(
        dossierSource,
        contains('RuntimeModuleLineageSource.emergencyManualSeed'),
      );
      expect(
        dossierSource,
        contains(
          'RuntimeModuleLineageSource.publishedTemplateVersionRuntimeAdd',
        ),
      );
      expect(
        dossierSource,
        contains('RuntimeModuleLineageSource.manualRuntimeAdd'),
      );
      expect(dossierSource, isNot(contains('_decodeModuleJsonObject')));
    });

    test(
      'manual runtime additions are clearly not treated as governed sources',
      () {
        final module =
            JobModuleInstance()
              ..moduleCode = 'MAN-66G'
              ..moduleTitle = 'Operator-added follow-up check'
              ..addedDuringExecution = true
              ..addReason = 'Unexpected condition found during execution';

        final info = RuntimeModuleLineageInfo.fromModule(module);

        expect(info.source, RuntimeModuleLineageSource.manualRuntimeAdd);
        expect(info.isGovernedPublishedSource, isFalse);
        expect(info.isEmergencyManualFallback, isFalse);
        expect(info.badgeLabel, 'Manual runtime add');
        expect(info.warning, contains('confirm provenance'));
        expect(info.summary, contains('Unexpected condition'));
      },
    );

    test(
      'operator-facing dossier copy distinguishes manual and fallback provenance',
      () {
        final dossierSource =
            File(
              'lib/features/planned_maintenance/presentation/dossier/planned_job_module_dossier.dart',
            ).readAsStringSync();

        expect(dossierSource, contains('Manual runtime addition'));
        expect(dossierSource, contains('Legacy/manual module'));
        expect(
          dossierSource,
          contains('without governed source metadata; confirm provenance'),
        );
        expect(
          dossierSource,
          contains('not from the published governed TemplateVersion'),
        );
        expect(dossierSource, contains('Published governed runtime addition'));
      },
    );
  });
}
