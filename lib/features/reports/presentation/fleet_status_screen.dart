import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/providers/plant_asset_overview_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../operational_events/presentation/operational_events_screen.dart';
import '../../operational_events/providers/operational_event_provider.dart';
import '../models/operations_report.dart';
import '../providers/operations_report_provider.dart';

class FleetStatusScreen extends ConsumerStatefulWidget {
  const FleetStatusScreen({super.key});

  @override
  ConsumerState<FleetStatusScreen> createState() => _FleetStatusScreenState();
}

class _FleetStatusScreenState extends ConsumerState<FleetStatusScreen> {
  String? _assetClassId;
  String? _assetInstanceId;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _startDate = _endDate.subtract(const Duration(days: 29));
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(assetClassesProvider);
    final assetsAsync = ref.watch(allAssetInstancesProvider);
    final classes = classesAsync.value ?? const [];
    final assets = assetsAsync.value ?? const [];
    final currentClassId = _assetClassId;
    final currentAssetId = _assetInstanceId;
    final selection =
        classesAsync.hasValue && assetsAsync.hasValue
            ? reconcileOperationsReportSelection(
              assetClassId: currentClassId,
              assetInstanceId: currentAssetId,
              classes: classes,
              assets: assets,
            )
            : OperationsReportSelection(
              assetClassId: currentClassId,
              assetInstanceId: currentAssetId,
            );
    if (selection.assetClassId != currentClassId ||
        selection.assetInstanceId != currentAssetId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _assetClassId != currentClassId ||
            _assetInstanceId != currentAssetId) {
          return;
        }
        setState(() {
          _assetClassId = selection.assetClassId;
          _assetInstanceId = selection.assetInstanceId;
        });
      });
    }
    final filter = OperationsReportFilter(
      startDate: _startDate,
      endDate: _endDate,
      assetClassId: selection.assetClassId,
      assetInstanceId: selection.assetInstanceId,
    );
    final reportAsync = ref.watch(operationsReportProvider(filter));

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Operations report'),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        surfaceTintColor: BafColors.card,
        actions: [
          IconButton(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OperationalEventsScreen(),
                  ),
                ),
            tooltip: 'Operational events',
            icon: const Icon(Icons.crisis_alert_outlined),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _ErrorState(
              message: error.toString(),
              onRetry: () => _invalidateReportSources(ref, filter),
            ),
        data:
            (report) => RefreshIndicator(
              onRefresh: () async {
                _invalidateReportSources(ref, filter);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _ReportFilters(
                    classes: classes,
                    assets: assets,
                    assetClassId: selection.assetClassId,
                    assetInstanceId: selection.assetInstanceId,
                    startDate: _startDate,
                    endDate: _endDate,
                    onClassChanged: (value) {
                      setState(() {
                        _assetClassId = value;
                        _assetInstanceId = null;
                      });
                    },
                    onAssetChanged:
                        (value) => setState(() => _assetInstanceId = value),
                    onDatesChanged: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: 'Current plant picture',
                    subtitle:
                        selection.assetClassId == null
                            ? 'All governed asset classes'
                            : classes
                                    .where(
                                      (item) =>
                                          item.id == selection.assetClassId,
                                    )
                                    .map((item) => item.name)
                                    .firstOrNull ??
                                'Selected class',
                  ),
                  const SizedBox(height: 10),
                  _MetricGrid(
                    metrics: [
                      _MetricData(
                        'Assets',
                        report.assetCount,
                        Icons.precision_manufacturing_outlined,
                        BafColors.assets,
                      ),
                      _MetricData(
                        'Available',
                        report.availableAssetCount,
                        Icons.check_circle_outline,
                        BafColors.success,
                      ),
                      _MetricData(
                        'Under maintenance',
                        report.underMaintenanceAssetCount,
                        Icons.build_outlined,
                        BafColors.maintenance,
                      ),
                      _MetricData(
                        'Down / unfit',
                        report.downAssetCount + report.unfitAssetCount,
                        Icons.warning_amber_rounded,
                        BafColors.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Work in period',
                    subtitle:
                        '${DateFormat('dd MMM yyyy').format(_startDate)} to ${DateFormat('dd MMM yyyy').format(_endDate)}',
                  ),
                  const SizedBox(height: 10),
                  _MetricGrid(
                    metrics: [
                      _MetricData(
                        'Issues',
                        report.issueCount,
                        Icons.report_problem_outlined,
                        BafColors.maintenance,
                        detail: '${report.openIssueCount} open',
                      ),
                      _MetricData(
                        'Critical issues',
                        report.criticalIssueCount,
                        Icons.priority_high_rounded,
                        BafColors.danger,
                      ),
                      _MetricData(
                        'Planned jobs',
                        report.plannedJobCount,
                        Icons.event_note_outlined,
                        BafColors.planned,
                        detail:
                            '${report.openPlannedJobCount} open · '
                            '${report.completedPlannedJobCount} complete · '
                            '${report.cancelledPlannedJobCount} cancelled',
                      ),
                      _MetricData(
                        'Disruptions',
                        report.disruptionCount,
                        Icons.crisis_alert_outlined,
                        BafColors.warning,
                        detail:
                            '${report.openDisruptionCount} open · ${_formatDuration(report.disruptionDuration)}',
                      ),
                    ],
                  ),
                  if (report.classSummaries.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle(
                      title: 'Asset-class summary',
                      subtitle: 'Health, issues, planned work and disruptions',
                    ),
                    const SizedBox(height: 8),
                    ...report.classSummaries.map(
                      (summary) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ClassSummaryCard(summary: summary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _FailureSection(
                    topComponents: report.topComponents,
                    topSubsystemPaths: report.topSubsystemPaths,
                  ),
                  const SizedBox(height: 24),
                  _OpenIssuesSection(issues: report.openIssues),
                  if (report.eventOccurrences.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _DisruptionSection(occurrences: report.eventOccurrences),
                  ],
                  const SizedBox(height: 20),
                  _SourceWindowNotice(report: report),
                ],
              ),
            ),
      ),
    );
  }
}

