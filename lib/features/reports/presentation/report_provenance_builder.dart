import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync_coordinator.dart';
import '../../../core/services/sync_service.dart';
import '../domain/report_provenance.dart';

ReportProvenance readApplicationReportProvenance(
  WidgetRef ref, {
  List<String> completenessNotes = const <String>[],
}) {
  final syncHealth = ref.read(syncRunHealthProvider);
  final pendingWrites = ref.read(syncPendingCountsProvider).asData?.value.total;
  return ReportProvenance(
    sourceMode:
        kIsWeb
            ? ReportSourceMode.cloudApplicationSnapshot
            : ReportSourceMode.hybridApplicationSnapshot,
    lastSyncCompletedAt: kIsWeb ? null : syncHealth.lastCompletedAt,
    lastSyncSucceeded: kIsWeb ? null : syncHealth.lastSucceeded,
    pendingLocalWrites: kIsWeb ? 0 : pendingWrites,
    completenessNotes: List<String>.unmodifiable(completenessNotes),
  );
}
