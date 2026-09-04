import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/validation/charge_number.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../abnormalities/data/abnormality_model.dart';
import '../../abnormalities/providers/abnormality_provider.dart';
import '../data/quality_warning.dart';
import '../providers/quality_provider.dart';
import '../services/quality_command_service.dart';

part 'quality_home_screen.widgets.dart';
part 'quality_home_screen.cards.dart';

enum _WarningFilter { open, review, closed }

enum QualityWorkspaceTab { warnings, monitoring }

class QualityHomeScreen extends ConsumerStatefulWidget {
  const QualityHomeScreen({
    super.key,
    this.initialTab = QualityWorkspaceTab.warnings,
  });

  const QualityHomeScreen.monitoring({super.key})
    : initialTab = QualityWorkspaceTab.monitoring;

  final QualityWorkspaceTab initialTab;

  @override
  ConsumerState<QualityHomeScreen> createState() => _QualityHomeScreenState();
}

class _QualityHomeScreenState extends ConsumerState<QualityHomeScreen> {
  _WarningFilter _filter = _WarningFilter.open;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Quality',
        appBarSubtitle: 'Verifying your approved quality scope',
        appBarIcon: Icons.verified_user_outlined,
        accent: BafColors.charges,
        label: 'Checking quality access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Quality',
        appBarSubtitle: 'Verifying your approved quality scope',
        appBarIcon: Icons.verified_user_outlined,
        accent: BafColors.charges,
        message: 'Quality access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.canViewQuality) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Quality',
        appBarSubtitle: 'Approved quality access only',
        appBarIcon: Icons.verified_user_outlined,
        accent: BafColors.charges,
        title: 'Quality access required',
        message:
            'An approved operational role is required to view quality records.',
      );
    }
    final warnings = ref.watch(qualityWarningsProvider);
    final monitoring = ref.watch(qualityMonitoringRequestsProvider);
    final warningCount = warnings.whenOrNull(
      data: (items) => items.where((warning) => warning.isOpen).length,
    );
    final monitoringCount = monitoring.whenOrNull(
      data:
          (items) =>
              items
                  .where(
                    (request) =>
                        request.status == QualityMonitoringStatus.active,
                  )
                  .length,
    );
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab.index,
      child: Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Quality',
            subtitle: 'Warnings, disposition and cycle monitoring',
            icon: Icons.verified_user_outlined,
            accent: BafColors.charges,
          ),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.warning_amber_rounded),
                text: 'Warnings (${warningCount ?? '--'})',
              ),
              Tab(
                icon: const Icon(Icons.monitor_heart_outlined),
                text: 'Monitoring (${monitoringCount ?? '--'})',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildWarnings(actor), _buildMonitoring(actor)],
        ),
      ),
    );
  }

  Widget _buildWarnings(AppUser? actor) {
    final warnings = ref.watch(qualityWarningsProvider);
    return warnings.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading quality warnings',
            color: BafColors.charges,
          ),
      error:
          (error, _) => _ErrorState(
            title: 'Quality warnings unavailable',
            detail: '$error',
            onRetry: () => ref.invalidate(qualityWarningsProvider),
          ),
      data: (items) {
        final open =
            items
                .where((warning) => warning.status == QualityWarningStatus.open)
                .length;
        final review =
            items
                .where(
                  (warning) =>
                      warning.status == QualityWarningStatus.closureRequested,
                )
                .length;
        final closed = items.length - open - review;
        final visible =
            items
                .where(
                  (warning) => switch (_filter) {
                    _WarningFilter.open =>
                      warning.status == QualityWarningStatus.open,
                    _WarningFilter.review =>
                      warning.status == QualityWarningStatus.closureRequested,
                    _WarningFilter.closed =>
                      warning.status == QualityWarningStatus.closed,
                  },
                )
                .toList();

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(qualityWarningsProvider),
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.xl,
            ),
            itemCount: visible.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryStrip(open: open, review: review, closed: closed),
                    if (items.length >= qualityWarningLiveWindowLimit) ...[
                      const SizedBox(height: BafSpacing.sm),
                      const _WindowScopeNotice(
                        text:
                            'Showing every open or review warning plus up to 500 recent warnings',
                      ),
                    ],
                    const SizedBox(height: BafSpacing.lg),
                    SegmentedButton<_WarningFilter>(
                      segments: const [
                        ButtonSegment(
                          value: _WarningFilter.open,
                          label: Text('Open'),
                        ),
                        ButtonSegment(
                          value: _WarningFilter.review,
                          label: Text('Review'),
                        ),
                        ButtonSegment(
                          value: _WarningFilter.closed,
                          label: Text('Closed'),
                        ),
                      ],
                      selected: <_WarningFilter>{_filter},
                      onSelectionChanged:
                          (selection) =>
                              setState(() => _filter = selection.first),
                    ),
                    const SizedBox(height: BafSpacing.lg),
                    if (visible.isEmpty)
                      const _EmptyState(
                        icon: Icons.fact_check_outlined,
                        title: 'No warnings in this view',
                      ),
                  ],
                );
              }

              final warning = visible[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: BafSpacing.md),
                child: _WarningCard(
                  warning: warning,
                  actor: actor,
                  busy: _submitting,
                  onRequestClosure: () => _requestWarningClosure(warning),
                  onDeclareRaRequired: () => _declareRaRequired(warning),
                  onRecordRaCompleted:
                      (linkedAbnormality) =>
                          _recordRaCompleted(warning, linkedAbnormality),
                  onClose:
                      (linkedAbnormality) =>
                          _closeWarning(warning, linkedAbnormality),
                  onReopen: () => _reopenWarning(warning),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMonitoring(AppUser? actor) {
    final requests = ref.watch(qualityMonitoringRequestsProvider);
    return requests.when(
      loading:
          () => const BafLoadingPanel(
            label: 'Loading cycle monitoring',
            color: BafColors.charges,
          ),
      error:
          (error, _) => _ErrorState(
            title: 'Monitoring requests unavailable',
            detail: '$error',
            onRetry: () => ref.invalidate(qualityMonitoringRequestsProvider),
          ),
      data:
          (items) => RefreshIndicator(
            onRefresh:
                () async => ref.invalidate(qualityMonitoringRequestsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BafSpacing.lg,
                BafSpacing.lg,
                BafSpacing.lg,
                BafSpacing.xl,
              ),
              children: [
                if (actor?.canManageQualityMonitoring == true)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _createMonitoringRequest,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New monitoring request'),
                    ),
                  ),
                const SizedBox(height: BafSpacing.lg),
                if (items.isEmpty)
                  const _EmptyState(
                    icon: Icons.monitor_heart_outlined,
                    title: 'No quality monitoring requests',
                  )
                else
                  for (final request in items) ...[
                    _MonitoringCard(
                      request: request,
                      canClose: actor?.canManageQualityMonitoring == true,
                      busy: _submitting,
                      onClose: () => _closeMonitoringRequest(request),
                    ),
                    const SizedBox(height: BafSpacing.md),
                  ],
              ],
            ),
          ),
    );
  }

  Future<void> _requestWarningClosure(QualityWarning warning) async {
    final reason = await _reasonDialog(
      title: 'Request warning closure',
      label: 'Operational evidence',
    );
    if (reason == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .requestWarningClosure(warning: warning, reason: reason),
    );
  }

  Future<void> _closeWarning(
    QualityWarning warning,
    ChargeAbnormality? linkedAbnormality,
  ) async {
    final decision = await showDialog<_WarningDecision>(
      context: context,
      builder:
          (context) => _CloseWarningDialog(
            warning: warning,
            linkedAbnormality: linkedAbnormality,
          ),
    );
    if (decision == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .closeWarning(
            warning: warning,
            disposition: decision.disposition,
            reason: decision.reason,
            linkedReannealingChargeNos: decision.raChargeNumbers,
          ),
    );
  }

  Future<void> _declareRaRequired(QualityWarning warning) async {
    final reason = await _reasonDialog(
      title: 'Declare re-annealing required',
      label: 'Decision evidence',
      initialValue: warning.warningReason,
    );
    if (reason == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .declareRaRequired(warning: warning, reason: reason),
    );
  }

  Future<void> _recordRaCompleted(
    QualityWarning warning,
    ChargeAbnormality abnormality,
  ) async {
    final completion = await showDialog<_RaCompletionInput>(
      context: context,
      builder:
          (context) => _RecordRaCompletionDialog(
            warning: warning,
            abnormality: abnormality,
          ),
    );
    if (completion == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .recordRaCompleted(
            warning: warning,
            reannealedToChargeNo: completion.newChargeNo,
            reason: completion.evidence,
          ),
    );
  }

  Future<void> _reopenWarning(QualityWarning warning) async {
    final reason = await _reasonDialog(
      title: 'Reopen quality warning',
      label: 'New evidence or correction reason',
    );
    if (reason == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .reopenWarning(warning: warning, reason: reason),
    );
  }

  Future<void> _createMonitoringRequest() async {
    final service = ref.read(qualityCommandServiceProvider);
    try {
      final pending = await service.pendingMonitoringCreation();
      if (!mounted) return;
      if (pending != null) {
        final retry = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Monitoring confirmation pending'),
                content: SingleChildScrollView(
                  child: Text(
                    'Base ${pending['baseNumber']}\n'
                    '${pending['grade']} - ${pending['cycleReference']}\n'
                    '${pending['reason']}\n\n'
                    'This submission has not been confirmed on this device.',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Later'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Retry confirmation'),
                  ),
                ],
              ),
        );
        if (retry == true && mounted) {
          await _runCommand(service.retryMonitoringCreation);
        }
        return;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    final request = await showDialog<_MonitoringInput>(
      context: context,
      builder: (context) => const _MonitoringRequestDialog(),
    );
    if (request == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .createMonitoringRequest(
            baseNumber: request.baseNumber,
            grade: request.grade,
            cycleReference: request.cycleReference,
            chargeNumbers: request.chargeNumbers,
            reason: request.reason,
          ),
    );
  }

  Future<void> _closeMonitoringRequest(QualityMonitoringRequest request) async {
    final reason = await _reasonDialog(
      title: 'Close monitoring request',
      label: 'Completion evidence',
    );
    if (reason == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .closeMonitoringRequest(request: request, reason: reason),
    );
  }

  Future<String?> _reasonDialog({
    required String title,
    required String label,
    String? initialValue,
  }) => showDialog<String>(
    context: context,
    builder:
        (context) => _ReasonDialog(
          title: title,
          label: label,
          initialValue: initialValue,
        ),
  );

  Future<void> _runCommand(
    Future<QualityCommandResult> Function() command,
  ) async {
    if (!mounted || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await command();
      var localReadbackApplied = true;
      try {
        localReadbackApplied = await _applyLinkedAbnormalityReadback(
          result.linkedAbnormality,
        );
        if (!localReadbackApplied && !kIsWeb) {
          final sync = await ref
              .read(syncCoordinatorProvider)
              .runFullSyncWithResult(
                reason: 'quality_command_readback',
                force: true,
              );
          if (sync == SyncRequestOutcome.succeeded) {
            localReadbackApplied = await _applyLinkedAbnormalityReadback(
              result.linkedAbnormality,
            );
          }
        }
      } catch (_) {
        localReadbackApplied = false;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            localReadbackApplied
                ? 'Quality record updated'
                : 'Updated in the cloud; this phone still needs a refresh sync.',
          ),
          backgroundColor:
              localReadbackApplied ? BafColors.sync : BafColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _applyLinkedAbnormalityReadback(
    ChargeAbnormality? remote,
  ) async {
    if (remote == null || kIsWeb) return true;
    final firestoreId = remote.firestoreId;
    if (firestoreId == null || firestoreId.trim().isEmpty) return false;
    final repository = ref.read(abnormalityRepositoryProvider);
    final accepted = await repository.applyAbnormalityCommandReadback(remote);
    if (!accepted) return false;
    final applied = await repository.getAbnormalityByFirestoreId(firestoreId);
    return applied != null &&
        applied.isSynced &&
        applied.version == remote.version &&
        applied.updatedAt.isAtSameMomentAs(remote.updatedAt) &&
        applied.isDeleted == remote.isDeleted &&
        applied.reannealingStatus == remote.reannealingStatus &&
        applied.reannealedToChargeNo == remote.reannealedToChargeNo;
  }
}

class _MonitoringRequestDialog extends StatefulWidget {
  const _MonitoringRequestDialog();

  @override
  State<_MonitoringRequestDialog> createState() =>
      _MonitoringRequestDialogState();
}

class _MonitoringRequestDialogState extends State<_MonitoringRequestDialog> {
  final _base = TextEditingController();
  final _grade = TextEditingController();
  final _cycle = TextEditingController();
  final _charges = TextEditingController();
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _base.dispose();
    _grade.dispose();
    _cycle.dispose();
    _charges.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New quality monitoring request'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _base,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Base number'),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _grade,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Grade'),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _cycle,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Cycle reference'),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _charges,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Charge numbers',
              hintText: 'Optional, comma separated',
            ),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            maxLength: 2000,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Monitoring reason'),
          ),
          if (_error != null) ...[
            const SizedBox(height: BafSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: BafColors.danger, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final base = int.tryParse(_base.text.trim());
          final grade = _grade.text.trim();
          final cycle = _cycle.text.trim();
          final reason = _reason.text.trim();
          final charges = _tryParsePositiveInts(_charges.text, maximum: 50);
          if (base == null ||
              base <= 0 ||
              grade.isEmpty ||
              cycle.isEmpty ||
              reason.isEmpty) {
            setState(
              () =>
                  _error =
                      'Enter a positive Base number, Grade, cycle and a reason.',
            );
            return;
          }
          if (charges == null) {
            setState(
              () => _error = 'Use up to 50 distinct five-digit charge numbers.',
            );
            return;
          }
          Navigator.pop(
            context,
            _MonitoringInput(
              baseNumber: base,
              grade: grade,
              cycleReference: cycle,
              chargeNumbers: charges,
              reason: reason,
            ),
          );
        },
        child: const Text('Create'),
      ),
    ],
  );
}

