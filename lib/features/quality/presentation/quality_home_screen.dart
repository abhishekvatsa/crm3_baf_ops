import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/quality_warning.dart';
import '../providers/quality_provider.dart';

enum _WarningFilter { open, review, closed }

class QualityHomeScreen extends ConsumerStatefulWidget {
  const QualityHomeScreen({super.key});

  @override
  ConsumerState<QualityHomeScreen> createState() => _QualityHomeScreenState();
}

class _QualityHomeScreenState extends ConsumerState<QualityHomeScreen> {
  _WarningFilter _filter = _WarningFilter.open;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(currentAppUserProvider).value;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Quality',
            subtitle: 'Warnings, disposition and cycle monitoring',
            icon: Icons.verified_user_outlined,
            accent: BafColors.charges,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Warnings'),
              Tab(icon: Icon(Icons.monitor_heart_outlined), text: 'Monitoring'),
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
      loading: () => const Center(child: CircularProgressIndicator()),
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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.lg,
              BafSpacing.xl,
            ),
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
                    (selection) => setState(() => _filter = selection.first),
              ),
              const SizedBox(height: BafSpacing.lg),
              if (visible.isEmpty)
                const _EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No warnings in this view',
                )
              else
                for (final warning in visible) ...[
                  _WarningCard(
                    warning: warning,
                    actor: actor,
                    busy: _submitting,
                    onRequestClosure: () => _requestWarningClosure(warning),
                    onClose: () => _closeWarning(warning),
                    onReopen: () => _reopenWarning(warning),
                  ),
                  const SizedBox(height: BafSpacing.md),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonitoring(AppUser? actor) {
    final requests = ref.watch(qualityMonitoringRequestsProvider);
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
                if (items.length == qualityMonitoringLiveWindowLimit) ...[
                  const SizedBox(height: BafSpacing.sm),
                  const _WindowScopeNotice(
                    text: 'Showing the 250 most recently updated requests',
                  ),
                ],
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

  Future<void> _closeWarning(QualityWarning warning) async {
    final decision = await showDialog<_WarningDecision>(
      context: context,
      builder: (context) => const _CloseWarningDialog(),
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
  }) => showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(title: title, label: label),
  );

  Future<void> _runCommand(Future<Object> Function() command) async {
    setState(() => _submitting = true);
    try {
      await command();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quality record updated'),
          backgroundColor: BafColors.sync,
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
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.open,
    required this.review,
    required this.closed,
  });

  final int open;
  final int review;
  final int closed;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _SummaryMetric(label: 'Open', value: open)),
      const SizedBox(width: BafSpacing.sm),
      Expanded(child: _SummaryMetric(label: 'Review', value: review)),
      const SizedBox(width: BafSpacing.sm),
      Expanded(child: _SummaryMetric(label: 'Closed', value: closed)),
    ],
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: BafSpacing.md,
      vertical: BafSpacing.md,
    ),
    decoration: BoxDecoration(
      color: BafColors.card,
      border: Border.all(color: BafColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: BafColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: BafColors.textSecondary),
        ),
      ],
    ),
  );
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.warning,
    required this.actor,
    required this.busy,
    required this.onRequestClosure,
    required this.onClose,
    required this.onReopen,
  });

  final QualityWarning warning;
  final AppUser? actor;
  final bool busy;
  final VoidCallback onRequestClosure;
  final VoidCallback onClose;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: BafColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: BafColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _statusIcon(warning.status),
                color: _statusColor(warning.status),
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  'Charge ${warning.sourceChargeNo}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: BafColors.textPrimary,
                  ),
                ),
              ),
              _StatusLabel(status: warning.status),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            warning.sourceSummary,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: BafColors.textPrimary,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            warning.warningReason,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.xs,
            children: [
              _Fact(
                icon: Icons.precision_manufacturing_outlined,
                text:
                    warning.affectedAssets.isEmpty
                        ? 'No asset recorded'
                        : warning.affectedAssets
                            .map((asset) => asset.label)
                            .join(', '),
              ),
              if (warning.component != null)
                _Fact(icon: Icons.settings_outlined, text: warning.component!),
              _Fact(
                icon: Icons.schedule_outlined,
                text: DateFormat(
                  'dd MMM yyyy, HH:mm',
                ).format(warning.createdAt),
              ),
            ],
          ),
          if (warning.closureRequestReason != null) ...[
            const SizedBox(height: BafSpacing.md),
            Text(
              'Closure request: ${warning.closureRequestReason}',
              style: const TextStyle(
                color: BafColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (warning.status == QualityWarningStatus.closed) ...[
            const SizedBox(height: BafSpacing.md),
            Text(
              _closureLabel(warning),
              style: const TextStyle(
                color: BafColors.sync,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              if (warning.status == QualityWarningStatus.open &&
                  actor?.canRequestQualityWarningClosure == true)
                OutlinedButton.icon(
                  onPressed: busy ? null : onRequestClosure,
                  icon: const Icon(Icons.forward_to_inbox_outlined),
                  label: const Text('Request closure'),
                ),
              if (warning.status != QualityWarningStatus.closed &&
                  actor?.canCloseQualityWarning == true)
                FilledButton.icon(
                  onPressed: busy ? null : onClose,
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Adjudicate'),
                ),
              if (warning.status == QualityWarningStatus.closed &&
                  actor?.canCloseQualityWarning == true)
                OutlinedButton.icon(
                  onPressed: busy ? null : onReopen,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Reopen'),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  static IconData _statusIcon(QualityWarningStatus status) => switch (status) {
    QualityWarningStatus.open => Icons.warning_amber_rounded,
    QualityWarningStatus.closureRequested => Icons.hourglass_top_rounded,
    QualityWarningStatus.closed => Icons.verified_rounded,
  };

  static Color _statusColor(QualityWarningStatus status) => switch (status) {
    QualityWarningStatus.open => BafColors.danger,
    QualityWarningStatus.closureRequested => BafColors.warning,
    QualityWarningStatus.closed => BafColors.sync,
  };

  static String _closureLabel(QualityWarning warning) {
    final disposition = warning.closureDisposition;
    final label = switch (disposition) {
      QualityWarningClosureDisposition.coilFoundAcceptable =>
        'Coil found acceptable',
      QualityWarningClosureDisposition.reannealingCompleted =>
        'Closed after re-annealing',
      QualityWarningClosureDisposition.qualityAdjudication =>
        'Closed by quality adjudication',
      null => 'Closed',
    };
    final ra = warning.linkedReannealingChargeNos;
    return ra.isEmpty ? label : '$label · RA ${ra.join(', ')}';
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});

  final QualityWarningStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      QualityWarningStatus.open => 'Open',
      QualityWarningStatus.closureRequested => 'Review',
      QualityWarningStatus.closed => 'Closed',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _WarningCard._statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _WarningCard._statusColor(status),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: BafColors.textSecondary),
      const SizedBox(width: 4),
      Text(
        text,
        style: const TextStyle(fontSize: 12, color: BafColors.textSecondary),
      ),
    ],
  );
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({
    required this.request,
    required this.canClose,
    required this.busy,
    required this.onClose,
  });

  final QualityMonitoringRequest request;
  final bool canClose;
  final bool busy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: BafColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                color: BafColors.charges,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Text(
                  'Base ${request.baseNumber} · ${request.grade}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: BafColors.textPrimary,
                  ),
                ),
              ),
              Text(
                request.status == QualityMonitoringStatus.active
                    ? 'Active'
                    : 'Closed',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color:
                      request.status == QualityMonitoringStatus.active
                          ? BafColors.warning
                          : BafColors.sync,
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.sm),
          Text(
            request.cycleReference,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: BafColors.textPrimary,
            ),
          ),
          const SizedBox(height: BafSpacing.xs),
          Text(
            request.reason,
            style: const TextStyle(color: BafColors.textSecondary),
          ),
          if (request.chargeNumbers.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.sm),
            Text(
              'Charges: ${request.chargeNumbers.join(', ')}',
              style: const TextStyle(color: BafColors.textSecondary),
            ),
          ],
          if (request.status == QualityMonitoringStatus.active && canClose) ...[
            const SizedBox(height: BafSpacing.md),
            OutlinedButton.icon(
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Complete monitoring'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _CloseWarningDialog extends StatefulWidget {
  const _CloseWarningDialog();

  @override
  State<_CloseWarningDialog> createState() => _CloseWarningDialogState();
}

class _CloseWarningDialogState extends State<_CloseWarningDialog> {
  QualityWarningClosureDisposition _disposition =
      QualityWarningClosureDisposition.coilFoundAcceptable;
  final _reason = TextEditingController();
  final _raCharges = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _raCharges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adjudicate quality warning'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<QualityWarningClosureDisposition>(
            initialValue: _disposition,
            decoration: const InputDecoration(labelText: 'Disposition'),
            items: const [
              DropdownMenuItem(
                value: QualityWarningClosureDisposition.coilFoundAcceptable,
                child: Text('Coil found acceptable'),
              ),
              DropdownMenuItem(
                value: QualityWarningClosureDisposition.reannealingCompleted,
                child: Text('Re-annealing completed'),
              ),
              DropdownMenuItem(
                value: QualityWarningClosureDisposition.qualityAdjudication,
                child: Text('Quality adjudication'),
              ),
            ],
            onChanged: (value) => setState(() => _disposition = value!),
          ),
          if (_disposition ==
              QualityWarningClosureDisposition.reannealingCompleted) ...[
            const SizedBox(height: BafSpacing.md),
            TextField(
              controller: _raCharges,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'RA charge numbers',
                hintText: '13001, 13002',
              ),
            ),
          ],
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _reason,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Decision evidence'),
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
          final reason = _reason.text.trim();
          final charges = _tryParsePositiveInts(_raCharges.text, maximum: 20);
          if (reason.length < 8) {
            setState(
              () => _error = 'Decision evidence needs at least 8 characters.',
            );
            return;
          }
          if (charges == null) {
            setState(
              () => _error = 'Use up to 20 distinct positive charge numbers.',
            );
            return;
          }
          if (_disposition ==
                  QualityWarningClosureDisposition.reannealingCompleted &&
              charges.isEmpty) {
            setState(
              () => _error = 'At least one RA charge number is required.',
            );
            return;
          }
          if (_disposition !=
                  QualityWarningClosureDisposition.reannealingCompleted &&
              charges.isNotEmpty) {
            setState(
              () => _error = 'RA charges apply only to re-annealing closure.',
            );
            return;
          }
          Navigator.pop(
            context,
            _WarningDecision(
              disposition: _disposition,
              reason: reason,
              raChargeNumbers: charges,
            ),
          );
        },
        child: const Text('Close warning'),
      ),
    ],
  );
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
            decoration: const InputDecoration(labelText: 'Grade'),
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _cycle,
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
              reason.length < 8) {
            setState(
              () =>
                  _error =
                      'Enter a positive Base number, Grade, cycle and a reason of at least 8 characters.',
            );
            return;
          }
          if (charges == null) {
            setState(
              () => _error = 'Use up to 50 distinct positive charge numbers.',
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
  const _ReasonDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

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
          if (value.length < 8) {
            setState(() => _error = 'Enter at least 8 characters.');
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
    if (value == null || value <= 0 || values.contains(value)) return null;
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
