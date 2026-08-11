import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _object(dynamic value) =>
    Map<String, dynamic>.from(value as Map);

List<Map<String, dynamic>> _objects(dynamic value) =>
    (value as List<dynamic>).map(_object).toList(growable: false);

void main() {
  group('C-04 test evidence taxonomy', () {
    final catalog =
        jsonDecode(
              File('governance/test-evidence-taxonomy.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final workflow =
        File('.github/workflows/release-gate.yml').readAsStringSync();
    final localGate = File('release_gate.ps1').readAsStringSync();

    test('levels and critical paths are explicit and evidence-bound', () {
      expect(catalog['schemaVersion'], 1);
      expect(catalog['authority'], 'C04_TEST_EVIDENCE_TAXONOMY');

      final levels = _objects(catalog['levels']);
      expect(levels, hasLength(8));
      final levelById = <String, Map<String, dynamic>>{
        for (final level in levels) level['id'] as String: level,
      };
      expect(levelById.keys, <String>{
        'source_contract',
        'host_unit',
        'host_widget',
        'firebase_emulator',
        'android_package',
        'android_emulator',
        'live_readback',
        'physical_device',
      });
      expect(levelById['physical_device']!['physicalDevice'], isTrue);
      expect(levelById['android_package']!['runtimeExecuted'], isTrue);
      expect(
        levelById['android_package']!['claim'],
        contains('exact release APK cold-start'),
      );
      for (final entry in levelById.entries) {
        if (entry.key != 'physical_device') {
          expect(entry.value['physicalDevice'], isFalse, reason: entry.key);
        }
      }

      final criticalPaths = _objects(catalog['criticalPaths']);
      expect(criticalPaths, hasLength(8));
      expect(
        criticalPaths.map((item) => item['id']).toSet(),
        hasLength(criticalPaths.length),
      );
      for (final criticalPath in criticalPaths) {
        final evidence = _objects(criticalPath['evidence']);
        expect(evidence.length, greaterThanOrEqualTo(2));
        expect(criticalPath['openEvidenceLevels'], isA<List<dynamic>>());
        for (final witness in evidence) {
          final level = witness['level'] as String;
          final path = witness['path'] as String;
          expect(levelById, contains(level), reason: path);
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    });

    test('CI headlines name their actual evidence level', () {
      final jobs = _objects(catalog['ciJobs']);
      expect(jobs, hasLength(5));
      expect(jobs.map((job) => job['id']).toSet(), <String>{
        'flutter_host',
        'android_package',
        'android_emulator',
        'firebase_emulator',
        'functions_host',
      });
      for (final job in jobs) {
        expect(workflow, contains('name: ${job['headline']}'));
      }

      expect(
        workflow,
        contains('Android release package + cold-start proof (non-production)'),
      );
      expect(
        workflow,
        contains(
          'Android emulator app-shell integration '
          '(not physical-device evidence)',
        ),
      );
      expect(
        workflow,
        contains('Cloud Functions host build + non-emulator tests'),
      );
      expect(
        localGate,
        contains('flutter host suite (source contracts + unit + widget)'),
      );
      expect(
        localGate,
        contains('test evidence taxonomy and critical-path coverage'),
      );
    });

    test('Android integration runs with pinned non-production boundaries', () {
      final device = _object(catalog['deviceIntegration']);
      final path = device['path'] as String;
      expect(File(path).existsSync(), isTrue);
      expect(device['ciJob'], 'android_emulator');
      expect(device['productionCredentialsUsed'], isFalse);
      expect(device['productionBackendUsed'], isFalse);
      expect(device['physicalDeviceEvidence'], isFalse);

      const action =
          'ReactiveCircus/android-emulator-runner@'
          'a421e43855164a8197daf9d8d40fe71c6996bb0d';
      expect(workflow, contains(action));
      expect(workflow, contains(path));
      expect(workflow, contains('api-level: 33'));
      final emulatorSections = workflow.split('\n  android-emulator:\n');
      expect(emulatorSections, hasLength(2));
      final emulatorJob =
          emulatorSections.last.split('\n  firestore-rules:\n').first;
      expect(emulatorJob, contains('timeout-minutes: 30'));

      final registry =
          jsonDecode(
                File('release/github-actions-pins.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final actions = _object(registry['actions']);
      final emulator = _object(actions['androidEmulatorRunner']);
      expect(emulator['repository'], 'ReactiveCircus/android-emulator-runner');
      expect(emulator['commitSha'], 'a421e43855164a8197daf9d8d40fe71c6996bb0d');

      final productionPolicy =
          File(
            'tools/release/Test-ProductionReleasePolicy.ps1',
          ).readAsStringSync();
      expect(productionPolicy, isNot(contains('Properties).Count -ne 5')));
      expect(
        productionPolicy,
        contains(r'$requiredProductionActionRepositories'),
      );
      expect(productionPolicy, contains(r'$actionPinsByRepository'));
      expect(productionPolicy, contains(r'$productionActionReferences'));

      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('integration_test:'));
      expect(pubspec, contains('sdk: flutter'));

      final gradleProperties =
          File('android/gradle.properties').readAsStringSync();
      expect(gradleProperties, contains('org.gradle.jvmargs=-Xmx4G'));
      expect(gradleProperties, contains('MaxMetaspaceSize=1G'));
      expect(gradleProperties, contains('org.gradle.workers.max=4'));
      expect(gradleProperties, isNot(contains('-Xmx8G')));
    });
  });
}
