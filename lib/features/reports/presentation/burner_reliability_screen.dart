import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/data/burner_condition_round.dart';
import '../../assets/presentation/burner_condition_round_screen.dart';
import '../../assets/presentation/asset_timeline_screen.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/providers/burner_condition_round_provider.dart';
import '../../assets/services/burner_condition_round_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/domain/burner_lockout_case.dart';
import '../models/burner_reliability_report.dart';
import '../providers/operations_report_provider.dart';

class BurnerReliabilityScreen extends ConsumerWidget {
  const BurnerReliabilityScreen({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialAssetInstanceId,
  });

  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? initialAssetInstanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(currentAppUserProvider)
        .when(
          loading:
              () => BafScreenStateScaffold.loading(
                appBarTitle: 'Report access',
                appBarSubtitle: 'Verifying your approved reporting scope',
                appBarIcon: Icons.verified_user_outlined,
                accent: BafColors.maintenance,
                label: 'Checking report access',
              ),
          error:
              (_, _) => BafScreenStateScaffold.error(
                appBarTitle: 'Report access',
                appBarSubtitle: 'Verifying your approved reporting scope',
                appBarIcon: Icons.verified_user_outlined,
                accent: BafColors.maintenance,
                message: 'Report access could not be verified.',
              ),
          data: (actor) {
            if (actor == null || !actor.canViewReports) {
              return BafScreenStateScaffold.access(
                appBarTitle: 'Report access',
                appBarSubtitle: 'Approved operational reporting only',
                appBarIcon: Icons.verified_user_outlined,
                accent: BafColors.maintenance,
                title: 'Report access required',
                message: 'Approved report access is required.',
              );
            }
            return _BurnerReliabilityBody(
              actor: actor,
              initialStartDate: initialStartDate,
              initialEndDate: initialEndDate,
              initialAssetInstanceId: initialAssetInstanceId,
            );
          },
        );
  }
}

class _BurnerReliabilityBody extends ConsumerStatefulWidget {
  const _BurnerReliabilityBody({
    required this.actor,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.initialAssetInstanceId,
  });

  final AppUser actor;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? initialAssetInstanceId;

  @override
  ConsumerState<_BurnerReliabilityBody> createState() =>
      _BurnerReliabilityBodyState();
}

