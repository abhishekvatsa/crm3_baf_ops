// FILE: lib/features/maintenance/presentation/resolve_form.dart

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/maintenance_model.dart';
import '../providers/maintenance_provider.dart';
import '../validation/maintenance_input_validator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../planned_maintenance/models/component_action_model.dart';
import '../../planned_maintenance/widgets/action_bottom_sheet.dart';
import '../../planned_maintenance/widgets/action_mini_card.dart';
import '../../../core/providers/refresh_providers.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../../core/widgets/persisted_data_integrity_notice.dart';
import '../domain/burner_lockout_case.dart';

class ResolveForm extends ConsumerStatefulWidget {
  final MaintenanceRecord ticket;
  const ResolveForm({super.key, required this.ticket});

  @override
  ConsumerState<ResolveForm> createState() => _ResolveFormState();
}

class _ResolveFormState extends ConsumerState<ResolveForm> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  bool _isSubmitting = false;
  DateTime _endTime = DateTime.now();

  final Set<String> _teamsInvolved = {};
  final List<ComponentAction> _actions = [];
  BurnerLockoutCase? _burnerLockout;
  final Map<int, Set<BurnerActionCode>> _burnerActions =
      <int, Set<BurnerActionCode>>{};
  final Map<int, BurnerResolutionOutcome?> _burnerOutcomes =
      <int, BurnerResolutionOutcome?>{};
  final Map<int, TextEditingController> _burnerNotes =
      <int, TextEditingController>{};
  final Map<int, TextEditingController> _burnerMicroampReadings =
      <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    final actionRead = widget.ticket.actionsReadResult;
    if (actionRead.isValid) {
      _actions.addAll(actionRead.entries);
    }
    final burnerRead = widget.ticket.burnerLockoutReadResult;
    if (burnerRead.isValid) {
      _burnerLockout = burnerRead.value;
      for (final position in _burnerLockout?.positions ?? const <int>[]) {
        _burnerActions[position] = <BurnerActionCode>{};
        _burnerOutcomes[position] = null;
        _burnerNotes[position] = TextEditingController();
        _burnerMicroampReadings[position] = TextEditingController();
      }
      if (_burnerLockout != null) _teamsInvolved.add('instrumentation');
    }
    final now = DateTime.now();
    if (widget.ticket.startDate.isAfter(now)) {
      _endTime = now;
    } else if (_endTime.isBefore(widget.ticket.startDate)) {
      _endTime = widget.ticket.startDate;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    for (final controller in _burnerNotes.values) {
      controller.dispose();
    }
    for (final controller in _burnerMicroampReadings.values) {
      controller.dispose();
    }
    super.dispose();
  }

  BurnerLockoutResolution? _buildBurnerResolution() {
    final lockout = _burnerLockout;
    if (lockout == null) return null;
    final outcomes = <int, BurnerResolutionOutcome>{};
    final microampReadings = <int, double>{};
    for (final position in lockout.positions) {
      final selectedActions = _burnerActions[position] ?? const {};
      if (selectedActions.isEmpty) {
        throw StateError(
          'Select the work or inspection done on Burner $position.',
        );
      }
      final outcome = _burnerOutcomes[position];
      if (outcome == null) {
        throw StateError('Select a terminal outcome for Burner $position.');
      }
      final notes = _burnerNotes[position]?.text.trim() ?? '';
      if (selectedActions.contains(BurnerActionCode.other) &&
          notes.length < 3) {
        throw StateError('Describe the other work done on Burner $position.');
      }
      final microampText = _burnerMicroampReadings[position]?.text.trim() ?? '';
      if (microampText.isNotEmpty) {
        final reading = double.tryParse(microampText);
        if (reading == null ||
            !reading.isFinite ||
            reading < 0 ||
            reading > burnerMicroampStructuralMaximum) {
          throw StateError(
            'Enter a valid non-negative microamp reading for Burner $position.',
          );
        }
        microampReadings[position] = reading;
      }
      outcomes[position] = outcome;
    }
    return BurnerLockoutResolution(
      outcomes: outcomes,
      microampReadings: microampReadings,
    );
  }

  List<ComponentAction> _buildBurnerComponentActions({
    required BurnerLockoutResolution resolution,
    required String performedBy,
    required DateTime performedAt,
  }) {
    final ticketId = widget.ticket.firestoreId ?? 'local_${widget.ticket.id}';
    final result = <ComponentAction>[];
    for (final position in resolution.attendedPositions) {
      final remarks = _burnerNotes[position]?.text.trim();
      for (final code in _burnerActions[position] ?? const {}) {
        result.add(
          buildBurnerComponentAction(
            ticketId: ticketId,
            furnaceNumber: widget.ticket.assetNumber,
            burnerPosition: position,
            code: code,
            outcome: resolution.outcomes[position]!,
            performedBy: performedBy,
            performedAt: performedAt,
            microampReading: resolution.microampReadings[position],
            remarks: remarks == null || remarks.isEmpty ? null : remarks,
          ),
        );
      }
    }
    return result;
  }

  double get _downtimeHours {
    final diff = _endTime.difference(widget.ticket.startDate);
    return diff.inMinutes / 60.0;
  }

  Future<void> _pickEndTime() async {
    final now = DateTime.now();

    if (widget.ticket.startDate.isAfter(now)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Ticket start time is in the future. Check the ticket start date first.',
          ),
        ),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _endTime,
      firstDate: widget.ticket.startDate,
      lastDate: now,
    );
    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime),
    );
    if (!mounted || time == null) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (picked.isAfter(now)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('End time cannot be in the future')),
      );
      return;
    }

    if (picked.isBefore(widget.ticket.startDate)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('End time cannot be before start time')),
      );
      return;
    }

    setState(() => _endTime = picked);
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!widget.ticket.actionsReadResult.isValid) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Cannot resolve: saved action evidence needs repair.'),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    if (!widget.ticket.resolutionHistoryReadResult.isValid) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot resolve: previous resolution history needs repair.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    if (!widget.ticket.burnerLockoutReadResult.isValid) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot resolve: burner-lockout evidence needs reconciliation.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (widget.ticket.workflowDeferred) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'This ticket is deferred by maintenance workflow. '
            'Reactivate or release the linked compliance request first.',
          ),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }

    final now = DateTime.now();
    if (widget.ticket.startDate.isAfter(now)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Cannot resolve: ticket start time is in the future'),
        ),
      );
      return;
    }

    if (_endTime.isAfter(now)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('End time cannot be in the future')),
      );
      return;
    }

    if (_endTime.isBefore(widget.ticket.startDate)) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('End time cannot be before start time')),
      );
      return;
    }

    final inputValidation = MaintenanceInputValidator.validateResolution(
      MaintenanceResolutionInput(
        ticket: widget.ticket,
        endDate: _endTime,
        remarks: _remarksController.text,
        teamsInvolved: _teamsInvolved,
        now: now,
      ),
    );
    if (inputValidation.isInvalid) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(inputValidation.summary),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }
    BurnerLockoutResolution? burnerResolution;
    try {
      burnerResolution = _buildBurnerResolution();
    } on StateError catch (error) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: BafColors.warning,
        ),
      );
      return;
    }

    final dynamic id = kIsWeb ? widget.ticket.firestoreId : widget.ticket.id;

    if (id == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Error: Ticket ID is missing')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final appUser = ref.read(currentAppUserProvider).value;
      final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
      if (appUser == null || !appUser.canCloseMaintenanceTicket) {
        throw StateError(
          'You are not authorized to close maintenance tickets.',
        );
      }
      final remarks = _remarksController.text.trim();
      final resolvedActions = <ComponentAction>[..._actions];
      if (burnerResolution != null) {
        resolvedActions.addAll(
          _buildBurnerComponentActions(
            resolution: burnerResolution,
            performedBy: appUser.name.isNotEmpty ? appUser.name : appUser.uid,
            performedAt: _endTime,
          ),
        );
        validateBurnerResolutionEvidence(
          lockout: _burnerLockout!,
          resolution: burnerResolution,
          actions: resolvedActions,
        );
      }

      final repository = ref.read(maintenanceRepositoryProvider);
      final refreshClosedTickets = ref.read(
        refreshClosedTicketsProvider.notifier,
      );
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.resolveTicket(
        id,
        actor: appUser,
        closedByUid: appUser.uid,
        closedByName:
            appUser.name.isNotEmpty
                ? appUser.name
                : (firebaseUser?.displayName ?? firebaseUser?.email),
        remarks: remarks,
        downtimeHours: double.parse(_downtimeHours.toStringAsFixed(2)),
        endDate: _endTime,
        teamsInvolved: _teamsInvolved.toList(),
        actions: resolvedActions.isEmpty ? null : resolvedActions,
        burnerResolution: burnerResolution,
      );

      refreshClosedTickets.state++;

      unawaited(
        syncCoordinator.runFullSync(reason: 'ticket_resolved', force: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Issue marked as resolved'),
          backgroundColor: BafColors.sync,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to resolve: $e'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(currentAppUserProvider).value;
    final actingAsName = appUser?.name;
    final fmt = DateFormat('dd MMM yyyy, HH:mm');
    final historyRead = widget.ticket.resolutionHistoryReadResult;
    final actionRead = widget.ticket.actionsReadResult;

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const Text(
          'Resolve Issue',
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
            BafSpacing.md,
            BafSpacing.lg,
            124,
          ),
          children: [
            _TicketSummaryCard(ticket: widget.ticket, fmt: fmt),
            const SizedBox(height: BafSpacing.lg),
            if (!historyRead.isValid) ...[
              const _HistoryIntegrityNotice(),
              const SizedBox(height: BafSpacing.lg),
            ] else if (historyRead.entries.isNotEmpty) ...[
              _HistorySection(history: historyRead.entries),
              const SizedBox(height: BafSpacing.lg),
            ],
            _SectionCard(
              title: 'Resolution timing',
              subtitle: 'Confirm when the issue was actually resolved.',
              icon: Icons.schedule_rounded,
              children: [
                InkWell(
                  onTap: _pickEndTime,
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                  child: Container(
                    padding: const EdgeInsets.all(BafSpacing.lg),
                    decoration: BoxDecoration(
                      color: BafColors.background,
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                      border: Border.all(color: BafColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: BafColors.sync,
                        ),
                        const SizedBox(width: BafSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resolution time',
                                style: TextStyle(
                                  color: BafColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fmt.format(_endTime),
                                style: const TextStyle(
                                  color: BafColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.edit_calendar_rounded,
                          color: BafColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                Container(
                  padding: const EdgeInsets.all(BafSpacing.lg),
                  decoration: BoxDecoration(
                    color: BafColors.sync.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.sync.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: BafColors.sync),
                      const SizedBox(width: BafSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calculated downtime',
                              style: TextStyle(
                                color: BafColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_downtimeHours.toStringAsFixed(2)} hours',
                              style: const TextStyle(
                                color: BafColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            if (_burnerLockout != null) ...[
              _BurnerAttendanceSection(
                lockout: _burnerLockout!,
                selectedActions: _burnerActions,
                outcomes: _burnerOutcomes,
                notes: _burnerNotes,
                microampReadings: _burnerMicroampReadings,
                onActionChanged: (position, action, selected) {
                  setState(() {
                    final actions = _burnerActions[position]!;
                    if (selected) {
                      actions.add(action);
                    } else {
                      actions.remove(action);
                    }
                  });
                },
                onOutcomeChanged: (position, outcome) {
                  setState(() => _burnerOutcomes[position] = outcome);
                },
              ),
              const SizedBox(height: BafSpacing.lg),
            ],
            _SectionCard(
              title:
                  _burnerLockout == null
                      ? 'Work done'
                      : 'Additional component work',
              subtitle:
                  _burnerLockout == null
                      ? 'Capture action details for traceability.'
                      : 'Add any work outside the burner attendance record.',
              icon: Icons.handyman_rounded,
              children: [
                if (!actionRead.isValid)
                  const PersistedDataIntegrityNotice(
                    title: 'Saved action evidence needs repair',
                    message:
                        'No actions were discarded or replaced. Resolution is blocked until this saved payload is repaired.',
                  )
                else if (_actions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(BafSpacing.md),
                    decoration: BoxDecoration(
                      color: BafColors.background,
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                      border: Border.all(color: BafColors.border),
                    ),
                    child: const Text(
                      'No additional component actions recorded.',
                      style: TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  )
                else
                  ..._actions.map((action) => ActionMiniCard(action: action)),
                const SizedBox(height: BafSpacing.md),
                OutlinedButton.icon(
                  onPressed: actionRead.isValid ? _addAction : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add repair / replacement / inspection action',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: BafColors.sync,
                    side: BorderSide(
                      color: BafColors.sync.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(BafRadius.medium),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.lg),
            _SectionCard(
              title: 'Teams and remarks',
              subtitle: 'Make ownership and root cause clear.',
              icon: Icons.groups_rounded,
              children: [
                const Text(
                  'Teams involved',
                  style: TextStyle(
                    color: BafColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: BafSpacing.md),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                        'electrical',
                        'mechanical',
                        'instrumentation',
                        'refractory',
                        'emd',
                      ].map((team) {
                        final selected = _teamsInvolved.contains(team);
                        return FilterChip(
                          label: Text(team.toUpperCase()),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color:
                                selected
                                    ? BafColors.sync
                                    : BafColors.textPrimary,
                          ),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _teamsInvolved.add(team);
                              } else {
                                _teamsInvolved.remove(team);
                              }
                            });
                          },
                          selectedColor: BafColors.sync.withValues(alpha: 0.11),
                          checkmarkColor: BafColors.sync,
                          backgroundColor: BafColors.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color:
                                  selected
                                      ? BafColors.sync.withValues(alpha: 0.35)
                                      : BafColors.border,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: BafSpacing.lg),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    'Work done / root cause summary',
                    hint:
                        'Describe the technical resolution and important observations...',
                    alignLabelWithHint: true,
                  ),
                  validator:
                      (value) => MaintenanceInputValidator.validateResolution(
                        MaintenanceResolutionInput(
                          ticket: widget.ticket,
                          endDate: _endTime,
                          remarks: value,
                          teamsInvolved: _teamsInvolved,
                        ),
                      ).messageFor('remarks'),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _ResolveBottomBar(
        isSubmitting: _isSubmitting,
        actingAsName: actingAsName,
        onSubmit: _isSubmitting ? null : _submit,
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: BafColors.background,
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
        borderSide: const BorderSide(color: BafColors.sync, width: 1.5),
      ),
    );
  }
}

class _BurnerAttendanceSection extends StatelessWidget {
  const _BurnerAttendanceSection({
    required this.lockout,
    required this.selectedActions,
    required this.outcomes,
    required this.notes,
    required this.microampReadings,
    required this.onActionChanged,
    required this.onOutcomeChanged,
  });

  final BurnerLockoutCase lockout;
  final Map<int, Set<BurnerActionCode>> selectedActions;
  final Map<int, BurnerResolutionOutcome?> outcomes;
  final Map<int, TextEditingController> notes;
  final Map<int, TextEditingController> microampReadings;
  final void Function(int position, BurnerActionCode action, bool selected)
  onActionChanged;
  final void Function(int position, BurnerResolutionOutcome? outcome)
  onOutcomeChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Burner attendance',
      subtitle: 'Account for every affected burner before closing the issue.',
      icon: Icons.engineering_rounded,
      children: [
        Wrap(
          spacing: BafSpacing.sm,
          runSpacing: BafSpacing.sm,
          children: [
            StatusBadge(
              label: lockout.positions.map((value) => 'B$value').join(', '),
              color: BafColors.audit,
              icon: Icons.local_fire_department_outlined,
            ),
            if (lockout.commonMode)
              const StatusBadge(
                label: 'COMMON MODE',
                color: BafColors.warning,
                icon: Icons.hub_outlined,
              ),
            if (lockout.hasRedHotObservation)
              StatusBadge(
                label:
                    'RED HOT ${lockout.redHotPositions.map((value) => 'B$value').join(', ')}',
                color: BafColors.danger,
                icon: Icons.warning_amber_rounded,
              ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        Text(
          'Reported stage: ${_cycleStageLabel(lockout.cycleStage)}  |  '
          'Relight attempts: ${lockout.relightAttempts}',
          style: const TextStyle(color: BafColors.textSecondary, height: 1.35),
        ),
        if (lockout.hmiAlarm != null) ...[
          const SizedBox(height: 4),
          Text(
            'HMI: ${lockout.hmiAlarm}',
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const Divider(height: BafSpacing.xl),
        for (var index = 0; index < lockout.positions.length; index++) ...[
          _BurnerAttendanceEditor(
            position: lockout.positions[index],
            redHot: lockout.redHotPositions.contains(lockout.positions[index]),
            selectedActions:
                selectedActions[lockout.positions[index]] ?? const {},
            outcome: outcomes[lockout.positions[index]],
            notesController: notes[lockout.positions[index]]!,
            microampController: microampReadings[lockout.positions[index]]!,
            onActionChanged:
                (action, selected) =>
                    onActionChanged(lockout.positions[index], action, selected),
            onOutcomeChanged:
                (outcome) =>
                    onOutcomeChanged(lockout.positions[index], outcome),
          ),
          if (index != lockout.positions.length - 1)
            const Divider(height: BafSpacing.xl),
        ],
      ],
    );
  }

  static String _cycleStageLabel(BurnerCycleStage value) => switch (value) {
    BurnerCycleStage.notRecorded => 'not recorded',
    BurnerCycleStage.purge => 'purge',
    BurnerCycleStage.ignition => 'ignition',
    BurnerCycleStage.firing => 'firing',
    BurnerCycleStage.unknown => 'unknown',
  };
}

class _BurnerAttendanceEditor extends StatelessWidget {
  const _BurnerAttendanceEditor({
    required this.position,
    required this.redHot,
    required this.selectedActions,
    required this.outcome,
    required this.notesController,
    required this.microampController,
    required this.onActionChanged,
    required this.onOutcomeChanged,
  });

  final int position;
  final bool redHot;
  final Set<BurnerActionCode> selectedActions;
  final BurnerResolutionOutcome? outcome;
  final TextEditingController notesController;
  final TextEditingController microampController;
  final void Function(BurnerActionCode action, bool selected) onActionChanged;
  final ValueChanged<BurnerResolutionOutcome?> onOutcomeChanged;

  @override
  Widget build(BuildContext context) {
    final resetOnly =
        selectedActions.isNotEmpty &&
        selectedActions.every((action) => action.isResetOnly);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Burner $position',
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (redHot)
              const Icon(
                Icons.local_fire_department_rounded,
                color: BafColors.danger,
              ),
          ],
        ),
        const SizedBox(height: BafSpacing.sm),
        Wrap(
          spacing: BafSpacing.sm,
          runSpacing: BafSpacing.sm,
          children: [
            for (final action in BurnerActionCode.values)
              FilterChip(
                label: Text(action.label),
                selected: selectedActions.contains(action),
                onSelected: (selected) => onActionChanged(action, selected),
              ),
          ],
        ),
        const SizedBox(height: BafSpacing.md),
        TextFormField(
          controller: microampController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _decoration(
            'Microamp reading',
          ).copyWith(suffixText: 'µA'),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) return null;
            final reading = double.tryParse(text);
            if (reading == null ||
                !reading.isFinite ||
                reading < 0 ||
                reading > burnerMicroampStructuralMaximum) {
              return 'Enter a valid non-negative reading';
            }
            return null;
          },
        ),
        const SizedBox(height: BafSpacing.md),
        DropdownButtonFormField<BurnerResolutionOutcome>(
          key: ValueKey('burner-$position-${outcome?.name ?? 'none'}'),
          initialValue: outcome,
          isExpanded: true,
          decoration: _decoration('Terminal outcome'),
          items: const [
            DropdownMenuItem(
              value: BurnerResolutionOutcome.returnedToService,
              child: Text('Returned to service'),
            ),
            DropdownMenuItem(
              value: BurnerResolutionOutcome.remainsLockedOut,
              child: Text('Remains locked out'),
            ),
            DropdownMenuItem(
              value: BurnerResolutionOutcome.isolatedForFollowUp,
              child: Text('Isolated for follow-up'),
            ),
          ],
          onChanged: onOutcomeChanged,
        ),
        if (outcome == BurnerResolutionOutcome.returnedToService &&
            resetOnly) ...[
          const SizedBox(height: BafSpacing.sm),
          const Text(
            'Reset-only evidence cannot support return to service. Record the '
            'inspection or corrective work that established readiness.',
            style: TextStyle(
              color: BafColors.danger,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
        const SizedBox(height: BafSpacing.md),
        TextFormField(
          controller: notesController,
          maxLines: 2,
          decoration: _decoration(
            selectedActions.contains(BurnerActionCode.other)
                ? 'Other work / observations (required)'
                : 'Observations / notes',
          ),
          validator: (value) {
            if (selectedActions.contains(BurnerActionCode.other) &&
                (value?.trim().length ?? 0) < 3) {
              return 'Describe the other work';
            }
            return null;
          },
        ),
      ],
    );
  }

  static InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: BafColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BafRadius.medium),
      borderSide: const BorderSide(color: BafColors.border),
    ),
  );
}

class _ResolveBottomBar extends StatelessWidget {
  final bool isSubmitting;
  final String? actingAsName;
  final VoidCallback? onSubmit;

  const _ResolveBottomBar({
    required this.isSubmitting,
    required this.actingAsName,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final actor = actingAsName?.trim();

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (actor != null && actor.isNotEmpty) ...[
              Text(
                'Acting as: $actor',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: BafSpacing.sm),
            ],
            SizedBox(
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
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.task_alt_rounded),
                label: Text(
                  isSubmitting ? 'Resolving...' : 'Mark as Resolved',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketSummaryCard extends StatelessWidget {
  final MaintenanceRecord ticket;
  final DateFormat fmt;

  const _TicketSummaryCard({required this.ticket, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final assetLabel =
        '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}';
    final innerCover = ticket.assetHierarchyReference?.innerCoverAssociation;

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
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: BafColors.sync.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: BafColors.sync,
                  size: 30,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assetLabel,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusBadge(
                          label: ticket.routedTo.name.toUpperCase(),
                          color: BafColors.maintenance,
                        ),
                        const StatusBadge(
                          label: 'Open',
                          color: BafColors.maintenance,
                          icon: Icons.timer_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.lg),
          Text(
            ticket.description,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          _MetaLine(
            icon: Icons.schedule_rounded,
            text: 'Started ${fmt.format(ticket.startDate)}',
          ),
          if (ticket.loggedByName != null) ...[
            const SizedBox(height: BafSpacing.xs),
            _MetaLine(
              icon: Icons.person_outline_rounded,
              text: 'Raised by ${ticket.loggedByName}',
            ),
          ],
          if (ticket.component != null &&
              ticket.component!.trim().isNotEmpty) ...[
            const SizedBox(height: BafSpacing.xs),
            _MetaLine(
              icon: Icons.account_tree_outlined,
              text: 'Component: ${ticket.component}',
            ),
          ],
          if (innerCover != null) ...[
            const SizedBox(height: BafSpacing.xs),
            _MetaLine(
              icon: Icons.layers_outlined,
              text:
                  innerCover.innerCoverSerialNumber == null
                      ? 'At event: no Inner Cover linked'
                      : 'At event: Inner Cover ${innerCover.innerCoverSerialNumber}',
            ),
          ],
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final List<ResolutionHistory> history;

  const _HistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Previous resolutions',
      subtitle: 'Read-only history from earlier closures/reopens.',
      icon: Icons.history_rounded,
      children:
          history.map((history) {
            final resolvedAt =
                history.resolvedAt == null
                    ? 'Unknown'
                    : DateFormat(
                      'dd MMM yyyy, HH:mm',
                    ).format(history.resolvedAt!);

            return Container(
              margin: const EdgeInsets.only(bottom: BafSpacing.md),
              padding: const EdgeInsets.all(BafSpacing.md),
              decoration: BoxDecoration(
                color: BafColors.background,
                borderRadius: BorderRadius.circular(BafRadius.medium),
                border: Border.all(color: BafColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetaLine(
                    icon: Icons.history_rounded,
                    text: 'Resolved: $resolvedAt',
                  ),
                  if (history.resolvedByName != null) ...[
                    const SizedBox(height: BafSpacing.xs),
                    _MetaLine(
                      icon: Icons.person_outline_rounded,
                      text: 'By: ${history.resolvedByName}',
                    ),
                  ],
                  if (history.remarks != null &&
                      history.remarks!.isNotEmpty) ...[
                    const SizedBox(height: BafSpacing.sm),
                    Text(
                      history.remarks!,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 12,
                        height: 1.3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (history.downtimeHours != null) ...[
                    const SizedBox(height: BafSpacing.sm),
                    StatusBadge(
                      label:
                          '${history.downtimeHours!.toStringAsFixed(2)} h downtime',
                      color: BafColors.audit,
                      icon: Icons.timer_outlined,
                    ),
                  ],
                  if (history.teamsInvolved.isNotEmpty) ...[
                    const SizedBox(height: BafSpacing.sm),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children:
                          history.teamsInvolved
                              .map(
                                (team) => StatusBadge(
                                  label: team.toUpperCase(),
                                  color: BafColors.charges,
                                ),
                              )
                              .toList(),
                    ),
                  ],
                  if (history.actionsJson != null &&
                      history.actionsJson != '[]') ...[
                    const SizedBox(height: BafSpacing.sm),
                    const Text(
                      'Actions taken',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.xs),
                    ...ComponentAction.decode(
                      history.actionsJson!,
                    ).map((action) => ActionMiniCard(action: action)),
                  ],
                ],
              ),
            );
          }).toList(),
    );
  }
}

class _HistoryIntegrityNotice extends StatelessWidget {
  const _HistoryIntegrityNotice();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      title: 'Resolution history needs repair',
      subtitle:
          'This issue cannot be changed until its saved history is valid.',
      icon: Icons.warning_amber_rounded,
      children: [
        Text(
          'No history entries were discarded or replaced.',
          style: TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
            children: [
              Icon(icon, color: BafColors.sync, size: 22),
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

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: BafColors.textSecondary),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
