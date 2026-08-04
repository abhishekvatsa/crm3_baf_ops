import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('C-06 Android release shrinking', () {
    test('release build enables R8 optimization and resource shrinking', () {
      final build = _read('android/app/build.gradle.kts');

      expect(build, contains('isMinifyEnabled = true'));
      expect(build, contains('isShrinkResources = true'));
      expect(build, contains('proguard-android-optimize.txt'));
      expect(build, contains('"proguard-rules.pro"'));
      expect(build, isNot(contains('isMinifyEnabled = false')));
      expect(build, isNot(contains('isShrinkResources = false')));
    });

    test('app rules do not broadly disable the shrinking pipeline', () {
      final rules = _read('android/app/proguard-rules.pro');
      final broadDisable = RegExp(
        r'^\s*-(dontshrink|dontoptimize|dontobfuscate)\b',
        multiLine: true,
        caseSensitive: false,
      );
      final blanketKeep = RegExp(
        r'^\s*-keep\s+class\s+\*\*',
        multiLine: true,
        caseSensitive: false,
      );

      expect(rules, isNot(matches(broadDisable)));
      expect(rules, isNot(matches(blanketKeep)));
    });

    test('package proof requires fresh nonempty shrinking evidence', () {
      final script = _read('tools/release/Invoke-CIAndroidPackageProof.ps1');

      expect(script, contains('outputs/mapping/release/mapping.txt'));
      expect(script, contains('outputs/mapping/release/resources.txt'));
      expect(script, contains(r'Remove-Item -LiteralPath $path -Force'));
      expect(
        script,
        contains('Expected release-shrinking evidence was not created'),
      );
      expect(script, contains('Release-shrinking evidence is empty'));
      expect(script, contains('r8MappingSha256='));
      expect(script, contains('resourceShrinkReportSha256='));
      expect(script, contains('PASS_C06_ANDROID_RELEASE_SHRINKING_PROOF'));
    });
  });
}
