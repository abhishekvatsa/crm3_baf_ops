// FILE: lib/core/services/isar_production_recovery_io.dart

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

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

  String toLine() {
    final suffix = error == null ? '' : ' error=$error';
    return '$status: $sourcePath -> $targetPath$suffix';
  }
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

class IsarRecoveryBackupEvidence {
  final int byteCount;
  final String sha256;

  const IsarRecoveryBackupEvidence({
    required this.byteCount,
    required this.sha256,
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

Future<Directory> _documentsDirectory() => getApplicationDocumentsDirectory();

String _stamp() {
  return DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
}

String _safeReason(String reason) {
  final cleaned = reason.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9_\-]+'),
    '_',
  );
  return cleaned.isEmpty ? 'recovery' : cleaned;
}

Future<Directory> _diagnosticsRoot() async {
  final docs = await _documentsDirectory();
  final dir = Directory('${docs.path}/baf_diagnostics');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<Directory> _newRecoveryDirectory(String reason) async {
  final root = await _diagnosticsRoot();
  final dir = Directory(
    '${root.path}/isar_recovery_${_safeReason(reason)}_${_stamp()}',
  );
  await dir.create(recursive: true);
  return dir;
}

Future<IsarStartupDiagnosticsResult> writeIsarStartupFailureDiagnostics({
  required String diagnosticsText,
}) async {
  final root = await _diagnosticsRoot();
  final dir = Directory('${root.path}/startup_failures');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/isar_startup_failure_${_stamp()}.txt');
  await file.writeAsString(diagnosticsText, flush: true);
  return IsarStartupDiagnosticsResult(
    filePath: file.path,
    directoryPath: dir.path,
  );
}

Future<IsarRecoveryPackageResult> createIsarRecoveryPackage({
  required String diagnosticsText,
  required String reason,
  String? manifestJsonText,
}) async {
  final recoveryDir = await _newRecoveryDirectory(reason);
  final report = File('${recoveryDir.path}/recovery_report.txt');
  await report.writeAsString(
    _recoveryReportHeader(reason) + diagnosticsText,
    flush: true,
  );

  String? manifestJsonPath;
  if (manifestJsonText != null && manifestJsonText.trim().isNotEmpty) {
    final manifest = File('${recoveryDir.path}/recovery_manifest.json');
    await manifest.writeAsString(manifestJsonText, flush: true);
    manifestJsonPath = manifest.path;
  }

  final backupDir = Directory('${recoveryDir.path}/raw_isar_backup');
  await backupDir.create(recursive: true);
  final copied = await _copyLikelyIsarFiles(backupDir);
  final warnings = <String>[];
  if (copied.where((entry) => entry.status == 'copied').isEmpty) {
    warnings.add(
      'No likely Isar store files were found to copy. If the database is healthy and open, this can still happen on some platforms/file layouts.',
    );
  }

  await _appendFileList(report, copied, warnings: warnings);

  return IsarRecoveryPackageResult(
    directoryPath: recoveryDir.path,
    reportPath: report.path,
    manifestJsonPath: manifestJsonPath,
    rawBackupDirectoryPath: backupDir.path,
    copiedFileCount: copied.where((entry) => entry.status == 'copied').length,
    warnings: warnings,
    files: copied,
  );
}

Future<IsarRecoveryPackageResult> createConsistentIsarRecoveryPackage({
  required Isar database,
  required String diagnosticsText,
  required String reason,
  String? manifestJsonText,
}) async {
  final sourcePath = database.path;
  if (sourcePath == null) {
    throw UnsupportedError(
      'The active Isar database does not expose a local store path.',
    );
  }

  final recoveryDir = await _newRecoveryDirectory(reason);
  final report = File('${recoveryDir.path}/recovery_report.txt');
  await report.writeAsString(
    _recoveryReportHeader(reason) + diagnosticsText,
    flush: true,
  );

  String? manifestJsonPath;
  if (manifestJsonText != null && manifestJsonText.trim().isNotEmpty) {
    final manifest = File('${recoveryDir.path}/recovery_manifest.json');
    await manifest.writeAsString(manifestJsonText, flush: true);
    manifestJsonPath = manifest.path;
  }

  final backupDir = Directory('${recoveryDir.path}/raw_isar_backup');
  await backupDir.create(recursive: true);
  final snapshot = File('${backupDir.path}/${database.name}.isar');
  await database.copyToFile(snapshot.path);
  if (!await snapshot.exists() || await snapshot.length() == 0) {
    throw StateError('The consistent Isar backup was not retained.');
  }

  final copied = <IsarRecoveryFileEntry>[
    IsarRecoveryFileEntry(
      sourcePath: sourcePath,
      targetPath: snapshot.path,
      status: 'copied',
    ),
  ];
  await _appendFileList(
    report,
    copied,
    title: 'Transactionally consistent Isar database backup',
  );

  return IsarRecoveryPackageResult(
    directoryPath: recoveryDir.path,
    reportPath: report.path,
    manifestJsonPath: manifestJsonPath,
    rawBackupDirectoryPath: backupDir.path,
    copiedFileCount: copied.length,
    warnings: const <String>[],
    files: copied,
  );
}

Future<IsarRecoveryBackupEvidence?> readIsarRecoveryBackupEvidence(
  String path,
) async {
  final file = File(path);
  final before = await file.stat();
  if (before.type != FileSystemEntityType.file || before.size <= 0) return null;
  final digest = await sha256.bind(file.openRead()).first;
  final after = await file.stat();
  if (after.type != FileSystemEntityType.file || after.size != before.size) {
    return null;
  }
  return IsarRecoveryBackupEvidence(
    byteCount: after.size,
    sha256: digest.toString(),
  );
}

Future<bool> isRetainedIsarRecoveryBackup(String path) async {
  return await readIsarRecoveryBackupEvidence(path) != null;
}

const _deviceRecoveryJournalDirectoryName =
    'CRM3_BAF_Ops_Device_Recovery_Journals';
const _deviceRecoveryStorageChannel = MethodChannel(
  'in.co.sail.bsl.crm3.bafops/recovery_storage',
);

class _DeviceRecoveryJournalPaths {
  const _DeviceRecoveryJournalPaths({
    required this.journalDirectory,
    required this.target,
    required this.pending,
  });

  final Directory journalDirectory;
  final File target;
  final File pending;
}

String _deviceRecoveryJournalFileName(String requestId) {
  if (requestId.isEmpty ||
      requestId.length > 128 ||
      !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(requestId)) {
    throw const FormatException('Invalid device-recovery request ID.');
  }
  return '$requestId.json';
}

Future<void> _syncRecoveryJournalDirectory(Directory directory) async {
  if (!Platform.isAndroid) {
    throw const FileSystemException(
      'Crash-durable device recovery is currently supported only on Android.',
    );
  }
  final synchronized = await _deviceRecoveryStorageChannel.invokeMethod<bool>(
    'syncDirectory',
    <String, Object?>{'directoryPath': directory.path},
  );
  if (synchronized != true) {
    throw FileSystemException(
      'Recovery-journal directory synchronization was not confirmed.',
      directory.path,
    );
  }
}

Future<_DeviceRecoveryJournalPaths> _deviceRecoveryJournalPaths(
  String requestId, {
  required bool createDirectory,
}) async {
  final documents = await _documentsDirectory();
  final directory = Directory(
    '${documents.path}/$_deviceRecoveryJournalDirectoryName',
  );
  if (createDirectory && !await directory.exists()) {
    await directory.create(recursive: true);
    await _syncRecoveryJournalDirectory(documents);
  }
  final target = File(
    '${directory.path}/${_deviceRecoveryJournalFileName(requestId)}',
  );
  return _DeviceRecoveryJournalPaths(
    journalDirectory: directory,
    target: target,
    pending: File('${target.path}.pending'),
  );
}

Future<String?> readCrashDurableIsarRecoveryJournal(String requestId) async {
  final paths = await _deviceRecoveryJournalPaths(
    requestId,
    createDirectory: false,
  );
  if (await paths.target.exists()) return paths.target.readAsString();
  if (!await paths.pending.exists()) return null;

  final serialized = await paths.pending.readAsString();
  if (serialized.isEmpty) {
    throw const FormatException(
      'Pending device-recovery journal cannot be empty.',
    );
  }
  await paths.pending.rename(paths.target.path);
  await _syncRecoveryJournalDirectory(paths.journalDirectory);
  if (await paths.target.readAsString() != serialized) {
    throw const FileSystemException(
      'Recovered device-recovery journal readback failed.',
    );
  }
  return serialized;
}

Future<void> writeCrashDurableIsarRecoveryJournal(
  String requestId,
  String serialized,
) async {
  if (serialized.isEmpty) {
    throw const FormatException('Device-recovery journal cannot be empty.');
  }
  final paths = await _deviceRecoveryJournalPaths(
    requestId,
    createDirectory: true,
  );
  final target = paths.target;
  final pending = paths.pending;
  try {
    if (await pending.exists()) await pending.delete();
    await pending.writeAsString(serialized, flush: true);
    if (await pending.readAsString() != serialized) {
      throw const FileSystemException(
        'Device-recovery journal write verification failed.',
      );
    }
    await pending.rename(target.path);
    await _syncRecoveryJournalDirectory(paths.journalDirectory);
    if (await target.readAsString() != serialized) {
      throw const FileSystemException(
        'Device-recovery journal replacement verification failed.',
      );
    }
  } finally {
    if (await pending.exists()) await pending.delete();
  }
}

Future<IsarControlledRebuildResult> rebuildLocalDatabaseAfterBackup({
  required String reason,
  required String diagnosticsText,
  String? manifestJsonText,
}) async {
  final package = await createIsarRecoveryPackage(
    diagnosticsText: diagnosticsText,
    manifestJsonText: manifestJsonText,
    reason: reason,
  );

  final movedAsideDir = Directory(
    '${package.directoryPath}/moved_aside_isar_store',
  );
  await movedAsideDir.create(recursive: true);
  final moved = await _moveLikelyIsarFiles(movedAsideDir);
  final warnings = <String>[...package.warnings];
  final failedMoves =
      moved.where((entry) => entry.status == 'move_failed').toList();
  if (failedMoves.isNotEmpty) {
    warnings.add(
      'One or more Isar files could not be moved aside. Local rebuild was not completed; the existing files were left in place.',
    );
  }
  if (moved.where((entry) => entry.status == 'moved').isEmpty) {
    warnings.add(
      'No likely Isar files were moved aside. The next open attempt may simply retry the existing store or create a clean one if no store files exist.',
    );
  }

  final success = failedMoves.isEmpty;
  final report = File(package.reportPath);
  await report.writeAsString(
    '\nControlled rebuild result\n'
    'success: $success\n'
    'movedAsideDirectory: ${movedAsideDir.path}\n'
    'movedFileCount: ${moved.where((entry) => entry.status == "moved").length}\n'
    'warnings: ${warnings.join(' | ')}\n',
    mode: FileMode.append,
    flush: true,
  );
  await _appendFileList(report, moved, title: 'Moved-aside files');

  return IsarControlledRebuildResult(
    success: success,
    recoveryDirectoryPath: package.directoryPath,
    reportPath: package.reportPath,
    rawBackupDirectoryPath: package.rawBackupDirectoryPath,
    movedAsideDirectoryPath: movedAsideDir.path,
    copiedFileCount: package.copiedFileCount,
    movedFileCount: moved.where((entry) => entry.status == 'moved').length,
    warnings: warnings,
    files: <IsarRecoveryFileEntry>[...package.files, ...moved],
  );
}

String _recoveryReportHeader(String reason) {
  return 'CRM-III BAF Ops Isar recovery package\n'
      'generatedAt: ${DateTime.now().toUtc().toIso8601String()}\n'
      'reason: $reason\n'
      'policy: diagnose -> backup -> export if possible -> confirm -> rebuild -> pull -> reconcile\n'
      'note: Firestore can restore synced cloud records only. Local-only unsynced evidence may exist only in the backed-up Isar files.\n\n';
}

Future<void> _appendFileList(
  File report,
  List<IsarRecoveryFileEntry> files, {
  List<String> warnings = const <String>[],
  String title = 'Raw Isar file backup',
}) async {
  final buffer =
      StringBuffer()
        ..writeln('')
        ..writeln(title)
        ..writeln('fileCount: ${files.length}');
  for (final warning in warnings) {
    buffer.writeln('warning: $warning');
  }
  for (final file in files) {
    buffer.writeln(file.toLine());
  }
  await report.writeAsString(
    buffer.toString(),
    mode: FileMode.append,
    flush: true,
  );
}

Future<List<FileSystemEntity>> _likelyIsarFiles() async {
  final docs = await _documentsDirectory();
  if (!await docs.exists()) return const <FileSystemEntity>[];
  final entries = await docs.list(followLinks: false).toList();
  return entries.where(_isLikelyIsarStoreEntity).toList(growable: false);
}

bool _isLikelyIsarStoreEntity(FileSystemEntity entity) {
  if (entity is! File) return false;
  final name =
      entity.uri.pathSegments.isEmpty
          ? entity.path.split(Platform.pathSeparator).last
          : entity.uri.pathSegments.last;
  return name == 'default.isar' ||
      name == 'default.isar.lock' ||
      name.startsWith('default.isar.') ||
      name.endsWith('.isar') ||
      name.endsWith('.isar.lock') ||
      name.endsWith('.isar.tmp');
}

Future<List<IsarRecoveryFileEntry>> _copyLikelyIsarFiles(
  Directory targetDir,
) async {
  final entries = await _likelyIsarFiles();
  final results = <IsarRecoveryFileEntry>[];
  for (final entity in entries) {
    final name =
        entity.uri.pathSegments.isEmpty
            ? entity.path.split(Platform.pathSeparator).last
            : entity.uri.pathSegments.last;
    final target = File('${targetDir.path}/$name');
    try {
      await (entity as File).copy(target.path);
      results.add(
        IsarRecoveryFileEntry(
          sourcePath: entity.path,
          targetPath: target.path,
          status: 'copied',
        ),
      );
    } catch (error) {
      results.add(
        IsarRecoveryFileEntry(
          sourcePath: entity.path,
          targetPath: target.path,
          status: 'copy_failed',
          error: '$error',
        ),
      );
    }
  }
  return results;
}

Future<List<IsarRecoveryFileEntry>> _moveLikelyIsarFiles(
  Directory targetDir,
) async {
  final entries = await _likelyIsarFiles();
  final results = <IsarRecoveryFileEntry>[];
  for (final entity in entries) {
    final name =
        entity.uri.pathSegments.isEmpty
            ? entity.path.split(Platform.pathSeparator).last
            : entity.uri.pathSegments.last;
    final target = File('${targetDir.path}/$name');
    try {
      await entity.rename(target.path);
      results.add(
        IsarRecoveryFileEntry(
          sourcePath: entity.path,
          targetPath: target.path,
          status: 'moved',
        ),
      );
    } catch (error) {
      results.add(
        IsarRecoveryFileEntry(
          sourcePath: entity.path,
          targetPath: target.path,
          status: 'move_failed',
          error: '$error',
        ),
      );
    }
  }
  return results;
}
