import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/sync_coordinator.dart';
import '../../../../core/theme/baf_design_system.dart';
import '../../../audit/models/audit_event_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../maintenance/data/maintenance_model.dart';
import '../../../maintenance/providers/maintenance_provider.dart';
import '../../providers/admin_stream_providers.dart';
import '../../utils/admin_ticket_helpers.dart';
import 'admin_data_browser_shared.dart';
import 'admin_delete_reason_dialog.dart';

// ============================================================================
// TICKETS BROWSER (with search, edit, delete, and timeline invalidation)
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

class _AdminEditTicketDialog extends StatefulWidget {
  final MaintenanceRecord ticket;
  final String editedByUid;
  final String editedByName;

  const _AdminEditTicketDialog({
    required this.ticket,
    required this.editedByUid,
    required this.editedByName,
  });

  @override
  State<_AdminEditTicketDialog> createState() => _AdminEditTicketDialogState();
}

class _AdminEditTicketDialogState extends State<_AdminEditTicketDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _assetNumberController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _componentController;
  late final TextEditingController _tagController;
  late final TextEditingController _remarksController;

  late AssetType _selectedType;
  late RoutedTo _selectedRouted;
  late MaintenanceType _selectedMaintenanceType;
  late TicketStatus _selectedStatus;

  @override
  void initState() {
    super.initState();
    final ticket = widget.ticket;
    _assetNumberController = TextEditingController(
      text: ticket.assetNumber.toString(),
    );
    _descriptionController = TextEditingController(text: ticket.description);
    _componentController = TextEditingController(text: ticket.component ?? '');
    _tagController = TextEditingController(text: ticket.tag ?? '');
    _remarksController = TextEditingController(text: ticket.remarks ?? '');
    _selectedType = ticket.assetType;
    _selectedRouted = ticket.routedTo;
    _selectedMaintenanceType = ticket.maintenanceType;
    _selectedStatus = ticket.status;
  }

  @override
  void dispose() {
    _assetNumberController.dispose();
    _descriptionController.dispose();
    _componentController.dispose();
    _tagController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Ticket'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AssetType>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Asset Type'),
                  items:
                      AssetType.values.map((type) {
                        return DropdownMenuItem<AssetType>(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _assetNumberController,
                  decoration: const InputDecoration(labelText: 'Asset Number'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final raw = value?.trim();
                    if (raw == null || raw.isEmpty) {
                      return 'Required';
                    }
                    if (int.tryParse(raw) == null) {
                      return 'Enter a valid whole number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                  validator:
                      (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<RoutedTo>(
                  initialValue: _selectedRouted,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Route To'),
                  items:
                      RoutedTo.values.map((route) {
                        return DropdownMenuItem<RoutedTo>(
                          value: route,
                          child: Text(route.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedRouted = value);
                  },
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
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedMaintenanceType = value);
                  },
                ),
                const SizedBox(height: BafSpacing.sm),
                DropdownButtonFormField<TicketStatus>(
                  initialValue: _selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items:
                      TicketStatus.values.map((status) {
                        return DropdownMenuItem<TicketStatus>(
                          value: status,
                          child: Text(status.name.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedStatus = value);
                  },
                ),
                if (_selectedStatus == TicketStatus.resolved &&
                    !widget.ticket.isResolved) ...[
                  const SizedBox(height: BafSpacing.sm),
                  const Text(
                    'Saving as resolved will stamp this ticket with the current admin identity and current time if closure fields are missing.',
                    style: TextStyle(
                      color: BafColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _componentController,
                  decoration: const InputDecoration(
                    labelText: 'Component (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    labelText: 'Instrument Tag (optional)',
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
                  textInputAction: TextInputAction.newline,
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
              copyTicketForAdminEdit(
                source: widget.ticket,
                assetType: _selectedType,
                assetNumber: int.parse(_assetNumberController.text.trim()),
                description: _descriptionController.text.trim(),
                routedTo: _selectedRouted,
                maintenanceType: _selectedMaintenanceType,
                status: _selectedStatus,
                component: cleanAdminOptionalText(_componentController.text),
                tag: cleanAdminTagText(_tagController.text),
                remarks: cleanAdminOptionalText(_remarksController.text),
                editedByUid: widget.editedByUid,
                editedByName: widget.editedByName,
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
          child: Text(
            'Logged: ${DateFormat('dd MMM yyyy, HH:mm').format(ticket.createdAt)} | By: ${ticket.loggedByName ?? ticket.reportedBy ?? 'Unknown'}',
            style: const TextStyle(
              color: BafColors.textSecondary,
              fontSize: 12,
            ),
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
              tooltip: 'Edit ticket',
              icon: const Icon(Icons.edit, color: BafColors.planned),
              onPressed: () => _showEditDialog(ticket),
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

  Future<void> _showEditDialog(MaintenanceRecord ticket) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final updatedTicket = await showDialog<MaintenanceRecord>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _AdminEditTicketDialog(
            ticket: ticket,
            editedByUid: appUser.uid,
            editedByName: appUser.name,
          ),
    );
    if (!mounted || updatedTicket == null) return;

    try {
      if (!appUser.canAdminEditMaintenanceTicket) {
        throw StateError('Admin authority required to edit tickets.');
      }
      final repository = ref.read(maintenanceRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.updateTicket(updatedTicket, actor: appUser);

      unawaited(
        syncCoordinator.runFullSync(reason: 'admin_ticket_edited', force: true),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Ticket updated');
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

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_ticket_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Ticket marked as deleted');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Delete failed: $e', color: BafColors.danger);
    }
  }
}
