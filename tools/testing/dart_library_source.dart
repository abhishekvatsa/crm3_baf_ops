import 'dart:io';

String readDartLibrarySource(String rootPath) {
  final root = File(rootPath);
  final source = root.readAsStringSync();
  final parts = RegExp(
    r"^\s*part\s+'([^']+)'\s*;",
    multiLine: true,
  ).allMatches(source);
  if (parts.isEmpty) return source;

  final sections = <String>[source];
  for (final match in parts) {
    final relativePath = match.group(1)!;
    sections.add(File('${root.parent.path}/$relativePath').readAsStringSync());
  }
  return sections.join('\n');
}
