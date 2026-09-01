import 'package:flutter/material.dart';

import '../../../core/theme/baf_design_system.dart';
import '../data/maintenance_model.dart';
import '../domain/burner_lockout_case.dart';
import '../domain/furnace_stuckup_case.dart';
import '../domain/maintenance_ticket_correction.dart';

class MaintenanceTicketCorrectionDialog extends StatefulWidget {
  const MaintenanceTicketCorrectionDialog({super.key, required this.ticket});

  final MaintenanceRecord ticket;

  @override
  State<MaintenanceTicketCorrectionDialog> createState() =>
      _MaintenanceTicketCorrectionDialogState();
}

class _MaintenanceTicketCorrectionDialogState
    extends State<MaintenanceTicketCorrectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _component;
  late final TextEditingController _subsystem;
  late final TextEditingController _tag;
  late final TextEditingController _classification;
  late final TextEditingController _otherDepartment;
  late final TextEditingController _remarks;
  late final TextEditingController _reason;
  late RoutedTo _route;
  late MaintenanceType _maintenanceType;
  late MaintenanceIssuePlantConditionEffect _plantConditionEffect;
  late bool _critical;
  String? _submissionError;

  bool get _isBurnerLockout =>
      widget.ticket.classification == burnerLockoutClassification;

  bool get _isFurnaceStuckup =>
      widget.ticket.classification == furnaceStuckupClassification;

  bool get _isBaseInnerCoverUnavailable =>
      widget.ticket.classification == baseInnerCoverUnavailableClassification;

  bool get _isSpecialized => _isBurnerLockout || _isFurnaceStuckup;

  bool get _hasImmutableIssueIdentity =>
      _isSpecialized || _isBaseInnerCoverUnavailable;

  bool get _hasRedHotBurner =>
      widget.ticket.burnerLockoutReadResult.value?.hasRedHotObservation == true;

  bool get _canCorrectRoute =>
      !_isSpecialized &&
      widget.ticket.status == TicketStatus.open &&
      widget.ticket.acknowledgedByUid == null &&
      widget.ticket.acknowledgedByName == null &&
      widget.ticket.acknowledgedAt == null;

  bool get _usesOtherDepartment =>
      tryMaintenanceTicketCorrectionLanes(
        source: widget.ticket,
        primaryRoute: _route,
      )?.contains(RoutedTo.others) ??
      _route == RoutedTo.others;

  @override
  void initState() {
    super.initState();
    final ticket = widget.ticket;
    _description = TextEditingController(text: ticket.description);
    _component = TextEditingController(text: ticket.component ?? '');
    _subsystem = TextEditingController(text: ticket.subsystem ?? '');
    _tag = TextEditingController(text: ticket.tag ?? '');
    _classification = TextEditingController(text: ticket.classification ?? '');
    _otherDepartment = TextEditingController(
      text: ticket.otherDepartment ?? '',
    );
    _remarks = TextEditingController(text: ticket.remarks ?? '');
    _reason = TextEditingController();
    _route = ticket.routedTo;
    _maintenanceType = ticket.maintenanceType;
    _plantConditionEffect =
        ticket.classification == furnaceStuckupClassification
            ? MaintenanceIssuePlantConditionEffect.stuckUp
            : ticket.effectivePlantConditionEffect ==
                MaintenanceIssuePlantConditionEffect.none
            ? MaintenanceIssuePlantConditionEffect.unfit
            : ticket.effectivePlantConditionEffect;
    _critical = ticket.isCritical;
  }

  @override
  void dispose() {
    _description.dispose();
    _component.dispose();
    _subsystem.dispose();
    _tag.dispose();
    _classification.dispose();
    _otherDepartment.dispose();
    _remarks.dispose();
    _reason.dispose();
    super.dispose();
  }

  String? _optionalLength(
    String? value, {
    required int maximum,
    int minimum = 0,
  }) {
    final length = value?.trim().length ?? 0;
    if (length > 0 && length < minimum) {
      return 'Enter at least $minimum characters';
    }
    if (length > maximum) return 'Use at most $maximum characters';
    return null;
  }

  void _submit() {
    setState(() => _submissionError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      final draft = buildMaintenanceTicketCorrection(
        source: widget.ticket,
        description: _description.text,
        routedTo: _route,
        maintenanceType: _maintenanceType,
        isCritical: _critical,
        plantConditionEffect: _plantConditionEffect,
        component: cleanMaintenanceOptionalText(_component.text),
        subsystem: cleanMaintenanceOptionalText(_subsystem.text),
        tag: cleanMaintenanceTagText(_tag.text),
        classification: cleanMaintenanceOptionalText(_classification.text),
        otherDepartment: cleanMaintenanceOptionalText(_otherDepartment.text),
        remarks: cleanMaintenanceOptionalText(_remarks.text),
        reason: _reason.text,
      );
      Navigator.pop(context, draft);
    } catch (error) {
      setState(() => _submissionError = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Correct issue record'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.40),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.policy_outlined,
                        color: BafColors.warning,
                        size: 22,
                      ),
                      SizedBox(width: BafSpacing.sm),
                      Expanded(
                        child: Text(
                          'Audited correction: preserve what actually happened. Do not invent, erase, or alter evidence to improve the record. Every changed field, the previous value, your identity, time, and reason are retained.',
                          style: TextStyle(
                            color: BafColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(
                    '${widget.ticket.assetType.name.toUpperCase()} ${widget.ticket.assetNumber}',
                  ),
                  subtitle: Text(
                    'Status, asset identity, closure authority, timestamps, work actions, and resolution history remain immutable here. Current status: ${widget.ticket.status.name}.',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length == 0) return 'Enter a description';
                    if (length > 2000) return 'Use at most 2000 characters';
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<RoutedTo>(
                  key: const ValueKey('ticket-correction-route'),
                  initialValue: _route,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Primary accountable lane',
                    helperText:
                        _canCorrectRoute
                            ? null
                            : 'Accountability is locked after acknowledgement or closure.',
                  ),
                  items: [
                    for (final route in RoutedTo.values)
                      DropdownMenuItem(
                        value: route,
                        child: Text(_routeLabel(route)),
                      ),
                  ],
                  onChanged:
                      _canCorrectRoute
                          ? (value) {
                            if (value == null) return;
                            setState(() {
                              _route = value;
                              if (!_usesOtherDepartment) {
                                _otherDepartment.clear();
                              }
                            });
                          }
                          : null,
                ),
                if (_usesOtherDepartment) ...[
                  const SizedBox(height: BafSpacing.sm),
                  TextFormField(
                    key: const ValueKey('ticket-correction-other-department'),
                    controller: _otherDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Other accountable team',
                    ),
                    validator: (value) {
                      if (_usesOtherDepartment &&
                          (value?.trim().isEmpty ?? true)) {
                        return 'Enter the accountable department';
                      }
                      return _optionalLength(value, minimum: 1, maximum: 80);
                    },
                  ),
                ],
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<MaintenanceType>(
                  key: const ValueKey('ticket-correction-maintenance-type'),
                  initialValue: _maintenanceType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Maintenance type',
                  ),
                  items: [
                    for (final type in MaintenanceType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(_maintenanceTypeLabel(type)),
                      ),
                  ],
                  onChanged:
                      _isSpecialized
                          ? null
                          : (value) {
                            if (value != null) {
                              setState(() => _maintenanceType = value);
                            }
                          },
                ),
                const SizedBox(height: BafSpacing.sm),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Critical issue'),
                  subtitle:
                      _hasRedHotBurner
                          ? const Text('Required by red-hot burner evidence')
                          : null,
                  value: _critical,
                  onChanged:
                      _hasRedHotBurner
                          ? null
                          : (value) => setState(() => _critical = value),
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<MaintenanceIssuePlantConditionEffect>(
                  key: const ValueKey('ticket-correction-plant-condition'),
                  initialValue: _plantConditionEffect,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Plant condition while issue is open',
                    helperText:
                        'The originating issue and correction remain audited.',
                  ),
                  items: [
                    for (final effect
                        in _isFurnaceStuckup
                            ? const [
                              MaintenanceIssuePlantConditionEffect.stuckUp,
                            ]
                            : _isBaseInnerCoverUnavailable
                            ? const [
                              MaintenanceIssuePlantConditionEffect.unavailable,
                            ]
                            : const [
                              MaintenanceIssuePlantConditionEffect.unfit,
                              MaintenanceIssuePlantConditionEffect.unavailable,
                            ])
                      DropdownMenuItem(
                        value: effect,
                        child: Text(effect.label),
                      ),
                  ],
                  onChanged:
                      _isFurnaceStuckup || _isBaseInnerCoverUnavailable
                          ? null
                          : (value) {
                            if (value != null) {
                              setState(() => _plantConditionEffect = value);
                            }
                          },
                ),
                TextFormField(
                  key: const ValueKey('ticket-correction-component'),
                  controller: _component,
                  enabled: !_hasImmutableIssueIdentity,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                  validator: (value) {
                    final message = _optionalLength(
                      value,
                      minimum: 1,
                      maximum: 120,
                    );
                    if (message != null) return message;
                    if ((value?.trim().isEmpty ?? true) &&
                        widget.ticket.component?.trim().isNotEmpty == true) {
                      return 'A recorded component cannot be cleared';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  key: const ValueKey('ticket-correction-subsystem'),
                  controller: _subsystem,
                  enabled: !_isBaseInnerCoverUnavailable,
                  decoration: const InputDecoration(
                    labelText: 'Subsystem (optional)',
                  ),
                  validator: (value) => _optionalLength(value, maximum: 1000),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  key: const ValueKey('ticket-correction-tag'),
                  controller: _tag,
                  enabled: !_hasImmutableIssueIdentity,
                  decoration: const InputDecoration(
                    labelText: 'Tag (optional)',
                  ),
                  validator: (value) => _optionalLength(value, maximum: 80),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  key: const ValueKey('ticket-correction-classification'),
                  controller: _classification,
                  enabled: !_hasImmutableIssueIdentity,
                  decoration: const InputDecoration(
                    labelText: 'Classification (optional)',
                  ),
                  validator: (value) => _optionalLength(value, maximum: 1000),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _remarks,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  validator: (value) => _optionalLength(value, maximum: 4000),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  key: const ValueKey('ticket-correction-reason'),
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Why is this correction necessary?',
                    helperText: 'This reason becomes part of the audit record.',
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length == 0) return 'Give a reason for the correction';
                    if (length > 2000) return 'Use at most 2000 characters';
                    return null;
                  },
                ),
                if (_submissionError != null) ...[
                  const SizedBox(height: BafSpacing.md),
                  Text(
                    _submissionError!,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Record correction'),
        ),
      ],
    );
  }

  static String _routeLabel(RoutedTo route) => switch (route) {
    RoutedTo.instrumentation => 'I&A',
    RoutedTo.refractory => 'RED / Refractory',
    RoutedTo.shiftInCharge => 'Shift In-Charge',
    RoutedTo.others => 'Other department',
    _ => route.name[0].toUpperCase() + route.name.substring(1),
  };

  static String _maintenanceTypeLabel(MaintenanceType type) =>
      type.name[0].toUpperCase() + type.name.substring(1);
}