class _WarningDecision {
  const _WarningDecision({
    required this.disposition,
    required this.reason,
    required this.raChargeNumbers,
  });

  final QualityWarningClosureDisposition disposition;
  final String reason;
  final List<int> raChargeNumbers;
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    this.initialValue,
  });

  final String title;
  final String label;
  final String? initialValue;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLength: 2000,
      maxLines: 4,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label, errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isEmpty) {
            setState(() => _error = 'Enter a reason.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: const Text('Submit'),
      ),
    ],
  );
}

class _MonitoringInput {
  const _MonitoringInput({
    required this.baseNumber,
    required this.grade,
    required this.cycleReference,
    required this.chargeNumbers,
    required this.reason,
  });

  final int baseNumber;
  final String grade;
  final String cycleReference;
  final List<int> chargeNumbers;
  final String reason;
}

List<int>? _tryParsePositiveInts(String raw, {required int maximum}) {
  final cleaned = raw.trim();
  if (cleaned.isEmpty) return <int>[];
  final tokens = cleaned.split(RegExp(r'[,\s]+'));
  if (tokens.length > maximum) return null;
  final values = <int>[];
  for (final token in tokens) {
    final value = int.tryParse(token);
    if (value == null ||
        !isValidChargeNumber(value) ||
        values.contains(value)) {
      return null;
    }
    values.add(value);
  }
  values.sort();
  return values;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(icon, size: 44, color: BafColors.textSecondary),
        const SizedBox(height: BafSpacing.md),
        Text(
          title,
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _WindowScopeNotice extends StatelessWidget {
  const _WindowScopeNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(
        Icons.history_rounded,
        size: 16,
        color: BafColors.textSecondary,
      ),
      const SizedBox(width: BafSpacing.xs),
      Expanded(
        child: Text(
          text,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: BafColors.danger),
          const SizedBox(height: BafSpacing.md),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: BafSpacing.xs),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
          const SizedBox(height: BafSpacing.md),
          IconButton(
            onPressed: onRetry,
            tooltip: 'Retry',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    ),
  );
}
