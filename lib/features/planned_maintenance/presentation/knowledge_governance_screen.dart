// FILE: lib/features/planned_maintenance/presentation/knowledge_governance_screen.dart
//
// Phase 5E — Knowledge Governance Screen.
//
// Admin/SI-only screen for governing the BAF Knowledge Base. Sits next to
// Template Publisher in the More tab. Provides:
//   - Search/filter (debounced) over all rows (active + retired + archived).
//   - Row editor with change-reason capture and structural diff preview.
//   - Lifecycle actions (retire / archive / restore).
//   - Matrix version dashboard (cloud / local / fallback).
//   - Tag-resolver correction promotion panel.
//   - Import / export (JSON + CSV).
//   - Recent governance audit feed.
//   - Sync-conflict review for outstanding local writes.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/baf_knowledge_model.dart';
import '../domain/baf_knowledge_repository.dart';
import '../domain/knowledge_governance_export.dart';
import '../providers/knowledge_governance_provider.dart';
import 'widgets/knowledge_filters_panel.dart';
import 'widgets/knowledge_row_editor.dart';
import 'widgets/knowledge_version_dashboard.dart';
import 'widgets/knowledge_audit_timeline.dart';
import 'widgets/knowledge_correction_promoter_panel.dart';

class KnowledgeGovernanceScreen extends ConsumerStatefulWidget {
  const KnowledgeGovernanceScreen({super.key});

  @override
  ConsumerState<KnowledgeGovernanceScreen> createState() =>
      _KnowledgeGovernanceScreenState();
}

class _KnowledgeGovernanceScreenState
    extends ConsumerState<KnowledgeGovernanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(currentAppUserProvider);
    return appUserAsync.when(
      loading: () => const _LoadingScaffold(),
      error: (e, _) => _ErrorScaffold(message: '$e'),
      data: (appUser) {
        if (appUser == null || !canManageKnowledgeBase(appUser)) {
          return const _NotAuthorisedScaffold();
        }
        return _buildScaffold(context, appUser);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, AppUser appUser) {
    return BafScreenScaffold(
      title: 'Knowledge governance',
      subtitle: 'Controlled BAF knowledge, tags and evidence',
      icon: Icons.account_tree_outlined,
      accent: BafColors.planned,
      bottom: TabBar(
        controller: _tab,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(icon: Icon(Icons.table_rows_outlined), text: 'Rows'),
          Tab(icon: Icon(Icons.sell_outlined), text: 'Promote tags'),
          Tab(icon: Icon(Icons.history_rounded), text: 'Audit log'),
          Tab(icon: Icon(Icons.sync_problem_outlined), text: 'Conflicts'),
        ],
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tab,
          children: [
            _RowsTab(
              appUser: appUser,
              searchController: _searchController,
              onSearchChanged: _onSearchChanged,
            ),
            KnowledgeCorrectionPromoterPanel(appUser: appUser),
            const KnowledgeAuditTimeline(),
            const _ConflictsTab(),
          ],
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      final filter = ref.read(knowledgeGovernanceFilterProvider);
      ref.read(knowledgeGovernanceFilterProvider.notifier).state = filter
          .copyWith(query: value);
    });
  }
}

// ─────────────────────────────────────────────────────────────
// ROWS TAB
// ─────────────────────────────────────────────────────────────

