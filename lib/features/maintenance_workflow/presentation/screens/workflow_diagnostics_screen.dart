import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<_WorkflowDiagnosticsSnapshot> _load() async {
    final quarantine = await WorkflowPullService.readQuarantine();
    final pending =
        await ref.read(workflowRepositoryProvider).getPendingCommands();
    return _WorkflowDiagnosticsSnapshot(
      quarantine: quarantine,
      pendingCommands: pending,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _clearQuarantine() async {
    await WorkflowPullService.clearQuarantine();
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
      return const _DiagnosticsAccessState(
        title: 'Checking diagnostics access',
        message: 'Please wait while your permissions are verified.',
        showProgress: true,
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canViewMaintenanceWorkflowDiagnostics) {
      return const _DiagnosticsAccessState(
        title: 'Admin/SI access required',
        message: 'Only approved Admin/SI users can open workflow diagnostics.',
      );
    }
    _future ??= _load();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflow Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_WorkflowDiagnosticsSnapshot>(
        future: _future!,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            final quarantineNeedsRepair =
                snapshot.error is WorkflowPullStateException;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_problem_outlined, size: 44),
                    const SizedBox(height: 16),
                    Text(
                      quarantineNeedsRepair
                          ? 'Workflow diagnostics need repair'
                          : 'Workflow diagnostics unavailable',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      quarantineNeedsRepair
                          ? 'The local quarantine log is malformed. Clear only this local log before retrying diagnostics.'
                          : '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    if (quarantineNeedsRepair) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _clearQuarantine,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Clear local log'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future!;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                const Text(
                  'This page is diagnostic only. It does not replay, alter or delete server workflow state. Command recovery remains governed by the idempotent retry service.',
                ),
              ],
            ),
          );
        },
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
      appBar: AppBar(title: const Text('Workflow Diagnostics')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress)
                const CircularProgressIndicator()
              else
                const Icon(Icons.lock_outline, size: 44),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
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
