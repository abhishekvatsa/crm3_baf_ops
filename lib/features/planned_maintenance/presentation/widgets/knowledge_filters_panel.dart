// FILE: lib/features/planned_maintenance/presentation/widgets/knowledge_filters_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../domain/knowledge_governance_models.dart';
import '../../domain/module_composer_models.dart';
import '../../providers/knowledge_governance_provider.dart';

class KnowledgeFiltersPanel extends ConsumerWidget {
  const KnowledgeFiltersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(knowledgeGovernanceFilterProvider);
    final notifier = ref.read(knowledgeGovernanceFilterProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      child: Row(
        children: [
          for (final status in KnowledgeLifecycleStatus.values)
            _chip(
              label: status.name,
              selected: filter.lifecycleStatuses.contains(status),
              onSelected: (value) {
                final next = Set<KnowledgeLifecycleStatus>.from(filter.lifecycleStatuses);
                if (value) {
                  next.add(status);
                } else {
                  next.remove(status);
                }
                if (next.isEmpty) next.add(KnowledgeLifecycleStatus.active);
                notifier.state = filter.copyWith(lifecycleStatuses: next);
              },
            ),
          const VerticalDivider(width: 24, color: BafColors.border),
          for (final readiness in ComposerReadiness.values)
            _chip(
              label: readiness.name,
              selected: filter.readinessStates.contains(readiness),
              onSelected: (value) {
                final next = Set<ComposerReadiness>.from(filter.readinessStates);
                if (value) {
                  next.add(readiness);
                } else {
                  next.remove(readiness);
                }
                notifier.state = filter.copyWith(readinessStates: next);
              },
            ),
          const VerticalDivider(width: 24, color: BafColors.border),
          _chip(
            label: 'has-tags',
            selected: filter.onlyTagBearingRows,
            onSelected: (value) =>
                notifier.state = filter.copyWith(onlyTagBearingRows: value),
          ),
          _chip(
            label: 'closure-critical',
            selected: filter.onlyClosureCritical,
            onSelected: (value) =>
                notifier.state = filter.copyWith(onlyClosureCritical: value),
          ),
          _chip(
            label: 'unsynced',
            selected: filter.onlyUnsynced,
            onSelected: (value) =>
                notifier.state = filter.copyWith(onlyUnsynced: value),
          ),
          if (!filter.isWideOpen)
            Padding(
              padding: const EdgeInsets.only(left: BafSpacing.sm),
              child: TextButton.icon(
                onPressed: () =>
                    notifier.state = KnowledgeGovernanceFilter.allActive(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: false,
        selectedColor: BafColors.planned.withValues(alpha: 0.18),
        side: BorderSide(
          color: selected
              ? BafColors.planned.withValues(alpha: 0.5)
              : BafColors.border,
        ),
      ),
    );
  }
}
