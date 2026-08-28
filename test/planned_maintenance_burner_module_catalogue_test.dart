import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_module_catalogue_seed.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_module_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'burner modules preserve investigation, manufacture and installation roles',
    () {
      final instrumentation = BafModuleCatalogueSeed.byCode('F-03');
      final mechanical = BafModuleCatalogueSeed.byCode('F-03M');

      expect(instrumentation, isNotNull);
      expect(
        instrumentation!.defaultDiscipline,
        JobModuleDiscipline.instrumentation,
      );
      expect(mechanical, isNotNull);
      expect(mechanical!.defaultDiscipline, JobModuleDiscipline.mechanical);
      expect(
        mechanical.fields
            .singleWhere((field) => field.fieldId == 'burnerBlockChanged')
            .required,
        isTrue,
      );
      expect(
        mechanical.standardItems.map((item) => item.title).join(' '),
        contains('governed Replacement component action'),
      );
      expect(
        mechanical.fields
            .singleWhere((field) => field.fieldId == 'supplyRoute')
            .options,
        containsAll(<String>['SAIL-made by RED', 'Purchased']),
      );
      expect(BafModuleCatalogueSeed.seedVersion, 'manualCatalogueV0_3');
    },
  );
}
