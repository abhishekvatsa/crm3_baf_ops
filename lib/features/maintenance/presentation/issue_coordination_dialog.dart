import 'package:flutter/material.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/validation/charge_number.dart';
import '../data/maintenance_model.dart';
import '../domain/issue_coordination_draft.dart';

Future<IssueCoordinationDraft?> showIssueCoordinationDialog(
  BuildContext context, {
  required MaintenanceRecord ticket,
}) => showDialog<IssueCoordinationDraft>(
  context: context,
  builder: (_) => _IssueCoordinationDialog(ticket: ticket),
);

class _IssueCoordinationDialog extends StatefulWidget {
  final MaintenanceRecord ticket;

  const _IssueCoordinationDialog({required this.ticket});

  @override
  State<_IssueCoordinationDialog> createState() =>
      _IssueCoordinationDialogState();
}

class _IssueCoordinationDialogState extends State<_IssueCoordinationDialog> {
  late final TextEditingController _chargeController;
  late final TextEditingController _activityController;
  late final TextEditingController _locationController;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  IssueCoordinationPurpose _purpose = IssueCoordinationPurpose.deferment;
  IssueCoordinationCondition _condition =
      IssueCoordinationCondition.chargeComplete;
  String _defermentBasis = 'ongoingCycle';
  String _supportType = 'craneMovement';
  String _resource = 'crane';
  String _priority = 'high';
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _chargeController = TextEditingController(
      text: widget.ticket.chargeNoAtEvent?.toString() ?? '',
    );
    _activityController = TextEditingController();
    _locationController = TextEditingController();
    _titleController = TextEditingController(
      text: 'Await current cycle completion',
    );
    _descriptionController = TextEditingController(
      text:
          'Operations to confirm the release condition before maintenance resumes on ${_assetLabel(widget.ticket)}.',
    );
  }

  @override
  void dispose() {
    _chargeController.dispose();
    _activityController.dispose();
    _locationController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.handshake_outlined, color: BafColors.warning),
      title: const Text('Coordinate with Operations'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BafSpacing.md),
                decoration: BoxDecoration(
                  color: BafColors.warning.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                  border: Border.all(
                    color: BafColors.warning.withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  '${_assetLabel(widget.ticket)} · ${widget.ticket.component ?? 'Maintenance issue'}',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: BafSpacing.lg),
              BafHorizontalControlRail(
                child: SegmentedButton<IssueCoordinationPurpose>(
                  segments: const [
                    ButtonSegment(
                      value: IssueCoordinationPurpose.deferment,
                      icon: Icon(Icons.pause_circle_outline_rounded),
                      label: Text('Deferment'),
                    ),
                    ButtonSegment(
                      value: IssueCoordinationPurpose.operationsSupport,
                      icon: Icon(Icons.precision_manufacturing_outlined),
                      label: Text('Operations support'),
                    ),
                  ],
                  selected: <IssueCoordinationPurpose>{_purpose},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    _setPurpose(selection.first);
                  },
                ),
              ),
              const SizedBox(height: BafSpacing.lg),
              if (_purpose == IssueCoordinationPurpose.deferment)
                ..._defermentFields()
              else
                ..._supportFields(),
              TextField(
                controller: _titleController,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Request title'),
              ),
              const SizedBox(height: BafSpacing.sm),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Required action and completion evidence',
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _priority = value);
                },
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: BafSpacing.md),
                Text(
                  _validationMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
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
          icon: const Icon(Icons.send_rounded),
          label: const Text('Send to Operations'),
        ),
      ],
    );
  }

  List<Widget> _defermentFields() => [
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _defermentBasis,
      decoration: const InputDecoration(labelText: 'Reason for deferment'),
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
        if (value != null) setState(() => _defermentBasis = value);
      },
    ),
    const SizedBox(height: BafSpacing.md),
    BafHorizontalControlRail(
      child: SegmentedButton<IssueCoordinationCondition>(
        segments: const [
          ButtonSegment(
            value: IssueCoordinationCondition.chargeComplete,
            icon: Icon(Icons.confirmation_number_outlined),
            label: Text('Charge complete'),
          ),
          ButtonSegment(
            value: IssueCoordinationCondition.activityRef,
            icon: Icon(Icons.task_alt_outlined),
            label: Text('Activity complete'),
          ),
        ],
        selected: <IssueCoordinationCondition>{_condition},
        onSelectionChanged: (selection) {
          if (selection.isNotEmpty) {
            setState(() => _condition = selection.first);
          }
        },
      ),
    ),
    const SizedBox(height: BafSpacing.md),
    if (_condition == IssueCoordinationCondition.chargeComplete)
      TextField(
        controller: _chargeController,
        keyboardType: TextInputType.number,
        inputFormatters: chargeNumberInputFormatters,
        decoration: const InputDecoration(
          labelText: 'Five-digit charge number',
          counterText: '',
        ),
        maxLength: 5,
      )
    else
      TextField(
        controller: _activityController,
        maxLength: 300,
        decoration: const InputDecoration(
          labelText: 'Activity that must be completed',
        ),
      ),
    const SizedBox(height: BafSpacing.md),
  ];

  List<Widget> _supportFields() => [
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _supportType,
      decoration: const InputDecoration(labelText: 'Support required'),
      items: const [
        DropdownMenuItem(value: 'craneMovement', child: Text('Crane movement')),
        DropdownMenuItem(
          value: 'assetRelocation',
          child: Text('Asset relocation'),
        ),
        DropdownMenuItem(value: 'isolation', child: Text('Isolation')),
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
        if (value != null) setState(() => _supportType = value);
      },
    ),
    const SizedBox(height: BafSpacing.md),
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _resource,
      decoration: const InputDecoration(labelText: 'Operations resource'),
      items: const [
        DropdownMenuItem(value: 'crane', child: Text('Crane')),
        DropdownMenuItem(value: 'transferCar', child: Text('Transfer car')),
        DropdownMenuItem(
          value: 'operationsCrew',
          child: Text('Operations crew'),
        ),
        DropdownMenuItem(value: 'utilities', child: Text('Utilities')),
        DropdownMenuItem(value: 'other', child: Text('Other')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _resource = value);
      },
    ),
    const SizedBox(height: BafSpacing.md),
    TextField(
      controller: _locationController,
      maxLength: 300,
      decoration: InputDecoration(
        labelText:
            const <String>{
                  'craneMovement',
                  'assetRelocation',
                }.contains(_supportType)
                ? 'Destination / work location'
                : 'Location (optional)',
      ),
    ),
    const SizedBox(height: BafSpacing.md),
  ];

  void _setPurpose(IssueCoordinationPurpose purpose) {
    setState(() {
      _purpose = purpose;
      _validationMessage = null;
      if (purpose == IssueCoordinationPurpose.deferment) {
        _titleController.text = 'Await current cycle completion';
        _descriptionController.text =
            'Operations to confirm the release condition before maintenance resumes on ${_assetLabel(widget.ticket)}.';
      } else {
        _titleController.text = 'Operations support required';
        _descriptionController.text =
            'Provide the selected operational support before maintenance resumes on ${_assetLabel(widget.ticket)}.';
      }
    });
  }

  void _submit() {
    try {
      final draft = IssueCoordinationDraft.validate(
        purpose: _purpose,
        condition: _condition,
        conditionChargeText: _chargeController.text,
        conditionRef: _activityController.text,
        defermentBasisKey: _defermentBasis,
        operationsSupportTypeKey: _supportType,
        operationsResourceKey: _resource,
        requestedLocation: _locationController.text,
        title: _titleController.text,
        description: _descriptionController.text,
        priorityKey: _priority,
      );
      Navigator.pop(context, draft);
    } on FormatException catch (error) {
      setState(() => _validationMessage = error.message);
    }
  }
}

String _assetLabel(MaintenanceRecord ticket) =>
    '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}';
