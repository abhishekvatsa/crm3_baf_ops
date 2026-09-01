import 'package:flutter/material.dart';

import '../../../maintenance/data/maintenance_model.dart';
import '../../data/job_lane_record.dart';
import '../../domain/maintenance_lane.dart';

class RaiseComplianceDraft {
  final String originLaneKey;
  final String targetLaneKey;
  final String title;
  final String description;
  final String requestPurposeKey;
  final String conditionTypeKey;
  final String? conditionRef;
  final String? defermentBasisKey;
  final String? operationsSupportTypeKey;
  final String? operationsResourceKey;
  final String? requestedLocation;
  final String priorityKey;
  final String? linkedMaintenanceId;
  final JobLaneRecord? gatingLane;

  const RaiseComplianceDraft({
    required this.originLaneKey,
    required this.targetLaneKey,
    required this.title,
    required this.description,
    required this.requestPurposeKey,
    required this.conditionTypeKey,
    required this.conditionRef,
    required this.defermentBasisKey,
    required this.operationsSupportTypeKey,
    required this.operationsResourceKey,
    required this.requestedLocation,
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
    builder:
        (_) => _RaiseComplianceDialog(
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
  State<_RaiseComplianceDialog> createState() => _RaiseComplianceDialogState();
}

class _RaiseComplianceDialogState extends State<_RaiseComplianceDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _conditionRefController = TextEditingController();
  final TextEditingController _requestedLocationController =
      TextEditingController();

  late String _originLaneKey;
  String _requestPurposeKey = 'assurance';
  String _targetLaneKey = MaintenanceLaneId.operations.value;
  String _conditionTypeKey = 'manual';
  String _defermentBasisKey = 'ongoingCycle';
  String _operationsSupportTypeKey = 'craneMovement';
  String _operationsResourceKey = 'crane';
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
    _requestedLocationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request assurance or support'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _requestPurposeKey,
                decoration: const InputDecoration(labelText: 'Request type'),
                items: const [
                  DropdownMenuItem(
                    value: 'assurance',
                    child: Text('Assurance / confirmation'),
                  ),
                  DropdownMenuItem(
                    value: 'deferment',
                    child: Text('Maintenance deferment'),
                  ),
                  DropdownMenuItem(
                    value: 'operationsSupport',
                    child: Text('Operations support'),
                  ),
                ],
                onChanged: _setPurpose,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
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
                isExpanded: true,
                key: ValueKey<String>('target-$_targetLaneKey'),
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
                onChanged:
                    _requestPurposeKey == 'assurance'
                        ? (value) {
                          if (value != null) {
                            setState(() => _targetLaneKey = value);
                          }
                        }
                        : null,
              ),
              if (_requestPurposeKey == 'deferment') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _defermentBasisKey,
                  decoration: const InputDecoration(
                    labelText: 'Reason for deferment',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'ongoingCycle',
                      child: Text('Ongoing cycle / charge'),
                    ),
                    DropdownMenuItem(
                      value: 'equipmentRequired',
                      child: Text('Equipment required by Operations'),
                    ),
                    DropdownMenuItem(
                      value: 'operationalCompliance',
                      child: Text('Operational compliance'),
                    ),
                    DropdownMenuItem(
                      value: 'safetyConstraint',
                      child: Text('Safety constraint'),
                    ),
                    DropdownMenuItem(
                      value: 'qualityConstraint',
                      child: Text('Quality constraint'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _defermentBasisKey = value);
                    }
                  },
                ),
              ],
              if (_requestPurposeKey == 'operationsSupport') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _operationsSupportTypeKey,
                  decoration: const InputDecoration(
                    labelText: 'Support required',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'craneMovement',
                      child: Text('Crane movement'),
                    ),
                    DropdownMenuItem(
                      value: 'assetRelocation',
                      child: Text('Asset relocation'),
                    ),
                    DropdownMenuItem(
                      value: 'isolation',
                      child: Text('Isolation'),
                    ),
                    DropdownMenuItem(
                      value: 'processPreparation',
                      child: Text('Process preparation'),
                    ),
                    DropdownMenuItem(
                      value: 'utilitySupport',
                      child: Text('Utility support'),
                    ),
                    DropdownMenuItem(
                      value: 'accessOrPermit',
                      child: Text('Access / permit'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _operationsSupportTypeKey = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _operationsResourceKey,
                  decoration: const InputDecoration(labelText: 'Resource'),
                  items: const [
                    DropdownMenuItem(value: 'crane', child: Text('Crane')),
                    DropdownMenuItem(
                      value: 'transferCar',
                      child: Text('Transfer car'),
                    ),
                    DropdownMenuItem(
                      value: 'operationsCrew',
                      child: Text('Operations crew'),
                    ),
                    DropdownMenuItem(
                      value: 'utilities',
                      child: Text('Utilities'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _operationsResourceKey = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _requestedLocationController,
                  decoration: const InputDecoration(
                    labelText: 'Destination / work location',
                  ),
                ),
              ],
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
                isExpanded: true,
                key: ValueKey<String>('condition-$_conditionTypeKey'),
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
                    labelText:
                        _conditionTypeKey == 'chargeComplete'
                            ? 'Charge / cycle reference'
                            : 'Activity reference',
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _linkedMaintenanceId,
                decoration: InputDecoration(
                  labelText:
                      _requestPurposeKey == 'deferment'
                          ? 'Linked maintenance ticket (required)'
                          : _conditionTypeKey == 'manual'
                          ? 'Linked maintenance ticket (optional)'
                          : 'Linked maintenance ticket (required)',
                  helperText:
                      _conditionTypeKey == 'manual'
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
                onChanged:
                    (value) => setState(() {
                      _linkedMaintenanceId = value ?? '';
                    }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
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
                isExpanded: true,
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
                onChanged:
                    (value) => setState(() {
                      _gatingLaneId = value ?? '';
                    }),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
        FilledButton(onPressed: _submit, child: const Text('Raise request')),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final conditionRef = _conditionRefController.text.trim();
    final requestedLocation = _requestedLocationController.text.trim();
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
    if ((_requestPurposeKey == 'deferment' || _conditionTypeKey != 'manual') &&
        _linkedMaintenanceId.isEmpty) {
      setState(() {
        _validationMessage =
            'Deferred compliance must be linked to an open maintenance ticket.';
      });
      return;
    }
    if (_requestPurposeKey == 'operationsSupport' &&
        (_operationsSupportTypeKey == 'craneMovement' ||
            _operationsSupportTypeKey == 'assetRelocation') &&
        requestedLocation.isEmpty) {
      setState(() {
        _validationMessage =
            'A destination or work location is required for movement.';
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
        requestPurposeKey: _requestPurposeKey,
        conditionTypeKey: _conditionTypeKey,
        conditionRef: conditionRef.isEmpty ? null : conditionRef,
        defermentBasisKey:
            _requestPurposeKey == 'deferment' ? _defermentBasisKey : null,
        operationsSupportTypeKey:
            _requestPurposeKey == 'operationsSupport'
                ? _operationsSupportTypeKey
                : null,
        operationsResourceKey:
            _requestPurposeKey == 'operationsSupport'
                ? _operationsResourceKey
                : null,
        requestedLocation:
            _requestPurposeKey == 'operationsSupport' &&
                    requestedLocation.isNotEmpty
                ? requestedLocation
                : null,
        priorityKey: _priorityKey,
        linkedMaintenanceId:
            _linkedMaintenanceId.isEmpty ? null : _linkedMaintenanceId,
        gatingLane: gatingLane,
      ),
    );
  }

  void _setPurpose(String? value) {
    if (value == null) return;
    setState(() {
      _requestPurposeKey = value;
      _validationMessage = null;
      if (value == 'deferment') {
        _targetLaneKey = MaintenanceLaneId.operations.value;
        if (_conditionTypeKey == 'manual') {
          _conditionTypeKey = 'chargeComplete';
        }
      } else if (value == 'operationsSupport') {
        _targetLaneKey = MaintenanceLaneId.operations.value;
        _conditionTypeKey = 'manual';
      }
    });
  }
}
