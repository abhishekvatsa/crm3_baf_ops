import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../data/uv_detector_lifecycle_event.dart';

class UvDetectorLifecycleList extends StatelessWidget {
  const UvDetectorLifecycleList({super.key, required this.events});

  final List<UvDetectorLifecycleEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(BafSpacing.xl),
          child: Text(
            'No verified UV-detector restoration has been recorded yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: BafColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(BafSpacing.lg),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: BafSpacing.sm),
      itemBuilder: (context, index) {
        final event = events[index];
        final sourceLabel = switch (event.sourceType) {
          UvDetectorLifecycleSourceType.maintenanceIssue => 'Issue resolution',
          UvDetectorLifecycleSourceType.legacyPlannedJob =>
            'Planned maintenance',
          UvDetectorLifecycleSourceType.workflowPlannedJob =>
            'Governed planned maintenance',
        };
        final disposition = switch (event.replacementDisposition) {
          UvDetectorReplacementDisposition.newPart => 'New detector',
          UvDetectorReplacementDisposition.repaired => 'Repaired detector',
          UvDetectorReplacementDisposition.revised => 'Revised detector',
        };
        return Container(
          padding: const EdgeInsets.all(BafSpacing.md),
          decoration: BoxDecoration(
            color: BafColors.card,
            border: Border.all(color: BafColors.border),
            borderRadius: BorderRadius.circular(BafRadius.small),
            boxShadow: BafShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: BafColors.instrument.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(BafRadius.small),
                    ),
                    child: const Icon(
                      Icons.sensors_rounded,
                      color: BafColors.instrument,
                    ),
                  ),
                  const SizedBox(width: BafSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Furnace ${event.assetNumber.toString().padLeft(2, '0')} · UV ${event.burnerPosition}',
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'dd MMM yyyy, HH:mm',
                          ).format(event.actionPerformedAt.toLocal()),
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
              const SizedBox(height: BafSpacing.sm),
              Wrap(
                spacing: BafSpacing.xs,
                runSpacing: BafSpacing.xs,
                children: [
                  const StatusBadge(
                    label: 'In service',
                    color: BafColors.success,
                  ),
                  StatusBadge(label: disposition, color: BafColors.assets),
                  const StatusBadge(
                    label: 'I&A installation',
                    color: BafColors.instrument,
                  ),
                  StatusBadge(label: sourceLabel, color: BafColors.planned),
                ],
              ),
              const SizedBox(height: BafSpacing.sm),
              Text(
                <String>[
                  event.hierarchyNodeName,
                  if (event.componentTag != null) 'Tag ${event.componentTag}',
                  'performed by ${event.performedByName}',
                  'closure recorded by ${event.completedByName}',
                ].join(' · '),
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
