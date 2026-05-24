// FILE: lib/core/services/isar_production_recovery_stub.dart

class IsarRecoveryFileEntry {
  final String sourcePath;
  final String targetPath;
  final String status;
  final String? error;

  const IsarRecoveryFileEntry({
    required this.sourcePath,
    required this.targetPath,
    required this.status,
    this.error,
  });
}

class IsarRecoveryPackageResult {
  final String directoryPath;
  final String reportPath;
  final String? manifestJsonPath;
  final String? rawBackupDirectoryPath;
  final int copiedFileCount;
  final List<String> warnings;
  final List<IsarRecoveryFileEntry> files;

  const IsarRecoveryPackageResult({
    required this.directoryPath,
    required this.reportPath,
    this.manifestJsonPath,
    this.rawBackupDirectoryPath,
    required this.copiedFileCount,
    required this.warnings,
    required this.files,
  });
}

class IsarStartupDiagnosticsResult {
  final String filePath;
  final String directoryPath;

  const IsarStartupDiagnosticsResult({
    required this.filePath,
    required this.directoryPath,
  });
}

class IsarControlledRebuildResult {
  final bool success;
  final String recoveryDirectoryPath;
  final String reportPath;
  final String? rawBackupDirectoryPath;
  final String? movedAsideDirectoryPath;
  final int copiedFileCount;
  final int movedFileCount;
  final List<String> warnings;
  final List<IsarRecoveryFileEntry> files;

  const IsarControlledRebuildResult({
    required this.success,
    required this.recoveryDirectoryPath,
    required this.reportPath,
    this.rawBackupDirectoryPath,
    this.movedAsideDirectoryPath,
    required this.copiedFileCount,
    required this.movedFileCount,
    required this.warnings,
    required this.files,
  });
}

Future<IsarStartupDiagnosticsResult> writeIsarStartupFailureDiagnostics({
  required String diagnosticsText,
}) async {
  throw UnsupportedError(
    'Isar startup diagnostics file writing is not available on this platform.',
  );
}

Future<IsarRecoveryPackageResult> createIsarRecoveryPackage({
  required String diagnosticsText,
  required String reason,
  String? manifestJsonText,
}) async {
  throw UnsupportedError(
    'Isar recovery package creation is not available on this platform.',
  );
}

Future<IsarControlledRebuildResult> rebuildLocalDatabaseAfterBackup({
  required String reason,
  required String diagnosticsText,
  String? manifestJsonText,
}) async {
  throw UnsupportedError(
    'Controlled Isar rebuild is not available on this platform.',
  );
}
