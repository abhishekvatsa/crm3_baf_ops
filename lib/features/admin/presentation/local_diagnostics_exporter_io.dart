// FILE: lib/features/admin/presentation/local_diagnostics_exporter_io.dart

import 'dart:io';

import 'package:path_provider/path_provider.dart';

class LocalDiagnosticsExportResult {
  final String fileName;
  final String path;

  const LocalDiagnosticsExportResult({
    required this.fileName,
    required this.path,
  });
}

Future<LocalDiagnosticsExportResult> saveLocalDiagnosticsText(String text) async {
  final directory = Platform.isAndroid
      ? (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory()
      : await getApplicationDocumentsDirectory();

  final folder = Directory('${directory.path}/baf_diagnostics');
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final stamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final fileName = 'baf_local_diagnostics_$stamp.txt';
  final file = File('${folder.path}/$fileName');
  await file.writeAsString(text, flush: true);

  return LocalDiagnosticsExportResult(
    fileName: fileName,
    path: file.path,
  );
}
