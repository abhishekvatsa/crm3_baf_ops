import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../assets/presentation/widgets/governed_asset_target_picker.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/serialization/persisted_data_reader.dart';
import '../data/maintenance_model.dart';
import '../domain/burner_lockout_case.dart';
import '../domain/furnace_stuckup_case.dart';
import '../domain/maintenance_ticket_correction.dart';

/// Known snapshot blockers only. The server also checks inverse links and
/// source IDs that are not projected into MaintenanceRecord, including
/// sourceInspectionObservationId, before accepting any target change.
String? maintenanceRegisteredTargetRetentionReason(MaintenanceRecord ticket) {
  if (ticket.status != TicketStatus.open || ticket.isResolved) {
    return 'The equipment target is locked after acknowledgement or closure. Keep the current target and retain the device values.';
  }
  if (const {
    burnerLockoutClassification,
    furnaceStuckupClassification,
    baseInnerCoverUnavailableClassification,
  }.contains(ticket.classification)) {
    return 'The equipment target is fixed by the specialized issue. Keep the current target and retain the device values.';
  }
  if (ticket.continuesIssueId != null ||
      ticket.workflowAggregateId != null ||
      ticket.operationalEventIssueLinkIds.isNotEmpty) {
    return 'This issue has linked evidence. Keep its current equipment target; related records need review before physical scope can change. Device values remain retained.';
  }
  final actions = ticket.actionsReadResult;
  if (!actions.isValid) {
    return 'Saved work evidence needs reconciliation before the equipment target can change. Keep the current target and retain the device values.';
  }
  if (actions.entries.isNotEmpty) {
    return 'This issue has recorded work. Keep its current equipment target; work evidence needs review before physical scope can change. Device values remain retained.';
  }
  try {
    final metadata = readOptionalJsonObject(
      ticket.metadataJson,
      field: 'metadataJson',
      source: 'maintenance target review',
    );
    if (metadata != null &&
        metadata.containsKey('issueLanePlan') &&
        metadata['issueLanePlan'] is! Map) {
      return 'Saved team evidence needs reconciliation before the equipment target can change. Keep the current target and retain the device values.';
    }
    if (ticket
        .issueLanePlanForOtherDepartmentRepair
        .acknowledgedLanes
        .isNotEmpty) {
      return 'The equipment target is locked after a team acknowledges the issue. Keep the current target and retain the device values.';
    }
    // The issue producer creates its quality warning when impact is suspected.
    if (ticket.qualityIntent?.isSuspected == true) {
      return 'This issue has linked quality evidence. Keep its current equipment target; quality records need review before physical scope can change. Device values remain retained.';
    }
  } on FormatException {
    return 'Saved issue evidence needs reconciliation before the equipment target can change. Keep the current target and retain the device values.';
  }
  return null;
}

