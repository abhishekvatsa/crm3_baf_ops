import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_stream_providers.dart';
import 'admin_data_browser/admin_pilot_purge.dart';

enum _CleanupKind { all, ticket, directive, template }

class _CleanupRow {
  final PilotPurgeTarget target;
  final _CleanupKind kind;
  final String subtitle;
  final DateTime? deletedAt;

  const _CleanupRow({
    required this.target,
    required this.kind,
    required this.subtitle,
    required this.deletedAt,
  });
}

class PilotDataCleanupScreen extends ConsumerStatefulWidget {
  const PilotDataCleanupScreen({super.key});

  @override
  ConsumerState<PilotDataCleanupScreen> createState() =>
      _PilotDataCleanupScreenState();
}

class _PilotDataCleanupScreenState
    extends ConsumerState<PilotDataCleanupScreen> {
  final _search = TextEditingController();
  final Set<String> _selected = <String>{};
  _CleanupKind _kind = _CleanupKind.all;
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentAppUserProvider).value;
    if (actor == null || !actor.isApproved || !actor.isAdmin) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Pilot data cleanup',
        appBarSubtitle: 'Select synchronized tombstones for permanent removal',
        appBarIcon: Icons.delete_sweep_outlined,
        accent: BafColors.danger,
        message: 'Fresh Admin authority is required.',
      );
    }

    final tickets = ref.watch(adminTicketsStreamProvider);
    final directives = ref.watch(adminDirectivesStreamProvider);
    final templates = ref.watch(adminTemplatesStreamProvider);
    final isLoading =
        tickets.isLoading || directives.isLoading || templates.isLoading;
    final firstError = tickets.error ?? directives.error ?? templates.error;
    final rows = <_CleanupRow>[
      for (final ticket in tickets.value ?? const [])
        if (ticket.isDeleted &&
            ticket.isSynced &&
            ticket.firestoreId != null &&
            ticket.firestoreId!.trim().isNotEmpty)
          _CleanupRow(
            target: PilotPurgeTarget(
              collectionId: 'maintenance_records',
              documentId: ticket.firestoreId!.trim(),
              expectedVersion: ticket.version,
              recordLabel:
                  '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}: ${ticket.description}',
            ),
            kind: _CleanupKind.ticket,
            subtitle:
                'Issue ticket | v${ticket.version} | ${ticket.deletedByName ?? 'Admin deletion'}',
            deletedAt: ticket.deletedAt,
          ),
      for (final directive in directives.value ?? const [])
        if (directive.isDeleted &&
            directive.isSynced &&
            directive.firestoreId != null &&
            directive.firestoreId!.trim().isNotEmpty)
          _CleanupRow(
            target: PilotPurgeTarget(
              collectionId: 'directives',
              documentId: directive.firestoreId!.trim(),
              expectedVersion: directive.version,
              recordLabel: directive.title,
            ),
            kind: _CleanupKind.directive,
            subtitle:
                'Directive | v${directive.version} | ${directive.deletedByName ?? 'Admin deletion'}',
            deletedAt: directive.deletedAt,
          ),
      for (final template in templates.value ?? const [])
        if (template.isDeleted &&
            template.isSynced &&
            template.firestoreId != null &&
            template.firestoreId!.trim().isNotEmpty)
          _CleanupRow(
            target: PilotPurgeTarget(
              collectionId: 'job_templates',
              documentId: template.firestoreId!.trim(),
              expectedVersion: template.version,
              recordLabel: template.jobName,
            ),
            kind: _CleanupKind.template,
            subtitle:
                'Legacy template | v${template.version} | ${template.deletedByName ?? 'Admin deletion'}',
            deletedAt: template.deletedAt,
          ),
    ]..sort((a, b) {
      final aDeletedAt = a.deletedAt;
      final bDeletedAt = b.deletedAt;
      final byDate = switch ((aDeletedAt, bDeletedAt)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final aDate?, final bDate?) => bDate.compareTo(aDate),
      };
      return byDate != 0
          ? byDate
          : a.target.recordLabel.compareTo(b.target.recordLabel);
    });
    final query = _search.text.trim().toLowerCase();
    final visible = rows
        .where((row) {
          if (_kind != _CleanupKind.all && row.kind != _kind) return false;
          if (query.isEmpty) return true;
          return row.target.recordLabel.toLowerCase().contains(query) ||
              row.target.documentId.toLowerCase().contains(query) ||
              row.subtitle.toLowerCase().contains(query);
        })
        .toList(growable: false);
    final visibleKeys = visible.map((row) => row.target.selectionKey).toSet();
    final selectedVisible = _selected.intersection(visibleKeys).length;
    final allKeys = rows.map((row) => row.target.selectionKey).toSet();
    final selectedTotal = _selected.intersection(allKeys).length;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.08),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                  ),
                  child: const Text(
                    'Only records already marked deleted appear here. The server refuses removal when retained business data still refers to a record. Users, assets, contacts and audit evidence are outside this tool.',
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search deleted records or document IDs',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_CleanupKind>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _CleanupKind.all,
                        label: Text('All'),
                        icon: Icon(Icons.inventory_2_outlined),
                      ),
                      ButtonSegment(
                        value: _CleanupKind.ticket,
                        label: Text('Tickets'),
                        icon: Icon(Icons.build_outlined),
                      ),
                      ButtonSegment(
                        value: _CleanupKind.directive,
                        label: Text('Directives'),
                        icon: Icon(Icons.assignment_outlined),
                      ),
                      ButtonSegment(
                        value: _CleanupKind.template,
                        label: Text('Templates'),
                        icon: Icon(Icons.description_outlined),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged:
                        _busy
                            ? null
                            : (selection) => setState(() {
                              _kind = selection.single;
                            }),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${visible.length} eligible | $selectedVisible selected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _busy || visible.isEmpty
                              ? null
                              : () => setState(() {
                                if (selectedVisible == visible.length) {
                                  _selected.removeAll(visibleKeys);
                                } else {
                                  _selected.addAll(visibleKeys);
                                }
                              }),
                      child: Text(
                        selectedVisible == visible.length && visible.isNotEmpty
                            ? 'Clear visible'
                            : 'Select visible',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child:
                isLoading && rows.isEmpty
                    ? const BafLoadingPanel(
                      label: 'Loading deleted pilot records',
                      color: BafColors.admin,
                    )
                    : firstError != null && rows.isEmpty
                    ? Center(child: Text('Could not load records: $firstError'))
                    : visible.isEmpty
                    ? const Center(
                      child: Text(
                        'No eligible deleted records match this view.',
                        style: TextStyle(color: BafColors.textSecondary),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                      itemCount: visible.length,
                      separatorBuilder:
                          (_, _) => const Divider(height: 1, indent: 54),
                      itemBuilder: (context, index) {
                        final row = visible[index];
                        final selected = _selected.contains(
                          row.target.selectionKey,
                        );
                        return CheckboxListTile(
                          value: selected,
                          enabled: !_busy,
                          onChanged:
                              _busy
                                  ? null
                                  : (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(row.target.selectionKey);
                                    } else {
                                      _selected.remove(row.target.selectionKey);
                                    }
                                  }),
                          secondary: Icon(
                            _kindIcon(row.kind),
                            color: _kindColor(row.kind),
                          ),
                          title: Text(
                            row.target.recordLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${row.subtitle}${row.deletedAt == null ? '' : ' | ${DateFormat('dd MMM yyyy, HH:mm').format(row.deletedAt!)}'}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: BafColors.danger,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
          onPressed: _busy || selectedTotal == 0 ? null : () => _purge(rows),
          icon:
              _busy
                  ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.delete_forever_rounded),
          label: Text(
            _busy
                ? 'Checking and removing records'
                : 'Permanently remove $selectedTotal selected',
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) => AppBar(
    title: SizedBox(
      width: MediaQuery.sizeOf(context).width - 104,
      child: const BafAppBarTitle(
        title: 'Pilot data cleanup',
        subtitle: 'Select synchronized tombstones for permanent removal',
        icon: Icons.delete_sweep_outlined,
        accent: BafColors.danger,
      ),
    ),
  );

  Future<void> _purge(List<_CleanupRow> allRows) async {
    final targets = allRows
        .where((row) => _selected.contains(row.target.selectionKey))
        .map((row) => row.target)
        .toList(growable: false);
    if (targets.isEmpty) return;
    final decision = await showDialog<_BulkPurgeDecision>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BulkPurgeDialog(recordCount: targets.length),
    );
    if (decision == null || !mounted) return;

    setState(() => _busy = true);
    var removed = 0;
    final failures = <String>[];
    try {
      final coordinator = ref.read(syncCoordinatorProvider);
      final preflight = await coordinator.runFullSyncWithResult(
        reason: 'pilot_cleanup_preflight',
        force: true,
      );
      if (preflight != SyncRequestOutcome.succeeded) {
        throw StateError(
          'Synchronization must finish before cleanup. No selected record was removed.',
        );
      }
      for (final target in targets) {
        try {
          await executePilotBusinessRecordPurge(
            ref: ref,
            target: target,
            reason: decision.reason,
            resumeSyncAfterCleanup: false,
          );
          removed++;
          _selected.remove(target.selectionKey);
        } catch (error) {
          failures.add('${target.recordLabel}: $error');
        }
      }
      await coordinator.runFullSyncWithResult(
        reason: 'pilot_cleanup_completed',
        force: true,
      );
      ref.invalidate(adminTicketsStreamProvider);
      ref.invalidate(adminDirectivesStreamProvider);
      ref.invalidate(adminTemplatesStreamProvider);
      if (!mounted) return;
      final failureText =
          failures.isEmpty
              ? ''
              : ' ${failures.length} refused because they changed or still have dependencies.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$removed record(s) permanently removed.$failureText'),
          backgroundColor:
              failures.isEmpty ? BafColors.success : BafColors.warning,
          action:
              failures.isEmpty
                  ? null
                  : SnackBarAction(
                    label: 'Details',
                    onPressed: () => _showFailures(failures),
                  ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleanup stopped: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showFailures(List<String> failures) => showDialog<void>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Records not removed'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: SelectableText(failures.join('\n\n')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
  );
}

IconData _kindIcon(_CleanupKind kind) => switch (kind) {
  _CleanupKind.ticket => Icons.build_outlined,
  _CleanupKind.directive => Icons.assignment_outlined,
  _CleanupKind.template => Icons.description_outlined,
  _CleanupKind.all => Icons.inventory_2_outlined,
};

Color _kindColor(_CleanupKind kind) => switch (kind) {
  _CleanupKind.ticket => BafColors.danger,
  _CleanupKind.directive => BafColors.warning,
  _CleanupKind.template => BafColors.planned,
  _CleanupKind.all => BafColors.admin,
};

class _BulkPurgeDecision {
  final String reason;

  const _BulkPurgeDecision(this.reason);
}

class _BulkPurgeDialog extends StatefulWidget {
  final int recordCount;

  const _BulkPurgeDialog({required this.recordCount});

  @override
  State<_BulkPurgeDialog> createState() => _BulkPurgeDialogState();
}

class _BulkPurgeDialogState extends State<_BulkPurgeDialog> {
  final _reason = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;

  String get expected => 'DELETE ${widget.recordCount} RECORDS';

  @override
  void dispose() {
    _reason.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Permanently remove selected records'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.recordCount} synchronized tombstone(s) will be checked independently. Removal cannot be undone.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Why is this pilot data no longer required?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              expected,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmation,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Type the confirmation exactly',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: BafColors.danger,
          foregroundColor: Colors.white,
        ),
        onPressed: _submit,
        icon: const Icon(Icons.delete_forever_rounded),
        label: const Text('Remove permanently'),
      ),
    ],
  );

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Enter a reason.');
      return;
    }
    if (_confirmation.text.trim() != expected) {
      setState(() => _error = 'The confirmation text does not match.');
      return;
    }
    Navigator.pop(context, _BulkPurgeDecision(reason));
  }
}
