// FILE: lib/features/admin/presentation/local_diagnostics_exporter_web.dart

class LocalDiagnosticsExportResult {
  final String fileName;
  final String path;

  const LocalDiagnosticsExportResult({
    required this.fileName,
    required this.path,
  });
}

Future<LocalDiagnosticsExportResult> saveLocalDiagnosticsText(String text) async {
  throw UnsupportedError(
    'Local diagnostics file export is not available on web. Use Copy diagnostics instead.',
  );
}
