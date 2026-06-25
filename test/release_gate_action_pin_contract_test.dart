import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'release gate and action registry are exact, unique, SHA-pinned peers',
    () {
      final registryText =
          File('release/github-actions-pins.json').readAsStringSync();
      final registry = jsonDecode(registryText) as Map<String, dynamic>;
      final actions = registry['actions'] as Map<String, dynamic>;

      final registryRepositories = <String>[];
      final expectedByRepository = <String, String>{};
      for (final entry in actions.entries) {
        final value = entry.value as Map<String, dynamic>;
        final repository = value['repository'] as String;
        final commitSha = value['commitSha'] as String;

        expect(
          commitSha,
          matches(RegExp(r'^[0-9a-f]{40}$')),
          reason:
              '${entry.key} ($repository) must use an exact 40-character '
              'lowercase SHA',
        );
        expect(
          expectedByRepository,
          isNot(contains(repository)),
          reason:
              '$repository appears more than once in '
              'github-actions-pins.json',
        );

        registryRepositories.add(repository);
        expectedByRepository[repository] = commitSha;
      }
      expect(expectedByRepository, isNotEmpty);

      final workflow =
          File('.github/workflows/release-gate.yml').readAsStringSync();
      final usesPattern = RegExp(
        r'^\s*-?\s*uses:\s*([^@\s]+)@([^\s#]+)\s*$',
        multiLine: true,
      );
      final useMatches = usesPattern
          .allMatches(workflow)
          .toList(growable: false);
      expect(useMatches, isNotEmpty);

      final usedRemoteRepositories = <String>{};
      for (final match in useMatches) {
        final repository = match.group(1)!;
        final reference = match.group(2)!;
        if (repository.startsWith('./')) continue;

        usedRemoteRepositories.add(repository);
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

      expect(
        usedRemoteRepositories,
        equals(expectedByRepository.keys.toSet()),
        reason:
            'The release gate and github-actions-pins.json must contain the '
            'same remote action repositories',
      );
      expect(
        registryRepositories.toSet().length,
        registryRepositories.length,
        reason: 'Action registry repositories must be unique',
      );
    },
  );
}
