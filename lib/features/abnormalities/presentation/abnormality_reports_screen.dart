// FILE: lib/features/abnormalities/presentation/abnormality_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/incremental_list_footer.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/abnormality_model.dart';
import '../domain/charge_ra_history.dart';
import '../providers/abnormality_provider.dart';
import 'abnormality_list_filter.dart';
import 'abnormality_charge_history_card.dart';
import 'abnormality_report_summary_card.dart';

class AbnormalityReportsScreen extends ConsumerStatefulWidget {
  const AbnormalityReportsScreen({super.key});

  @override
  ConsumerState<AbnormalityReportsScreen> createState() =>
      _AbnormalityReportsScreenState();
}

class _AbnormalityReportsScreenState
    extends ConsumerState<AbnormalityReportsScreen> {
  Future<List<ChargeAbnormality>>? _future;
  String? _futureActorUid;

  final _scrollController = ScrollController();
  final _resultsAnchor = GlobalKey();
  final _historyAnchor = GlobalKey();
  int? _historyCharge;

  String _searchQuery = '';
  final _searchController = TextEditingController();
  int _visibleLimit = businessListPageSize;
  AbnormalityCategory? _categoryFilter;
  AbnormalityListFilter _raFilter = AbnormalityListFilter.open;
  AbnormalitySeverity? _severityFilter;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ChargeAbnormality>> _load() {
    return ref.read(abnormalityRepositoryProvider).getAllAbnormalities();
  }

  void _ensureLoadedFor(AppUser actor) {
    if (_future != null && _futureActorUid == actor.uid) return;
    _futureActorUid = actor.uid;
    _historyCharge = null;
    _visibleLimit = businessListPageSize;
    _future = _load();
  }

  void _clearLoadedReport() {
    _futureActorUid = null;
    _future = null;
    _historyCharge = null;
  }

  Future<void> _refresh() async {
    final actorAsync = ref.read(currentAppUserProvider);
    if (actorAsync.hasError) return;
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) return;
    final next = _load();
    setState(() {
      _futureActorUid = actor.uid;
      _future = next;
    });
    await next;
  }

  void _jumpTo(GlobalKey anchor) {
    // The first list child owns the report controls and anchors. Bring it back
    // into the viewport before locating an anchor after a filter/history change.
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = anchor.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: 0,
        );
      }
    });
  }

  void _setReportScope({
    AbnormalityListFilter status = AbnormalityListFilter.all,
    AbnormalitySeverity? severity,
    int? historyCharge,
  }) {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _categoryFilter = null;
      _severityFilter = severity;
      _raFilter = status;
      _historyCharge = historyCharge;
      _visibleLimit = businessListPageSize;
    });
    _jumpTo(historyCharge == null ? _resultsAnchor : _historyAnchor);
  }

  void _showChargeHistory(int charge) => _setReportScope(historyCharge: charge);

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      _clearLoadedReport();
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Abnormality reports',
        appBarSubtitle: 'Verifying your approved reporting scope',
        appBarIcon: Icons.analytics_outlined,
        accent: BafColors.charges,
        label: 'Checking abnormality-report access',
      );
    }
    if (actorAsync.hasError) {
      _clearLoadedReport();
      return BafScreenStateScaffold.error(
        appBarTitle: 'Abnormality reports',
        appBarSubtitle: 'Verifying your approved reporting scope',
        appBarIcon: Icons.analytics_outlined,
        accent: BafColors.charges,
        message: 'Abnormality-report access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      _clearLoadedReport();
      return BafScreenStateScaffold.access(
        appBarTitle: 'Abnormality reports',
        appBarSubtitle: 'Charge patterns, quality exposure and closure',
        appBarIcon: Icons.analytics_outlined,
        accent: BafColors.charges,
        title: 'Abnormality-report access required',
        message: 'An approved account is required to view abnormality reports.',
      );
    }
    _ensureLoadedFor(actor);
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Abnormality reports',
          subtitle: 'Charge patterns, quality exposure and closure',
          icon: Icons.analytics_outlined,
          accent: BafColors.charges,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            color: BafColors.sync,
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<ChargeAbnormality>>(
        future: _future!,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const BafLoadingPanel(
              label: 'Building abnormality report',
              color: BafColors.charges,
            );
          }

          if (snapshot.hasError) {
            return _StateCard(
              icon: Icons.error_outline_rounded,
              title: 'Could not load abnormality reports',
              message: '${snapshot.error}',
              color: BafColors.danger,
            );
          }

          final records = snapshot.data ?? const <ChargeAbnormality>[];
          final history = _historyCharge == null
              ? null
              : ChargeRaHistoryIndex(records).forCharge(_historyCharge!);
          final filtered = history?.records ?? _applyFilters(records);
          final visible = filtered.take(_visibleLimit).toList(growable: false);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(BafSpacing.lg),
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AbnormalityReportSummaryCard(
                      selected:
                          _historyCharge != null ||
                              _searchQuery.trim().isNotEmpty ||
                              _categoryFilter != null
                          ? null
                          : _raFilter == AbnormalityListFilter.all &&
                                _severityFilter == AbnormalitySeverity.critical
                          ? 'Critical'
                          : _severityFilter != null
                          ? null
                          : switch (_raFilter) {
                              AbnormalityListFilter.open => 'RA Pending',
                              AbnormalityListFilter.completed => 'RA Done',
                              AbnormalityListFilter.all => 'Total',
                              _ => null,
                            },
                      onTotal: () => _setReportScope(),
                      onMatching: () => _jumpTo(_resultsAnchor),
                      onRaPending: () =>
                          _setReportScope(status: AbnormalityListFilter.open),
                      onRaCompleted: () => _setReportScope(
                        status: AbnormalityListFilter.completed,
                      ),
                      onCritical: () => _setReportScope(
                        severity: AbnormalitySeverity.critical,
                      ),
                      total: records.length,
                      filtered: filtered.length,
                      raPending: records
                          .where(
                            (record) =>
                                record.reannealingStatus ==
                                    ReannealingStatus.pendingDecision ||
                                record.reannealingStatus ==
                                    ReannealingStatus.required,
                          )
                          .length,
                      raCompleted: records
                          .where(
                            (record) =>
                                record.reannealingStatus ==
                                ReannealingStatus.completed,
                          )
                          .length,
                      critical: records
                          .where(
                            (record) =>
                                record.severity == AbnormalitySeverity.critical,
                          )
                          .length,
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _FiltersCard(
                      searchController: _searchController,
                      categoryFilter: _categoryFilter,
                      severityFilter: _severityFilter,
                      raFilter: _raFilter,
                      onSearchChanged: (value) {
                        setState(() {
                          _historyCharge = null;
                          _searchQuery = value;
                          _visibleLimit = businessListPageSize;
                        });
                      },
                      onCategoryChanged: (value) {
                        setState(() {
                          _historyCharge = null;
                          _categoryFilter = value;
                          _visibleLimit = businessListPageSize;
                        });
                      },
                      onSeverityChanged: (value) {
                        setState(() {
                          _historyCharge = null;
                          _severityFilter = value;
                          _visibleLimit = businessListPageSize;
                        });
                      },
                      onRaChanged: (value) {
                        setState(() {
                          _historyCharge = null;
                          _raFilter = value;
                          _visibleLimit = businessListPageSize;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _historyCharge = null;
                          _searchQuery = '';
                          _searchController.clear();
                          _categoryFilter = null;
                          _severityFilter = null;
                          _raFilter = AbnormalityListFilter.open;
                          _visibleLimit = businessListPageSize;
                        });
                      },
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    _InsightGrid(records: filtered),
                    const SizedBox(height: BafSpacing.lg),
                    if (history != null) ...[
                      AbnormalityChargeHistoryCard(
                        key: _historyAnchor,
                        chargeNumber: _historyCharge!,
                        history: history,
                        onClose: () => _setReportScope(),
                      ),
                      const SizedBox(height: BafSpacing.lg),
                    ],
                    Semantics(
                      key: _resultsAnchor,
                      header: true,
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: BafSpacing.md),
                        child: Text(
                          history == null
                              ? '${filtered.length} matching abnormalities'
                              : '${filtered.length} abnormalities in this charge history',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ],
                ),
                if (filtered.isEmpty)
                  const _StateCard(
                    icon: Icons.manage_search_rounded,
                    title: 'No matching abnormalities',
                    message:
                        'Change filters or pull to refresh. The report only shows locally available, non-deleted records.',
                  )
                else
                  ...visible.map(
                    (record) => KeyedSubtree(
                      key: ValueKey(
                        'abnormality-report-row-${record.firestoreId ?? record.id}',
                      ),
                      child: _ReportRecordCard(
                        record: record,
                        onChargeHistory: _showChargeHistory,
                      ),
                    ),
                  ),
                IncrementalListFooter(
                  visibleCount: visible.length,
                  totalCount: filtered.length,
                  onShowMore: () =>
                      setState(() => _visibleLimit += businessListPageSize),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<ChargeAbnormality> _applyFilters(List<ChargeAbnormality> records) {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = records.where((record) {
      if (_categoryFilter != null && record.category != _categoryFilter) {
        return false;
      }

      if (_severityFilter != null && record.severity != _severityFilter) {
        return false;
      }

      if (!_raFilter.includes(record)) {
        return false;
      }

      if (query.isEmpty) return true;

      final text = [
        record.sourceChargeNo.toString(),
        record.reannealedToChargeNo?.toString() ?? '',
        record.abnormalityTypeCode,
        record.abnormalityTypeTitle,
        record.observedReason,
        record.description ?? '',
        record.component ?? '',
        record.affectedAssetsLabel,
        record.possibleRootReasonNotes ?? '',
        record.loggedByName ?? '',
      ].join(' ').toLowerCase();

      return text.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final byDate = b.loggedAt.compareTo(a.loggedAt);
      return byDate != 0
          ? byDate
          : (a.firestoreId ?? '${a.id}').compareTo(b.firestoreId ?? '${b.id}');
    });
    return filtered;
  }
}

// ─────────────────────────────────────────────────────────────
// UI WIDGETS
// ─────────────────────────────────────────────────────────────

class _FiltersCard extends StatelessWidget {
  final TextEditingController searchController;
  final AbnormalityCategory? categoryFilter;
  final AbnormalitySeverity? severityFilter;
  final AbnormalityListFilter raFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AbnormalityCategory?> onCategoryChanged;
  final ValueChanged<AbnormalitySeverity?> onSeverityChanged;
  final ValueChanged<AbnormalityListFilter> onRaChanged;
  final VoidCallback onClear;

  const _FiltersCard({
    required this.searchController,
    required this.categoryFilter,
    required this.severityFilter,
    required this.raFilter,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onSeverityChanged,
    required this.onRaChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.filter_alt_rounded,
            title: 'Filters',
            subtitle:
                'Search by charge, abnormality type, reason, asset, component or user.',
            color: BafColors.sync,
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: searchController,
            decoration:
                _inputDecoration(
                  label: 'Search',
                  hint: 'Charge no., RA charge, reason, asset...',
                ).copyWith(
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: BafColors.textSecondary,
                  ),
                ),
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              _FilterDropdown<AbnormalityCategory>(
                label: 'Category',
                value: categoryFilter,
                values: AbnormalityCategory.values,
                itemLabel: _categoryLabel,
                onChanged: onCategoryChanged,
              ),
              _FilterDropdown<AbnormalitySeverity>(
                label: 'Severity',
                value: severityFilter,
                values: AbnormalitySeverity.values,
                itemLabel: _severityLabel,
                onChanged: onSeverityChanged,
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<AbnormalityListFilter>(
                  key: ValueKey(raFilter),
                  initialValue: raFilter,
                  isExpanded: true,
                  decoration: _inputDecoration(label: 'Status'),
                  items: [
                    for (final filter in AbnormalityListFilter.values)
                      DropdownMenuItem(
                        value: filter,
                        child: Text(filter.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onRaChanged(value);
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          const Text(
            'Open means an RA decision or action is pending. Quality adjudication is tracked separately.',
            style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<T?>(
        key: ValueKey((label, value)),
        isExpanded: true,
        initialValue: value,
        decoration: _inputDecoration(label: label),
        items: [
          DropdownMenuItem<T?>(value: null, child: const Text('All')),
          ...values.map(
            (item) =>
                DropdownMenuItem<T?>(value: item, child: Text(itemLabel(item))),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _InsightGrid extends StatelessWidget {
  final List<ChargeAbnormality> records;

  const _InsightGrid({required this.records});

  @override
  Widget build(BuildContext context) {
    final byCategory = _countBy<AbnormalityCategory>(
      records,
      (record) => record.category,
    );

    final byRoot = _countBy<RootReasonCategory>(
      records,
      (record) => record.possibleRootReasonCategory,
    );

    final byAsset = <AssetType, int>{};
    for (final record in records) {
      for (final asset in record.affectedAssets) {
        byAsset[asset.assetType] = (byAsset[asset.assetType] ?? 0) + 1;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 760;

        final cards = [
          _BreakdownCard<AbnormalityCategory>(
            title: 'By Category',
            icon: Icons.category_rounded,
            color: BafColors.charges,
            values: byCategory,
            labelBuilder: _categoryLabel,
          ),
          _BreakdownCard<RootReasonCategory>(
            title: 'By Root Reason',
            icon: Icons.manage_search_rounded,
            color: BafColors.audit,
            values: byRoot,
            labelBuilder: _rootReasonCategoryLabel,
          ),
          _BreakdownCard<AssetType>(
            title: 'By Asset Type',
            icon: Icons.precision_manufacturing_rounded,
            color: BafColors.assets,
            values: byAsset,
            labelBuilder: _assetTypeLabel,
          ),
        ];

        if (!useTwoColumns) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: BafSpacing.md),
              cards[1],
              const SizedBox(height: BafSpacing.md),
              cards[2],
            ],
          );
        }

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: BafSpacing.md),
                Expanded(child: cards[1]),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            cards[2],
          ],
        );
      },
    );
  }

  static Map<T, int> _countBy<T>(
    List<ChargeAbnormality> records,
    T Function(ChargeAbnormality record) selector,
  ) {
    final result = <T, int>{};

    for (final record in records) {
      final key = selector(record);
      result[key] = (result[key] ?? 0) + 1;
    }

    return result;
  }
}

class _BreakdownCard<T> extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Map<T, int> values;
  final String Function(T value) labelBuilder;

  const _BreakdownCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.values,
    required this.labelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: icon,
            title: title,
            subtitle: entries.isEmpty
                ? 'No records in current filter.'
                : 'Top contributors in current filter.',
            color: color,
          ),
          const SizedBox(height: BafSpacing.md),
          if (entries.isEmpty)
            const Text(
              'No data',
              style: TextStyle(color: BafColors.textSecondary, fontSize: 13),
            )
          else
            ...entries.take(6).map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        labelBuilder(entry.key),
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    StatusBadge(
                      label: '${entry.value}',
                      color: color,
                      icon: Icons.numbers_rounded,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ReportRecordCard extends StatelessWidget {
  final ChargeAbnormality record;

  final ValueChanged<int> onChargeHistory;

  const _ReportRecordCard({
    required this.record,
    required this.onChargeHistory,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(record.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: BafSpacing.md),
      child: DashboardCard(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(BafRadius.large),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(BafSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          StatusBadge(
                            label: record.abnormalityTypeCode,
                            color: BafColors.admin,
                            icon: Icons.tag_rounded,
                          ),
                          StatusBadge(
                            label: _categoryLabel(record.category),
                            color: categoryColor,
                            icon: Icons.category_rounded,
                          ),
                          StatusBadge(
                            label: _severityLabel(record.severity),
                            color: _severityColor(record.severity),
                            icon: Icons.priority_high_rounded,
                          ),
                          StatusBadge(
                            label: _raStatusLabel(record.reannealingStatus),
                            color: _raStatusColor(record.reannealingStatus),
                            icon: Icons.repeat_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Text(
                        record.abnormalityTypeTitle,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: BafSpacing.xs),
                      Text(
                        record.observedReason,
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 13,
                          height: 1.28,
                        ),
                      ),
                      const SizedBox(height: BafSpacing.md),
                      Wrap(
                        spacing: BafSpacing.sm,
                        runSpacing: BafSpacing.sm,
                        children: [
                          _ChargeHistoryButton(
                            charge: record.sourceChargeNo,
                            label: 'Old charge ${record.sourceChargeNo}',
                            onPressed: () =>
                                onChargeHistory(record.sourceChargeNo),
                          ),
                          if (record.reannealedToChargeNo != null)
                            _ChargeHistoryButton(
                              charge: record.reannealedToChargeNo!,
                              label:
                                  'New charge ${record.reannealedToChargeNo}',
                              onPressed: () =>
                                  onChargeHistory(record.reannealedToChargeNo!),
                            ),
                          _SoftChip(
                            icon: Icons.precision_manufacturing_rounded,
                            label: record.affectedAssetsLabel,
                          ),
                          _SoftChip(
                            icon: Icons.manage_search_rounded,
                            label: _rootReasonCategoryLabel(
                              record.possibleRootReasonCategory,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: BafSpacing.md),
                      if (record.reannealingStatus ==
                          ReannealingStatus.completed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: BafSpacing.xs),
                          child: Text(
                            record.assessment?.raPerformedAt == null
                                ? 'RA date: not recorded'
                                : 'RA date: ${DateFormat('dd MMM yyyy, HH:mm').format(record.assessment!.raPerformedAt!.toLocal())}',
                            style: const TextStyle(
                              color: BafColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      Text(
                        'Logged ${DateFormat('dd MMM yyyy, HH:mm').format(record.loggedAt)}'
                        '${record.loggedByName == null ? '' : ' by ${record.loggedByName}'}',
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChargeHistoryButton extends StatelessWidget {
  const _ChargeHistoryButton({
    required this.charge,
    required this.label,
    required this.onPressed,
  });
  final int charge;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'View recorded RA history for charge $charge',
    child: OutlinedButton.icon(
      key: ValueKey('abnormality-history-charge-$charge'),
      onPressed: onPressed,
      icon: const Icon(Icons.account_tree_outlined, size: 16),
      label: Text(label),
    ),
  );
}

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16, color: BafColors.assets),
      label: Text(label),
      labelStyle: const TextStyle(
        color: BafColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: BafColors.assets.withValues(alpha: 0.08),
      side: BorderSide(color: BafColors.assets.withValues(alpha: 0.16)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(BafRadius.medium),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: BafSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Text(
                subtitle,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? BafColors.charges;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: DashboardCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: effectiveColor),
              const SizedBox(height: BafSpacing.md),
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                message,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

InputDecoration _inputDecoration({required String label, String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: BafColors.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.navySoft, width: 1.4),
    ),
  );
}

String _categoryLabel(AbnormalityCategory category) {
  switch (category) {
    case AbnormalityCategory.process:
      return 'Process';
    case AbnormalityCategory.equipment:
      return 'Equipment';
    case AbnormalityCategory.resultQuality:
      return 'Result / Quality';
    case AbnormalityCategory.reannealing:
      return 'Re-annealing';
    case AbnormalityCategory.other:
      return 'Other';
  }
}

String _severityLabel(AbnormalitySeverity severity) {
  switch (severity) {
    case AbnormalitySeverity.low:
      return 'Low';
    case AbnormalitySeverity.medium:
      return 'Medium';
    case AbnormalitySeverity.high:
      return 'High';
    case AbnormalitySeverity.critical:
      return 'Critical';
  }
}

String _raStatusLabel(ReannealingStatus status) {
  switch (status) {
    case ReannealingStatus.notApplicable:
      return 'Not Applicable';
    case ReannealingStatus.pendingDecision:
      return 'Pending Decision';
    case ReannealingStatus.required:
      return 'Required';
    case ReannealingStatus.notRequired:
      return 'Not Required';
    case ReannealingStatus.completed:
      return 'Completed';
  }
}

String _rootReasonCategoryLabel(RootReasonCategory category) {
  switch (category) {
    case RootReasonCategory.unknown:
      return 'Unknown';
    case RootReasonCategory.baseRelated:
      return 'Base Related';
    case RootReasonCategory.furnaceRelated:
      return 'Furnace Related';
    case RootReasonCategory.forceCoolerRelated:
      return 'Force Cooler Related';
    case RootReasonCategory.atmosphereRelated:
      return 'Atmosphere Related';
    case RootReasonCategory.thermocoupleTemperature:
      return 'Thermocouple / Temperature';
    case RootReasonCategory.cycleInterruption:
      return 'Cycle Interruption';
    case RootReasonCategory.materialOrCoilCondition:
      return 'Material / Coil Condition';
    case RootReasonCategory.operationsRelated:
      return 'Operations Related';
    case RootReasonCategory.other:
      return 'Other';
  }
}

String _assetTypeLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'Base';
    case AssetType.furnace:
      return 'Furnace';
    case AssetType.forceCooler:
      return 'Force Cooler';
    case AssetType.innerCover:
      return 'Inner Cover';
    case AssetType.governedCustom:
      return 'Governed Asset';
  }
}

Color _categoryColor(AbnormalityCategory category) {
  switch (category) {
    case AbnormalityCategory.process:
      return BafColors.planned;
    case AbnormalityCategory.equipment:
      return BafColors.maintenance;
    case AbnormalityCategory.resultQuality:
      return BafColors.charges;
    case AbnormalityCategory.reannealing:
      return BafColors.audit;
    case AbnormalityCategory.other:
      return BafColors.admin;
  }
}

Color _severityColor(AbnormalitySeverity severity) {
  switch (severity) {
    case AbnormalitySeverity.low:
      return BafColors.success;
    case AbnormalitySeverity.medium:
      return BafColors.warning;
    case AbnormalitySeverity.high:
      return BafColors.maintenance;
    case AbnormalitySeverity.critical:
      return BafColors.danger;
  }
}

Color _raStatusColor(ReannealingStatus status) {
  switch (status) {
    case ReannealingStatus.notApplicable:
      return BafColors.textSecondary;
    case ReannealingStatus.pendingDecision:
      return BafColors.warning;
    case ReannealingStatus.required:
      return BafColors.audit;
    case ReannealingStatus.notRequired:
      return BafColors.admin;
    case ReannealingStatus.completed:
      return BafColors.success;
  }
}
