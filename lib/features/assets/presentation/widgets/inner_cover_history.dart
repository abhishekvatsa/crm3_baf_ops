import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/serialization/tolerant_snapshot_decode.dart';
import '../../../../core/theme/baf_design_system.dart';
import '../../data/inner_cover_lifecycle.dart';
import '../../domain/inner_cover_date_format.dart';

/// Readable history stays visible when a later snapshot is unavailable. An
/// empty cached or partially decoded snapshot never proves an empty history.
class InnerCoverHistory extends StatefulWidget {
  final String subjectId;
  final bool showBase;
  final AsyncValue<DecodedSnapshotBatch<InnerCoverLinkage>> history;
  final VoidCallback onRetry;

  const InnerCoverHistory({
    super.key,
    required this.subjectId,
    required this.showBase,
    required this.history,
    required this.onRetry,
  });

  @override
  State<InnerCoverHistory> createState() => _InnerCoverHistoryState();
}

class _InnerCoverHistoryState extends State<InnerCoverHistory> {
  DecodedSnapshotBatch<InnerCoverLinkage>? _lastBatch;

  @override
  void initState() {
    super.initState();
    _lastBatch = widget.history.asData?.value;
  }

  @override
  void didUpdateWidget(InnerCoverHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId ||
        oldWidget.showBase != widget.showBase) {
      _lastBatch = null;
    }
    _lastBatch = widget.history.asData?.value ?? _lastBatch;
  }

  @override
  Widget build(BuildContext context) {
    final batch = _lastBatch;
    final rows = batch?.records ?? const <InnerCoverLinkage>[];
    final verified =
        !widget.history.isLoading &&
        !widget.history.hasError &&
        batch != null &&
        batch.isComplete &&
        batch.isServerConfirmed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.history.isLoading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: BafSpacing.sm),
          const Text('Checking history…'),
        ],
        if (widget.history.hasError) ...[
          Text(
            rows.isEmpty
                ? 'History unavailable. No conclusion can be drawn about earlier assignments.'
                : 'History unavailable. Showing the last loaded entries; history may be incomplete.',
            style: const TextStyle(color: BafColors.danger),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry history'),
            ),
          ),
        ],
        if (batch != null && !batch.isComplete)
          Padding(
            padding: const EdgeInsets.only(bottom: BafSpacing.sm),
            child: Text(
              'History incomplete: ${batch.rejectedDocumentIds.length} '
              'record(s) could not be read. Readable entries are shown below.',
              style: const TextStyle(color: BafColors.warning),
            ),
          ),
        if (batch != null && !batch.isServerConfirmed)
          const Padding(
            padding: EdgeInsets.only(bottom: BafSpacing.sm),
            child: Text(
              'History is not yet server-confirmed. Earlier assignments may be missing.',
              style: TextStyle(color: BafColors.warning),
            ),
          ),
        if (rows.isEmpty && verified)
          Text(
            widget.showBase
                ? 'No Base linkage has been recorded for this cover.'
                : 'No Inner Cover assignment has been recorded for this Base.',
            style: const TextStyle(color: BafColors.textSecondary),
          ),
        for (final row in rows)
          _HistoryCard(row: row, showBase: widget.showBase),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final InnerCoverLinkage row;
  final bool showBase;

  const _HistoryCard({required this.row, required this.showBase});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(innerCoverDateTimePattern);
    return Card(
      margin: const EdgeInsets.only(top: BafSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  row.active ? Icons.link_rounded : Icons.history_rounded,
                  color: row.active
                      ? BafColors.success
                      : BafColors.textSecondary,
                ),
                Text(
                  showBase
                      ? 'Base ${row.baseAssetNumber}'
                      : 'Inner Cover ${row.innerCoverSerialNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(row.active ? 'Current assignment' : 'Previous assignment'),
              ],
            ),
            const SizedBox(height: BafSpacing.sm),
            Text('Pairing recorded ${date.format(row.installedAt.toLocal())}'),
            Text('By ${row.installedByName}'),
            if (!row.active) ...[
              const SizedBox(height: BafSpacing.sm),
              Text(
                'Removed physically: ${row.removedPhysicalAt == null ? 'not recorded' : date.format(row.removedPhysicalAt!.toLocal())}',
              ),
              Text('Removal recorded ${date.format(row.removedAt!.toLocal())}'),
              Text('By ${row.removedByName} · ${row.removalReason}'),
            ],
          ],
        ),
      ),
    );
  }
}
