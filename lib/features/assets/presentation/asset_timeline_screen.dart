// FILE: lib/features/assets/presentation/asset_timeline_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../maintenance/data/maintenance_model.dart';
import '../models/timeline_entry.dart';
import '../providers/asset_timeline_provider.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/providers/auth_provider.dart';

class AssetTimelineScreen extends ConsumerWidget {
  final AssetType? initialAssetType;
  final int? initialAssetNumber;

  const AssetTimelineScreen({
    super.key,
    this.initialAssetType,
    this.initialAssetNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    return actorAsync.when(
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (_, _) => const Scaffold(
            body: Center(child: Text('Could not verify asset access.')),
          ),
      data: (actor) {
        if (actor == null || !actor.canViewOperationalAssets) {
          return const Scaffold(
            body: Center(child: Text('Approved access is required.')),
          );
        }
        return _AssetTimelineBody(
          initialAssetType: initialAssetType,
          initialAssetNumber: initialAssetNumber,
        );
      },
    );
  }
}

class _AssetTimelineBody extends ConsumerStatefulWidget {
  final AssetType? initialAssetType;
  final int? initialAssetNumber;

  const _AssetTimelineBody({
    required this.initialAssetType,
    required this.initialAssetNumber,
  });

  @override
  ConsumerState<_AssetTimelineBody> createState() =>
      _AssetTimelineScreenState();
}

class _AssetTimelineScreenState extends ConsumerState<_AssetTimelineBody> {
  late final TextEditingController _assetNumberController;

  @override
  void initState() {
    super.initState();
    _assetNumberController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.initialAssetType != null) {
        ref.read(selectedAssetTypeProvider.notifier).state =
            widget.initialAssetType;
      }

