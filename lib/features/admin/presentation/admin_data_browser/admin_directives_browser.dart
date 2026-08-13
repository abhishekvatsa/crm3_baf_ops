import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/sync_coordinator.dart';
import '../../../../core/theme/baf_design_system.dart';
import '../../../audit/models/audit_event_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../directives/data/operational_directive_model.dart';
import '../../../directives/providers/operational_directive_provider.dart';
import '../../../maintenance/data/maintenance_model.dart';
import '../../providers/admin_stream_providers.dart';
import 'admin_data_browser_shared.dart';
import 'admin_delete_reason_dialog.dart';
import 'admin_edit_directive_dialog.dart';

// ============================================================================
// DIRECTIVES BROWSER (with search, edit, delete)
// ============================================================================

class DirectivesBrowser extends ConsumerStatefulWidget {
  const DirectivesBrowser({super.key});

  @override
  ConsumerState<DirectivesBrowser> createState() => _DirectivesBrowserState();
}

class _DirectivesBrowserState extends ConsumerState<DirectivesBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final directivesAsync = ref.watch(adminDirectivesStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search title, target, asset, component, tag, issuer, or remarks',
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
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: directivesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (directives) {
                final filtered = directives.where(_matchesSearch).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No directives match.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.md,
                    BafSpacing.sm,
                    BafSpacing.md,
                    BafSpacing.xl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: BafSpacing.sm),
                  itemBuilder:
                      (ctx, idx) => _DirectiveCard(directive: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(OperationalDirective directive) {
    if (_searchQuery.isEmpty) return true;

    final haystack =
        [
          directive.title,
          directive.description,
          directive.directedTo.name,
          directive.status.name,
          directive.priority.name,
          directive.assetType?.name,
          directive.assetNumber?.toString(),
          directive.component,
          directive.subsystem,
          directive.tag,
          directive.hierarchyPath?.join(' '),
          directiveOwnerName(directive),
          directive.remarks,
        ].whereType<String>().join(' ').toLowerCase();

    return haystack.contains(_searchQuery);
  }
}

class _DirectiveCard extends ConsumerStatefulWidget {
  final OperationalDirective directive;

  const _DirectiveCard({required this.directive});

  @override
  ConsumerState<_DirectiveCard> createState() => _DirectiveCardState();
}

class _DirectiveCardState extends ConsumerState<_DirectiveCard> {
  @override
  Widget build(BuildContext context) {
    final d = widget.directive;
    final statusColor = _statusColor(d.status);

    return Container(
      padding: const EdgeInsets.all(BafSpacing.md),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.large),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BafRadius.medium),
            ),
            child: Icon(Icons.assignment_late_rounded, color: statusColor),
          ),
          const SizedBox(width: BafSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        d.title,
                        style: const TextStyle(
                          color: BafColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: BafSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BafSpacing.sm,
                        vertical: BafSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        d.status.name.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'To: ${_roleLabel(d.directedTo)} · Issued: ${DateFormat('dd MMM yyyy, HH:mm').format(d.createdAt)}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'By ${directiveOwnerName(d) ?? 'Unknown'}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (d.assetType != null ||
                    d.component != null ||
                    d.tag != null) ...[
                  const SizedBox(height: BafSpacing.sm),
                  Wrap(
                    spacing: BafSpacing.sm,
                    runSpacing: BafSpacing.sm,
                    children: [
                      if (d.assetType != null)
                        MiniChip(
                          label:
                              '${_assetTypeLabel(d.assetType!)} ${d.assetNumber ?? ''}'
                                  .trim(),
                          color: BafColors.assets,
                        ),
                      if (d.component != null)
                        MiniChip(label: d.component!, color: BafColors.planned),
                      if (d.tag != null)
                        MiniChip(label: d.tag!, color: BafColors.audit),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: BafSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit directive',
                icon: const Icon(Icons.edit_rounded, color: BafColors.assets),
                onPressed: () => _showEditDialog(d),
              ),
              if (!d.isDeleted)
                IconButton(
                  tooltip: 'Mark directive deleted',
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: BafColors.danger,
                  ),
                  onPressed: () => _confirmDelete(d),
                )
              else
                const MiniChip(label: 'DELETED', color: BafColors.admin),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(AppRole role) {
    switch (role) {
      case AppRole.si:
        return 'SI';
      case AppRole.contractSupervisor:
        return 'Contract Supervisor';
      case AppRole.shiftSupervisor:
        return 'Shift Supervisor';
      case AppRole.seniorElectrical:
        return 'Sr. Electrical';
      case AppRole.seniorMechanical:
        return 'Sr. Mechanical';
      case AppRole.seniorInstrumentation:
        return 'Sr. I&A';
      case AppRole.seniorRefractory:
        return 'Sr. Refractory';
      case AppRole.refractory:
        return 'Refractory';
      case AppRole.operations:
        return 'Operations';
      case AppRole.admin:
        return 'Admin';
    }
  }

  String _assetTypeLabel(AssetType type) {
    switch (type) {
      case AssetType.base:
        return 'BASE';
      case AssetType.furnace:
        return 'FURNACE';
      case AssetType.forceCooler:
        return 'FORCE COOLER';
      case AssetType.innerCover:
        return 'INNER COVER';
      case AssetType.governedCustom:
        return 'GOVERNED ASSET';
    }
  }

  Color _statusColor(DirectiveStatus status) {
    switch (status) {
      case DirectiveStatus.open:
        return BafColors.warning;
      case DirectiveStatus.acknowledged:
        return BafColors.planned;
      case DirectiveStatus.closed:
        return BafColors.sync;
    }
  }

  Future<void> _showEditDialog(OperationalDirective directive) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Try again.',
        color: BafColors.warning,
      );
      return;
    }

    final updated = await showDialog<OperationalDirective>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminEditDirectiveDialog(directive: directive),
    );
    if (!mounted || updated == null) return;

    try {
      final repository = ref.read(directiveRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.updateDirective(updated, actor: appUser);

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_directive_edited',
          force: true,
        ),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Directive updated');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Save failed: $e', color: BafColors.danger);
    }
  }

  Future<void> _confirmDelete(OperationalDirective directive) async {
    final appUser = ref.read(currentAppUserProvider).value;
    if (appUser == null) {
      showAdminDataSnack(
        context,
        'Admin identity is still loading. Please try again.',
        color: BafColors.warning,
      );
      return;
    }

    if (!appUser.canDeleteDirective) {
      showAdminDataSnack(
        context,
        'Only Admin can delete directives.',
        color: BafColors.danger,
      );
      return;
    }

    final decision = await showDialog<AdminDeleteDecision>(
      context: context,
      builder:
          (_) => const AdminDeleteReasonDialog(
            title: 'Mark Directive as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? directive.firestoreId : directive.id;
    if (id == null) {
      showAdminDataSnack(
        context,
        'Directive is missing its sync identifier.',
        color: BafColors.warning,
      );
      return;
    }

    try {
      final repository = ref.read(directiveRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteDirective(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: directive.toAuditMap(),
        ),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_directive_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Directive marked as deleted');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Delete failed: $e', color: BafColors.danger);
    }
  }
}
