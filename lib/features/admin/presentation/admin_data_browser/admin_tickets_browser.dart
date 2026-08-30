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
import '../../../maintenance/domain/furnace_stuckup_case.dart';
import '../../../maintenance/providers/maintenance_provider.dart';
import '../../../maintenance/services/maintenance_issue_command_reconciler.dart';
import '../../../maintenance_workflow/domain/workflow_types.dart';
import '../../../maintenance_workflow/providers/workflow_providers.dart';
import '../../../maintenance_workflow/services/workflow_command_factory.dart';
import '../../providers/admin_stream_providers.dart';
import '../../utils/admin_ticket_helpers.dart';
import 'admin_data_browser_shared.dart';
import 'admin_delete_reason_dialog.dart';
import 'admin_pilot_purge.dart';

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
    case TicketStatus.closedWithoutResolution:
      return BafColors.warning;
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

  bool get _isFurnaceStuckup =>
      widget.ticket.classification == furnaceStuckupClassification;

  bool get _isSpecializedIssue => _isBurnerLockout || _isFurnaceStuckup;

  bool get _hasRedHotBurner =>
      widget.ticket.burnerLockoutReadResult.value?.hasRedHotObservation == true;

  bool get _canCorrectRoute =>
      !_isSpecializedIssue &&
      widget.ticket.status == TicketStatus.open &&
      widget.ticket.acknowledgedByUid == null &&
      widget.ticket.acknowledgedByName == null &&
      widget.ticket.acknowledgedAt == null;

  bool get _usesOtherDepartment =>
      tryAdminTicketCorrectionLanes(
        source: widget.ticket,
        primaryRoute: _selectedRouted,
      )?.contains(RoutedTo.others) ??
      _selectedRouted == RoutedTo.others;

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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.md),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(BafRadius.medium),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.40),
                    ),
                  ),
                  child: const Text(
                    'Audited correction: preserve the facts. Do not invent or erase evidence. Before-and-after values, your identity, time, and reason are retained permanently.',
                    style: TextStyle(
                      color: BafColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
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
                          (value?.trim().isEmpty ?? true)
                              ? 'Enter a description'
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
                            : _isFurnaceStuckup
                            ? 'Furnace stuck-up remains accountable to Mechanical.'
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
                              if (!_usesOtherDepartment) {
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
                      _isSpecializedIssue
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
                  enabled: !_isSpecializedIssue,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                  validator: (value) {
                    final length = value?.trim().length ?? 0;
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
                  enabled: !_isSpecializedIssue,
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
                  enabled: !_isSpecializedIssue,
                  decoration: const InputDecoration(
                    labelText: 'Classification (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                if (_usesOtherDepartment) ...[
                  TextFormField(
                    controller: _otherDepartmentController,
                    decoration: const InputDecoration(
                      labelText: 'Other accountable team',
                    ),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      if (length == 0) return 'Enter the accountable team';
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
                    if (value?.trim().isEmpty ?? true) {
                      return 'Give a reason for the correction';
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
    final statusChip = Chip(
      label: Text(
        ticket.isDeleted ? 'DELETED' : ticket.status.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: ticket.isDeleted ? BafColors.textSecondary : statusColor,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    Widget buildActionButtons() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!evidenceIsValid)
            const Tooltip(
              message: 'Saved ticket evidence is malformed',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: BafColors.danger,
                  size: 20,
                ),
              ),
            ),
          IconButton(
            key: const ValueKey('admin-ticket-description-view'),
            tooltip: 'View full ticket description',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => _showDescriptionDialog(ticket),
          ),
          IconButton(
            tooltip:
                evidenceIsValid
                    ? 'Correct ticket'
                    : 'Repair saved evidence before correction',
            icon: Icon(
              Icons.edit,
              color:
                  evidenceIsValid ? BafColors.planned : BafColors.textSecondary,
            ),
            onPressed:
                evidenceIsValid ? () => _showCorrectionDialog(ticket) : null,
          ),
          if (!ticket.isDeleted)
            IconButton(
              tooltip: 'Mark deleted',
              icon: const Icon(Icons.delete, color: BafColors.danger),
              onPressed: () => _confirmDelete(ticket),
            )
          else if (ticket.firestoreId != null)
            IconButton(
              tooltip: 'Permanently remove pilot record',
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: BafColors.danger,
              ),
              onPressed: () => _purgePermanently(ticket),
            ),
        ],
      );
    }

    return Card(
      key: ValueKey('admin-ticket-${ticket.firestoreId ?? ticket.id}'),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final assetLabel =
              '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}';
          final metadata =
              'Logged ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.createdAt)} · ${ticket.loggedByName ?? ticket.reportedBy ?? 'Unknown'}';
          const compactDescriptionStyle = TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.25,
          );
          const desktopDescriptionStyle = TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w700,
          );
          final actionButtons = buildActionButtons();
          if (compact) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color:
                        ticket.isDeleted
                            ? BafColors.textSecondary
                            : statusColor,
                    width: 7,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          assetLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BafColors.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: BafSpacing.sm),
                      statusChip,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ticket.description,
                    key: const ValueKey('admin-ticket-description-preview'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: compactDescriptionStyle,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    metadata,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Align(alignment: Alignment.centerRight, child: actionButtons),
                ],
              ),
            );
          }
          return ListTile(
            title: Text(
              '$assetLabel – ${ticket.description}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: desktopDescriptionStyle,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: BafSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                statusChip,
                const SizedBox(width: BafSpacing.xs),
                actionButtons,
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDescriptionDialog(MaintenanceRecord ticket) async {
    final assetLabel =
        '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}';
    final metadata =
        'Logged ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.createdAt)} by '
        '${ticket.loggedByName ?? ticket.reportedBy ?? 'Unknown'}';
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.description_outlined),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Text(
                    assetLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.isDeleted
                          ? 'Deleted · ${ticket.status.name}'
                          : ticket.status.name,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.sm),
                    SelectableText(
                      ticket.description,
                      key: const ValueKey('admin-ticket-full-description'),
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: BafSpacing.md),
                    Text(
                      metadata,
                      style: const TextStyle(
                        color: BafColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
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

  Future<void> _purgePermanently(MaintenanceRecord ticket) async {
    final id = ticket.firestoreId;
    if (id == null) return;
    await purgePilotBusinessRecord(
      context: context,
      ref: ref,
      collectionId: 'maintenance_records',
      documentId: id,
      expectedVersion: ticket.version,
      recordLabel:
          '${ticket.assetType.name.toUpperCase()} ${ticket.assetNumber}: ${ticket.description}',
    );
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

    final firestoreId = ticket.firestoreId?.trim();
    if (firestoreId == null || firestoreId.isEmpty) {
      showAdminDataSnack(context, 'Ticket is missing its sync identifier.');
      return;
    }

    try {
      if (!appUser.canSoftDeleteMaintenanceTicket) {
        throw StateError('Admin authority required to delete tickets.');
      }
      final remoteRepository = ref.read(firestoreMaintenanceRepo);
      final deletionReconciler = ref.read(
        maintenanceIssueCommandReconcilerProvider,
      );
      final syncCoordinator = ref.read(syncCoordinatorProvider);
      final auditContext = AuditContext(
        performedByUid: appUser.uid,
        performedByName: appUser.name,
        reason: decision.reason,
        reasonNotes: decision.notes,
        before: ticket.toAuditMap(),
      );

      if (kIsWeb) {
        await remoteRepository.deleteTicket(
          firestoreId,
          actor: appUser,
          auditContext: auditContext,
        );
      } else {
        await deletionReconciler.softDeleteServerFirst(
          localRecord: ticket,
          actor: appUser,
          auditContext: auditContext,
        );
      }

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
