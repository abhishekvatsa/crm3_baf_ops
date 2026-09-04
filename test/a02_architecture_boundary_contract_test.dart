import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('A-02 machine inventory is complete and source-enforced', () {
    final result = Process.runSync('python', const <String>[
      'tools/v4/a02_architecture_inventory.py',
    ], workingDirectory: Directory.current.path);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final report = jsonDecode('${result.stdout}') as Map<String, dynamic>;
    expect(report['result'], 'PASS');
    expect(report['findingId'], 'A-02');
    expect(report['hotspotCount'], greaterThanOrEqualTo(1));
    expect(report['failures'], isEmpty);
  });

  test('mixed repositories retain explicit local and remote ownership', () {
    const roots = <String, String>{
      'lib/features/maintenance/providers/maintenance_provider.dart':
          'maintenance_provider',
      'lib/features/abnormalities/providers/abnormality_provider.dart':
          'abnormality_provider',
      'lib/features/directives/providers/operational_directive_provider.dart':
          'operational_directive_provider',
      'lib/features/planned_maintenance/providers/job_diary_provider.dart':
          'job_diary_provider',
      'lib/features/planned_maintenance/providers/job_module_provider.dart':
          'job_module_provider',
      'lib/features/planned_maintenance/providers/planned_maintenance_provider.dart':
          'planned_maintenance_provider',
      'lib/features/planned_maintenance/providers/template_governance_provider.dart':
          'template_governance_provider',
    };

    for (final entry in roots.entries) {
      final root = File(entry.key).readAsStringSync();
      expect(root, contains("part '${entry.value}.local.dart';"));
      expect(root, contains("part '${entry.value}.remote.dart';"));
      expect(root, isNot(contains('class Isar')));
      expect(root, isNot(contains('class Firestore')));

      final directory = File(entry.key).parent.path;
      final local =
          File('$directory/${entry.value}.local.dart').readAsStringSync();
      final remote =
          File('$directory/${entry.value}.remote.dart').readAsStringSync();
      expect(local, contains("part of '${entry.value}.dart';"));
      expect(local, isNot(contains('FirebaseFirestore.instance')));
      expect(remote, contains("part of '${entry.value}.dart';"));
      expect(remote, isNot(contains('writeTxn(')));
    }
  });

  test(
    'quality and abnormality screens keep their extracted UI boundaries',
    () {
      const libraries = <String, List<String>>{
        'lib/features/abnormalities/presentation/charge_abnormalities_screen': [
          'form',
          'widgets',
        ],
        'lib/features/quality/presentation/quality_home_screen': [
          'cards',
          'widgets',
        ],
      };
      for (final entry in libraries.entries) {
        final root = File('${entry.key}.dart').readAsStringSync();
        final name = entry.key.split('/').last;
        for (final suffix in entry.value) {
          expect(root, contains("part '$name.$suffix.dart';"));
        }
        for (final path in [
          '${entry.key}.dart',
          ...entry.value.map((suffix) => '${entry.key}.$suffix.dart'),
        ]) {
          final source = File(path).readAsStringSync();
          expect(
            const LineSplitter().convert(source).length,
            lessThan(1200),
            reason: path,
          );
          expect(
            source,
            isNot(contains('FirebaseFirestore.instance')),
            reason: path,
          );
          expect(source, isNot(contains('Isar.getInstance()')), reason: path);
        }
      }
    },
  );

  test(
    'asset hierarchy administration stays decomposed by UI responsibility',
    () {
      const rootPath =
          'lib/features/admin/presentation/admin_data_browser/'
          'admin_asset_hierarchy_tab.dart';
      final root = File(rootPath).readAsStringSync();
      const parts = <String>[
        'admin_asset_hierarchy_tab.class_dialogs.dart',
        'admin_asset_hierarchy_tab.asset_registry.dart',
        'admin_asset_hierarchy_tab.component_registry.dart',
        'admin_asset_hierarchy_tab.asset_dialog.dart',
        'admin_asset_hierarchy_tab.component_dialog.dart',
        'admin_asset_hierarchy_tab.reason_dialog.dart',
        'admin_asset_hierarchy_tab.toolbar.dart',
      ];
      for (final part in parts) {
        expect(root, contains("part '$part';"));
        final source =
            File('${File(rootPath).parent.path}/$part').readAsStringSync();
        expect(source, contains("part of 'admin_asset_hierarchy_tab.dart';"));
        expect(source.split('\n').length, lessThanOrEqualTo(1200));
      }
      expect(root.split('\n').length, lessThanOrEqualTo(1200));
    },
  );

  test('A-02 policy carries complete evidence-bound dispositions', () {
    final manifest =
        jsonDecode(
              File(
                'governance/a02-architecture-boundaries-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final surfaces =
        (manifest['surfaces'] as List).cast<Map<String, dynamic>>();
    expect(surfaces, isNotEmpty);
    expect(
      surfaces.map((surface) => surface['path']).toSet().length,
      surfaces.length,
    );
    expect(
      surfaces.where((surface) => surface['disposition'] == 'decomposed'),
      isNotEmpty,
    );
    for (final surface in surfaces) {
      expect(surface['owner'], isNotEmpty);
      expect(surface['purpose'], isNotEmpty);
      expect(surface['authorityBoundary'], isNotEmpty);
      expect(surface['persistenceOwnership'], isNotEmpty);
      expect(surface['transactionOwnership'], isNotEmpty);
      expect(surface['rationale'], isNotEmpty);
      expect(surface['regressionTests'], isNotEmpty);
      expect(surface['reArmCondition'], isNotEmpty);
    }
  });
}
