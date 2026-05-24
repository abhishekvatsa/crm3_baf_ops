// FILE: lib/features/admin/presentation/local_diagnostics_exporter.dart

export 'local_diagnostics_exporter_stub.dart'
    if (dart.library.io) 'local_diagnostics_exporter_io.dart'
    if (dart.library.html) 'local_diagnostics_exporter_web.dart';