/// Presentation eligibility; the correction builder and server remain authority.
String? maintenanceCorrectionFieldRetentionReason(
  MaintenanceRecord ticket,
  String field, {
  Object? proposedValue,
}) {
  final burner = ticket.classification == burnerLockoutClassification;
  final stuckup = ticket.classification == furnaceStuckupClassification;
  final availability =
      ticket.classification == baseInnerCoverUnavailableClassification;
  final specialized = burner || stuckup;
  if ((specialized &&
          const {
            'routedTo',
            'maintenanceType',
            'component',
            'subsystem',
            'tag',
            'classification',
          }.contains(field)) ||
      (availability &&
          const {
            'component',
            'subsystem',
            'tag',
            'classification',
            'plantConditionEffect',
          }.contains(field)) ||
      (stuckup && field == 'plantConditionEffect')) {
    return 'This field is fixed by the specialized issue. The device value is retained without being applied.';
  }
  if (field == 'isCritical' &&
      burner &&
      ticket.burnerLockoutReadResult.value?.hasRedHotObservation == true) {
    return 'Criticality is required by red-hot burner evidence. The device value is retained without being applied.';
  }
  if (field == 'routedTo') {
    if (ticket.status != TicketStatus.open ||
        ticket.acknowledgedByUid != null ||
        ticket.acknowledgedByName != null ||
        ticket.acknowledgedAt != null) {
      return 'Accountability is locked after acknowledgement or closure. The device value is retained without being applied.';
    }
    try {
      if (ticket
          .issueLanePlanForOtherDepartmentRepair
          .acknowledgedLanes
          .isNotEmpty) {
        return 'Accountability is locked after acknowledgement or closure. The device value is retained without being applied.';
      }
    } on FormatException {
      return 'Saved team accountability needs reconciliation before routing can change. The device value is retained without being applied.';
    }
  }
  if (field == 'otherDepartment' &&
      ticket.otherDepartment?.trim().isNotEmpty == true) {
    try {
      final lanes = ticket.issueLanePlanForOtherDepartmentRepair;
      if (lanes.acknowledgedLanes.contains(RoutedTo.others.name) ||
          lanes.completedLanes.contains(RoutedTo.others.name)) {
        return 'The other accountable team has already acknowledged this issue. The device value is retained without being applied.';
      }
    } on FormatException {
      return 'Saved team accountability needs reconciliation before the department can change. The device value is retained without being applied.';
    }
  }
  if (ticket.assetHierarchyRefJson != null &&
      const {'component', 'subsystem', 'tag'}.contains(field)) {
    return maintenanceRegisteredTargetRetentionReason(ticket) ??
        'Review a registered target in the correction form. The server checks related records before accepting a target change. Device labels are retained without being copied.';
  }
  if (field == 'classification' &&
      const {
        burnerLockoutClassification,
        furnaceStuckupClassification,
        baseInnerCoverUnavailableClassification,
      }.contains(proposedValue)) {
    return 'A standard issue cannot be reclassified as a specialized issue. The device value is retained without being applied.';
  }
  if (field == 'plantConditionEffect' &&
      proposedValue != null &&
      !const {'unfit', 'unavailable'}.contains(proposedValue)) {
    return 'This issue must mark the asset Unfit or Unavailable. The device value is retained without being applied.';
  }
  return null;
}

class MaintenanceTicketCorrectionDialog extends ConsumerStatefulWidget {
  const MaintenanceTicketCorrectionDialog({
    super.key,
    required this.ticket,
    this.initialValues,
    this.onSubmit,
  });

  final MaintenanceRecord ticket;
  final Map<String, Object?>? initialValues;
  final Future<void> Function(MaintenanceTicketCorrectionDraft)? onSubmit;

  @override
  ConsumerState<MaintenanceTicketCorrectionDialog> createState() =>
      _MaintenanceTicketCorrectionDialogState();
}

