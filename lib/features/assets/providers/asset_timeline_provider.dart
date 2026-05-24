import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../planned_maintenance/data/job_template_model.dart';
import '../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../models/timeline_entry.dart';

// ─── Filter State ─────────────────────────────────────────────────────────────

final selectedAssetTypeProvider = StateProvider<AssetType?>((ref) => null);
final assetNumberQueryProvider = StateProvider<String>((ref) => '');

// ─── Scoped Timeline Filter ───────────────────────────────────────────────────

class AssetTimelineFilter {
  final AssetType? assetType;
  final int? assetNumber;

  const AssetTimelineFilter({
    this.assetType,
    this.assetNumber,
  });

  bool get hasExactAsset => assetType != null && assetNumber != null;

  @override
  bool operator ==(Object other) {
    return other is AssetTimelineFilter &&
        other.assetType == assetType &&
        other.assetNumber == assetNumber;
  }

  @override
  int get hashCode => Object.hash(assetType, assetNumber);
}

// ─── Bounded Timeline Query Limits ───────────────────────────────────────────
// Broad timeline views are operational summaries, not full export/history views.
// Exact asset views stay richer while still capped to protect tablet UI during
// sync bursts and large-history stores.
const int _broadTimelineSourceLimit = 300;
const int _exactAssetTimelineSourceLimit = 500;
const int _broadTimelineEntryLimit = 300;
const int _exactAssetTimelineEntryLimit = 500;

// ─── Underlying Reactive Streams ──────────────────────────────────────────────

final _maintenanceStreamProvider =
StreamProvider.family<List<MaintenanceRecord>, AssetTimelineFilter>(
      (ref, filter) {
    final repo = ref.watch(maintenanceRepositoryProvider);

    if (filter.hasExactAsset) {
      return repo.watchTicketsForAsset(
        filter.assetType!,
        filter.assetNumber!,
        limit: _exactAssetTimelineSourceLimit,
      );
    }

    if (filter.assetType != null) {
      return repo.watchTicketsByAssetType(
        filter.assetType!,
        limit: _broadTimelineSourceLimit,
      );
    }

    return repo.watchAllTickets(limit: _broadTimelineSourceLimit);
  },
);

final _executionStreamProvider =
StreamProvider.family<List<JobExecution>, AssetTimelineFilter>(
      (ref, filter) {
    final repo = ref.watch(plannedRepositoryProvider);

    if (filter.hasExactAsset) {
      return repo.watchExecutionsForAsset(
        filter.assetType!,
        filter.assetNumber!,
        limit: _exactAssetTimelineSourceLimit,
      );
    }

    if (filter.assetType != null) {
      return repo.watchExecutionsByAssetType(
        filter.assetType!,
        limit: _broadTimelineSourceLimit,
      );
    }

    return repo.watchAllExecutions(limit: _broadTimelineSourceLimit);
  },
);

// ─── Timeline Provider (FULLY REACTIVE + FILTER-SCOPED) ───────────────────────

final assetTimelineProvider = Provider<AsyncValue<List<TimelineEntry>>>((ref) {
  final selectedType = ref.watch(selectedAssetTypeProvider);
  final numberQuery = ref.watch(assetNumberQueryProvider).trim();
  final number = numberQuery.isEmpty ? null : int.tryParse(numberQuery);

  if (numberQuery.isNotEmpty && number == null) {
    return const AsyncData(<TimelineEntry>[]);
  }

  final filter = AssetTimelineFilter(
    assetType: selectedType,
    assetNumber: number,
  );

  final maintenanceAsync = ref.watch(_maintenanceStreamProvider(filter));
  final executionAsync = ref.watch(_executionStreamProvider(filter));

  return maintenanceAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
    data: (tickets) => executionAsync.when(
      loading: () => const AsyncLoading(),
      error: (e, s) => AsyncError(e, s),
      data: (executions) {
        final filteredTickets = selectedType == null && number != null
            ? tickets.where((t) => t.assetNumber == number).toList()
            : tickets;

        final filteredExecutions = selectedType == null && number != null
            ? executions.where((e) => e.assetNumber == number).toList()
            : executions;

        final entries = [
          ...filteredTickets.map((t) => TimelineEntry.fromTicket(t)),
          ...filteredExecutions.map((e) => TimelineEntry.fromExecution(e)),
        ];

        entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final entryLimit = filter.hasExactAsset
            ? _exactAssetTimelineEntryLimit
            : _broadTimelineEntryLimit;
        return AsyncData(entries.take(entryLimit).toList(growable: false));
      },
    ),
  );
});