class _BurnerReliabilityBodyState
    extends ConsumerState<_BurnerReliabilityBody> {
  late DateTime _startDate;
  late DateTime _endDate;
  late String? _assetInstanceId;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _endDate = _dateOnly(widget.initialEndDate ?? today);
    _startDate = _dateOnly(
      widget.initialStartDate ?? _endDate.subtract(const Duration(days: 29)),
    );
    _assetInstanceId = widget.initialAssetInstanceId;
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(assetClassesProvider);
    final assetsAsync = ref.watch(allAssetInstancesProvider);
    if ((classesAsync.isLoading && !classesAsync.hasValue) ||
        (assetsAsync.isLoading && !assetsAsync.hasValue)) {
      return _shell(
        const BafLoadingPanel(
          label: 'Loading governed Furnace records',
          color: BafColors.maintenance,
        ),
      );
    }
    if ((classesAsync.hasError && !classesAsync.hasValue) ||
        (assetsAsync.hasError && !assetsAsync.hasValue)) {
      return _shell(
        _ReportError(
          message: 'Could not load governed Furnace records.',
          onRetry: () {
            ref.invalidate(assetClassesProvider);
            ref.invalidate(allAssetInstancesProvider);
          },
        ),
      );
    }

    final furnaceClasses = (classesAsync.value ?? const <AssetClassRecord>[])
        .where(
          (item) =>
              item.status == AssetHierarchyStatus.active &&
              item.legacyAssetTypeKey == AssetType.furnace.name,
        )
        .toList(growable: false);
    if (furnaceClasses.length != 1) {
      return _shell(
        const _ReportNotice(
          icon: Icons.rule_folder_outlined,
          title: 'Furnace authority needs reconciliation',
          message:
              'Exactly one active asset class must carry the Furnace legacy mapping.',
        ),
      );
    }
    final furnaceClass = furnaceClasses.single;
    final furnaces =
        (assetsAsync.value ?? const <AssetInstanceRecord>[])
            .where((item) => item.assetClassId == furnaceClass.id)
            .toList()
          ..sort(
            (left, right) => left.assetNumber.compareTo(right.assetNumber),
          );
    final selectedAsset = _findSelectedAsset(furnaces, _assetInstanceId);
    if (_assetInstanceId != null && selectedAsset == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _assetInstanceId != null) {
          setState(() => _assetInstanceId = null);
        }
      });
    }
    final period = (
      actorUid: widget.actor.uid,
      startInclusive: _startDate,
      endExclusive: _endDate.add(const Duration(days: 1)),
    );
    final roundsQuery = (
      startInclusive: period.startInclusive,
      endExclusive: period.endExclusive,
      assetInstanceId: selectedAsset?.id,
    );
    final ticketsAsync = ref.watch(operationsReportTicketsProvider(period));
    final roundsAsync = ref.watch(burnerConditionRoundsProvider(roundsQuery));
    if ((roundsAsync.isLoading && !roundsAsync.hasValue) ||
        (ticketsAsync.isLoading && !ticketsAsync.hasValue)) {
      return _shell(
        const BafLoadingPanel(
          label: 'Loading burner reliability evidence',
          color: BafColors.maintenance,
        ),
      );
    }
    if ((roundsAsync.hasError && !roundsAsync.hasValue) ||
        (ticketsAsync.hasError && !ticketsAsync.hasValue)) {
      return _shell(
        _ReportError(
          message: 'Could not load burner reliability evidence.',
          onRetry: () {
            ref.invalidate(operationsReportTicketsProvider(period));
            ref.invalidate(burnerConditionRoundsProvider(roundsQuery));
          },
        ),
      );
    }
    return _shell(
      Builder(
        builder: (context) {
          final scopedTickets = _scopeTickets(
            ticketsAsync.requireValue,
            selectedAsset,
          );
          final scopedRounds = _scopeRounds(
            roundsAsync.requireValue,
            selectedAsset,
          );
          final BurnerReliabilityReport report;
          try {
            report = buildBurnerReliabilityReport(scopedTickets, scopedRounds);
          } on StateError {
            return const _ReportNotice(
              icon: Icons.report_problem_outlined,
              title: 'Burner evidence needs repair',
              message:
                  'A classified burner record is incomplete or malformed. Reliability totals are withheld.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(assetClassesProvider);
              ref.invalidate(allAssetInstancesProvider);
              ref.invalidate(operationsReportTicketsProvider(period));
              ref.invalidate(burnerConditionRoundsProvider(roundsQuery));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.lg,
                BafSpacing.md,
                BafSpacing.lg,
                BafSpacing.xl,
              ),
              children: [
                _BurnerFilters(
                  furnaces: furnaces,
                  selectedAssetId: selectedAsset?.id,
                  startDate: _startDate,
                  endDate: _endDate,
                  onAssetChanged:
                      (value) => setState(() => _assetInstanceId = value),
                  onDateRangePressed: _selectDateRange,
                ),
                const SizedBox(height: BafSpacing.lg),
                _ReliabilityMetrics(report: report),
                const SizedBox(height: BafSpacing.sm),
                const Text(
                  burnerConditionRoundHistoryDisclosure,
                  style: TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: BafSpacing.xl),
                _ReportHeader(
                  count: report.rows.length,
                  selectedAsset: selectedAsset,
                ),
                const SizedBox(height: BafSpacing.sm),
                if (report.rows.isEmpty)
                  const _ReportNotice(
                    icon: Icons.local_fire_department_outlined,
                    title: 'No burner evidence in this period',
                    message:
                        'Change the date or Furnace filter to inspect another evidence window.',
                  )
                else
                  ...report.rows.map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: BafSpacing.sm),
                      child: _BurnerReliabilityCard(
                        row: row,
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder:
                                    (_) => AssetTimelineScreen(
                                      initialAssetType: AssetType.furnace,
                                      initialAssetNumber: row.furnaceNumber,
                                    ),
                              ),
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Scaffold _shell(Widget body) => Scaffold(
    backgroundColor: BafColors.background,
    appBar: AppBar(
      title: const BafAppBarTitle(
        title: 'Burner reliability',
        subtitle: 'Lockouts, readings and burner-block life',
        icon: Icons.local_fire_department_outlined,
        accent: BafColors.maintenance,
      ),
      actions: [
        if (widget.actor.canRecordBurnerConditionRound)
          IconButton(
            tooltip: 'Record burner round',
            onPressed: _openRoundForm,
            icon: const Icon(Icons.fact_check_outlined),
          ),
      ],
    ),
    body: body,
  );

  Future<void> _openRoundForm() async {
    final result = await Navigator.of(context).push<BurnerConditionRoundResult>(
      MaterialPageRoute<BurnerConditionRoundResult>(
        builder:
            (_) => BurnerConditionRoundScreen(
              initialAssetInstanceId: _assetInstanceId,
            ),
      ),
    );
    if (!mounted || result == null) return;
    ref.invalidate(burnerConditionRoundsProvider);
    final recordedMessage =
        result.directiveId == null
            ? 'Burner round recorded.'
            : 'Burner round and critical I&A directive recorded.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.retryIdentityCleanupPending
              ? '$recordedMessage Local retry cleanup is pending; the committed round remains safe.'
              : recordedMessage,
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (!mounted || range == null) return;
    setState(() {
      _startDate = _dateOnly(range.start);
      _endDate = _dateOnly(range.end);
    });
  }
}

class _BurnerFilters extends StatelessWidget {
  const _BurnerFilters({
    required this.furnaces,
    required this.selectedAssetId,
    required this.startDate,
    required this.endDate,
    required this.onAssetChanged,
    required this.onDateRangePressed,
  });

  final List<AssetInstanceRecord> furnaces;
  final String? selectedAssetId;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<String?> onAssetChanged;
  final VoidCallback onDateRangePressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedAssetId ?? '',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Furnace',
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('All Furnaces')),
              for (final furnace in furnaces)
                DropdownMenuItem(
                  value: furnace.id,
                  child: Text(
                    '${furnace.name} (${furnace.assetNumber})'
                    '${furnace.isActive ? '' : ' - retired'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged:
                (value) => onAssetChanged(
                  value == null || value.isEmpty ? null : value,
                ),
          ),
          const SizedBox(height: BafSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDateRangePressed,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(
                '${DateFormat('dd MMM yyyy').format(startDate)} - '
                '${DateFormat('dd MMM yyyy').format(endDate)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReliabilityMetrics extends StatelessWidget {
  const _ReliabilityMetrics({required this.report});

  final BurnerReliabilityReport report;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 1.75,
      crossAxisSpacing: BafSpacing.sm,
      mainAxisSpacing: BafSpacing.sm,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _Metric(
          label: 'Lockout reports',
          value: report.issueCount,
          icon: Icons.warning_amber_rounded,
          color: BafColors.maintenance,
        ),
        _Metric(
          label: 'Condition rounds',
          value: report.roundCount,
          icon: Icons.fact_check_outlined,
          color: BafColors.assets,
        ),
        _Metric(
          label: 'Open positions',
          value: report.openPositionCount,
          icon: Icons.error_outline_rounded,
          color: BafColors.danger,
        ),
        _Metric(
          label: 'Red-hot records',
          value: report.redHotObservationCount,
          icon: Icons.local_fire_department_outlined,
          color: BafColors.warning,
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.count, required this.selectedAsset});

  final int count;
  final AssetInstanceRecord? selectedAsset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Furnace burner positions',
            style: TextStyle(
              color: BafColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        StatusBadge(
          label: '$count',
          color: BafColors.assets,
          icon: selectedAsset == null ? Icons.factory_outlined : null,
        ),
      ],
    );
  }
}

class _BurnerReliabilityCard extends StatelessWidget {
  const _BurnerReliabilityCard({required this.row, required this.onTap});

  final BurnerReliabilityRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actions =
        row.actionCounts.entries.toList()..sort((left, right) {
          final count = right.value.compareTo(left.value);
          return count != 0 ? count : left.key.name.compareTo(right.key.name);
        });
    return Material(
      color: BafColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: BorderSide(
          color:
              row.openCount > 0
                  ? BafColors.danger.withValues(alpha: 0.32)
                  : BafColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BafSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.displayTag,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusBadge(
                    label:
                        row.openCount > 0
                            ? '${row.openCount} open report${row.openCount == 1 ? '' : 's'}'
                            : 'No open lockout',
                    color:
                        row.openCount > 0
                            ? BafColors.danger
                            : BafColors.success,
                  ),
                  const SizedBox(width: BafSpacing.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: BafColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: BafSpacing.xs,
                runSpacing: BafSpacing.xs,
                children: [
                  StatusBadge(
                    label: '${row.issueCount} reports',
                    color: BafColors.assets,
                  ),
                  if (row.roundCount > 0)
                    StatusBadge(
                      label: '${row.roundCount} rounds',
                      color: BafColors.charges,
                    ),
                  if (row.redHotCount > 0)
                    StatusBadge(
                      label: '${row.redHotCount} red hot',
                      color: BafColors.warning,
                    ),
                  if (row.returnedCount > 0)
                    StatusBadge(
                      label: '${row.returnedCount} returned',
                      color: BafColors.success,
                    ),
                  if (row.followUpCount > 0)
                    StatusBadge(
                      label: '${row.followUpCount} follow-up',
                      color: BafColors.maintenance,
                    ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.speed_outlined,
                    size: 19,
                    color: BafColors.charges,
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: Text(
                      row.latestMicroampReading == null
                          ? 'No microamp reading recorded'
                          : '${NumberFormat('0.###').format(row.latestMicroampReading)} microamp'
                              '${row.latestMicroampAt == null ? '' : ' on ${DateFormat('dd MMM yyyy').format(row.latestMicroampAt!)}'}',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (row.latestFlameObservation != null) ...[
                const SizedBox(height: BafSpacing.sm),
                Text(
                  'Latest round: ${row.latestFlameObservation!.label}'
                  '${row.latestRoundAt == null ? '' : ' on ${DateFormat('dd MMM yyyy, HH:mm').format(row.latestRoundAt!)}'}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: BafSpacing.md),
                Wrap(
                  spacing: BafSpacing.xs,
                  runSpacing: BafSpacing.xs,
                  children: [
                    for (final action in actions.take(3))
                      StatusBadge(
                        label: '${action.key.label}: ${action.value}',
                        color: BafColors.audit,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: BafSpacing.sm),
              Text(
                'Latest evidence ${DateFormat('dd MMM yyyy, HH:mm').format(row.latest)}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportNotice extends StatelessWidget {
  const _ReportNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: BafColors.textSecondary),
            const SizedBox(height: BafSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: BafSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BafColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: BafColors.danger),
            const SizedBox(height: BafSpacing.sm),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: BafSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

AssetInstanceRecord? _findSelectedAsset(
  List<AssetInstanceRecord> furnaces,
  String? assetInstanceId,
) {
  if (assetInstanceId == null) return null;
  for (final furnace in furnaces) {
    if (furnace.id == assetInstanceId) return furnace;
  }
  return null;
}

List<MaintenanceRecord> _scopeTickets(
  List<MaintenanceRecord> tickets,
  AssetInstanceRecord? selectedAsset,
) {
  return tickets
      .where((ticket) {
        if (ticket.classification != burnerLockoutClassification) return false;
        if (selectedAsset == null) return true;
        final referencedAssetId =
            ticket.assetHierarchyReference?.assetInstanceId;
        if (referencedAssetId != null) {
          return referencedAssetId == selectedAsset.id;
        }
        return ticket.assetType == AssetType.furnace &&
            ticket.assetNumber == selectedAsset.assetNumber;
      })
      .toList(growable: false);
}

List<BurnerConditionRound> _scopeRounds(
  List<BurnerConditionRound> rounds,
  AssetInstanceRecord? selectedAsset,
) {
  if (selectedAsset == null) return rounds;
  return rounds
      .where((round) => round.assetInstanceId == selectedAsset.id)
      .toList(growable: false);
}
