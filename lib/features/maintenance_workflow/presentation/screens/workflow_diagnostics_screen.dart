import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/baf_design_system.dart';
import '../../../../core/widgets/baf_ui.dart';
import '../../../../core/widgets/brand/brand_widgets.dart';
import '../../../../core/widgets/dashboard/status_badge.dart';
import '../../../auth/data/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/workflow_command_record.dart';
import '../../providers/workflow_providers.dart';
import '../../services/workflow_pull_service.dart';

class WorkflowDiagnosticsScreen extends ConsumerStatefulWidget {
  const WorkflowDiagnosticsScreen({super.key});

  @override
  ConsumerState<WorkflowDiagnosticsScreen> createState() =>
      _WorkflowDiagnosticsScreenState();
}

class _WorkflowDiagnosticsScreenState
    extends ConsumerState<WorkflowDiagnosticsScreen> {
  Future<_WorkflowDiagnosticsSnapshot>? _future;
  String? _futureActorUid;

  Future<_WorkflowDiagnosticsSnapshot> _load() async {
    final quarantine = await WorkflowPullService.readQuarantine();
    final pending =
        await ref.read(workflowRepositoryProvider).getPendingCommands();
    return _WorkflowDiagnosticsSnapshot(
      quarantine: quarantine,
      pendingCommands: pending,
    );
  }

  void _ensureLoadedFor(AppUser actor) {
    if (_future != null && _futureActorUid == actor.uid) return;
    _futureActorUid = actor.uid;
    _future = _load();
  }

  void _clearLoadedDiagnostics() {
    _futureActorUid = null;
    _future = null;
  }

  void _refresh() {
    final actorAsync = ref.read(currentAppUserProvider);
    final actor =
        actorAsync.isLoading || actorAsync.hasError ? null : actorAsync.value;
    if (actor == null || !actor.canViewMaintenanceWorkflowDiagnostics) {
      setState(_clearLoadedDiagnostics);
      return;
    }
    setState(() {
      _futureActorUid = actor.uid;
      _future = _load();
    });
  }

  Future<void> _clearQuarantine() async {
    final actorAsync = ref.read(currentAppUserProvider);
    final actor =
        actorAsync.isLoading || actorAsync.hasError ? null : actorAsync.value;
    if (actor == null || !actor.canViewMaintenanceWorkflowDiagnostics) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics authority is no longer valid.'),
        ),
      );
      return;
    }
    try {
      await WorkflowPullService.clearQuarantine();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Local workflow log could not be cleared.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Workflow pull quarantine cleared.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      _clearLoadedDiagnostics();
      return const _DiagnosticsAccessState(
        title: 'Checking diagnostics access',
        message: 'Please wait while your permissions are verified.',
        showProgress: true,
      );
    }
    if (actorAsync.hasError) {
      _clearLoadedDiagnostics();
      return const _DiagnosticsAccessState(
        title: 'Diagnostics access could not be verified',
        message: 'Try again after your approved account can be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canViewMaintenanceWorkflowDiagnostics) {
      _clearLoadedDiagnostics();
      return const _DiagnosticsAccessState(
        title: 'Admin/SI access required',
        message: 'Only approved Admin/SI users can open workflow diagnostics.',
      );
    }
    _ensureLoadedFor(actor);

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Workflow diagnostics',
          subtitle: 'Local integrity and uncertain command review',
          icon: Icons.troubleshoot_outlined,
          accent: BafColors.admin,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BafContentFrame(
        maxWidth: 960,
        child: FutureBuilder<_WorkflowDiagnosticsSnapshot>(
          future: _future!,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const BafLoadingPanel(
                label: 'Reading local workflow diagnostics',
                color: BafColors.admin,
              );
            }
            if (snapshot.hasError || snapshot.data == null) {
              final quarantineNeedsRepair =
                  snapshot.error is WorkflowPullStateException;
              return BafStatePanel(
                icon: Icons.sync_problem_outlined,
                color: BafColors.danger,
                title:
                    quarantineNeedsRepair
                        ? 'Workflow diagnostics need repair'
                        : 'Workflow diagnostics unavailable',
                message:
                    quarantineNeedsRepair
                        ? 'The local quarantine log is malformed. Clear only this local log before retrying diagnostics.'
                        : '${snapshot.error}',
                primaryLabel:
                    quarantineNeedsRepair ? 'Clear local log' : 'Try again',
                primaryIcon:
                    quarantineNeedsRepair
                        ? Icons.delete_sweep_outlined
                        : Icons.refresh_rounded,
                onPrimary: quarantineNeedsRepair ? _clearQuarantine : _refresh,
              );
            }
            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _future!;
              },
              child: ListView(
                children: [
                  BafScreenIntro(
                    title: 'Local workflow health',
                    subtitle:
                        'Review isolated malformed records and commands awaiting governed recovery.',
                    icon: Icons.health_and_safety_outlined,
                    accent: BafColors.admin,
                    trailing: StatusBadge(
                      label:
                          data.quarantine.isEmpty &&
                                  data.pendingCommands.isEmpty
                              ? 'Healthy'
                              : 'Attention needed',
                      color:
                          data.quarantine.isEmpty &&
                                  data.pendingCommands.isEmpty
                              ? BafColors.success
                              : BafColors.warning,
                    ),
                  ),
                  const SizedBox(height: BafSpacing.lg),
                  _SummaryCard(
                    quarantineCount: data.quarantine.length,
                    pendingCommandCount: data.pendingCommands.length,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Quarantined projection records',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed:
                            data.quarantine.isEmpty ? null : _clearQuarantine,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear local log'),
                      ),
                    ],
                  ),
                  if (data.quarantine.isEmpty)
                    const _EmptyCard(
                      text:
                          'No malformed workflow projection is retained locally.',
                    )
                  else
                    ...data.quarantine.reversed.map(
                      (record) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber_rounded),
                          title: Text(
                            '${record.collection}/${record.documentId}',
                          ),
                          subtitle: Text(
                            '${record.stage}: ${record.error}\n'
                            'Observed: ${record.observedAt ?? 'unknown'}\n'
                            'Quarantined: ${record.quarantinedAt}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Unresolved uncertain commands',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (data.pendingCommands.isEmpty)
                    const _EmptyCard(
                      text:
                          'No workflow command is awaiting retry or manual review.',
                    )
                  else
                    ...data.pendingCommands.map(
                      (command) => Card(
                        child: ListTile(
                          leading: Icon(
                            command.stateKey == 'manualReview'
                                ? Icons.rule_folder_outlined
                                : Icons.sync_problem_outlined,
                          ),
                          title: Text(command.commandTypeKey),
                          subtitle: Text(
                            '${command.aggregateId}\n'
                            '${command.stateKey} · attempts ${command.attemptCount}'
                            '${command.lastErrorCode == null ? '' : '\n${command.lastErrorCode}: ${command.lastErrorMessage ?? ''}'}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const BafRecordSurface(
                    accent: BafColors.audit,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: BafColors.audit,
                        ),
                        SizedBox(width: BafSpacing.md),
                        Expanded(
                          child: Text(
                            'This page is diagnostic only. It does not replay, alter or delete server workflow state. Command recovery remains governed by the idempotent retry service.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: BafSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DiagnosticsAccessState extends StatelessWidget {
  final String title;
  final String message;
  final bool showProgress;

  const _DiagnosticsAccessState({
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Workflow diagnostics',
          subtitle: 'Local integrity and uncertain command review',
          icon: Icons.troubleshoot_outlined,
          accent: BafColors.admin,
        ),
      ),
      body:
          showProgress
              ? BafLoadingPanel(label: title, color: BafColors.admin)
              : BafStatePanel(
                icon: Icons.lock_outline_rounded,
                color: BafColors.audit,
                title: title,
                message: message,
              ),
    );
  }
}

class _WorkflowDiagnosticsSnapshot {
  final List<WorkflowPullQuarantineRecord> quarantine;
  final List<WorkflowCommandRecord> pendingCommands;

  const _WorkflowDiagnosticsSnapshot({
    required this.quarantine,
    required this.pendingCommands,
  });
}

class _SummaryCard extends StatelessWidget {
  final int quarantineCount;
  final int pendingCommandCount;

  const _SummaryCard({
    required this.quarantineCount,
    required this.pendingCommandCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Quarantined records',
                value: quarantineCount,
              ),
            ),
            Expanded(
              child: _Metric(
                label: 'Pending commands',
                value: pendingCommandCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineMedium),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
  );
}
