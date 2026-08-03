import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _normalizedPath(File file) => file.absolute.path.replaceAll('\\', '/');

void main() {
  test('lib has no internal Dart import cycles', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList(growable: false);
    final knownPaths = files.map(_normalizedPath).toSet();
    final graph = <String, Set<String>>{
      for (final file in files) _normalizedPath(file): <String>{},
    };
    final importPattern = RegExp(
      r'''^\s*import\s+['"]([^'"]+)['"]''',
      multiLine: true,
    );

    for (final file in files) {
      final source = file.readAsStringSync();
      final sourcePath = _normalizedPath(file);
      for (final match in importPattern.allMatches(source)) {
        final uri = match.group(1)!;
        late final File target;
        if (uri.startsWith('package:crm3_baf_ops/')) {
          target = File('lib/${uri.substring('package:crm3_baf_ops/'.length)}');
        } else if (!uri.contains(':')) {
          target = File.fromUri(file.absolute.uri.resolve(uri));
        } else {
          continue;
        }
        final targetPath = _normalizedPath(target);
        if (knownPaths.contains(targetPath)) {
          graph[sourcePath]!.add(targetPath);
        }
      }
    }

    var nextIndex = 0;
    final indices = <String, int>{};
    final lowLinks = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final cycles = <List<String>>[];

    void visit(String node) {
      indices[node] = nextIndex;
      lowLinks[node] = nextIndex;
      nextIndex += 1;
      stack.add(node);
      onStack.add(node);

      for (final target in graph[node]!) {
        if (!indices.containsKey(target)) {
          visit(target);
          if (lowLinks[target]! < lowLinks[node]!) {
            lowLinks[node] = lowLinks[target]!;
          }
        } else if (onStack.contains(target) &&
            indices[target]! < lowLinks[node]!) {
          lowLinks[node] = indices[target]!;
        }
      }

      if (lowLinks[node] != indices[node]) return;
      final component = <String>[];
      while (true) {
        final member = stack.removeLast();
        onStack.remove(member);
        component.add(member);
        if (member == node) break;
      }
      if (component.length > 1 || graph[node]!.contains(node)) {
        cycles.add(component);
      }
    }

    for (final file in graph.keys) {
      if (!indices.containsKey(file)) visit(file);
    }

    cycles.sort((left, right) => right.length.compareTo(left.length));
    final rootPrefix =
        '${Directory.current.absolute.path.replaceAll('\\', '/')}/';
    final cycleSummary =
        cycles.isEmpty
            ? ''
            : cycles.first
                .map((path) => path.replaceFirst(rootPrefix, ''))
                .join('\n');
    expect(
      cycles,
      isEmpty,
      reason:
          cycles.isEmpty
              ? null
              : 'Largest import cycle has ${cycles.first.length} files:\n'
                  '$cycleSummary',
    );
  });
}