class _MaintenanceTicketCorrectionDialogState
    extends ConsumerState<MaintenanceTicketCorrectionDialog> {
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
  bool _submitting = false;
  String? _targetReferenceJson;
  String? _targetLabel;

  bool get _isFurnaceStuckup =>
      widget.ticket.classification == furnaceStuckupClassification;

  bool get _isBaseInnerCoverUnavailable =>
      widget.ticket.classification == baseInnerCoverUnavailableClassification;

  bool _canEdit(String field) =>
      maintenanceCorrectionFieldRetentionReason(widget.ticket, field) == null;

  Future<void> _selectCorrectedTarget() async {
    try {
      final retentionReason = maintenanceRegisteredTargetRetentionReason(
        widget.ticket,
      );
      if (retentionReason != null) throw StateError(retentionReason);
      final original = widget.ticket.assetHierarchyReference;
      if (original == null) {
        throw StateError('The registered target must be reconciled first.');
      }
      final repository = ref.read(assetHierarchyRepositoryProvider);
      final assets = await repository
          .watchAssetInstances(original.assetClassId)
          .first;
      final asset = assets.singleWhere(
        (value) => value.id == original.assetInstanceId,
      );
      final nodes = await repository.watchNodes(original.assetClassId).first;
      if (!mounted) return;
      final selection = await showGovernedAssetTargetPicker(
        context: context,
        asset: asset,
        nodes: nodes,
        selectedNodeId: original.nodeId,
      );
      if (!mounted || selection?.reference == null) return;
      setState(() {
        _targetReferenceJson = selection!.reference!.encode();
        _targetLabel = selection.node!.name;
      });
    } catch (error) {
      if (mounted) setState(() => _submissionError = '$error');
    }
  }

  bool get _hasRedHotBurner =>
      widget.ticket.burnerLockoutReadResult.value?.hasRedHotObservation == true;

  bool get _canCorrectRoute => _canEdit('routedTo');

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
    final initial = <String, Object?>{
      for (final entry
          in (widget.initialValues ?? const <String, Object?>{}).entries)
        if (maintenanceCorrectionFieldRetentionReason(
              ticket,
              entry.key,
              proposedValue: entry.value,
            ) ==
            null)
          entry.key: entry.value,
    };
    String text(String field, String? fallback) =>
        (initial.containsKey(field) ? initial[field] as String? : fallback) ??
        '';
    _description = TextEditingController(
      text: text('description', ticket.description),
    );
    _component = TextEditingController(
      text: text('component', ticket.component),
    );
    _subsystem = TextEditingController(
      text: text('subsystem', ticket.subsystem),
    );
    _tag = TextEditingController(text: text('tag', ticket.tag));
    _classification = TextEditingController(
      text: text('classification', ticket.classification),
    );
    _otherDepartment = TextEditingController(
      text: text('otherDepartment', ticket.otherDepartment),
    );
    _remarks = TextEditingController(text: text('remarks', ticket.remarks));
    _reason = TextEditingController();
    _route = RoutedTo.values.byName(text('routedTo', ticket.routedTo.name));
    _maintenanceType = MaintenanceType.values.byName(
      text('maintenanceType', ticket.maintenanceType.name),
    );
    _plantConditionEffect = initial.containsKey('plantConditionEffect')
        ? MaintenanceIssuePlantConditionEffect.values.byName(
            initial['plantConditionEffect'] as String,
          )
        : ticket.classification == furnaceStuckupClassification
        ? MaintenanceIssuePlantConditionEffect.stuckUp
        : ticket.effectivePlantConditionEffect ==
              MaintenanceIssuePlantConditionEffect.none
        ? MaintenanceIssuePlantConditionEffect.unfit
        : ticket.effectivePlantConditionEffect;
    _critical = initial['isCritical'] as bool? ?? ticket.isCritical;
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

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submissionError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      if (_targetReferenceJson != null) {
        final retentionReason = maintenanceRegisteredTargetRetentionReason(
          widget.ticket,
        );
        if (retentionReason != null) throw StateError(retentionReason);
      }
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
        targetReferenceJson: _targetReferenceJson,
      );
      await widget.onSubmit?.call(draft);
      if (!mounted) return;
      Navigator.pop(context, draft);
    } catch (error) {
      if (mounted) setState(() => _submissionError = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        title: const Text('Correct issue record'),
        content: AbsorbPointer(
          absorbing: _submitting,
          child: ConstrainedBox(
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
                      key: const ValueKey('ticket-correction-description'),
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
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
                        helperText: _canCorrectRoute
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
                      onChanged: _canCorrectRoute
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
                        key: const ValueKey(
                          'ticket-correction-other-department',
                        ),
                        controller: _otherDepartment,
                        enabled: _canEdit('otherDepartment'),
                        decoration: InputDecoration(
                          labelText: 'Other accountable team',
                          helperText: _canEdit('otherDepartment')
                              ? null
                              : 'Accountability is locked after this team acknowledges the issue.',
                        ),
                        validator: (value) {
                          if (_usesOtherDepartment &&
                              (value?.trim().isEmpty ?? true)) {
                            return 'Enter the accountable department';
                          }
                          return _optionalLength(
                            value,
                            minimum: 1,
                            maximum: 80,
                          );
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
                      onChanged: _canEdit('maintenanceType')
                          ? (value) {
                              if (value != null) {
                                setState(() => _maintenanceType = value);
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    SwitchListTile.adaptive(
                      key: const ValueKey('ticket-correction-critical'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Critical issue'),
                      subtitle: _hasRedHotBurner
                          ? const Text('Required by red-hot burner evidence')
                          : null,
                      value: _critical,
                      onChanged: _canEdit('isCritical')
                          ? (value) => setState(() => _critical = value)
                          : null,
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    DropdownButtonFormField<
                      MaintenanceIssuePlantConditionEffect
                    >(
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
                                    MaintenanceIssuePlantConditionEffect
                                        .stuckUp,
                                  ]
                                : _isBaseInnerCoverUnavailable
                                ? const [
                                    MaintenanceIssuePlantConditionEffect
                                        .unavailable,
                                  ]
                                : const [
                                    MaintenanceIssuePlantConditionEffect.unfit,
                                    MaintenanceIssuePlantConditionEffect
                                        .unavailable,
                                  ])
                          DropdownMenuItem(
                            value: effect,
                            child: Text(effect.label),
                          ),
                      ],
                      onChanged: _canEdit('plantConditionEffect')
                          ? (value) {
                              if (value != null) {
                                setState(() => _plantConditionEffect = value);
                              }
                            }
                          : null,
                    ),
                    if (widget.ticket.assetHierarchyRefJson != null) ...[
                      if (maintenanceRegisteredTargetRetentionReason(
                            widget.ticket,
                          ) ==
                          null) ...[
                        OutlinedButton.icon(
                          key: const ValueKey('ticket-correction-target'),
                          onPressed: _selectCorrectedTarget,
                          icon: const Icon(Icons.account_tree_outlined),
                          label: Text(
                            _targetLabel == null
                                ? 'Review registered target on this asset'
                                : 'Target selected for review: $_targetLabel',
                          ),
                        ),
                        const Text(
                          'The server checks related records before accepting a target change. Existing work or linked evidence must keep its original equipment scope until reviewed.',
                        ),
                      ] else
                        Text(
                          maintenanceRegisteredTargetRetentionReason(
                            widget.ticket,
                          )!,
                        ),
                    ],
                    TextFormField(
                      key: const ValueKey('ticket-correction-component'),
                      controller: _component,
                      enabled: _canEdit('component'),
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
                            widget.ticket.component?.trim().isNotEmpty ==
                                true) {
                          return 'A recorded component cannot be cleared';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    TextFormField(
                      key: const ValueKey('ticket-correction-subsystem'),
                      controller: _subsystem,
                      enabled: _canEdit('subsystem'),
                      decoration: const InputDecoration(
                        labelText: 'Subsystem (optional)',
                      ),
                      validator: (value) =>
                          _optionalLength(value, maximum: 1000),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    TextFormField(
                      key: const ValueKey('ticket-correction-tag'),
                      controller: _tag,
                      enabled: _canEdit('tag'),
                      decoration: const InputDecoration(
                        labelText: 'Tag (optional)',
                      ),
                      validator: (value) => _optionalLength(value, maximum: 80),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    TextFormField(
                      key: const ValueKey('ticket-correction-classification'),
                      controller: _classification,
                      enabled: _canEdit('classification'),
                      decoration: const InputDecoration(
                        labelText: 'Classification (optional)',
                      ),
                      validator: (value) =>
                          _optionalLength(value, maximum: 1000),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    TextFormField(
                      key: const ValueKey('ticket-correction-remarks'),
                      controller: _remarks,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(labelText: 'Remarks'),
                      validator: (value) =>
                          _optionalLength(value, maximum: 4000),
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
                        helperText:
                            'This reason becomes part of the audit record.',
                      ),
                      validator: (value) {
                        final length = value?.trim().length ?? 0;
                        if (length == 0) {
                          return 'Give a reason for the correction';
                        }
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
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(
              _submitting ? 'Checking correction…' : 'Record correction',
            ),
          ),
        ],
      ),
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
