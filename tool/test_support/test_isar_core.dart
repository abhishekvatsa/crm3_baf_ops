import 'dart:ffi';
import 'dart:io';

import 'package:isar/isar.dart';

/// Initializes the Isar native core deterministically for Flutter tests.
///
/// Governed verification builds provide [CRM_ISAR_CORE_PATH]. When present,
/// the exact file is mapped to the current ABI and network download is
/// disabled. Ordinary developer runs retain the existing Linux-local and
/// download fallback behavior.
Future<void> initializeTestIsarCore() async {
  final configuredPath = Platform.environment['CRM_ISAR_CORE_PATH']?.trim();
  final configuredCoreRequired =
      Platform.environment['CRM_ISAR_CORE_REQUIRED'] == '1';

  final libraries = <Abi, String>{};

  if (configuredPath != null && configuredPath.isNotEmpty) {
    final configuredLibrary = File(configuredPath).absolute;

    if (!configuredLibrary.existsSync()) {
      throw StateError(
        'CRM_ISAR_CORE_PATH does not exist: '
        '${configuredLibrary.path}',
      );
    }

    libraries[Abi.current()] = configuredLibrary.path;
  } else if (configuredCoreRequired) {
    throw StateError(
      'CRM_ISAR_CORE_REQUIRED=1 but CRM_ISAR_CORE_PATH was not provided.',
    );
  } else if (Abi.current() == Abi.linuxX64) {
    final localLinuxLibrary =
        File('${Directory.current.path}/libisar.so').absolute;

    if (localLinuxLibrary.existsSync()) {
      libraries[Abi.linuxX64] = localLinuxLibrary.path;
    }
  }

  await Isar.initializeIsarCore(
    libraries: libraries,
    download: libraries.isEmpty && !configuredCoreRequired,
  );
}