class OperationsReportSelection {
  const OperationsReportSelection({
    required this.assetClassId,
    required this.assetInstanceId,
  });

  final String? assetClassId;
  final String? assetInstanceId;
}

OperationsReportSelection reconcileOperationsReportSelection({
  required String? assetClassId,
  required String? assetInstanceId,
  required List<AssetClassRecord> classes,
  required List<AssetInstanceRecord> assets,
}) {
  final activeClassIds = {
    for (final item in classes)
      if (item.isActive) item.id,
  };
  final resolvedClassId =
      assetClassId != null && activeClassIds.contains(assetClassId)
          ? assetClassId
          : null;
  final selectedAsset =
      assetInstanceId == null
          ? null
          : assets.where((item) => item.id == assetInstanceId).firstOrNull;
  final assetRemainsAvailable =
      selectedAsset != null &&
      selectedAsset.isActive &&
      activeClassIds.contains(selectedAsset.assetClassId) &&
      (resolvedClassId == null ||
          selectedAsset.assetClassId == resolvedClassId);
  return OperationsReportSelection(
    assetClassId: resolvedClassId,
    assetInstanceId: assetRemainsAvailable ? assetInstanceId : null,
  );
}

void _invalidateReportSources(WidgetRef ref, OperationsReportFilter filter) {
  final period = (
    startInclusive: filter.startInclusive,
    endExclusive: filter.endExclusive,
  );
  ref.invalidate(operationsReportTicketsProvider(period));
  ref.invalidate(operationsReportExecutionsProvider(period));
  ref.invalidate(operationalEventsForReportsProvider);
  ref.invalidate(assetClassesProvider);
  ref.invalidate(allAssetInstancesProvider);
  ref.invalidate(assetOperationalConditionsProvider);
  ref.invalidate(equipmentStatusProvider(null));
  ref.invalidate(plantAssetOverviewProvider);
  ref.invalidate(operationsReportClockProvider);
  ref.invalidate(operationsReportProvider(filter));
}

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.classes,
    required this.assets,
    required this.assetClassId,
    required this.assetInstanceId,
    required this.startDate,
    required this.endDate,
    required this.onClassChanged,
    required this.onAssetChanged,
    required this.onDatesChanged,
  });

  final List<AssetClassRecord> classes;
  final List<AssetInstanceRecord> assets;
  final String? assetClassId;
  final String? assetInstanceId;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onAssetChanged;
  final void Function(DateTime start, DateTime end) onDatesChanged;

  @override
  Widget build(BuildContext context) {
    final availableClasses = classes.where((item) => item.isActive).toList();
    final availableAssets =
        assets
            .where(
              (item) =>
                  item.isActive &&
                  (assetClassId == null || item.assetClassId == assetClassId),
            )
            .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scope and period',
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: ValueKey<String>('asset-class-${assetClassId ?? 'all'}'),
            initialValue: assetClassId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Asset class',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All asset classes'),
              ),
              ...availableClasses.map(
                (item) => DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: onClassChanged,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            key: ValueKey<String>(
              'physical-asset-${assetClassId ?? 'all'}-'
              '${assetInstanceId ?? 'all'}',
            ),
            initialValue: assetInstanceId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Physical asset',
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All assets in scope'),
              ),
              ...availableAssets.map(
                (item) => DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text(
                    '${item.assetClassName} ${item.assetNumber} · ${item.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onAssetChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Start date',
                  value: startDate,
                  onTap: () async {
                    final date = await _pickDate(context, startDate);
                    if (date != null && !date.isAfter(endDate)) {
                      onDatesChanged(date, endDate);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'End date',
                  value: endDate,
                  onTap: () async {
                    final date = await _pickDate(context, endDate);
                    if (date != null && !date.isBefore(startDate)) {
                      onDatesChanged(startDate, date);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PeriodButton(label: '7 days', onPressed: () => _applyDays(7)),
              _PeriodButton(label: '30 days', onPressed: () => _applyDays(30)),
              _PeriodButton(label: '90 days', onPressed: () => _applyDays(90)),
              _PeriodButton(
                label: 'This year',
                onPressed: () {
                  final now = DateTime.now();
                  onDatesChanged(
                    DateTime(now.year),
                    DateTime(now.year, now.month, now.day),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyDays(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    onDatesChanged(end.subtract(Duration(days: days - 1)), end);
  }

  static Future<DateTime?> _pickDate(BuildContext context, DateTime current) =>
      showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(BafRadius.medium),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      child: Text(DateFormat('dd MMM yyyy').format(value)),
    ),
  );
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: BafColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        subtitle,
        style: const TextStyle(color: BafColors.textSecondary, fontSize: 12),
      ),
    ],
  );
}

class _MetricData {
  const _MetricData(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.detail,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String? detail;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 680 ? 4 : 2;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            metrics
                .map(
                  (metric) =>
                      SizedBox(width: width, child: _Metric(metric: metric)),
                )
                .toList(),
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.metric});
  final _MetricData metric;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 116),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: metric.color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(metric.icon, color: metric.color, size: 21),
        const Spacer(),
        Text(
          '${metric.value}',
          style: TextStyle(
            color: metric.color,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          metric.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        if (metric.detail != null)
          Text(
            metric.detail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 10,
            ),
          ),
      ],
    ),
  );
}

