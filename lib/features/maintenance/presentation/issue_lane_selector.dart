import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../data/maintenance_model.dart';
import '../validation/maintenance_input_validator.dart';

class IssueLaneSelector extends StatelessWidget {
  const IssueLaneSelector({
    super.key,
    required this.selectedLanes,
    required this.primaryLane,
    required this.mandatoryLane,
    required this.otherDepartmentController,
    required this.lanesDecoration,
    required this.primaryDecoration,
    required this.otherDepartmentDecoration,
    required this.onLaneChanged,
    required this.onPrimaryChanged,
  });

  final Set<RoutedTo> selectedLanes;
  final RoutedTo primaryLane;
  final RoutedTo? mandatoryLane;
  final TextEditingController otherDepartmentController;
  final InputDecoration lanesDecoration;
  final InputDecoration primaryDecoration;
  final InputDecoration otherDepartmentDecoration;
  final void Function(RoutedTo lane, bool selected) onLaneChanged;
  final ValueChanged<RoutedTo> onPrimaryChanged;

  List<RoutedTo> get _orderedLanes => <RoutedTo>[
    primaryLane,
    ...RoutedTo.values.where(
      (lane) => lane != primaryLane && selectedLanes.contains(lane),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: lanesDecoration,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lane in RoutedTo.values)
                FilterChip(
                  label: Text(issueLaneLabel(lane)),
                  avatar:
                      lane == mandatoryLane
                          ? const Icon(Icons.lock_rounded, size: 15)
                          : null,
                  selected: selectedLanes.contains(lane),
                  onSelected: (selected) => onLaneChanged(lane, selected),
                  selectedColor: BafColors.maintenance.withValues(alpha: 0.12),
                  checkmarkColor: BafColors.maintenance,
                  side: BorderSide(
                    color:
                        selectedLanes.contains(lane)
                            ? BafColors.maintenance.withValues(alpha: 0.45)
                            : BafColors.border,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: BafSpacing.xs),
        Text(
          selectedLanes.length == 1
              ? '${issueLaneLabel(primaryLane)} is the accountable lane.'
              : '${selectedLanes.length} accountable lanes; ${issueLaneLabel(primaryLane)} remains the primary lane.',
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        if (selectedLanes.length > 1) ...[
          const SizedBox(height: BafSpacing.md),
          DropdownButtonFormField<RoutedTo>(
            key: ValueKey(
              'issue-primary-${primaryLane.name}-${_orderedLanes.map((lane) => lane.name).join('-')}',
            ),
            initialValue: primaryLane,
            isExpanded: true,
            decoration: primaryDecoration,
            items: [
              for (final lane in RoutedTo.values.where(selectedLanes.contains))
                DropdownMenuItem<RoutedTo>(
                  value: lane,
                  child: Text(issueLaneLabel(lane)),
                ),
            ],
            onChanged:
                mandatoryLane == null
                    ? (lane) {
                      if (lane != null) onPrimaryChanged(lane);
                    }
                    : null,
          ),
        ],
        if (selectedLanes.contains(RoutedTo.others)) ...[
          const SizedBox(height: BafSpacing.md),
          TextFormField(
            controller: otherDepartmentController,
            decoration: otherDepartmentDecoration,
            textCapitalization: TextCapitalization.words,
            validator:
                (value) => MaintenanceInputValidator.validateOtherDepartment(
                  routedTo: RoutedTo.others,
                  value: value,
                ).messageFor('otherDepartment'),
          ),
        ],
      ],
    );
  }
}

String issueLaneLabel(RoutedTo lane) => switch (lane) {
  RoutedTo.operations => 'Operations',
  RoutedTo.electrical => 'Electrical',
  RoutedTo.mechanical => 'Mechanical',
  RoutedTo.instrumentation => 'I&A',
  RoutedTo.refractory => 'RED / Refractory',
  RoutedTo.emd => 'EMD',
  RoutedTo.shiftInCharge => 'Shift In-Charge',
  RoutedTo.others => 'Others',
};
