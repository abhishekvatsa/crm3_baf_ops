// FILE: lib/features/abnormalities/presentation/abnormality_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/dashboard_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../data/abnormality_model.dart';
import '../providers/abnormality_provider.dart';

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

  String _searchQuery = '';
  AbnormalityCategory? _categoryFilter;
  ReannealingStatus? _raFilter;
  AbnormalitySeverity? _severityFilter;

  Future<List<ChargeAbnormality>> _load() {
    return ref.read(abnormalityRepositoryProvider).getAllAbnormalities();
  }

  void _ensureLoadedFor(AppUser actor) {
    if (_future != null && _futureActorUid == actor.uid) return;
    _futureActorUid = actor.uid;
    _future = _load();
  }

  void _clearLoadedReport() {
    _futureActorUid = null;
    _future = null;
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

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading && !actorAsync.hasValue) {
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
          final filtered = _applyFilters(records);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(BafSpacing.lg),
              children: [
                _HeaderCard(
                  total: records.length,
                  filtered: filtered.length,
                  raPending:
                      records
                          .where(
                            (record) =>
                                record.reannealingStatus ==
                                    ReannealingStatus.pendingDecision ||
                                record.reannealingStatus ==
                                    ReannealingStatus.required,
                          )
                          .length,
                  raCompleted:
                      records
                          .where(
                            (record) =>
                                record.reannealingStatus ==
                                ReannealingStatus.completed,
                          )
                          .length,
                  critical:
                      records
                          .where(
                            (record) =>
                                record.severity == AbnormalitySeverity.critical,
                          )
                          .length,
                ),
                const SizedBox(height: BafSpacing.lg),
                _FiltersCard(
                  searchQuery: _searchQuery,
                  categoryFilter: _categoryFilter,
                  severityFilter: _severityFilter,
                  raFilter: _raFilter,
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  onCategoryChanged: (value) {
                    setState(() => _categoryFilter = value);
                  },
                  onSeverityChanged: (value) {
                    setState(() => _severityFilter = value);
                  },
                  onRaChanged: (value) {
                    setState(() => _raFilter = value);
                  },
                  onClear: () {
                    setState(() {
                      _searchQuery = '';
                      _categoryFilter = null;
                      _severityFilter = null;
                      _raFilter = null;
                    });
                  },
                ),
                const SizedBox(height: BafSpacing.lg),
                _InsightGrid(records: filtered),
                const SizedBox(height: BafSpacing.lg),
                if (filtered.isEmpty)
                  const _StateCard(
                    icon: Icons.manage_search_rounded,
                    title: 'No matching abnormalities',
                    message:
                        'Change filters or pull to refresh. The report only shows locally available, non-deleted records.',
                  )
                else
                  ...filtered.map(
                    (record) => _ReportRecordCard(record: record),
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

    final filtered =
        records.where((record) {
          if (_categoryFilter != null && record.category != _categoryFilter) {
            return false;
          }

          if (_severityFilter != null && record.severity != _severityFilter) {
            return false;
          }

          if (_raFilter != null && record.reannealingStatus != _raFilter) {
            return false;
          }

          if (query.isEmpty) return true;

          final text =
              [
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

    filtered.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return filtered;
  }
}

// ─────────────────────────────────────────────────────────────
// UI WIDGETS
// ─────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final int total;
  final int filtered;
  final int raPending;
  final int raCompleted;
  final int critical;

  const _HeaderCard({
    required this.total,
    required this.filtered,
    required this.raPending,
    required this.raCompleted,
    required this.critical,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      backgroundColor: BafColors.navy,
      borderColor: BafColors.navySoft.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.white),
              ),
              const SizedBox(width: BafSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Abnormality intelligence',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: BafSpacing.xs),
                    Text(
                      'Review recurrence, RA load, critical events and affected-asset patterns.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              _MetricPill(label: 'Total', value: total),
              _MetricPill(label: 'Shown', value: filtered),
              _MetricPill(label: 'RA Pending', value: raPending),
              _MetricPill(label: 'RA Done', value: raCompleted),
              _MetricPill(label: 'Critical', value: critical),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int value;

  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 82),
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final String searchQuery;
  final AbnormalityCategory? categoryFilter;
  final AbnormalitySeverity? severityFilter;
  final ReannealingStatus? raFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<AbnormalityCategory?> onCategoryChanged;
  final ValueChanged<AbnormalitySeverity?> onSeverityChanged;
  final ValueChanged<ReannealingStatus?> onRaChanged;
  final VoidCallback onClear;

  const _FiltersCard({
    required this.searchQuery,
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
            decoration: _inputDecoration(
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
              _FilterDropdown<ReannealingStatus>(
                label: 'RA Status',
                value: raFilter,
                values: ReannealingStatus.values,
                itemLabel: _raStatusLabel,
                onChanged: onRaChanged,
              ),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Clear'),
              ),
            ],
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
    final entries =
        values.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: icon,
            title: title,
            subtitle:
                entries.isEmpty
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

  const _ReportRecordCard({required this.record});

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
                          _SoftChip(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Old charge ${record.sourceChargeNo}',
                          ),
                          if (record.reannealedToChargeNo != null)
                            _SoftChip(
                              icon: Icons.repeat_rounded,
                              label:
                                  'New charge ${record.reannealedToChargeNo}',
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