      if (widget.initialAssetNumber != null) {
        final text = widget.initialAssetNumber.toString();
        _assetNumberController.text = text;
        ref.read(assetNumberQueryProvider.notifier).state = text;
      } else {
        final existing = ref.read(assetNumberQueryProvider);
        if (existing.isNotEmpty) {
          _assetNumberController.text = existing;
        }
      }
    });
  }

  @override
  void dispose() {
    _assetNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(selectedAssetTypeProvider);
    final selectedNumber = ref.watch(assetNumberQueryProvider);
    final timelineAsync = ref.watch(assetTimelineProvider);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text('Asset Timeline'),
        backgroundColor: Colors.white,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          _TimelineFilterCard(
            selectedType: selectedType,
            assetNumberController: _assetNumberController,
            onTypeSelected: (type) {
              ref.read(selectedAssetTypeProvider.notifier).state = type;
            },
            onNumberChanged: (value) {
              ref.read(assetNumberQueryProvider.notifier).state = value.trim();
            },
            onClearNumber:
                selectedNumber.isEmpty
                    ? null
                    : () {
                      _assetNumberController.clear();
                      ref.read(assetNumberQueryProvider.notifier).state = '';
                    },
          ),
          Expanded(
            child: timelineAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: 'Error: $e'),
              data: (entries) {
                if (entries.isEmpty) {
                  return const _EmptyTimelineState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
                  itemCount: entries.length + 1,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _TimelineHeader(
                        count: entries.length,
                        selectedType: selectedType,
                        selectedNumber: selectedNumber,
                      );
                    }
                    return _TimelineCard(entry: entries[index - 1]);
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

class _TimelineFilterCard extends StatelessWidget {
  final AssetType? selectedType;
  final TextEditingController assetNumberController;
  final ValueChanged<AssetType?> onTypeSelected;
  final ValueChanged<String> onNumberChanged;
  final VoidCallback? onClearNumber;

  const _TimelineFilterCard({
    required this.selectedType,
    required this.assetNumberController,
    required this.onTypeSelected,
    required this.onNumberChanged,
    required this.onClearNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  Icons.precision_manufacturing_rounded,
                  color: BafColors.assets,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Asset context',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Trace maintenance and planned work together.',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _AssetTypeChip(
                  label: 'ALL',
                  selected: selectedType == null,
                  onTap: () => onTypeSelected(null),
                ),
                ...AssetType.values.map(
                  (type) => _AssetTypeChip(
                    label: _assetLabel(type),
                    selected: selectedType == type,
                    onTap: () => onTypeSelected(type),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: assetNumberController,
            keyboardType: TextInputType.number,
            onChanged: onNumberChanged,
            decoration: InputDecoration(
              hintText: 'Filter by asset number, e.g. 221',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon:
                  onClearNumber == null
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

class _TimelineHeader extends StatelessWidget {
  final int count;
  final AssetType? selectedType;
  final String selectedNumber;

  const _TimelineHeader({
    required this.count,
    required this.selectedType,
    required this.selectedNumber,
  });

  @override
  Widget build(BuildContext context) {
    final filterLabel = [
      if (selectedType != null) _assetLabel(selectedType!),
      if (selectedNumber.trim().isNotEmpty) selectedNumber.trim(),
    ].join(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          StatusBadge(
            label: '$count recent events',
            color: BafColors.assets,
            icon: Icons.timeline_rounded,
          ),
          if (filterLabel.isNotEmpty)
            StatusBadge(
              label: filterLabel,
              color: BafColors.planned,
              icon: Icons.filter_alt_rounded,
            ),
        ],
      ),
    );
  }
}

class _AssetTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AssetTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : BafColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: BafColors.assets,
        backgroundColor: BafColors.background,
        side: BorderSide(color: selected ? BafColors.assets : BafColors.border),
        showCheckmark: false,
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final TimelineEntry entry;

  const _TimelineCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (color, icon, typeLabel) = switch (entry.type) {
      TimelineEventType.maintenance => (
        BafColors.maintenance,
        Icons.report_problem_rounded,
        'MAINTENANCE',
      ),
      TimelineEventType.plannedJob => (
        BafColors.planned,
        Icons.assignment_turned_in_rounded,
        'PLANNED JOB',
      ),
      TimelineEventType.equipmentProjection => (
        BafColors.assets,
        Icons.precision_manufacturing_rounded,
        'EQUIPMENT STATE',
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BafRadius.large),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: color, size: 25),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_assetLabel(entry.assetType)} ${entry.assetNumber}',
                                    style: const TextStyle(
                                      color: BafColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(label: typeLabel, color: color),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entry.title,
                              style: const TextStyle(
                                color: BafColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.subtitle,
                              style: const TextStyle(
                                color: BafColors.textSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusBadge(
                                  label: entry.isResolved ? 'CLOSED' : 'OPEN',
                                  color:
                                      entry.isResolved
                                          ? BafColors.sync
                                          : BafColors.warning,
                                  icon:
                                      entry.isResolved
                                          ? Icons.check_circle_rounded
                                          : Icons.pending_actions_rounded,
                                ),
                                StatusBadge(
                                  label: DateFormat(
                                    'dd MMM yyyy, HH:mm',
                                  ).format(entry.timestamp),
                                  color: BafColors.admin,
                                  icon: Icons.schedule_rounded,
                                ),
                              ],
                            ),
                          ],
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

class _EmptyTimelineState extends StatelessWidget {
  const _EmptyTimelineState();

  @override
  Widget build(BuildContext context) {
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
                  Icons.history_rounded,
                  color: BafColors.assets,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No events found',
                style: TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try adjusting asset type or asset number filters.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
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
            border: Border.all(color: BafColors.danger.withValues(alpha: 0.18)),
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

String _assetLabel(AssetType type) {
  switch (type) {
    case AssetType.base:
      return 'BASE';
    case AssetType.furnace:
      return 'FURNACE';
    case AssetType.forceCooler:
      return 'FC';
    case AssetType.innerCover:
      return 'IC';
  }
}
