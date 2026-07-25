import 'package:flutter/material.dart';

import '../../../maintenance/data/maintenance_model.dart';
import '../../data/job_lane_record.dart';
import '../../domain/maintenance_lane.dart';

class RaiseComplianceDraft {
  final String originLaneKey;
  final String targetLaneKey;
  final String title;
  final String description;
  final String conditionTypeKey;
  final String? conditionRef;
  final String priorityKey;
  final String? linkedMaintenanceId;
  final JobLaneRecord? gatingLane;

  const RaiseComplianceDraft({
    required this.originLaneKey,
    required this.targetLaneKey,
    required this.title,
    required this.description,
    required this.conditionTypeKey,
    required this.conditionRef,
    required this.priorityKey,
    required this.linkedMaintenanceId,
    required this.gatingLane,
  });
}

Future<RaiseComplianceDraft?> showRaiseComplianceDialog(
  BuildContext context, {
  required List<JobLaneRecord> originLanes,
  required List<JobLaneRecord> activeLanes,
  required List<MaintenanceRecord> maintenanceTickets,
}) {
  if (originLanes.isEmpty) return Future<RaiseComplianceDraft?>.value();
  return showDialog<RaiseComplianceDraft>(
    context: context,
    builder: (_) => _RaiseComplianceDialog(
      originLanes: originLanes,
      activeLanes: activeLanes,
      maintenanceTickets: maintenanceTickets,
    ),
  );
}

class _RaiseComplianceDialog extends StatefulWidget {
  final List<JobLaneRecord> originLanes;
  final List<JobLaneRecord> activeLanes;
  final List<MaintenanceRecord> maintenanceTickets;

  const _RaiseComplianceDialog({
    required this.originLanes,
    required this.activeLanes,
    required this.maintenanceTickets,
  });

  @override
  State<_RaiseComplianceDialog> createState() =>
      _RaiseComplianceDialogState();
}

class _RaiseComplianceDialogState extends State<_RaiseComplianceDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _conditionRefController = TextEditingController();

  late String _originLaneKey;
  String _targetLaneKey = MaintenanceLaneId.operations.value;
  String _conditionTypeKey = 'manual';
  String _priorityKey = 'medium';
  String _linkedMaintenanceId = '';
  String _gatingLaneId = '';
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _originLaneKey = widget.originLanes.first.laneKey;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _conditionRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Raise compliance request'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _originLaneKey,
                decoration: const InputDecoration(
                  labelText: 'Raised from accountable lane',
                ),
                items: widget.originLanes
                    .map(
                      (lane) => DropdownMenuItem<String>(
                        value: lane.laneKey,
                        child: Text(lane.laneKey.toUpperCase()),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _originLaneKey = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _targetLaneKey,
                decoration: const InputDecoration(labelText: 'Target lane'),
                items: MaintenanceLaneCatalog.crm3.definitions
                    .map(
                      (lane) => DropdownMenuItem<String>(
                        value: lane.id.value,
                        child: Text('${lane.code} — ${lane.displayName}'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _targetLaneKey = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Request title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Required action or confirmation',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _conditionTypeKey,
                decoration: const InputDecoration(labelText: 'When due'),
                items: const [
                  DropdownMenuItem(value: 'manual', child: Text('Immediately')),
                  DropdownMenuItem(
                    value: 'chargeComplete',
                    child: Text('After current cycle / charge'),
                  ),
                  DropdownMenuItem(
                    value: 'activityRef',
                    child: Text('After a named activity'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _conditionTypeKey = value);
                },
              ),
              if (_conditionTypeKey != 'manual') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _conditionRefController,
                  decoration: InputDecoration(
                    labelText: _conditionTypeKey == 'chargeComplete'
                        ? 'Charge / cycle reference'
                        : 'Activity reference',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _linkedMaintenanceId,
                decoration: InputDecoration(
                  labelText: _conditionTypeKey == 'manual'
                      ? 'Linked maintenance ticket (optional)'
                      : 'Linked maintenance ticket (required)',
                  helperText: _conditionTypeKey == 'manual'
                      ? 'Link when the request governs an existing ticket.'
                      : 'Deferred work must bind to a real open ticket on this asset.',
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('No linked maintenance ticket'),
                  ),
                  ...widget.maintenanceTickets.map(
                    (ticket) => DropdownMenuItem<String>(
                      value: ticket.firestoreId,
                      child: Text(
                        '${ticket.firestoreId ?? ticket.id} — ${ticket.description}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _linkedMaintenanceId = value ?? '';
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priorityKey,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priorityKey = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _gatingLaneId,
                decoration: const InputDecoration(
                  labelText: 'Block a lane until confirmed (optional)',
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Informational / non-blocking'),
                  ),
                  ...widget.activeLanes.map(
                    (lane) => DropdownMenuItem<String>(
                      value: lane.firestoreId,
                      child: Text('Block ${lane.laneKey.toUpperCase()} lane'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _gatingLaneId = value ?? '';
                }),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        FilledButton(
          onPressed: _submit,
          child: const Text('Raise request'),
        ),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final conditionRef = _conditionRefController.text.trim();
    if (title.isEmpty || description.isEmpty) {
      setState(() {
        _validationMessage = 'Title and required action are mandatory.';
      });
      return;
    }
    if (_conditionTypeKey != 'manual' && conditionRef.isEmpty) {
      setState(() {
        _validationMessage = 'A due-condition reference is mandatory.';
      });
      return;
    }
    if (_conditionTypeKey != 'manual' && _linkedMaintenanceId.isEmpty) {
      setState(() {
        _validationMessage =
            'Deferred compliance must be linked to an open maintenance ticket.';
      });
      return;
    }

    JobLaneRecord? gatingLane;
    if (_gatingLaneId.isNotEmpty) {
      for (final lane in widget.activeLanes) {
        if (lane.firestoreId == _gatingLaneId) {
          gatingLane = lane;
          break;
        }
      }
    }

    Navigator.pop(
      context,
      RaiseComplianceDraft(
        originLaneKey: _originLaneKey,
        targetLaneKey: _targetLaneKey,
        title: title,
        description: description,
        conditionTypeKey: _conditionTypeKey,
        conditionRef: conditionRef.isEmpty ? null : conditionRef,
        priorityKey: _priorityKey,
        linkedMaintenanceId:
            _linkedMaintenanceId.isEmpty ? null : _linkedMaintenanceId,
        gatingLane: gatingLane,
      ),
    );
  }
}
