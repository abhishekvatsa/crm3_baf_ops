// FILE: lib/features/planned_maintenance/presentation/complete_job_screen.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/job_template_model.dart';
import '../data/job_module_model.dart';
import '../models/component_action_model.dart';
import '../providers/planned_maintenance_provider.dart';
import '../providers/job_module_provider.dart';
import '../services/planned_job_server_completion_service.dart';
import '../widgets/action_bottom_sheet.dart';
import '../widgets/action_mini_card.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../maintenance_workflow/data/job_lane_record.dart';
import '../../maintenance_workflow/data/workflow_aggregate_record.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/domain/workflow_policy.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../maintenance_workflow/presentation/widgets/red_exit_dialog.dart';

class CompleteJobScreen extends ConsumerStatefulWidget {
  final JobExecution execution;

  const CompleteJobScreen({super.key, required this.execution});

  @override
  ConsumerState<CompleteJobScreen> createState() => _CompleteJobScreenState();
}

enum _CompletionPhase { idle, preflightSync, completing }

class _CompleteJobScreenState extends ConsumerState<CompleteJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();

  bool _isSubmitting = false;
  bool _loadingTemplate = true;
  _CompletionPhase _completionPhase = _CompletionPhase.idle;

  JobTemplate? _template;

  final Set<String> _teamsInvolved = {};
  final Map<String, dynamic> _responses = {};
  final List<ComponentAction> _actions = [];

  @override
  void initState() {
    super.initState();
    final actionRead = widget.execution.actionsReadResult;
    if (actionRead.isValid) {
      _actions.addAll(actionRead.entries);
    }
    final responseRead = widget.execution.responsesReadResult;
    if (responseRead.isValid) {
      for (final response in responseRead.entries) {
        _responses[response.key] = response.value;
      }
    }
    _loadTemplate();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  JobModuleQueryKey get _moduleQueryKey => JobModuleQueryKey(
    jobExecutionFirestoreId: widget.execution.firestoreId,
    jobExecutionLocalId: widget.execution.id,
  );

  Future<void> _loadTemplate() async {
    if (widget.execution.isGovernedTemplateAssignment) {
      if (mounted) setState(() => _loadingTemplate = false);
      return;
    }

    try {
      JobTemplate? template;
      final id = widget.execution.templateFirestoreId;

      if (id.isNotEmpty) {
        template = await ref
            .read(plannedRepositoryProvider)
            .getTemplateByFirestoreId(id);
      }

      if (!mounted) return;
      setState(() {
        _template = template;
        _loadingTemplate = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTemplate = false);
    }
  }

  Future<void> _submit() async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null || !appUser.canCompleteJobExecution) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are not authorized to complete planned jobs.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    if (!widget.execution.actionsReadResult.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot complete: saved action evidence needs repair.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    if (!widget.execution.responsesReadResult.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot complete: saved response evidence needs repair.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }

    final moduleGate = _ModuleClosureGateResult.fromAsyncValue(
      ref.read(jobModulesProvider(_moduleQueryKey)),
    );
    if (!moduleGate.canComplete) {
      await _showModuleGateDialog(moduleGate);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_template != null) {
      for (final field in _orderedFields(_template!)) {
        if (_isDisplayOnlyField(field)) continue;
        if (field.isRequired && _isMissingRequired(field)) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text('Required field missing: ${field.label}'),
              backgroundColor: BafColors.danger,
            ),
          );
          return;
        }
      }
    }

    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _completionPhase = _CompletionPhase.preflightSync;
    });

    try {
      final repository = ref.read(plannedRepositoryProvider);
      SyncCoordinator? syncCoordinator;

      final remarks = _remarksController.text.trim();

      final existingResponses = widget.execution.responsesReadResult.entries;
      final existingByKey = <String, FieldResponse>{
        for (final response in existingResponses) response.key: response,
      };
      final editableFields =
          _template == null
              ? const <TemplateField>[]
              : _orderedFields(
                _template!,
              ).where((field) => !_isDisplayOnlyField(field)).toList();
      final editableKeys = editableFields.map((field) => field.key).toSet();
      final fieldResponses =
          _template == null
              ? null
              : <FieldResponse>[
                ...editableFields.map((field) {
                  final existing = existingByKey[field.key];
                  return FieldResponse(
                    key: field.key,
                    fieldLabel: field.label,
                    fieldType: field.type,
                    value: _responses[field.key] ?? '',
                    extensions: existing?.extensions,
                  );
                }),
                ...existingResponses.where(
                  (response) => !editableKeys.contains(response.key),
                ),
              ];

      final id = kIsWeb ? widget.execution.firestoreId : widget.execution.id;
      if (id == null) throw Exception('Execution ID missing');

      try {
        final coordinator = ref.read(syncCoordinatorProvider);
        syncCoordinator = coordinator;
        await coordinator.runFullSyncWithResult(
          reason: 'pre_complete_planned_job',
          force: true,
        );
      } catch (_) {
        // Best effort only. The completion repository/server path below remains
        // the authoritative guard and reports any still-unsynced modules.
        if (!mounted) return;
      }

      if (!mounted) return;
      setState(() => _completionPhase = _CompletionPhase.completing);

      if (widget.execution.workflowSchemaVersion == 1) {
        final workflowId = widget.execution.firestoreId?.trim();
        if (workflowId == null || workflowId.isEmpty) {
          throw StateError('Workflow execution identity is missing.');
        }
        final workflowRepository = ref.read(workflowRepositoryProvider);
        final workflow = await workflowRepository.getWorkflow(workflowId);
        if (workflow == null) {
          throw StateError(
            'Maintenance workflow is not available locally. Synchronize and try again.',
          );
        }
        final lanes = await workflowRepository.getLanes(workflowId);
        final activeLanes = lanes.where(
          (lane) =>
              lane.statusKey != 'removed' && lane.statusKey != 'terminated',
        );
        if (activeLanes.isEmpty ||
            activeLanes.any((lane) => lane.statusKey != 'closed')) {
          throw StateError(
            'Every active maintenance lane must be closed before final job closure.',
          );
        }

        final redAlreadySelected = activeLanes.any(
          (lane) => lane.laneKey == 'red',
        );
        RedExitAnswers? redAnswers;
        final assetTypeKey = widget.execution.assetType.name;
        if (WorkflowPolicy.isRedApplicable(assetTypeKey) &&
            !redAlreadySelected) {
          if (!mounted) return;
          redAnswers = await showRedExitDialog(
            context,
            askPreparation: WorkflowPolicy.requiresStandPreparationQuestion(
              assetTypeKey,
            ),
          );
          if (!mounted || redAnswers == null) return;
        }

        final command = WorkflowCommandFactory.create(
          type: WorkflowCommandType.finalizeJob,
          aggregateId: workflowId,
          expectedVersion: workflow.version,
          payload: <String, Object?>{
            'remarks': remarks,
            'teamsInvolved': _teamsInvolved.toList(growable: false),
            'responsesJson':
                fieldResponses == null
                    ? widget.execution.responsesJson
                    : FieldResponse.encode(fieldResponses),
            'actionsJson': ComponentAction.encode(_actions),
            if (redAnswers != null) 'redRequired': redAnswers.redRequired,
            if (redAnswers?.preparationRequired != null)
              'preparationRequired': redAnswers!.preparationRequired,
          },
        );
        await ref
            .read(workflowCommandControllerProvider.notifier)
            .execute(command);
      } else {
        await repository.completeExecution(
          id,
          actor: appUser,
          remarks: remarks,
          teamsInvolved: _teamsInvolved.toList(),
          responses: fieldResponses,
          actions: _actions.isEmpty ? null : _actions,
        );
      }

      if (syncCoordinator != null) {
        unawaited(
          syncCoordinator.runFullSync(reason: 'job_completed', force: true),
        );
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.pop(context);

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Job marked as completed'),
          backgroundColor: BafColors.sync,
        ),
      );
    } on PlannedJobServerClosureGateException catch (e) {
      if (!mounted) return;
      await _showServerClosureGateDialog(e);
    } on PlannedJobServerCompletionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(e.operatorMessage),
          backgroundColor: BafColors.danger,
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      final message =
          e.message.toLowerCase().contains('unsynced module')
              ? 'Some module changes could not be synced to the server. Open the execution dossier, check the affected module, and try again.'
              : e.message;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), backgroundColor: BafColors.danger),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to complete: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _completionPhase = _CompletionPhase.idle;
        });
      }
    }
  }

  bool _isDisplayOnlyField(TemplateField field) {
    return field.type == FieldType.sectionHeader ||
        field.type == FieldType.instruction;
  }

  bool _isMissingRequired(TemplateField field) {
    final value = _responses[field.key];
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    return false;
  }

  List<TemplateField> _orderedFields(JobTemplate template) {
    return List<TemplateField>.from(template.parsedFields)
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> _addAction() async {
    final result = await showModalBottomSheet<ComponentAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BafColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ActionBottomSheet(),
    );

    if (!mounted || result == null) return;
    setState(() => _actions.add(result));
  }

  Widget _buildField(TemplateField field) {
    switch (field.type) {
      case FieldType.text:
        return _FieldPadding(
          child: TextFormField(
            decoration: _inputDecoration(_requiredLabel(field)),
            onChanged: (value) => _responses[field.key] = value,
            validator: (value) {
              if (field.isRequired && (value == null || value.trim().isEmpty)) {
                return 'Required';
              }
              return null;
            },
          ),
        );

      case FieldType.longText:
        return _FieldPadding(
          child: TextFormField(
            maxLines: 3,
            decoration: _inputDecoration(
              _requiredLabel(field),
              alignLabelWithHint: true,
            ),
            onChanged: (value) => _responses[field.key] = value,
            validator: (value) {
              if (field.isRequired && (value == null || value.trim().isEmpty)) {
                return 'Required';
              }
              return null;
            },
          ),
        );

      case FieldType.number:
        return _FieldPadding(
          child: TextFormField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDecoration(
              field.unit != null && field.unit!.trim().isNotEmpty
                  ? '${_requiredLabel(field)} (${field.unit})'
                  : _requiredLabel(field),
            ),
            onChanged:
                (value) =>
                    _responses[field.key] =
                        double.tryParse(value.trim()) ?? value,
            validator: (value) {
              if (field.isRequired && (value == null || value.trim().isEmpty)) {
                return 'Required';
              }
              if (value != null &&
                  value.trim().isNotEmpty &&
                  double.tryParse(value.trim()) == null) {
                return 'Enter a valid number';
              }
              return null;
            },
          ),
        );

      case FieldType.yesNo:
        final value =
            _responses[field.key] == true || _responses[field.key] == 'true';
        return _FieldPadding(
          child: _ToggleCard(
            label: _requiredLabel(field),
            value: value,
            onChanged: (newValue) {
              setState(() => _responses[field.key] = newValue);
            },
          ),
        );

      case FieldType.checkbox:
        final value =
            _responses[field.key] == true || _responses[field.key] == 'true';
        return _FieldPadding(
          child: _CheckboxCard(
            label: _requiredLabel(field),
            value: value,
            onChanged: (newValue) {
              setState(() => _responses[field.key] = newValue ?? false);
            },
          ),
        );

      case FieldType.dropdown:
        final selected = _responses[field.key] as String?;
        return _FieldPadding(
          child: DropdownButtonFormField<String>(
            initialValue: selected,
            isExpanded: true,
            decoration: _inputDecoration(_requiredLabel(field)),
            items:
                (field.options ?? [])
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              setState(() => _responses[field.key] = value ?? '');
            },
            validator: (value) {
              if (field.isRequired && (value == null || value.isEmpty)) {
                return 'Required';
              }
              return null;
            },
          ),
        );

      case FieldType.multiSelect:
        final selected =
            (_responses[field.key] as List?)?.cast<String>() ?? <String>[];
        return _FieldPadding(
          child: _MultiSelectField(
            label: _requiredLabel(field),
            options: field.options ?? const [],
            selected: selected,
            requiredField: field.isRequired,
            onChanged: (updated) {
              setState(() => _responses[field.key] = updated);
            },
          ),
        );

      case FieldType.dateTime:
        final current = _responses[field.key] as String?;
        return _FieldPadding(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (!mounted || date == null) return;

              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (!mounted) return;

              final combined =
                  time == null
                      ? date
                      : DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );

              setState(() {
                _responses[field.key] = combined.toIso8601String();
              });
            },
            borderRadius: BorderRadius.circular(BafRadius.medium),
            child: InputDecorator(
              decoration: _inputDecoration(
                _requiredLabel(field),
                suffixIcon: const Icon(Icons.calendar_month_rounded),
              ),
              child: Text(
                _formatDateTimeResponse(current),
                style: TextStyle(
                  color:
                      current != null
                          ? BafColors.textPrimary
                          : BafColors.textSecondary,
                  fontWeight:
                      current != null ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );

      case FieldType.sectionHeader:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 14, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: BafColors.planned.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(
              color: BafColors.planned.withValues(alpha: 0.16),
            ),
          ),
          child: Text(
            field.label.toUpperCase(),
            style: const TextStyle(
              color: BafColors.planned,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.9,
            ),
          ),
        );

      case FieldType.instruction:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BafColors.assets.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(BafRadius.medium),
            border: Border.all(color: BafColors.assets.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: BafColors.assets,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  field.instructionText ?? field.label,
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTemplate) {
      return const Scaffold(
        backgroundColor: BafColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final fields =
        _template == null ? <TemplateField>[] : _orderedFields(_template!);
    final modulesAsync = ref.watch(jobModulesProvider(_moduleQueryKey));
    final moduleGate = _ModuleClosureGateResult.fromAsyncValue(modulesAsync);
    final appUser = ref.watch(currentAppUserProvider).value;
    final hasCompletionAuthority = appUser?.canCompleteJobExecution ?? false;
    final actionRead = widget.execution.actionsReadResult;
    final responseRead = widget.execution.responsesReadResult;
    final workflowId = widget.execution.firestoreId?.trim();
    final workflowAsync =
        widget.execution.workflowSchemaVersion == 1 &&
                workflowId != null &&
                workflowId.isNotEmpty
            ? ref.watch(workflowRecordProvider(workflowId))
            : null;
    final workflowLanesAsync =
        widget.execution.workflowSchemaVersion == 1 &&
                workflowId != null &&
                workflowId.isNotEmpty
            ? ref.watch(workflowLanesProvider(workflowId))
            : null;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text(
          'Complete Job',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: BafColors.card,
        foregroundColor: BafColors.textPrimary,
        elevation: 0,
        surfaceTintColor: BafColors.card,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            BafSpacing.lg,
            BafSpacing.sm,
            BafSpacing.lg,
            112,
          ),
          children: [
            _JobContextCard(execution: widget.execution),
            if (!actionRead.isValid) ...[
              const SizedBox(height: BafSpacing.lg),
              const PersistedDataIntegrityNotice(
                title: 'Saved action evidence needs repair',
                message:
                    'Completion is blocked until this payload is repaired. No saved actions were discarded or replaced.',
              ),
            ],
            if (!responseRead.isValid) ...[
              const SizedBox(height: BafSpacing.lg),
              const PersistedDataIntegrityNotice(
                title: 'Saved response evidence needs repair',
                message:
                    'Completion is blocked until this payload is repaired. No saved responses were discarded or replaced.',
              ),
            ],
            const SizedBox(height: BafSpacing.lg),
            _CompletionAuthorityCard(hasAuthority: hasCompletionAuthority),
            const SizedBox(height: BafSpacing.lg),
            _ModuleClosureGateCard(gate: moduleGate),
            if (workflowAsync != null && workflowLanesAsync != null) ...[
              const SizedBox(height: BafSpacing.lg),
              _WorkflowClosureGateCard(
                workflowAsync: workflowAsync,
                lanesAsync: workflowLanesAsync,
              ),
            ],
            if (!widget.execution.isGovernedTemplateAssignment) ...[
              const SizedBox(height: BafSpacing.lg),
              _SectionCard(
                title: 'Checklist responses',
                subtitle:
                    fields.isEmpty
                        ? 'No checklist was defined for this legacy template.'
                        : 'Complete the required checks before closing the job.',
                icon: Icons.fact_check_rounded,
                children:
                    fields.isEmpty
                        ? const [
                          Text(
                            'No checklist defined for this legacy template.',
                            style: TextStyle(
                              color: BafColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ]
                        : fields.map(_buildField).toList(),
              ),
            ],
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Actions / observations',
              subtitle: 'Record component-level observations or work done.',
              icon: Icons.build_circle_rounded,
              children: [
                if (_actions.isEmpty)
                  const _EmptyInlineState(
                    icon: Icons.add_task_rounded,
                    text: 'No actions added yet.',
                    color: BafColors.planned,
                  )
                else
                  ..._actions.map((action) => ActionMiniCard(action: action)),
                const SizedBox(height: BafSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: actionRead.isValid ? _addAction : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BafColors.planned,
                      side: BorderSide(
                        color: BafColors.planned.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(BafRadius.medium),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Add Action / Observation',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Teams and remarks',
              subtitle: 'Capture who attended and any final notes.',
              icon: Icons.groups_rounded,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _teamKeys.map((team) {
                        final selected = _teamsInvolved.contains(team);
                        return FilterChip(
                          label: Text(_teamLabel(team)),
                          selected: selected,
                          selectedColor: BafColors.planned.withValues(
                            alpha: 0.14,
                          ),
                          checkmarkColor: BafColors.planned,
                          side: BorderSide(
                            color:
                                selected
                                    ? BafColors.planned.withValues(alpha: 0.35)
                                    : BafColors.border,
                          ),
                          onSelected: (value) {
                            setState(() {
                              value
                                  ? _teamsInvolved.add(team)
                                  : _teamsInvolved.remove(team);
                            });
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: BafSpacing.lg),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    'Remarks (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _CompleteJobBottomBar(
        isSubmitting: _isSubmitting,
        completionPhase: _completionPhase,
        hasCompletionAuthority: hasCompletionAuthority,
        onSubmit:
            _isSubmitting ||
                    !hasCompletionAuthority ||
                    !actionRead.isValid ||
                    !responseRead.isValid ||
                    !moduleGate.canComplete
                ? null
                : _submit,
      ),
    );
  }

  Future<void> _showModuleGateDialog(_ModuleClosureGateResult gate) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: BafColors.card,
          surfaceTintColor: BafColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.large),
          ),
          title: const Row(
            children: [
              Icon(Icons.rule_rounded, color: BafColors.warning),
              SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  'Module closure gate blocked',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This planned job cannot be completed until the required process modules satisfy the closure gate.',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    gate.blockingMessage,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Review Modules'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showServerClosureGateDialog(
    PlannedJobServerClosureGateException error,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: BafColors.card,
          surfaceTintColor: BafColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BafRadius.large),
          ),
          title: const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: BafColors.warning),
              SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  'Server closure gate blocked',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'The server rechecked the latest synced module state and rejected final completion. This protects the planned-job dossier from stale local data.',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    error.blockingMessage,
                    style: const TextStyle(
                      color: BafColors.textPrimary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Review Modules'),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    bool alignLabelWithHint = false,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: alignLabelWithHint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: BafColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
        borderSide: const BorderSide(color: BafColors.planned, width: 1.5),
      ),
    );
  }

  String _requiredLabel(TemplateField field) {
    return field.isRequired ? '${field.label} *' : field.label;
  }

  String _formatDateTimeResponse(String? value) {
    if (value == null || value.isEmpty) return 'Tap to select';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd MMM yyyy, HH:mm').format(parsed);
  }

  static const List<String> _teamKeys = [
    'electrical',
    'mechanical',
    'instrumentation',
    'refractory',
    'emd',
  ];

  String _teamLabel(String team) {
    switch (team) {
      case 'electrical':
        return 'ELECTRICAL';
      case 'mechanical':
        return 'MECHANICAL';
      case 'instrumentation':
        return 'I&A';
      case 'refractory':
        return 'REFRACTORY';
      case 'emd':
        return 'EMD';
      default:
        return team.toUpperCase();
    }
  }
}

class _CompletionAuthorityCard extends StatelessWidget {
  final bool hasAuthority;

  const _CompletionAuthorityCard({required this.hasAuthority});

  @override
  Widget build(BuildContext context) {
    final color = hasAuthority ? BafColors.sync : BafColors.warning;
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasAuthority
                ? Icons.verified_user_rounded
                : Icons.lock_clock_rounded,
            color: color,
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAuthority
                      ? 'Completion authority verified'
                      : 'Completion authority required',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasAuthority
                      ? 'Final planned-job closure may be performed by supervisor, Admin, or SI roles. Module readiness is checked separately below.'
                      : 'Only Admin, SI, Contract Supervisor, or Shift Supervisor roles may close a planned job. You may still review and save module evidence where permitted.',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleClosureGateResult {
  final bool isLoading;
  final Object? loadError;
  final List<JobModuleInstance> modules;
  final List<JobModuleInstance> requiredModules;
  final List<JobModuleInstance> openRequiredModules;
  final List<JobModuleInstance> waitingAcceptanceModules;
  final List<JobModuleInstance> missingResponseModules;
  final List<JobModuleInstance> attentionModules;
  final List<JobModuleInstance> invalidPayloadModules;

  const _ModuleClosureGateResult({
    required this.isLoading,
    required this.loadError,
    required this.modules,
    required this.requiredModules,
    required this.openRequiredModules,
    required this.waitingAcceptanceModules,
    required this.missingResponseModules,
    required this.attentionModules,
    required this.invalidPayloadModules,
  });

  factory _ModuleClosureGateResult.fromAsyncValue(
    AsyncValue<List<JobModuleInstance>> value,
  ) {
    return value.when(
      loading:
          () => const _ModuleClosureGateResult(
            isLoading: true,
            loadError: null,
            modules: [],
            requiredModules: [],
            openRequiredModules: [],
            waitingAcceptanceModules: [],
            missingResponseModules: [],
            attentionModules: [],
            invalidPayloadModules: [],
          ),
      error:
          (error, _) => _ModuleClosureGateResult(
            isLoading: false,
            loadError: error,
            modules: const [],
            requiredModules: const [],
            openRequiredModules: const [],
            waitingAcceptanceModules: const [],
            missingResponseModules: const [],
            attentionModules: const [],
            invalidPayloadModules: const [],
          ),
      data: (records) {
        final modules =
            records.where((module) => !module.isDeleted).toList()
              ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        final requiredModules =
            modules.where((module) => module.requiredForClosure).toList();
        final openRequiredModules =
            requiredModules
                .where((module) => _isOpenRequiredStatus(module.status))
                .toList();
        final waitingAcceptanceModules =
            requiredModules
                .where((module) => module.status == JobModuleStatus.submitted)
                .toList();
        final invalidPayloadModules =
            modules
                .where(
                  (module) =>
                      !module.fieldDefinitionsReadResult.isValid ||
                      !module.responsesReadResult.isValid ||
                      !module.actionsReadResult.isValid,
                )
                .toList();
        final missingResponseModules =
            requiredModules
                .where(
                  (module) =>
                      !invalidPayloadModules.contains(module) &&
                      module.status != JobModuleStatus.notApplicable &&
                      _moduleMissingRequiredEvidence(module),
                )
                .toList();
        final attentionModules =
            requiredModules
                .where(
                  (module) =>
                      module.requiresFollowUp ||
                      (module.pendingIssue != null &&
                          module.pendingIssue!.trim().isNotEmpty),
                )
                .toList();

        return _ModuleClosureGateResult(
          isLoading: false,
          loadError: null,
          modules: modules,
          requiredModules: requiredModules,
          openRequiredModules: openRequiredModules,
          waitingAcceptanceModules: waitingAcceptanceModules,
          missingResponseModules: missingResponseModules,
          attentionModules: attentionModules,
          invalidPayloadModules: invalidPayloadModules,
        );
      },
    );
  }

  bool get hasModules => modules.isNotEmpty;

  /// Strict closure policy for v1: no admin override is implemented yet.
  /// This is a deliberate safe default pending the catalogue §6 policy decision
  /// on strict block vs block-with-admin/SI override and mandatory reason.
  bool get canComplete {
    if (isLoading || loadError != null) return false;
    if (!hasModules) return true;
    return openRequiredModules.isEmpty &&
        waitingAcceptanceModules.isEmpty &&
        missingResponseModules.isEmpty &&
        attentionModules.isEmpty &&
        invalidPayloadModules.isEmpty;
  }

  String get statusLabel {
    if (isLoading) return 'Checking modules';
    if (loadError != null) return 'Module check failed';
    if (!hasModules) return 'Legacy closure path';
    return canComplete ? 'Ready for closure' : 'Closure blocked';
  }

  Color get statusColor {
    if (canComplete) return BafColors.sync;
    if (isLoading) return BafColors.planned;
    return BafColors.warning;
  }

  String get summary {
    if (isLoading) return 'Loading process modules before allowing closure.';
    if (loadError != null) {
      return 'Unable to verify process modules. Completion is blocked to protect dossier integrity.';
    }
    if (!hasModules) {
      return 'No process modules are attached. Legacy completion remains available.';
    }
    if (requiredModules.isEmpty) {
      return 'Process modules exist, but none are marked required for closure.';
    }
    if (canComplete) {
      return 'All required process modules are accepted or marked not applicable with required evidence clear.';
    }
    return _compactGateWarning(this);
  }

  String get blockingMessage {
    if (isLoading) {
      return 'Process modules are still loading. Please wait and try again.';
    }
    if (loadError != null) {
      return 'Process modules could not be verified: $loadError\n\nCompletion is blocked to protect dossier integrity.';
    }
    if (canComplete) return 'All module closure gates are satisfied.';

    final lines = <String>['Resolve the following before completing this job:'];
    void addSection(String title, List<JobModuleInstance> items) {
      if (items.isEmpty) return;
      lines.add('\n$title');
      for (final module in items.take(8)) {
        lines.add('• ${_moduleShortTitle(module)}');
      }
      if (items.length > 8) lines.add('• +${items.length - 8} more');
    }

    addSection('Required modules still open:', openRequiredModules);
    addSection(
      'Required modules submitted but not accepted:',
      waitingAcceptanceModules,
    );
    addSection(
      'Required modules missing required evidence:',
      missingResponseModules,
    );
    addSection(
      'Required modules with pending issue/follow-up:',
      attentionModules,
    );
    addSection(
      'Modules with saved evidence that needs repair:',
      invalidPayloadModules,
    );
    return lines.join('\n');
  }
}

class _ModuleClosureGateCard extends StatelessWidget {
  final _ModuleClosureGateResult gate;

  const _ModuleClosureGateCard({required this.gate});

  @override
  Widget build(BuildContext context) {
    final color = gate.statusColor;
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                gate.canComplete ? Icons.verified_rounded : Icons.rule_rounded,
                color: color,
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Module closure gate',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gate.summary,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: gate.statusLabel,
                color: color,
                icon:
                    gate.canComplete
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GateMetric(label: '${gate.modules.length}', caption: 'modules'),
              _GateMetric(
                label: '${gate.requiredModules.length}',
                caption: 'required',
              ),
              _GateMetric(
                label: '${gate.openRequiredModules.length}',
                caption: 'open',
              ),
              _GateMetric(
                label: '${gate.waitingAcceptanceModules.length}',
                caption: 'awaiting accept',
              ),
              _GateMetric(
                label: '${gate.missingResponseModules.length}',
                caption: 'missing evidence',
              ),
              _GateMetric(
                label: '${gate.attentionModules.length}',
                caption: 'attention',
              ),
              _GateMetric(
                label: '${gate.invalidPayloadModules.length}',
                caption: 'needs repair',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GateMetric extends StatelessWidget {
  final String label;
  final String caption;

  const _GateMetric({required this.label, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            caption,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isOpenRequiredStatus(JobModuleStatus status) {
  return status == JobModuleStatus.notStarted ||
      status == JobModuleStatus.draftSaved ||
      status == JobModuleStatus.inProgress ||
      status == JobModuleStatus.reopened;
}

bool _moduleMissingRequiredEvidence(JobModuleInstance module) {
  final definitions = module.fieldDefinitionsReadResult.entries;
  final ordinaryRequiredKeys =
      definitions
          .where(
            (definition) =>
                _fieldRequired(definition) &&
                !_isSafetyGateDefinition(definition),
          )
          .map(_fieldKey)
          .where((key) => key != null && key.isNotEmpty)
          .cast<String>()
          .toList();

  final responsesByKey = {
    for (final response in module.responsesReadResult.entries)
      response.key: response.value,
  };

  if (ordinaryRequiredKeys.isNotEmpty) {
    return ordinaryRequiredKeys.any(
      (key) => !_hasEvidenceValue(responsesByKey[key]),
    );
  }

  final hasAnyOrdinaryField = definitions.any(
    (definition) => !_isSafetyGateDefinition(definition),
  );
  if (hasAnyOrdinaryField) return module.responsesReadResult.entries.isEmpty;
  return false;
}

bool _fieldRequired(Map<String, dynamic> definition) {
  return definition['required'] == true || definition['isRequired'] == true;
}

String? _fieldKey(Map<String, dynamic> definition) {
  for (final key in ['fieldId', 'key', 'id', 'name']) {
    final raw = definition[key];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  }
  return null;
}

bool _isSafetyGateDefinition(Map<String, dynamic> definition) {
  final raw = definition['type'] ?? definition['fieldType'] ?? '';
  final key = raw.toString().trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '',
  );
  return key == 'safetygate' || key == 'safetyconfirmation';
}

bool _hasEvidenceValue(dynamic value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  return true;
}

String _moduleShortTitle(JobModuleInstance module) {
  final code = module.moduleCode?.trim();
  final title = module.moduleTitle.trim();
  if (code != null && code.isNotEmpty) return '$code — $title';
  return title;
}

String _compactGateWarning(_ModuleClosureGateResult gate) {
  final issues = <String>[];
  if (gate.openRequiredModules.isNotEmpty) {
    issues.add('${gate.openRequiredModules.length} required open');
  }
  if (gate.waitingAcceptanceModules.isNotEmpty) {
    issues.add('${gate.waitingAcceptanceModules.length} awaiting acceptance');
  }
  if (gate.missingResponseModules.isNotEmpty) {
    issues.add('${gate.missingResponseModules.length} missing evidence');
  }
  if (gate.attentionModules.isNotEmpty) {
    issues.add('${gate.attentionModules.length} with pending issue/follow-up');
  }
  if (gate.invalidPayloadModules.isNotEmpty) {
    issues.add('${gate.invalidPayloadModules.length} needing evidence repair');
  }
  return issues.join(' • ');
}

class _CompleteJobBottomBar extends StatelessWidget {
  final bool isSubmitting;
  final _CompletionPhase completionPhase;
  final bool hasCompletionAuthority;
  final VoidCallback? onSubmit;

  const _CompleteJobBottomBar({
    required this.isSubmitting,
    required this.completionPhase,
    required this.hasCompletionAuthority,
    required this.onSubmit,
  });

  String get _buttonLabel {
    if (!isSubmitting) {
      return hasCompletionAuthority
          ? 'Mark Job Completed'
          : 'Completion Not Authorized';
    }

    return switch (completionPhase) {
      _CompletionPhase.preflightSync => 'Syncing changes...',
      _CompletionPhase.completing => 'Completing job...',
      _CompletionPhase.idle => 'Completing...',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.lg,
          BafSpacing.md,
          BafSpacing.lg,
          BafSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: BafColors.card,
          border: Border(top: BorderSide(color: BafColors.border)),
        ),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: BafColors.sync,
              foregroundColor: Colors.white,
              disabledBackgroundColor: BafColors.border,
              disabledForegroundColor: BafColors.textSecondary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(BafRadius.medium),
              ),
            ),
            icon:
                isSubmitting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.task_alt_rounded),
            label: Text(
              _buttonLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldPadding extends StatelessWidget {
  final Widget child;

  const _FieldPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }
}

class _ToggleCard extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: SwitchListTile(
        title: Text(
          label,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        value: value,
        activeThumbColor: BafColors.planned,
        onChanged: onChanged,
      ),
    );
  }
}

class _CheckboxCard extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _CheckboxCard({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BafColors.background,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        value: value,
        activeColor: BafColors.planned,
        onChanged: onChanged,
      ),
    );
  }
}

class _MultiSelectField extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final bool requiredField;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectField({
    required this.label,
    required this.options,
    required this.selected,
    required this.requiredField,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: BafSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((option) {
                final isSelected = selected.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: BafColors.planned.withValues(alpha: 0.14),
                  checkmarkColor: BafColors.planned,
                  side: BorderSide(
                    color:
                        isSelected
                            ? BafColors.planned.withValues(alpha: 0.35)
                            : BafColors.border,
                  ),
                  onSelected: (value) {
                    final updated = List<String>.from(selected);
                    value ? updated.add(option) : updated.remove(option);
                    onChanged(updated);
                  },
                );
              }).toList(),
        ),
        if (requiredField && selected.isEmpty) ...[
          const SizedBox(height: BafSpacing.xs),
          const Text(
            'Required',
            style: TextStyle(
              color: BafColors.danger,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _JobContextCard extends StatelessWidget {
  final JobExecution execution;

  const _JobContextCard({required this.execution});

  @override
  Widget build(BuildContext context) {
    final assetLabel =
        '${execution.assetType.name.toUpperCase()} ${execution.assetNumber}'
            .trim();

    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.planned.withValues(alpha: 0.18)),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: BafColors.planned.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: BafColors.planned,
              size: 30,
            ),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete planned job',
                  style: TextStyle(
                    color: BafColors.planned,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  execution.templateName ?? 'Job',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge(
                      label: assetLabel,
                      color: BafColors.assets,
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                    const StatusBadge(
                      label: 'Work execution',
                      color: BafColors.planned,
                      icon: Icons.work_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: BafColors.planned, size: 22),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          ...children,
        ],
      ),
    );
  }
}

class _EmptyInlineState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _EmptyInlineState({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: BafSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: BafColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowClosureGateCard extends StatelessWidget {
  final AsyncValue<WorkflowAggregateRecord?> workflowAsync;
  final AsyncValue<List<JobLaneRecord>> lanesAsync;

  const _WorkflowClosureGateCard({
    required this.workflowAsync,
    required this.lanesAsync,
  });

  @override
  Widget build(BuildContext context) {
    final workflow = workflowAsync.value;
    final lanes = lanesAsync.value ?? const <JobLaneRecord>[];
    final active = lanes.where(
      (lane) => lane.statusKey != 'removed' && lane.statusKey != 'terminated',
    );
    final ready =
        workflow != null &&
        active.isNotEmpty &&
        active.every((lane) => lane.statusKey == 'closed');
    final loading = workflowAsync.isLoading || lanesAsync.isLoading;
    final color = ready ? BafColors.sync : BafColors.warning;

    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.account_tree_rounded : Icons.hub_outlined,
            color: color,
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading
                      ? 'Checking workflow lanes…'
                      : ready
                      ? 'All workflow lanes are closed'
                      : 'Workflow lane closure is incomplete',
                  style: const TextStyle(
                    color: BafColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'The current lane and compliance state is loading.'
                      : ready
                      ? 'The server will still recheck lane versions, blocking compliance, RED applicability and equipment state.'
                      : 'Return to the job dossier and close or formally resolve every active lane before final submission.',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
