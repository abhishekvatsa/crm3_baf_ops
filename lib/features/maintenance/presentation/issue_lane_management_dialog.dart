import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../data/maintenance_model.dart';
import '../domain/burner_lockout_case.dart';
import '../domain/furnace_stuckup_case.dart';

class IssueLaneChange {
  const IssueLaneChange({
    required this.lanes,
    required this.otherDepartment,
    required this.reason,
  });

  final List<RoutedTo> lanes;
  final String? otherDepartment;
  final String reason;
}

Future<IssueLaneChange?> showIssueLaneManagementDialog(
  BuildContext context, {
  required MaintenanceRecord ticket,
}) => showDialog<IssueLaneChange>(
  context: context,
  builder: (_) => _IssueLaneManagementDialog(ticket: ticket),
);

class _IssueLaneManagementDialog extends StatefulWidget {
  const _IssueLaneManagementDialog({required this.ticket});

  final MaintenanceRecord ticket;

  @override
  State<_IssueLaneManagementDialog> createState() =>
      _IssueLaneManagementDialogState();
}

class _IssueLaneManagementDialogState
    extends State<_IssueLaneManagementDialog> {
  final _reasonController = TextEditingController();
  final _otherDepartmentController = TextEditingController();
  late final Set<RoutedTo> _selected;
  late RoutedTo _primary;
  String? _error;

  RoutedTo? get _mandatory =>
      widget.ticket.classification == burnerLockoutClassification
          ? RoutedTo.instrumentation
          : widget.ticket.classification == furnaceStuckupClassification
          ? RoutedTo.mechanical
          : null;

  @override
  void initState() {
    super.initState();
    final lanes = widget.ticket.issueLanePlan.assignedLanes
        .map(RoutedTo.values.byName)
        .toList(growable: false);
    _selected = lanes.toSet();
    _primary = lanes.first;
    _otherDepartmentController.text = widget.ticket.otherDepartment ?? '';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _otherDepartmentController.dispose();
    super.dispose();
  }

  void _toggle(RoutedTo lane, bool selected) {
    if (!selected && (lane == _mandatory || _selected.length == 1)) return;
    setState(() {
      _error = null;
      if (selected) {
        _selected.add(lane);
      } else {
        _selected.remove(lane);
        if (_primary == lane) {
          _primary = RoutedTo.values.firstWhere(_selected.contains);
        }
        if (lane == RoutedTo.others) _otherDepartmentController.clear();
      }
    });
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    final otherDepartment = _otherDepartmentController.text.trim();
    if (reason.length < 12) {
      setState(() => _error = 'Give a clear reason of at least 12 characters.');
      return;
    }
    if (_selected.contains(RoutedTo.others) && otherDepartment.length < 2) {
      setState(() => _error = 'Name the receiving team represented by Others.');
      return;
    }
    final lanes = <RoutedTo>[
      _primary,
      ...RoutedTo.values.where(
        (lane) => lane != _primary && _selected.contains(lane),
      ),
    ];
    Navigator.pop(
      context,
      IssueLaneChange(
        lanes: lanes,
        otherDepartment:
            _selected.contains(RoutedTo.others) ? otherDepartment : null,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mandatory = _mandatory;
    return AlertDialog(
      title: const Text('Manage accountable lanes'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select every discipline accountable for this issue. Existing progress is retained only for lanes that remain selected.',
              ),
              const SizedBox(height: BafSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final lane in RoutedTo.values)
                    FilterChip(
                      label: Text(_laneLabel(lane)),
                      avatar:
                          lane == mandatory
                              ? const Icon(Icons.lock_rounded, size: 15)
                              : null,
                      selected: _selected.contains(lane),
                      onSelected: (value) => _toggle(lane, value),
                    ),
                ],
              ),
              const SizedBox(height: BafSpacing.md),
              DropdownButtonFormField<RoutedTo>(
                key: ValueKey(
                  'issue-lane-management-primary-${_primary.name}-'
                  '${_selected.map((lane) => lane.name).join('-')}',
                ),
                initialValue: _primary,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Primary lane'),
                items: [
                  for (final lane in RoutedTo.values.where(_selected.contains))
                    DropdownMenuItem(
                      value: lane,
                      child: Text(_laneLabel(lane)),
                    ),
                ],
                onChanged:
                    mandatory == null
                        ? (lane) {
                          if (lane != null) setState(() => _primary = lane);
                        }
                        : null,
              ),
              if (_selected.contains(RoutedTo.others)) ...[
                const SizedBox(height: BafSpacing.md),
                TextField(
                  controller: _otherDepartmentController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Other receiving team',
                  ),
                ),
              ],
              const SizedBox(height: BafSpacing.md),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for lane change',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: BafSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: BafColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Apply lanes'),
        ),
      ],
    );
  }
}

String _laneLabel(RoutedTo lane) => switch (lane) {
  RoutedTo.operations => 'Operations',
  RoutedTo.electrical => 'Electrical',
  RoutedTo.mechanical => 'Mechanical',
  RoutedTo.instrumentation => 'I&A',
  RoutedTo.refractory => 'RED',
  RoutedTo.emd => 'EMD',
  RoutedTo.shiftInCharge => 'Shift supervisor',
  RoutedTo.others => 'Others',
};
