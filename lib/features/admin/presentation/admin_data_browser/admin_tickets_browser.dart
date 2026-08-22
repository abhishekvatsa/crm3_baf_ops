import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/sync_coordinator.dart';
import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../audit/models/audit_event_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../maintenance/data/maintenance_model.dart';
import '../../../maintenance/domain/burner_lockout_case.dart';
import '../../../maintenance/providers/maintenance_provider.dart';
import '../../../maintenance_workflow/domain/workflow_types.dart';
import '../../../maintenance_workflow/providers/workflow_providers.dart';
import '../../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../providers/admin_stream_providers.dart';
import '../../utils/admin_ticket_helpers.dart';
import 'admin_data_browser_shared.dart';
import 'admin_delete_reason_dialog.dart';

// ============================================================================
// TICKETS BROWSER (with search, governed correction, delete, and timeline invalidation)
// ============================================================================

Color _adminTicketStatusColor(TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return BafColors.danger;
    case TicketStatus.acknowledged:
      return BafColors.warning;
    case TicketStatus.inProgress:
      return BafColors.planned;
    case TicketStatus.resolved:
      return BafColors.success;
  }
}

class _AdminCorrectTicketDialog extends StatefulWidget {
  final MaintenanceRecord ticket;

  const _AdminCorrectTicketDialog({required this.ticket});

  @override
  State<_AdminCorrectTicketDialog> createState() =>
      _AdminCorrectTicketDialogState();
}

