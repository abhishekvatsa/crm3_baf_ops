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

  @override
  void initState() {
    super.initState();
    final actionRead = widget.ticket.actionsReadResult;
    if (actionRead.isValid) {
      _actions.addAll(actionRead.entries);
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
    super.dispose();
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
        actions: _actions.isEmpty ? null : _actions,
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
            _SectionCard(
              title: 'Work done',
              subtitle: 'Capture action details for traceability.',
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
                      'No detailed actions added yet. You can still resolve with remarks below.',
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
