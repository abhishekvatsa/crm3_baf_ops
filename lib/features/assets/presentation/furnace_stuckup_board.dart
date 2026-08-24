import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/domain/furnace_stuckup_case.dart';
import '../../maintenance_workflow/domain/workflow_types.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../../maintenance_workflow/services/workflow_command_factory.dart';
import '../data/furnace_stuckup_record.dart';
import '../providers/furnace_stuckup_provider.dart';

enum _CaseView { active, pendingCause, history }

class FurnaceStuckupBoard extends ConsumerStatefulWidget {
  const FurnaceStuckupBoard({super.key});

  @override
  ConsumerState<FurnaceStuckupBoard> createState() =>
      _FurnaceStuckupBoardState();
}

class _FurnaceStuckupBoardState extends ConsumerState<FurnaceStuckupBoard> {
  _CaseView _view = _CaseView.active;
  String? _busyCaseId;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Furnace stuck-up',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.vertical_align_top_rounded,
        accent: BafColors.warning,
        label: 'Checking Furnace stuck-up access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Furnace stuck-up',
        appBarSubtitle: 'Verifying your approved asset scope',
        appBarIcon: Icons.vertical_align_top_rounded,
        accent: BafColors.warning,
        message: 'Furnace stuck-up access could not be verified.',
      );
    }
    final user = actorAsync.value;
    if (user == null || !user.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Furnace stuck-up',
        appBarSubtitle: 'Assembly availability and confirmed causes',
        appBarIcon: Icons.vertical_align_top_rounded,
        accent: BafColors.warning,
        title: 'Furnace stuck-up access required',
        message: 'An approved account is required to view stuck-up cases.',
      );
    }
    final cases = ref.watch(furnaceStuckupCasesProvider);
    final declarations = ref.watch(assetConditionDeclarationsProvider);
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Furnace stuck-up',
          subtitle: 'Assembly availability and confirmed causes',
          icon: Icons.vertical_align_top_rounded,
          accent: BafColors.warning,
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: cases.when(
              loading:
                  () => const BafLoadingPanel(
                    label: 'Loading Furnace stuck-up cases',
                    color: BafColors.warning,
                  ),
              error:
                  (error, _) => _LoadFailure(
                    onRetry: () {
                      ref.invalidate(furnaceStuckupCasesProvider);
                      ref.invalidate(assetConditionDeclarationsProvider);
                    },
                  ),
              data:
                  (records) => _buildBody(
                    user: user,
                    records: records,
                    declarations:
                        declarations.value ??
                        const <AssetConditionDeclarationRecord>[],
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required AppUser? user,
    required List<FurnaceStuckupRecord> records,
    required List<AssetConditionDeclarationRecord> declarations,
  }) {
    final active = records.where((record) => record.isActive).length;
    final pending = records.where((record) => record.needsAdjudication).length;
    final visible = records
        .where((record) {
          return switch (_view) {
            _CaseView.active => record.isActive,
            _CaseView.pendingCause => record.needsAdjudication,
            _CaseView.history => !record.isActive && !record.needsAdjudication,
          };
        })
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(furnaceStuckupCasesProvider);
        ref.invalidate(assetConditionDeclarationsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.md,
          BafSpacing.md,
          BafSpacing.md,
          BafSpacing.xl,
        ),
        children: [
          _StatusBand(
            active: active,
            pending: pending,
            confirmedBulged: declarations.length,
          ),
          const SizedBox(height: BafSpacing.lg),
          SegmentedButton<_CaseView>(
            segments: <ButtonSegment<_CaseView>>[
              ButtonSegment(
                value: _CaseView.active,
                icon: const Icon(Icons.link_off_rounded),
                label: Text('Active $active'),
              ),
              ButtonSegment(
                value: _CaseView.pendingCause,
                icon: const Icon(Icons.fact_check_outlined),
                label: Text('Cause $pending'),
              ),
              const ButtonSegment(
                value: _CaseView.history,
                icon: Icon(Icons.history_rounded),
                label: Text('History'),
              ),
            ],
            selected: <_CaseView>{_view},
            onSelectionChanged:
                (selection) => setState(() => _view = selection.first),
          ),
          const SizedBox(height: BafSpacing.lg),
          if (visible.isEmpty)
            _EmptyCases(view: _view)
          else
            for (final record in visible) ...[
              _StuckupCaseCard(
                record: record,
                busy: _busyCaseId == record.id,
                canRelease:
                    record.isActive &&
                    (user?.canReleaseFurnaceStuckup ?? false),
                canAdjudicate:
                    record.needsAdjudication &&
                    (user?.canAdjudicateFurnaceStuckup ?? false),
                onRelease: () => _release(record),
                onAdjudicate: () => _adjudicate(record),
              ),
              const SizedBox(height: BafSpacing.md),
            ],
          if (declarations.isNotEmpty) ...[
            const SizedBox(height: BafSpacing.lg),
            const Text(
              'Confirmed Inner Cover conditions',
              style: TextStyle(
                color: BafColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: BafSpacing.sm),
            for (final declaration in declarations)
              _ConditionDeclarationTile(declaration: declaration),
          ],
        ],
      ),
    );
  }

  Future<void> _release(FurnaceStuckupRecord record) async {
    final notes = await _showNotesDialog(
      title: 'Release physical obstruction',
      message:
          'Confirm that the Furnace has been separated from Base ${record.baseAssetNumber}. This clears only the stuck-up availability block; the maintenance issue remains accountable.',
      actionLabel: 'Release',
    );
    if (!mounted || notes == null) return;
    await _execute(
      record,
      type: WorkflowCommandType.releaseFurnaceStuckup,
      payload: <String, Object?>{'releaseNotes': notes},
      success: 'Physical obstruction released.',
    );
  }

  Future<void> _adjudicate(FurnaceStuckupRecord record) async {
    final input = await showDialog<_AdjudicationInput>(
      context: context,
      builder: (context) => _AdjudicationDialog(record: record),
    );
    if (!mounted || input == null) return;
    await _execute(
      record,
      type: WorkflowCommandType.adjudicateFurnaceStuckup,
      payload: <String, Object?>{
        'confirmedCause': input.cause.name,
        'adjudicationNotes': input.notes,
      },
      success:
          input.cause == FurnaceStuckupCause.inconclusive
              ? 'Cause recorded as inconclusive.'
              : 'Cause confirmed with governed evidence.',
    );
  }

  Future<void> _execute(
    FurnaceStuckupRecord record, {
    required WorkflowCommandType type,
    required Map<String, Object?> payload,
    required String success,
  }) async {
    if (_busyCaseId != null) return;
    setState(() => _busyCaseId = record.id);
    try {
      final command = WorkflowCommandFactory.create(
        type: type,
        aggregateId: record.id,
        expectedVersion: record.version,
        payload: payload,
      );
      await ref
          .read(workflowCommandControllerProvider.notifier)
          .execute(command);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: BafColors.success),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('The governed action could not be completed: $error'),
          backgroundColor: BafColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyCaseId = null);
    }
  }

  Future<String?> _showNotesDialog({
    required String title,
    required String message,
    required String actionLabel,
  }) => showDialog<String>(
    context: context,
    builder:
        (_) => _FurnaceStuckupNotesDialog(
          title: title,
          message: message,
          actionLabel: actionLabel,
        ),
  );
}

