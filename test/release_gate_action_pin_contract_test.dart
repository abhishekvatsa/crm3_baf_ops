import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release gate uses only registry-approved full-length action SHAs', () {
    final registry =
        jsonDecode(File('release/github-actions-pins.json').readAsStringSync())
            as Map<String, dynamic>;
    final actions = registry['actions'] as Map<String, dynamic>;
    final expectedByRepository = <String, String>{
      for (final entry in actions.entries)
        (entry.value as Map<String, dynamic>)['repository'] as String:
            (entry.value as Map<String, dynamic>)['commitSha'] as String,
    };

    final workflow =
        File('.github/workflows/release-gate.yml').readAsStringSync();
    final usesPattern = RegExp(
      r'^\s*-?\s*uses:\s*([^@\s]+)@([^\s#]+)\s*$',
      multiLine: true,
    );
    final useMatches = usesPattern.allMatches(workflow).toList(growable: false);
    expect(useMatches, isNotEmpty);

    for (final match in useMatches) {
      final repository = match.group(1)!;
      final reference = match.group(2)!;
      if (repository.startsWith('./')) continue;

      expect(
        reference,
        matches(RegExp(r'^[0-9a-f]{40}$')),
        reason: '$repository must use an exact 40-character lowercase SHA',
      );
      expect(
        expectedByRepository,
        contains(repository),
        reason: '$repository is not governed by github-actions-pins.json',
      );
      expect(
        reference,
        expectedByRepository[repository],
        reason: '$repository differs from its governed registry authority',
      );
    }
  });
}
