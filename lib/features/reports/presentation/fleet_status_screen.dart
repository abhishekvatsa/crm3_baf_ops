// FILE: lib/features/reports/presentation/fleet_status_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/asset_fleet_status.dart';
import '../providers/fleet_status_provider.dart';
import '../../assets/presentation/asset_timeline_screen.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';

final fleetAssetNumberFilterProvider = StateProvider<String>((ref) => '');

class FleetStatusScreen extends ConsumerStatefulWidget {
  const FleetStatusScreen({super.key});

  @override
  ConsumerState<FleetStatusScreen> createState() => _FleetStatusScreenState();
}

class _FleetStatusScreenState extends ConsumerState<FleetStatusScreen> {
  AssetType _selectedType = AssetType.furnace;
  late final TextEditingController _assetNumberController;

  @override
  void initState() {
    super.initState();
    _assetNumberController = TextEditingController(
      text: ref.read(fleetAssetNumberFilterProvider),
    );
  }

  @override
  void dispose() {
    _assetNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetNumberFilter = ref.watch(fleetAssetNumberFilterProvider).trim();
    final parsedAssetNumber = assetNumberFilter.isEmpty
        ? null
        : int.tryParse(assetNumberFilter);
    final fleetAsync = assetNumberFilter.isNotEmpty && parsedAssetNumber == null
        ? const AsyncData(<AssetFleetStatus>[])
        : ref.watch(
      filteredFleetStatusProvider(
        FleetStatusFilter(
          assetType: _selectedType,
          assetNumber: parsedAssetNumber,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Fleet Status'),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: Column(
        children: [
          _FleetFilterCard(
            selectedType: _selectedType,
            assetNumberController: _assetNumberController,
            onTypeChanged: (type) {
              if (type == null) return;
              setState(() => _selectedType = type);
            },
            onNumberChanged: (value) {
              ref.read(fleetAssetNumberFilterProvider.notifier).state =
                  value.trim();
            },
            onClearNumber: assetNumberFilter.isEmpty
                ? null
                : () {
              _assetNumberController.clear();
              ref.read(fleetAssetNumberFilterProvider.notifier).state = '';
            },
          ),
          Expanded(
            child: fleetAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorState(message: 'Error: $err'),
              data: (assets) {
                if (assets.isEmpty) {
                  return _EmptyFleetState(
                    filter: assetNumberFilter,
                    selectedType: _selectedType,
                    onClearFilter: assetNumberFilter.isEmpty
                        ? null
                        : () {
                      _assetNumberController.clear();
                      ref
                          .read(fleetAssetNumberFilterProvider.notifier)
                          .state = '';
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                  itemCount: assets.length + 1,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _FleetSummaryHeader(
                        selectedType: _selectedType,
                        count: assets.length,
                        filter: assetNumberFilter,
                      );
                    }
                    return _AssetCard(asset: assets[index - 1]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetFilterCard extends StatelessWidget {
  final AssetType selectedType;
  final TextEditingController assetNumberController;
  final ValueChanged<AssetType?> onTypeChanged;
  final ValueChanged<String> onNumberChanged;
  final VoidCallback? onClearNumber;

  const _FleetFilterCard({
    required this.selectedType,
    required this.assetNumberController,
    required this.onTypeChanged,
    required this.onNumberChanged,
    required this.onClearNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: BafColors.assets.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: BafColors.assets,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet health',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Recent open issues, recent work and service aging.',
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<AssetType>(
            initialValue: selectedType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Asset type',
              prefixIcon: const Icon(Icons.precision_manufacturing_rounded),
              filled: true,
              fillColor: BafColors.background,
              isDense: true,
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
                borderSide: const BorderSide(
                  color: BafColors.assets,
                  width: 1.5,
                ),
              ),
            ),
            items: AssetType.values
                .map(
                  (type) => DropdownMenuItem(
                value: type,
                child: Text(
                  _assetTypeLabel(type),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
                .toList(),
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: assetNumberController,
            keyboardType: TextInputType.number,
            onChanged: onNumberChanged,
            decoration: InputDecoration(
              hintText: 'Filter by exact asset number',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: onClearNumber == null
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: onClearNumber,
              ),
              filled: true,
              fillColor: BafColors.background,
              isDense: true,
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
                borderSide: const BorderSide(
                  color: BafColors.assets,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetSummaryHeader extends StatelessWidget {
  final AssetType selectedType;
  final int count;
  final String filter;

  const _FleetSummaryHeader({
    required this.selectedType,
    required this.count,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusBadge(
          label: '${_assetTypeLabel(selectedType)} · $count recent assets',
          color: BafColors.assets,
          icon: Icons.inventory_2_rounded,
        ),
        if (filter.trim().isNotEmpty)
          StatusBadge(
            label: 'Asset ${filter.trim()}',
            color: BafColors.planned,
            icon: Icons.filter_alt_rounded,
          ),
      ],
    );
  }
}

class _AssetCard extends StatelessWidget {
  final AssetFleetStatus asset;

  const _AssetCard({required this.asset});

  String _workflowStateLabel() {
    switch (asset.operationalStateKey) {
      case 'underMaintenance':
        return 'Under maintenance';
      case 'awaitingPreparation':
        return 'Preparation pending';
      case 'underRED':
        return 'Under RED';
      case 'available':
        return 'Available';
      case 'inService':
        return 'In service';
      default:
        return asset.operationalStateKey;
    }
  }

  Color _workflowStateColor() {
    switch (asset.operationalStateKey) {
      case 'underRED':
        return BafColors.danger;
      case 'awaitingPreparation':
        return BafColors.warning;
      case 'underMaintenance':
        return BafColors.planned;
      case 'available':
      case 'inService':
        return BafColors.sync;
      default:
        return BafColors.textSecondary;
    }
  }

  IconData _workflowStateIcon() {
    switch (asset.operationalStateKey) {
      case 'underRED':
        return Icons.local_fire_department_rounded;
      case 'awaitingPreparation':
        return Icons.hourglass_bottom_rounded;
      case 'underMaintenance':
        return Icons.build_circle_rounded;
      case 'available':
        return Icons.check_circle_outline_rounded;
      case 'inService':
        return Icons.play_circle_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _agingColor() {
    switch (asset.agingSeverity) {
      case 0:
        return BafColors.sync;
      case 1:
        return BafColors.warning;
      default:
        return BafColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    final agingColor = _agingColor();
    final hasOpenTickets = asset.openTicketsCount > 0;

    return Container(
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: InkWell(
          borderRadius: BorderRadius.circular(BafRadius.large),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AssetTimelineScreen(
                  initialAssetType: asset.assetType,
                  initialAssetNumber: asset.assetNumber,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: BafColors.assets.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.precision_manufacturing_rounded,
                        color: BafColors.assets,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_assetTypeLabel(asset.assetType)} ${asset.assetNumber}',
                            style: const TextStyle(
                              color: BafColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusBadge(
                                label: _workflowStateLabel(),
                                color: _workflowStateColor(),
                                icon: _workflowStateIcon(),
                              ),
                              StatusBadge(
                                label: hasOpenTickets
                                    ? '${asset.openTicketsCount} recent open'
                                    : 'No open issues',
                                color: hasOpenTickets
                                    ? BafColors.danger
                                    : BafColors.sync,
                                icon: hasOpenTickets
                                    ? Icons.report_problem_rounded
                                    : Icons.check_circle_rounded,
                              ),
                              StatusBadge(
                                label: asset.daysSinceLastCompletedJob == null
                                    ? 'Never serviced'
                                    : '${asset.daysSinceLastCompletedJob} days',
                                color: agingColor,
                                icon: Icons.schedule_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: BafColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Recent completed jobs',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (asset.recentCompletedJobs.isEmpty)
                  const _NoJobsLine()
                else
                  Column(
                    children: asset.recentCompletedJobs.map((execution) {
                      final completedAt = execution.completedAt;
                      final date = completedAt == null
                          ? 'No date'
                          : DateFormat('dd MMM yyyy').format(completedAt);
                      return _CompletedJobLine(
                        title: execution.templateName ?? 'Unnamed Job',
                        date: date,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedJobLine extends StatelessWidget {
  final String title;
  final String date;

  const _CompletedJobLine({
    required this.title,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 16,
            color: BafColors.sync,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoJobsLine extends StatelessWidget {
  const _NoJobsLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: const Text(
        'No completed jobs recorded yet.',
        style: TextStyle(
          color: BafColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyFleetState extends StatelessWidget {
  final String filter;
  final AssetType selectedType;
  final VoidCallback? onClearFilter;

  const _EmptyFleetState({
    required this.filter,
    required this.selectedType,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = filter.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(color: BafColors.border),
            boxShadow: BafShadows.subtle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: BafColors.assets.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: BafColors.assets,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hasFilter
                    ? 'No asset matches $filter'
                    : 'No ${_assetTypeLabel(selectedType).toLowerCase()} assets found',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try changing asset type or clearing the asset number filter.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
              if (onClearFilter != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onClearFilter,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear filter'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(BafRadius.large),
            border: Border.all(
              color: BafColors.danger.withValues(alpha: 0.18),
            ),
            boxShadow: BafShadows.subtle,
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: BafColors.danger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    height: 1.3,
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

String _assetTypeLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'BASE';
    case AssetType.furnace:
      return 'FURNACE';
    case AssetType.forceCooler:
      return 'FORCE COOLER';
    case AssetType.innerCover:
      return 'INNER COVER';
  }
}