class _FurnaceStuckupNotesDialog extends StatefulWidget {
  const _FurnaceStuckupNotesDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
  });

  final String title;
  final String message;
  final String actionLabel;

  @override
  State<_FurnaceStuckupNotesDialog> createState() =>
      _FurnaceStuckupNotesDialogState();
}

class _FurnaceStuckupNotesDialogState
    extends State<_FurnaceStuckupNotesDialog> {
  final _notesController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.message),
        const SizedBox(height: BafSpacing.md),
        TextField(
          controller: _notesController,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Release evidence',
            hintText: 'What was physically verified?',
            errorText: _error,
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
    ],
  );

  void _submit() {
    final notes = _notesController.text.trim();
    if (notes.length < 8 || notes.length > 1000) {
      setState(() => _error = 'Enter 8-1,000 characters of verified evidence.');
      return;
    }
    Navigator.pop(context, notes);
  }
}

class _StatusBand extends StatelessWidget {
  const _StatusBand({
    required this.active,
    required this.pending,
    required this.confirmedBulged,
  });

  final int active;
  final int pending;
  final int confirmedBulged;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(BafSpacing.lg),
    decoration: BoxDecoration(
      color: BafColors.navy,
      borderRadius: BorderRadius.circular(BafRadius.medium),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assembly integrity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: BafSpacing.md),
        Row(
          children: [
            Expanded(child: _BandMetric(value: active, label: 'Blocked')),
            Expanded(
              child: _BandMetric(value: pending, label: 'Cause pending'),
            ),
            Expanded(
              child: _BandMetric(value: confirmedBulged, label: 'Bulged ICs'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _BandMetric extends StatelessWidget {
  const _BandMetric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(
          color: BafColors.instrument,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _StuckupCaseCard extends StatelessWidget {
  const _StuckupCaseCard({
    required this.record,
    required this.busy,
    required this.canRelease,
    required this.canAdjudicate,
    required this.onRelease,
    required this.onAdjudicate,
  });

  final FurnaceStuckupRecord record;
  final bool busy;
  final bool canRelease;
  final bool canAdjudicate;
  final VoidCallback onRelease;
  final VoidCallback onAdjudicate;

  @override
  Widget build(BuildContext context) {
    final obstructionColor =
        record.isActive ? BafColors.danger : BafColors.success;
    final date = DateFormat('dd MMM yyyy, HH:mm').format(record.reportedAt);
    return Container(
      padding: const EdgeInsets.all(BafSpacing.lg),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: BafColors.border),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: obstructionColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(BafRadius.small),
                ),
                child: Icon(
                  record.isActive
                      ? Icons.link_off_rounded
                      : Icons.check_circle_outline_rounded,
                  color: obstructionColor,
                ),
              ),
              const SizedBox(width: BafSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Furnace ${record.furnaceAssetNumber.toString().padLeft(2, '0')} on Base ${record.baseAssetNumber}',
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Inner Cover ${record.innerCoverSerialNumber} · Charge ${record.chargeNoAtEvent ?? 'not recorded'}',
                      style: const TextStyle(color: BafColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          Wrap(
            spacing: BafSpacing.sm,
            runSpacing: BafSpacing.sm,
            children: [
              _StatePill(
                label: record.isActive ? 'Temporarily blocked' : 'Released',
                color: obstructionColor,
              ),
              _StatePill(
                label: switch (record.adjudicationStatus) {
                  FurnaceStuckupAdjudicationStatus.pending => 'Cause pending',
                  FurnaceStuckupAdjudicationStatus.confirmed =>
                    'Cause confirmed',
                  FurnaceStuckupAdjudicationStatus.inconclusive =>
                    'Inconclusive',
                },
                color:
                    record.needsAdjudication
                        ? BafColors.warning
                        : BafColors.audit,
              ),
            ],
          ),
          const SizedBox(height: BafSpacing.md),
          _DetailLine(
            icon: Icons.search_rounded,
            text:
                'Initial suspicion: ${record.suspectedCause.label}${record.confirmedCause == null ? '' : ' · Confirmed: ${record.confirmedCause!.label}'}',
          ),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text: '$date · ${record.operatingContext.label}',
          ),
          _DetailLine(
            icon: Icons.person_outline_rounded,
            text: 'Reported by ${record.reportedByName}',
          ),
          if (record.releaseNotes != null)
            _DetailLine(
              icon: Icons.lock_open_rounded,
              text: record.releaseNotes!,
            ),
          if (record.adjudicationNotes != null)
            _DetailLine(
              icon: Icons.fact_check_outlined,
              text: record.adjudicationNotes!,
            ),
          if (canRelease || canAdjudicate) ...[
            const Divider(height: BafSpacing.xl),
            Wrap(
              spacing: BafSpacing.sm,
              runSpacing: BafSpacing.sm,
              children: [
                if (canRelease)
                  FilledButton.icon(
                    onPressed: busy ? null : onRelease,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Release obstruction'),
                  ),
                if (canAdjudicate)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onAdjudicate,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Adjudicate cause'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(BafRadius.small),
      border: Border.all(color: color.withValues(alpha: 0.24)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BafSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: BafColors.textSecondary),
        const SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: BafColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConditionDeclarationTile extends StatelessWidget {
  const _ConditionDeclarationTile({required this.declaration});
  final AssetConditionDeclarationRecord declaration;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BafColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(BafRadius.small),
      ),
      child: const Icon(Icons.warning_amber_rounded, color: BafColors.warning),
    ),
    title: Text(
      'Inner Cover ${declaration.assetSerialNumber} · Bulged',
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
    subtitle: Text(
      '${declaration.evidenceCount} confirmed stuck-up ${declaration.evidenceCount == 1 ? 'case' : 'cases'}',
    ),
  );
}

class _AdjudicationInput {
  const _AdjudicationInput({required this.cause, required this.notes});
  final FurnaceStuckupCause cause;
  final String notes;
}

class _AdjudicationDialog extends StatefulWidget {
  const _AdjudicationDialog({required this.record});
  final FurnaceStuckupRecord record;
  @override
  State<_AdjudicationDialog> createState() => _AdjudicationDialogState();
}

class _AdjudicationDialogState extends State<_AdjudicationDialog> {
  late FurnaceStuckupCause _cause;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cause =
        widget.record.suspectedCause == FurnaceStuckupCause.unknown
            ? FurnaceStuckupCause.inconclusive
            : widget.record.suspectedCause;
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adjudicate stuck-up cause'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Furnace ${widget.record.furnaceAssetNumber} · Base ${widget.record.baseAssetNumber} · IC ${widget.record.innerCoverSerialNumber}',
          ),
          const SizedBox(height: BafSpacing.md),
          DropdownButtonFormField<FurnaceStuckupCause>(
            initialValue: _cause,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Adjudicated cause'),
            items: [
              for (final value in FurnaceStuckupCause.values)
                if (value != FurnaceStuckupCause.unknown)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.label, overflow: TextOverflow.ellipsis),
                  ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _cause = value);
            },
          ),
          const SizedBox(height: BafSpacing.md),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Inspection evidence',
              hintText: 'What was inspected and confirmed?',
              alignLabelWithHint: true,
            ),
          ),
          if (_cause == FurnaceStuckupCause.innerCoverBulging ||
              _cause == FurnaceStuckupCause.combinedCondition) ...[
            const SizedBox(height: BafSpacing.md),
            const Text(
              'This will create or extend a persistent Bulged declaration for the Inner Cover serial. It does not retire the cover.',
              style: TextStyle(
                color: BafColors.warning,
                fontWeight: FontWeight.w700,
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
          final notes = _notes.text.trim();
          if (notes.length >= 8 && notes.length <= 2000) {
            Navigator.pop(
              context,
              _AdjudicationInput(cause: _cause, notes: notes),
            );
          }
        },
        child: const Text('Record decision'),
      ),
    ],
  );
}

class _EmptyCases extends StatelessWidget {
  const _EmptyCases({required this.view});
  final _CaseView view;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 56),
    child: Column(
      children: [
        const Icon(Icons.task_alt_rounded, size: 44, color: BafColors.success),
        const SizedBox(height: BafSpacing.md),
        Text(
          switch (view) {
            _CaseView.active =>
              'No Furnace is currently blocked by a stuck-up.',
            _CaseView.pendingCause =>
              'No stuck-up cause is awaiting adjudication.',
            _CaseView.history =>
              'No completed stuck-up history is available yet.',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(color: BafColors.textSecondary),
        ),
      ],
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(BafSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            size: 42,
            color: BafColors.danger,
          ),
          const SizedBox(height: BafSpacing.md),
          const Text('Stuck-up evidence could not be loaded.'),
          const SizedBox(height: BafSpacing.md),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
