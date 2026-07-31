import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/dashboard/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/job_template_model.dart';
import '../providers/planned_maintenance_provider.dart';
import 'planned_job_detail_screen.dart';

class ClosedJobDossiersScreen extends ConsumerStatefulWidget {
  const ClosedJobDossiersScreen({super.key});

  @override
  ConsumerState<ClosedJobDossiersScreen> createState() =>
      _ClosedJobDossiersScreenState();
}

class _ClosedJobDossiersScreenState
    extends ConsumerState<ClosedJobDossiersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(title: const Text('Closed Job Dossiers')),
      body: actorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _DossierMessage(
              icon: Icons.error_outline_rounded,
              title: 'Could not verify access',
              message: '$error',
            ),
        data: (actor) {
          if (actor == null || !actor.canViewClosedJobDossiers) {
            return const _DossierMessage(
              icon: Icons.lock_outline_rounded,
              title: 'Approved access required',
              message:
                  'Closed planned-job records are available to approved users.',
            );
          }

          return _ClosedDossierList(
            query: _query,
            onQueryChanged: (value) => setState(() => _query = value),
          );
        },
      ),
    );
  }
}

class _ClosedDossierList extends ConsumerWidget {
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _ClosedDossierList({required this.query, required this.onQueryChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dossiersAsync = ref.watch(closedExecutionsProvider);

    return dossiersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, _) => _DossierMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load closed jobs',
            message: '$error',
          ),
      data: (dossiers) {
        final visible = _filter(dossiers, query);
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(closedExecutionsProvider);
            await ref.read(closedExecutionsProvider.future);
          },
          child: ListView(
            key: const ValueKey('closed-job-dossiers-list'),
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.xl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey('closed-job-dossiers-search'),
                        onChanged: onQueryChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search jobs, assets or teams',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: BafSpacing.sm),
                      Text(
                        '${visible.length} of ${dossiers.length} recent closed records',
                        style: const TextStyle(
                          color: BafColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: BafSpacing.md),
                      if (visible.isEmpty)
                        _DossierMessage(
                          icon: Icons.inventory_2_outlined,
                          title:
                              dossiers.isEmpty
                                  ? 'No closed job dossiers'
                                  : 'No matching dossiers',
                          message:
                              dossiers.isEmpty
                                  ? 'Completed and cancelled planned jobs will appear here.'
                                  : 'Try another job, asset or team name.',
                        )
                      else
                        ...visible.map(
                          (execution) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: BafSpacing.sm,
                            ),
                            child: _ClosedDossierTile(execution: execution),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<JobExecution> _filter(List<JobExecution> dossiers, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return dossiers;
    return dossiers
        .where(
          (execution) => <String?>[
            execution.templateName,
            execution.templatePackageCode,
            execution.assetType.name,
            '${execution.assetNumber}',
            execution.completedByName,
            execution.cancellationReason,
            ...execution.assignedAgencies,
            ...execution.teamsInvolved,
          ].any((value) => value?.toLowerCase().contains(needle) == true),
        )
        .toList(growable: false);
  }
}

class _ClosedDossierTile extends StatelessWidget {
  final JobExecution execution;

  const _ClosedDossierTile({required this.execution});

  @override
  Widget build(BuildContext context) {
    final cancelled = execution.isCancelled;
    final closedAt = execution.completedAt ?? execution.cancelledAt;
    final title = execution.templateName?.trim();
    final assetType = execution.assetType.name;
    final assetLabel =
        '${assetType[0].toUpperCase()}${assetType.substring(1)} ${execution.assetNumber}';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        key: ValueKey(
          'closed-job-dossier-${execution.firestoreId ?? execution.id}',
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: BafSpacing.md,
          vertical: BafSpacing.sm,
        ),
        leading: Icon(
          cancelled ? Icons.cancel_outlined : Icons.task_alt_rounded,
          color: cancelled ? BafColors.warning : BafColors.success,
        ),
        title: Text(
          title == null || title.isEmpty ? 'Unnamed planned job' : title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: BafSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$assetLabel${closedAt == null ? '' : ' · ${DateFormat('dd MMM yyyy, HH:mm').format(closedAt.toLocal())}'}',
              ),
              const SizedBox(height: BafSpacing.xs),
              StatusBadge(
                label: cancelled ? 'Cancelled' : 'Completed',
                color: cancelled ? BafColors.warning : BafColors.success,
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlannedJobDetailScreen(execution: execution),
              ),
            ),
      ),
    );
  }
}

class _DossierMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _DossierMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: BafColors.textSecondary),
            const SizedBox(height: BafSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BafColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BafColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
