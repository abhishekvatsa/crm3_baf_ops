import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/sync_coordinator.dart';
import '../../../../core/theme/baf_design_system.dart';
import '../../../audit/models/audit_event_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../planned_maintenance/data/job_template_model.dart';
import '../../../planned_maintenance/providers/planned_maintenance_provider.dart';
import '../../providers/admin_stream_providers.dart';
import '../../utils/admin_search_sort_helpers.dart';
import 'admin_data_browser_shared.dart';
import 'admin_delete_reason_dialog.dart';

// ============================================================================
// TEMPLATES BROWSER (delete only – no edit)
// ============================================================================

class TemplatesBrowser extends ConsumerStatefulWidget {
  const TemplatesBrowser({super.key});

  @override
  ConsumerState<TemplatesBrowser> createState() => _TemplatesBrowserState();
}

class _TemplatesBrowserState extends ConsumerState<TemplatesBrowser> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(adminTemplatesStreamProvider);

    return ColoredBox(
      color: BafColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BafSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText:
                    'Search by job name, asset type, agency, or component',
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
            child: templatesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (err, _) => Center(
                    child: Text(
                      'Error: $err',
                      style: const TextStyle(color: BafColors.danger),
                    ),
                  ),
              data: (templates) {
                final filtered =
                    templates
                        .where(
                          (template) => templateMatchesAdminSearch(
                            template,
                            _searchQuery,
                          ),
                        )
                        .toList()
                      ..sort(compareTemplatesForAdmin);

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No templates match.',
                      style: TextStyle(color: BafColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: BafSpacing.md),
                  itemCount: filtered.length,
                  itemBuilder:
                      (ctx, idx) => _TemplateCard(template: filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends ConsumerStatefulWidget {
  final JobTemplate template;

  const _TemplateCard({required this.template});

  @override
  ConsumerState<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends ConsumerState<_TemplateCard> {
  @override
  Widget build(BuildContext context) {
    final template = widget.template;
    final fieldCount = template.parsedFields.length;
    final scopeLabel = templateScopeLabel(template);

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
        leading: Container(
          width: 10,
          height: 46,
          decoration: BoxDecoration(
            color:
                template.isDeleted
                    ? BafColors.textSecondary
                    : BafColors.planned,
            borderRadius: BorderRadius.circular(BafRadius.small),
          ),
        ),
        title: Text(
          template.jobName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BafColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${template.applicableAssetType.name.toUpperCase()} | ${formatAgencyList(template.assignedAgencies)}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: BafSpacing.xs),
              Wrap(
                spacing: BafSpacing.xs,
                runSpacing: BafSpacing.xs,
                children: [
                  AdminChip(
                    label: '$fieldCount fields',
                    color: BafColors.planned,
                  ),
                  if (scopeLabel != null)
                    AdminChip(label: scopeLabel, color: BafColors.assets),
                  if (template.isDeprecated)
                    const AdminChip(
                      label: 'DEPRECATED',
                      color: BafColors.warning,
                    ),
                  if (template.isDeleted)
                    const AdminChip(
                      label: 'DELETED',
                      color: BafColors.textSecondary,
                    ),
                ],
              ),
              if (template.createdByName != null &&
                  template.createdByName!.trim().isNotEmpty) ...[
                const SizedBox(height: BafSpacing.xs),
                Text(
                  'Created by ${template.createdByName!.trim()} • ${DateFormat('dd MMM yyyy, HH:mm').format(template.createdAt)}',
                  style: const TextStyle(
                    color: BafColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!template.isDeleted)
              IconButton(
                tooltip: 'Mark deleted',
                icon: const Icon(Icons.delete, color: BafColors.danger),
                onPressed: () => _confirmDelete(template),
              )
            else
              const AdminChip(label: 'DELETED', color: BafColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(JobTemplate template) async {
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
            title: 'Mark Template as Deleted',
            message:
                'Mark this as deleted? It will be hidden from active records but retained for audit and recovery.',
          ),
    );
    if (!mounted || decision == null) return;

    final id = kIsWeb ? template.firestoreId : template.id;
    if (id == null) {
      showAdminDataSnack(
        context,
        'Template ID is missing',
        color: BafColors.warning,
      );
      return;
    }

    try {
      if (!appUser.canDeleteLegacyJobTemplate) {
        throw StateError(
          'Admin authority required to delete legacy templates.',
        );
      }
      final repository = ref.read(plannedRepositoryProvider);
      final syncCoordinator = ref.read(syncCoordinatorProvider);

      await repository.deleteTemplate(
        id,
        actor: appUser,
        auditContext: AuditContext(
          performedByUid: appUser.uid,
          performedByName: appUser.name,
          reason: decision.reason,
          reasonNotes: decision.notes,
          before: template.toAuditMap(),
        ),
      );

      unawaited(
        syncCoordinator.runFullSync(
          reason: 'admin_template_deleted',
          force: true,
        ),
      );

      if (!mounted) return;
      showAdminDataSnack(context, 'Template marked as deleted');
    } catch (e) {
      if (!mounted) return;
      showAdminDataSnack(context, 'Delete failed: $e', color: BafColors.danger);
    }
  }
}