class _RowsTab extends ConsumerWidget {
  final AppUser appUser;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _RowsTab({
    required this.appUser,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAsync = ref.watch(knowledgeRowsViewProvider);
    final filter = ref.watch(knowledgeGovernanceFilterProvider);

    return viewAsync.when(
      loading: () => const BafLoadingPanel(label: 'Loading governed knowledge'),
      error:
          (e, _) => BafStatePanel.error(
            title: 'Knowledge base unavailable',
            message: 'The governed knowledge rows could not be loaded. $e',
            onPrimary: () => ref.invalidate(knowledgeRowsViewProvider),
          ),
      data: (view) {
        final rows =
            filter.apply(view.rows).toList()
              ..sort((a, b) => a.rowCode.compareTo(b.rowCode));
        return Column(
          children: [
            KnowledgeVersionDashboard(
              meta: view.meta,
              totalRowCount: view.rows.length,
            ),
            const Divider(height: 1, color: BafColors.border),
            _SearchAndActionsBar(
              controller: searchController,
              onChanged: onSearchChanged,
              onCreate: () => _openEditorForCreate(context, ref, appUser),
              onExport: () => _exportBundle(context, ref),
              onImport: () => _importBundle(context, ref, appUser),
            ),
            const KnowledgeFiltersPanel(),
            const Divider(height: 1, color: BafColors.border),
            Expanded(
              child:
                  rows.isEmpty
                      ? const _EmptyRows()
                      : ListView.separated(
                        padding: const EdgeInsets.all(BafSpacing.md),
                        itemBuilder:
                            (_, i) => _KnowledgeRowCard(
                              row: rows[i],
                              onTap:
                                  () => _openEditorForUpdate(
                                    context,
                                    ref,
                                    appUser,
                                    rows[i],
                                  ),
                            ),
                        separatorBuilder:
                            (_, __) => const SizedBox(height: BafSpacing.sm),
                        itemCount: rows.length,
                      ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openEditorForCreate(
    BuildContext context,
    WidgetRef ref,
    AppUser appUser,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BafColors.background,
      builder: (_) => KnowledgeRowEditor.forCreate(actor: appUser),
    );
  }

  Future<void> _openEditorForUpdate(
    BuildContext context,
    WidgetRef ref,
    AppUser appUser,
    BafKnowledgeRow row,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BafColors.background,
      builder: (_) => KnowledgeRowEditor.forUpdate(actor: appUser, before: row),
    );
  }

  Future<void> _exportBundle(BuildContext context, WidgetRef ref) async {
    final format = await _pickFormat(context);
    if (format == null) {
      return;
    }
    final bundle = ref.read(knowledgeExportBundleProvider(format));
    if (!context.mounted) {
      return;
    }
    await _showExportBundleSheet(context, format: format, body: bundle.body);
  }

  Future<void> _importBundle(
    BuildContext context,
    WidgetRef ref,
    AppUser appUser,
  ) async {
    final format = await _pickFormat(context, includeImportHint: true);
    if (format == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    final body = await showDialog<String>(
      context: context,
      builder: (_) => _KnowledgeBundlePasteDialog(format: format),
    );
    if (body == null || body.trim().isEmpty) {
      return;
    }

    final view = ref.read(knowledgeRowsViewProvider).valueOrNull;
    final byCode = <String, BafKnowledgeRow>{
      for (final row in view?.rows ?? const <BafKnowledgeRow>[])
        row.rowCode: row,
    };
    final summary = KnowledgeGovernanceExport.parse(
      body: body,
      format: format,
      existingRowsByCode: byCode,
    );
    if (!context.mounted) {
      return;
    }

    final shouldApply = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Import preview'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rows considered: ${summary.rowsConsidered}'),
                    Text('Accepted (will write): ${summary.rowsAccepted}'),
                    Text('Rejected: ${summary.rowsRejected}'),
                    if (summary.rejected.isNotEmpty) ...[
                      const SizedBox(height: BafSpacing.sm),
                      const Text(
                        'Rejection reasons:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: BafSpacing.xs),
                      ...summary.rejected
                          .take(8)
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '· ${r.rowCode}: ${r.messages.join(', ')}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              if (summary.rowsAccepted > 0)
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Apply ${summary.rowsAccepted}'),
                ),
            ],
          ),
    );
    if (!context.mounted || shouldApply != true) {
      return;
    }
    final controllerInstance = ref.read(knowledgeGovernanceControllerProvider);
    try {
      final result = await controllerInstance.applyImport(
        summary: summary,
        actor: appUser,
      );
      if (!context.mounted) {
        return;
      }
      _showKnowledgeSnack(
        context,
        'Import: ${result.applied} written, ${result.rejectedAtSave} rejected.',
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      _showKnowledgeSnack(context, 'Import failed: $e');
    }
  }

  Future<KnowledgeBundleFormat?> _pickFormat(
    BuildContext context, {
    bool includeImportHint = false,
  }) async {
    return showDialog<KnowledgeBundleFormat>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Choose format'),
            content:
                includeImportHint
                    ? const Text(
                      'JSON imports preserve every governed field. CSV imports use ; as the inner separator for list-valued columns.',
                    )
                    : null,
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.pop(context, KnowledgeBundleFormat.json),
                child: const Text('JSON'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(context, KnowledgeBundleFormat.csv),
                child: const Text('CSV'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _showExportBundleSheet(
    BuildContext context, {
    required KnowledgeBundleFormat format,
    required String body,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BafColors.background,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.48,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.lg,
                  BafSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Knowledge export · ${format.name.toUpperCase()}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: BafColors.border),
                          borderRadius: BorderRadius.circular(BafRadius.medium),
                        ),
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(BafSpacing.md),
                          child: SelectableText(
                            body,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: BafSpacing.md),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: body));
                        if (!sheetContext.mounted) {
                          return;
                        }
                        _showKnowledgeSnack(
                          sheetContext,
                          'Copied to clipboard',
                        );
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy export body'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

void _showKnowledgeSnack(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

class _KnowledgeBundlePasteDialog extends StatefulWidget {
  final KnowledgeBundleFormat format;

  const _KnowledgeBundlePasteDialog({required this.format});

  @override
  State<_KnowledgeBundlePasteDialog> createState() =>
      _KnowledgeBundlePasteDialogState();
}

class _KnowledgeBundlePasteDialogState
    extends State<_KnowledgeBundlePasteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleBodyChanged);
  }

  void _handleBodyChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleBodyChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canParse = _controller.text.trim().isNotEmpty;

    return AlertDialog(
      title: Text('Paste ${widget.format.name.toUpperCase()} bundle'),
      content: SizedBox(
        width: 640,
        height: bafDialogBodyHeight(context, preferred: 360, minimum: 140),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Paste JSON or CSV body here…',
            alignLabelWithHint: true,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              canParse ? () => Navigator.pop(context, _controller.text) : null,
          child: const Text('Parse'),
        ),
      ],
    );
  }
}

class _SearchAndActionsBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCreate;
  final VoidCallback onExport;
  final VoidCallback onImport;

  const _SearchAndActionsBar({
    required this.controller,
    required this.onChanged,
    required this.onCreate,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BafSpacing.md,
        BafSpacing.sm,
        BafSpacing.md,
        BafSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Search rowCode, tag, component, safety class…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
              ),
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          IconButton(
            tooltip: 'New row',
            onPressed: onCreate,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: 'Export',
            onPressed: onExport,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Import',
            onPressed: onImport,
            icon: const Icon(Icons.upload_rounded),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeRowCard extends StatelessWidget {
  final BafKnowledgeRow row;
  final VoidCallback onTap;

  const _KnowledgeRowCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final lifecycleColor = _lifecycleColor(row.lifecycleStatus);
    final readinessColor = _readinessColor(row.composerReadiness);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.rowCode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  StatusBadge(label: 'v${row.version}', color: BafColors.audit),
                  const SizedBox(width: 6),
                  StatusBadge(
                    label: row.lifecycleStatus,
                    color: lifecycleColor,
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.xs),
              Text(
                row.taskText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BafColors.textPrimary),
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (row.assetFamily.isNotEmpty)
                    StatusBadge(
                      label: row.assetFamily,
                      color: BafColors.assets,
                    ),
                  StatusBadge(label: row.discipline, color: BafColors.planned),
                  StatusBadge(
                    label: row.composerReadiness,
                    color: readinessColor,
                  ),
                  if (row.requiredForClosure == 'yes')
                    const StatusBadge(
                      label: 'closure-critical',
                      color: BafColors.danger,
                    ),
                  if (row.deviceTags.isNotEmpty)
                    StatusBadge(
                      label: row.deviceTags.join(', '),
                      color: BafColors.charges,
                      icon: Icons.tag_rounded,
                    ),
                  if (!row.isSynced)
                    const StatusBadge(
                      label: 'unsynced',
                      color: BafColors.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _lifecycleColor(String status) {
    switch (status) {
      case 'retired':
        return BafColors.warning;
      case 'archived':
        return BafColors.textSecondary;
      default:
        return BafColors.success;
    }
  }

  Color _readinessColor(String readiness) {
    switch (readiness) {
      case 'readyPreset':
        return BafColors.success;
      case 'consultRequired':
      case 'needsReview':
      case 'inferredNeedsReview':
        return BafColors.warning;
      case 'tagOnly':
      case 'troubleshootingOnly':
      case 'futureIntegration':
      case 'referenceOnly':
        return BafColors.textSecondary;
      default:
        return BafColors.audit;
    }
  }
}

class _EmptyRows extends StatelessWidget {
  const _EmptyRows();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(BafSpacing.xl),
        child: Text(
          'No rows match this filter.\nTry clearing filters or adjusting search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: BafColors.textSecondary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CONFLICTS TAB
// ─────────────────────────────────────────────────────────────

class _ConflictsTab extends ConsumerWidget {
  const _ConflictsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(knowledgeGovernanceSyncConflictsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(knowledgeGovernanceSyncConflictsProvider);
        await ref.read(knowledgeGovernanceSyncConflictsProvider.future);
      },
      child: conflictsAsync.when(
        loading:
            () => const BafLoadingPanel(
              label: 'Scanning knowledge conflicts',
              color: BafColors.planned,
            ),
        error:
            (e, _) => ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(BafSpacing.lg),
                  child: Text('Conflict scan failed:\n$e'),
                ),
              ],
            ),
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(BafSpacing.xl),
                  child: Text(
                    'No outstanding sync conflicts on knowledge rows.\n\nA conflict appears here when a local edit was made offline but Firestore now reports a newer version. Pull-to-refresh re-scans.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BafColors.textSecondary),
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(BafSpacing.md),
            itemBuilder:
                (_, i) => _ConflictCard(
                  conflict: conflicts[i],
                  onAcceptCloud: () => _acceptCloud(context, ref, conflicts[i]),
                ),
            separatorBuilder: (_, __) => const SizedBox(height: BafSpacing.sm),
            itemCount: conflicts.length,
          );
        },
      ),
    );
  }

  Future<void> _acceptCloud(
    BuildContext context,
    WidgetRef ref,
    KnowledgeSyncConflict conflict,
  ) async {
    final repo = ref.read(bafKnowledgeRepositoryProvider);
    try {
      await repo.pullCloudToLocal();
      ref.invalidate(knowledgeGovernanceSyncConflictsProvider);
      if (!context.mounted) {
        return;
      }
      _showKnowledgeSnack(
        context,
        'Pulled cloud version of ${conflict.rowCode}.',
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      _showKnowledgeSnack(context, 'Pull failed: $e');
    }
  }
}

class _ConflictCard extends StatelessWidget {
  final KnowledgeSyncConflict conflict;
  final VoidCallback onAcceptCloud;

  const _ConflictCard({required this.conflict, required this.onAcceptCloud});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    conflict.rowCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                StatusBadge(
                  label: 'local v${conflict.localVersion}',
                  color: BafColors.warning,
                ),
                const SizedBox(width: 6),
                StatusBadge(
                  label: 'cloud v${conflict.cloudVersion}',
                  color: BafColors.danger,
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              'Cloud edited by ${conflict.cloudUpdatedByName.isEmpty ? "unknown" : conflict.cloudUpdatedByName}.',
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (conflict.cloudChangeSummary.isNotEmpty) ...[
              const SizedBox(height: BafSpacing.xs),
              Text(
                'Cloud reason: ${conflict.cloudChangeSummary}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: BafSpacing.sm),
            const Text(
              'Recommended: accept the cloud row, then re-apply your local changes through the editor with a fresh change reason.',
              style: TextStyle(fontSize: 12, color: BafColors.textSecondary),
            ),
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onAcceptCloud,
                icon: const Icon(Icons.cloud_download_rounded),
                label: const Text('Pull cloud'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SCAFFOLD HELPERS
// ─────────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return BafScreenStateScaffold.loading(
      appBarTitle: 'Knowledge governance',
      appBarSubtitle: 'Controlled BAF knowledge, tags and evidence',
      appBarIcon: Icons.account_tree_outlined,
      accent: BafColors.planned,
      label: 'Checking knowledge authority',
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;

  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return BafScreenStateScaffold.error(
      appBarTitle: 'Knowledge governance',
      appBarSubtitle: 'Controlled BAF knowledge, tags and evidence',
      appBarIcon: Icons.account_tree_outlined,
      accent: BafColors.planned,
      message: message,
    );
  }
}

class _NotAuthorisedScaffold extends StatelessWidget {
  const _NotAuthorisedScaffold();

  @override
  Widget build(BuildContext context) {
    return BafScreenStateScaffold.access(
      appBarTitle: 'Knowledge governance',
      appBarSubtitle: 'Controlled BAF knowledge, tags and evidence',
      appBarIcon: Icons.account_tree_outlined,
      accent: BafColors.planned,
      title: 'Knowledge authority required',
      message:
          'Only approved Admin or SI users may govern the BAF knowledge base.',
    );
  }
}