class _ClassSummaryCard extends StatelessWidget {
  const _ClassSummaryCard({required this.summary});
  final AssetClassReportSummary summary;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.assetClassName,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _CompactCount('Assets', summary.assetCount),
            _CompactCount('Available', summary.availableCount),
            _CompactCount('Maintenance', summary.underMaintenanceCount),
            _CompactCount('Down', summary.downCount),
            _CompactCount('Unfit', summary.unfitCount),
            _CompactCount('Issues', summary.issueCount),
            _CompactCount('Open issues', summary.openIssueCount),
            _CompactCount('PM jobs', summary.plannedJobCount),
            _CompactCount('Open PM', summary.openPlannedJobCount),
            _CompactCount('Disruptions', summary.disruptionCount),
          ],
        ),
      ],
    ),
  );
}

class _CompactCount extends StatelessWidget {
  const _CompactCount(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: BafColors.background,
      borderRadius: BorderRadius.circular(BafRadius.small),
    ),
    child: Text(
      '$label $value',
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _FailureSection extends StatelessWidget {
  const _FailureSection({
    required this.topComponents,
    required this.topSubsystemPaths,
  });
  final List<CountedReportLabel> topComponents;
  final List<CountedReportLabel> topSubsystemPaths;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionTitle(
        title: 'Failure concentration',
        subtitle:
            'Issue frequency by governed component and recorded subsystem path',
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (context, constraints) {
          final children = [
            _RankedList(title: 'Top components', rows: topComponents),
            _RankedList(
              title: 'Top recorded subsystem paths',
              rows: topSubsystemPaths,
            ),
          ];
          if (constraints.maxWidth >= 680) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 10),
                Expanded(child: children[1]),
              ],
            );
          }
          return Column(
            children: [children[0], const SizedBox(height: 10), children[1]],
          );
        },
      ),
    ],
  );
}