class _AdminCorrectTicketDialogState extends State<_AdminCorrectTicketDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _componentController;
  late final TextEditingController _subsystemController;
  late final TextEditingController _tagController;
  late final TextEditingController _classificationController;
  late final TextEditingController _otherDepartmentController;
  late final TextEditingController _remarksController;
  late final TextEditingController _reasonController;

  late RoutedTo _selectedRouted;
  late MaintenanceType _selectedMaintenanceType;
  late bool _isCritical;

  bool get _isBurnerLockout =>
      widget.ticket.classification == burnerLockoutClassification;

  bool get _hasRedHotBurner =>
      widget.ticket.burnerLockoutReadResult.value?.hasRedHotObservation == true;

  bool get _canCorrectRoute =>
      !_isBurnerLockout &&
      widget.ticket.status == TicketStatus.open &&
      widget.ticket.acknowledgedByUid == null &&
      widget.ticket.acknowledgedByName == null &&
      widget.ticket.acknowledgedAt == null;

  @override
  void initState() {
    super.initState();
    final ticket = widget.ticket;
    _descriptionController = TextEditingController(text: ticket.description);
    _componentController = TextEditingController(text: ticket.component ?? '');
    _subsystemController = TextEditingController(text: ticket.subsystem ?? '');
    _tagController = TextEditingController(text: ticket.tag ?? '');
    _classificationController = TextEditingController(
      text: ticket.classification ?? '',
    );
    _otherDepartmentController = TextEditingController(
      text: ticket.otherDepartment ?? '',
    );
    _remarksController = TextEditingController(text: ticket.remarks ?? '');
    _reasonController = TextEditingController();
    _selectedRouted = ticket.routedTo;
    _selectedMaintenanceType = ticket.maintenanceType;
    _isCritical = ticket.isCritical;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _componentController.dispose();
    _subsystemController.dispose();
    _tagController.dispose();
    _classificationController.dispose();
    _otherDepartmentController.dispose();
    _remarksController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Correct ticket record'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(
                    '${widget.ticket.assetType.name.toUpperCase()} ${widget.ticket.assetNumber}',
                  ),
                  subtitle: Text(
                    'Asset identity and lifecycle status use their own governed actions. Current status: ${widget.ticket.status.name}.',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                  validator:
                      (value) =>
                          (value?.trim().length ?? 0) < 5
                              ? 'Enter at least 5 characters'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<RoutedTo>(
                  initialValue: _selectedRouted,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Route To',
                    helperText:
                        _isBurnerLockout
                            ? 'Burner lockout remains accountable to I&A.'
                            : _canCorrectRoute
                            ? null
                            : 'Route is locked after acknowledgement or work starts.',
                  ),
                  items:
                      RoutedTo.values.map((route) {
                        return DropdownMenuItem<RoutedTo>(
                          value: route,
                          child: Text(route.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged:
                      _canCorrectRoute
                          ? (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedRouted = value;
                              if (value != RoutedTo.others) {
                                _otherDepartmentController.clear();
                              }
                            });
                          }
                          : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<MaintenanceType>(
                  initialValue: _selectedMaintenanceType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Maintenance Type',
                  ),
                  items:
                      MaintenanceType.values.map((type) {
                        return DropdownMenuItem<MaintenanceType>(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged:
                      _isBurnerLockout
                          ? null
                          : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _selectedMaintenanceType = value);
                          },
                ),
                const SizedBox(height: BafSpacing.sm),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Critical issue'),
                  value: _isCritical,
                  onChanged:
                      _hasRedHotBurner
                          ? null
                          : (value) => setState(() => _isCritical = value),
                ),
                TextFormField(
                  controller: _componentController,
                  enabled: !_isBurnerLockout,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
                    if (length == 1) return 'Enter at least 2 characters';
                    if (length > 120) return 'Use at most 120 characters';
                    if (length == 0 &&
                        widget.ticket.component?.trim().isNotEmpty == true) {
                      return 'A recorded component cannot be cleared';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _subsystemController,
                  decoration: const InputDecoration(
                    labelText: 'Subsystem (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _tagController,
                  enabled: !_isBurnerLockout,
                  decoration: const InputDecoration(
                    labelText: 'Instrument Tag (optional)',
                  ),
                  validator:
                      (value) =>
                          (value?.trim().length ?? 0) > 80
                              ? 'Use at most 80 characters'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _classificationController,
                  enabled: !_isBurnerLockout,
                  decoration: const InputDecoration(
                    labelText: 'Classification (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                if (_selectedRouted == RoutedTo.others) ...[
                  TextFormField(
                    controller: _otherDepartmentController,
                    decoration: const InputDecoration(
                      labelText: 'Other department',
                    ),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      if (length < 2) return 'Enter at least 2 characters';
                      if (length > 80) return 'Use at most 80 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: BafSpacing.sm),
                ],
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Correction reason',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if ((value?.trim().length ?? 0) < 12) {
                      return 'Give a clear reason of at least 12 characters';
                    }
                    return null;
                  },
                ),
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
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.pop(
              context,
              buildAdminTicketCorrection(
                source: widget.ticket,
                description: _descriptionController.text.trim(),
                routedTo: _selectedRouted,
                maintenanceType: _selectedMaintenanceType,
                isCritical: _isCritical,
                component: cleanAdminOptionalText(_componentController.text),
                subsystem: cleanAdminOptionalText(_subsystemController.text),
                tag: cleanAdminTagText(_tagController.text),
                classification: cleanAdminOptionalText(
                  _classificationController.text,
                ),
                otherDepartment: cleanAdminOptionalText(
                  _otherDepartmentController.text,
                ),
                remarks: cleanAdminOptionalText(_remarksController.text),
                reason: _reasonController.text,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class TicketsBrowser extends ConsumerStatefulWidget {
  const TicketsBrowser({super.key});

  @override
  ConsumerState<TicketsBrowser> createState() => _TicketsBrowserState();
}

class _TicketsBrowserState extends ConsumerState<TicketsBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(adminTicketsStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search by asset number, description, tag, or component',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: BafColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(BafRadius.small),
                  borderSide: const BorderSide(color: BafColors.border),
                ),
                isDense: true,
              ),
              onChanged:
                  (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ticketsAsync.when(
              loading:
                  () => const BafLoadingPanel(
                    label: 'Loading maintenance records',
                    color: BafColors.admin,
                  ),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (tickets) {
                final filtered =
                    tickets.where((t) {
                      if (_searchQuery.isEmpty) return true;
                      return t.assetNumber.toString().contains(_searchQuery) ||
                          t.description.toLowerCase().contains(_searchQuery) ||
                          (t.tag?.toLowerCase().contains(_searchQuery) ??
                              false) ||
                          (t.component?.toLowerCase().contains(_searchQuery) ??
                              false);
                    }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No tickets match.',
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: BafSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) => _TicketCard(ticket: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends ConsumerStatefulWidget {
  final MaintenanceRecord ticket;
  const _TicketCard({required this.ticket});

  @override
  ConsumerState<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends ConsumerState<_TicketCard> {
  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final statusColor = _adminTicketStatusColor(ticket.status);
    final evidenceIsValid =
        ticket.actionsReadResult.isValid &&
        ticket.resolutionHistoryReadResult.isValid;

    return Card(
      color: BafColors.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        horizontal: BafSpacing.md,
        vertical: BafSpacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BafRadius.medium),
        side: const BorderSide(color: BafColors.border),
      ),
      child: ListTile(
        title: Text(
          '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber} – ${ticket.description}',
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Logged: ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.createdAt)} | By: ${ticket.loggedByName ?? ticket.reportedBy ?? 'Unknown'}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (!evidenceIsValid) ...[
                const SizedBox(height: 4),
                const Text(
                  'Saved evidence needs repair before correction',
                  style: TextStyle(
                    color: BafColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        leading: Container(
          width: 10,
          height: 42,
          decoration: BoxDecoration(
            color: ticket.isDeleted ? BafColors.textSecondary : statusColor,
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(
                ticket.isDeleted ? 'DELETED' : ticket.status.name.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              backgroundColor:
                  ticket.isDeleted ? BafColors.textSecondary : statusColor,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: BafSpacing.xs),
            IconButton(
              tooltip:
                  evidenceIsValid
                      ? 'Correct ticket'
                      : 'Repair saved evidence before correction',
              icon: Icon(
                Icons.edit,
                color:
                    evidenceIsValid
                        ? BafColors.planned
                        : BafColors.textSecondary,
              ),
              onPressed:
                  evidenceIsValid ? () => _showCorrectionDialog(ticket) : null,
            ),
            if (!ticket.isDeleted)
              IconButton(
                tooltip: 'Mark deleted',
                icon: const Icon(Icons.delete, color: BafColors.danger),
                onPressed: () => _confirmDelete(ticket),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCorrectionDialog(MaintenanceRecord ticket) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final correction = await showDialog<AdminTicketCorrectionDraft>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminCorrectTicketDialog(ticket: ticket),
    );
    if (!mounted || correction == null) return;

    try {
      if (!appUser.canCorrectMaintenanceTicket) {
        throw StateError('Admin authority required to correct tickets.');
      }
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final ticketId = ticket.firestoreId;
      if (ticketId == null || ticketId.trim().isEmpty) {
        throw StateError('Ticket has no governed server identity.');
      }
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(
            WorkflowCommandFactory.create(
              type: WorkflowCommandType.correctMaintenanceTicket,
              aggregateId: ticketId,
              expectedVersion: ticket.version,
              payload: <String, Object?>{
                'reason': correction.reason,
                'corrections': correction.corrections,
              },
            ),
          );
      await syncCoordinator.runFullSync(
        reason: 'admin_ticket_corrected',
        force: true,
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Ticket correction recorded');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Save failed: $e', color: BafColors.danger);
    }
  }

  Future<void> _confirmDelete(MaintenanceRecord ticket) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final decision = await showDialog<AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const AdminDeleteReasonDialog(
            title: 'Mark Ticket as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? ticket.firestoreId : ticket.id;
    if (id == null) {
      showAdminDataSnack(context, 'Ticket is missing its sync identifier.');
      return;
    }

    try {
      if (!appUser.canSoftDeleteMaintenanceTicket) {
        throw StateError('Admin authority required to delete tickets.');
      }
      final repository = ref.read(maintenanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteTicket(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: ticket.toAuditMap(),
        ),
      );

      final syncOutcome = await syncCoordinator.runFullSyncWithResult(
        reason: 'admin_ticket_deleted',
        force: true,
      );

      if (!mounted) return;
      showAdminMutationSyncOutcome(
        context,
        action: 'Ticket deletion',
        outcome: syncOutcome,
      );
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Delete failed: $e', color: BafColors.danger);
    }
  }
}