class _RankedList extends StatelessWidget {
  const _RankedList({required this.title, required this.rows});
  final String title;
  final List<CountedReportLabel> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          const Text(
            'No classified issues in this period.',
            style: TextStyle(color: BafColors.textSecondary, fontSize: 12),
          )
        else
          ...rows.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${entry.value.count}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _OpenIssuesSection extends StatelessWidget {
  const _OpenIssuesSection({required this.issues});
  final List<MaintenanceRecord> issues;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        title: 'Still-open issues',
        subtitle: '${issues.length} unresolved in the selected scope',
      ),
      const SizedBox(height: 8),
      if (issues.isEmpty)
        const _QuietEmpty(text: 'No unresolved issues in this period.')
      else
        ...issues
            .take(50)
            .map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: BafColors.card,
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color:
                          issue.isCritical
                              ? BafColors.danger.withValues(alpha: 0.28)
                              : BafColors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        issue.isCritical
                            ? Icons.priority_high_rounded
                            : Icons.report_problem_outlined,
                        color:
                            issue.isCritical
                                ? BafColors.danger
                                : BafColors.maintenance,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              issue.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${_assetTypeLabel(issue.assetType)} ${issue.assetNumber}'
                              '${issue.subsystem == null ? '' : ' · ${issue.subsystem}'}'
                              '${issue.component == null ? '' : ' · ${issue.component}'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: BafColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'Since ${DateFormat('dd MMM yyyy').format(issue.startDate)} · ${issue.routedTo.name}',
                              style: const TextStyle(
                                color: BafColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      if (issues.length > 50)
        Text(
          '${issues.length - 50} more open issues are included in the totals.',
          style: const TextStyle(color: BafColors.textSecondary, fontSize: 12),
        ),
    ],
  );
}

class _DisruptionSection extends StatelessWidget {
  const _DisruptionSection({required this.occurrences});
  final List<OperationalEventReportOccurrence> occurrences;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        title: 'Operational disruptions',
        subtitle:
            '${occurrences.length} occurrences overlapped the selected period',
      ),
      const SizedBox(height: 8),
      ...occurrences
          .take(30)
          .map(
            (occurrence) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                occurrence.isOpen ? Icons.crisis_alert : Icons.task_alt_rounded,
                color:
                    occurrence.isOpen ? BafColors.warning : BafColors.success,
              ),
              title: Text(
                occurrence.interval.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${occurrence.interval.eventType.label} · ${occurrence.interval.severity.label} · ${DateFormat('dd MMM, HH:mm').format(occurrence.interval.startedAt.toLocal())}',
                  ),
                  if (!occurrence.isOpen) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Resolved by ${occurrence.interval.resolvedByName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      occurrence.interval.resolutionNote ??
                          'Closure evidence unavailable',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
              trailing: Text(occurrence.isOpen ? 'Open' : 'Resolved'),
            ),
          ),
    ],
  );
}

class _SourceWindowNotice extends StatelessWidget {
  const _SourceWindowNotice({required this.report});
  final OperationsReport report;

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_outlined, size: 17, color: BafColors.textSecondary),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'All issue, planned-job and disruption records overlapping the selected period were evaluated.',
            style: TextStyle(
              color: BafColors.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuietEmpty extends StatelessWidget {
  const _QuietEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        const Icon(Icons.task_alt_rounded, color: BafColors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: BafColors.danger),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          IconButton(
            onPressed: onRetry,
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );
}

String _assetTypeLabel(AssetType type) => switch (type) {
  AssetType.base => 'Base',
  AssetType.furnace => 'Furnace',
  AssetType.forceCooler => 'Force cooler',
  AssetType.innerCover => 'Inner cover',
  AssetType.governedCustom => 'Governed asset',
};

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  if (hours < 24) return '${hours}h';
  final days = hours ~/ 24;
  final remainder = hours % 24;
  return remainder == 0 ? '${days}d' : '${days}d ${remainder}h';
}
