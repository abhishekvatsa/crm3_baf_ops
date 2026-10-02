import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/services/sync_coordinator.dart';
import '../../../core/validation/charge_number.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/incremental_list_footer.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../admin/presentation/saved_submission_review_screen.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/presentation/current_actor_gate.dart';
import '../../auth/providers/auth_provider.dart';
import '../../abnormalities/data/abnormality_model.dart';
import '../../abnormalities/presentation/ra_performed_at_field.dart';
import '../../abnormalities/providers/abnormality_provider.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../data/quality_warning.dart';
import '../providers/quality_provider.dart';
import '../services/quality_command_service.dart';

part 'quality_home_screen.widgets.dart';
part 'quality_home_screen.cards.dart';
part 'quality_home_screen.dialogs.dart';

enum _WarningFilter { open, all, review, closed }

enum _MonitoringFilter { open, all, closed, cancelled }

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
  _MonitoringFilter _monitoringFilter = _MonitoringFilter.open;
  int _warningVisibleLimit = businessListPageSize;
  int _monitoringVisibleLimit = businessListPageSize;
  bool _submitting = false;

  void _selectWarningFilter(_WarningFilter filter) => setState(() {
    _filter = filter;
    _warningVisibleLimit = businessListPageSize;
  });

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
      data: (items) => monitoringPopulationIsQualified(items)
          ? items
                .where(
                  (request) => request.status == QualityMonitoringStatus.active,
                )
                .length
          : null,
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
            isScrollable: MediaQuery.textScalerOf(context).scale(14) > 18,
            tabAlignment: MediaQuery.textScalerOf(context).scale(14) > 18
                ? TabAlignment.start
                : null,
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
      loading: () => const BafLoadingPanel(
        label: 'Loading quality warnings',
        color: BafColors.charges,
      ),
      error: (error, _) => _ErrorState(
        title: 'Quality warnings unavailable',
        detail: '$error',
        onRetry: () => ref.invalidate(qualityWarningsProvider),
      ),
      data: (items) {
        final open = items.where((warning) => warning.isOpen).length;
        final review = items
            .where(
              (warning) =>
                  warning.status == QualityWarningStatus.closureRequested,
            )
            .length;
        final closed = items
            .where((warning) => warning.status == QualityWarningStatus.closed)
            .length;
        final filtered =
            items
                .where(
                  (warning) => switch (_filter) {
                    _WarningFilter.all => true,
                    _WarningFilter.open => warning.isOpen,
                    _WarningFilter.review =>
                      warning.status == QualityWarningStatus.closureRequested,
                    _WarningFilter.closed =>
                      warning.status == QualityWarningStatus.closed,
                  },
                )
                .toList()
              ..sort((left, right) {
                final status = left.status.index.compareTo(right.status.index);
                if (status != 0) return status;
                final date = right.updatedAt.compareTo(left.updatedAt);
                return date != 0
                    ? date
                    : left.warningId.compareTo(right.warningId);
              });
        final visible = filtered.take(_warningVisibleLimit).toList();

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
            key: const ValueKey('quality-warnings-list'),
            itemCount: visible.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryStrip(
                      open: open,
                      review: review,
                      closed: closed,
                      selected: _filter,
                      onSelected: _selectWarningFilter,
                    ),
                    if (review > 0) ...[
                      const SizedBox(height: BafSpacing.xs),
                      const Text(
                        'Open includes warnings awaiting review.',
                        style: TextStyle(color: BafColors.textSecondary),
                      ),
                    ],
                    if (items.length >= qualityWarningLiveWindowLimit) ...[
                      const SizedBox(height: BafSpacing.sm),
                      const _WindowScopeNotice(
                        text:
                            'Available: all open/review warnings and up to 500 recent warnings',
                      ),
                    ],
                    const SizedBox(height: BafSpacing.lg),
                    _QualityStatusFilter<_WarningFilter>(
                      key: const ValueKey('quality-warning-status-filter'),
                      segments: const [
                        ButtonSegment(
                          value: _WarningFilter.open,
                          label: Text('Open'),
                        ),
                        ButtonSegment(
                          value: _WarningFilter.all,
                          label: Text('All'),
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
                      onSelectionChanged: (selection) =>
                          _selectWarningFilter(selection.first),
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

              if (index == visible.length + 1) {
                return IncrementalListFooter(
                  visibleCount: visible.length,
                  totalCount: filtered.length,
                  onShowMore: () => setState(
                    () => _warningVisibleLimit += businessListPageSize,
                  ),
                );
              }

              final warning = visible[index - 1];
              return Padding(
                key: ValueKey('quality-warning-${warning.warningId}'),
                padding: const EdgeInsets.only(bottom: BafSpacing.md),
                child: _WarningCard(
                  warning: warning,
                  actor: actor,
                  busy: _submitting,
                  onRequestClosure: () => _requestWarningClosure(warning),
                  onDeclareRaRequired: () => _declareRaRequired(warning),
                  onRecordRaCompleted: (linkedAbnormality) =>
                      _recordRaCompleted(warning, linkedAbnormality),
                  onClose: (linkedAbnormality) =>
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
    return Column(
      children: [
        if (!kIsWeb && actor?.canManageQualityMonitoring == true)
          Padding(
            padding: const EdgeInsets.all(BafSpacing.lg),
            child: Wrap(
              spacing: BafSpacing.md,
              runSpacing: BafSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: _submitting ? null : _createMonitoringRequest,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New monitoring request'),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => _createMonitoringRequest(savedOnly: true),
                  child: const Text('Check saved monitoring'),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SavedSubmissionReviewScreen(),
                          ),
                        ),
                  child: const Text('Review saved submissions'),
                ),
              ],
            ),
          ),
        Expanded(
          child: requests.when(
            loading: () => const BafLoadingPanel(
              label: 'Loading cycle monitoring',
              color: BafColors.charges,
            ),
            error: (error, _) => _ErrorState(
              title: 'Monitoring requests unavailable',
              detail: '$error',
              onRetry: () => ref.invalidate(qualityMonitoringRequestsProvider),
            ),
            data: (items) {
              final filtered =
                  items
                      .where(
                        (request) => switch (_monitoringFilter) {
                          _MonitoringFilter.open =>
                            request.status == QualityMonitoringStatus.active,
                          _MonitoringFilter.all => true,
                          _MonitoringFilter.closed =>
                            request.status == QualityMonitoringStatus.closed &&
                                !request.isCancelled,
                          _MonitoringFilter.cancelled => request.isCancelled,
                        },
                      )
                      .toList()
                    ..sort((left, right) {
                      final status = left.status.index.compareTo(
                        right.status.index,
                      );
                      if (status != 0) return status;
                      final date = right.createdAt.compareTo(left.createdAt);
                      return date != 0
                          ? date
                          : left.requestId.compareTo(right.requestId);
                    });
              final visible = filtered.take(_monitoringVisibleLimit).toList();
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(qualityMonitoringRequestsProvider),
                child: ListView(
                  key: const ValueKey('quality-monitoring-list'),
                  padding: const EdgeInsets.fromLTRB(
                    BafSpacing.lg,
                    BafSpacing.lg,
                    BafSpacing.lg,
                    BafSpacing.xl,
                  ),
                  children: [
                    _QualityStatusFilter<_MonitoringFilter>(
                      key: const ValueKey('quality-monitoring-status-filter'),
                      segments: const [
                        ButtonSegment(
                          value: _MonitoringFilter.open,
                          label: Text('Open'),
                        ),
                        ButtonSegment(
                          value: _MonitoringFilter.all,
                          label: Text('All'),
                        ),
                        ButtonSegment(
                          value: _MonitoringFilter.closed,
                          label: Text('Closed'),
                        ),
                        ButtonSegment(
                          value: _MonitoringFilter.cancelled,
                          label: Text('Cancelled'),
                        ),
                      ],
                      selected: {_monitoringFilter},
                      onSelectionChanged: (selection) => setState(() {
                        _monitoringFilter = selection.first;
                        _monitoringVisibleLimit = businessListPageSize;
                      }),
                    ),
                    const SizedBox(height: BafSpacing.md),
                    if (!monitoringPopulationIsQualified(items))
                      const Padding(
                        padding: EdgeInsets.only(bottom: BafSpacing.md),
                        child: Text(
                          'Monitoring evidence is incomplete or not server-confirmed. Valid records remain visible; totals are unverified.',
                        ),
                      ),
                    if (kIsWeb)
                      const Text(
                        'Use the Android app to create or change monitoring with saved recovery support.',
                      ),
                    if (filtered.isEmpty &&
                        monitoringPopulationIsQualified(items))
                      const _EmptyState(
                        icon: Icons.monitor_heart_outlined,
                        title: 'No monitoring requests in this view',
                      )
                    else
                      for (final request in visible) ...[
                        _MonitoringCard(
                          key: ValueKey(
                            'quality-monitoring-${request.requestId}',
                          ),
                          request: request,
                          canClose:
                              !kIsWeb &&
                              actor?.canManageQualityMonitoring == true,
                          busy: _submitting,
                          onClose: () => _closeMonitoringRequest(request),
                          onCorrect: () => _reviewMonitoring(request, false),
                          onCancel: () => _reviewMonitoring(request, true),
                          canCheckSaved: !kIsWeb && actor?.isApproved == true,
                          onCheckSaved: () => _runCommand(
                            () => ref
                                .read(qualityCommandServiceProvider)
                                .checkSavedMonitoringChange(request.requestId),
                          ),
                        ),
                        const SizedBox(height: BafSpacing.md),
                      ],
                    IncrementalListFooter(
                      visibleCount: visible.length,
                      totalCount: filtered.length,
                      onShowMore: () => setState(
                        () => _monitoringVisibleLimit += businessListPageSize,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
      builder: (context) => _CloseWarningDialog(
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
            raPerformedAt: decision.raPerformedAt,
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
      builder: (context) =>
          _RecordRaCompletionDialog(warning: warning, abnormality: abnormality),
    );
    if (completion == null) return;
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .recordRaCompleted(
            warning: warning,
            reannealedToChargeNo: completion.newChargeNo,
            reason: completion.evidence,
            raPerformedAt: completion.performedAt,
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

  Future<void> _createMonitoringRequest({bool savedOnly = false}) async {
    final container = ProviderScope.containerOf(context, listen: false);
    String? originUid;
    void requireOrigin() {
      final access = CurrentActorAccess.resolve(
        container.read(currentAppUserProvider),
      );
      final message = currentActorActionMessage(
        access,
        originUid: originUid,
        permission: (actor) => actor.canManageQualityMonitoring,
      );
      if (message != null) throw QualityCommandException(message);
      originUid ??= access.actor!.uid;
    }

    try {
      requireOrigin();
      final service = container.read(qualityCommandServiceProvider);
      final pending = await service.pendingMonitoringCreation();
      requireOrigin();
      if (!mounted) return;
      if (pending != null) {
        final choice = await showDialog<String>(
          context: context,
          builder: (context) => CurrentActorDialogGuard(
            originUid: originUid!,
            permission: (actor) => actor.canManageQualityMonitoring,
            child: AlertDialog(
              title: const Text('Monitoring confirmation pending'),
              content: SingleChildScrollView(
                child: Text(
                  'Base ${pending['baseNumber']}\n'
                  '${pending['grade']} - ${pending['cycleReference']}\n'
                  'Charges: ${(pending['chargeNumbers'] as List).join(', ')}\n'
                  '${pending['reason']}\n\n'
                  '${pending['savedExplanation'] ?? ''}\n'
                  '${pending['savedReasonCode'] ?? ''}\n'
                  '${pending['savedSubmissionState'] == 'acceptedPendingAdoption' ? 'Monitoring was recorded. Check its current record; creation will not be sent again.' : 'The original entries are saved on this device. Check this submission before creating another.'}',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Later'),
                ),
                if (pending['canCancelBeforeSend'] == true)
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    child: const Text('Cancel unsent request'),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, 'check'),
                  child: const Text('Check saved request'),
                ),
              ],
            ),
          ),
        );
        requireOrigin();
        if (!mounted) return;
        if (choice == 'check') {
          await _runCommand(service.retryMonitoringCreation);
        }
        if (choice == 'cancel') {
          await service.cancelNeverSentMonitoringCreation();
        }
        return;
      }
      if (savedOnly) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No saved monitoring submission needs confirmation.'),
          ),
        );
        return;
      }
      final governedBases = await _loadGovernedBases();
      requireOrigin();
      if (!mounted) return;
      final request = await showDialog<_MonitoringInput>(
        context: context,
        builder: (context) => CurrentActorDialogGuard(
          originUid: originUid!,
          permission: (actor) => actor.canManageQualityMonitoring,
          child: _MonitoringRequestDialog(bases: governedBases),
        ),
      );
      requireOrigin();
      if (request == null || !mounted) return;
      await _runCommand(
        () => service.createMonitoringRequest(
          baseNumber: request.baseNumber,
          baseAssetClassId: request.baseAssetClassId,
          baseAssetInstanceId: request.baseAssetInstanceId,
          baseAssetInstanceVersion: request.baseAssetInstanceVersion,
          grade: request.grade,
          cycleReference: request.cycleReference,
          chargeNumbers: request.chargeNumbers,
          reason: request.reason,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'), backgroundColor: BafColors.danger),
        );
      }
    }
  }

  Future<List<AssetInstanceRecord>> _loadGovernedBases() async {
    final values = await Future.wait<Object>([
      ref.read(assetClassesProvider.future),
      ref.read(allAssetInstancesProvider.future),
    ]);
    final classes = values[0] as List<AssetClassRecord>;
    final assets = values[1] as List<AssetInstanceRecord>;
    final baseClasses = classes
        .where((item) => item.isActive && item.legacyAssetTypeKey == 'base')
        .toList(growable: false);
    if (baseClasses.length != 1) {
      throw StateError(
        'Exactly one active governed Base class is required before creating monitoring.',
      );
    }
    final classId = baseClasses.single.id;
    final bases =
        assets
            .where((item) => item.isActive && item.assetClassId == classId)
            .toList(growable: false)
          ..sort(
            (left, right) => left.assetNumber.compareTo(right.assetNumber),
          );
    if (bases.isEmpty) {
      throw StateError(
        'No active governed Base is available for cycle monitoring.',
      );
    }
    final numbers = <int>{};
    if (bases.any((base) => !numbers.add(base.assetNumber))) {
      throw StateError(
        'The governed Base register contains duplicate active numbers. Reconcile it before creating monitoring.',
      );
    }
    return bases;
  }

  Future<void> _closeMonitoringRequest(QualityMonitoringRequest request) async {
    final origin = ref.read(currentAppUserProvider).asData?.value;
    if (origin?.canManageQualityMonitoring != true) return;
    final reason = await _reasonDialog(
      title: 'Close monitoring request',
      label: 'Completion evidence',
      originUid: origin!.uid,
    );
    if (reason == null || !mounted) return;
    final current = ref.read(currentAppUserProvider).asData?.value;
    if (current?.uid != origin.uid ||
        current?.canManageQualityMonitoring != true) {
      return;
    }
    await _runCommand(
      () => ref
          .read(qualityCommandServiceProvider)
          .closeMonitoringRequest(request: request, reason: reason),
    );
  }

  Future<void> _reviewMonitoring(
    QualityMonitoringRequest request,
    bool cancel,
  ) async {
    final origin = ref.read(currentAppUserProvider).asData?.value;
    if (kIsWeb || origin?.canManageQualityMonitoring != true) return;
    bool stillOrigin() {
      final current = ref.read(currentAppUserProvider).asData?.value;
      return mounted &&
          current?.uid == origin!.uid &&
          current?.canManageQualityMonitoring == true;
    }

    try {
      Map<String, dynamic> payload;
      if (cancel) {
        final reason = await showDialog<String>(
          context: context,
          builder: (_) => CurrentActorDialogGuard(
            originUid: origin!.uid,
            permission: (actor) => actor.canManageQualityMonitoring,
            child: const _ReasonDialog(
              title: 'Cancel monitoring',
              label:
                  'Why is further monitoring not required? This is not completed monitoring.',
            ),
          ),
        );
        if (reason == null || !stillOrigin()) return;
        payload = {'reason': reason};
      } else {
        final bases = await _loadGovernedBases();
        if (!mounted || !stillOrigin()) return;
        final corrected = await showDialog<_MonitoringInput>(
          context: context,
          builder: (_) => CurrentActorDialogGuard(
            originUid: origin!.uid,
            permission: (actor) => actor.canManageQualityMonitoring,
            child: _MonitoringRequestDialog(bases: bases, initial: request),
          ),
        );
        if (corrected == null || !stillOrigin()) return;
        payload = {
          'reason': corrected.reason,
          'baseNumber': corrected.baseNumber,
          'baseAssetClassId': corrected.baseAssetClassId,
          'baseAssetInstanceId': corrected.baseAssetInstanceId,
          'baseAssetInstanceVersion': corrected.baseAssetInstanceVersion,
          'grade': corrected.grade,
          'cycleReference': corrected.cycleReference,
          'chargeNumbers': corrected.chargeNumbers,
        };
      }
      await _runCommand(
        () => ref
            .read(qualityCommandServiceProvider)
            .reviewMonitoring(
              request: request,
              operation: cancel
                  ? QualityCommandOperation.cancelMonitoringRequest
                  : QualityCommandOperation.correctMonitoringRequest,
              payload: payload,
            ),
      );
    } catch (error) {
      if (mounted && stillOrigin()) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<String?> _reasonDialog({
    required String title,
    required String label,
    String? initialValue,
    String? originUid,
  }) => showDialog<String>(
    context: context,
    builder: (context) => originUid == null
        ? _ReasonDialog(title: title, label: label, initialValue: initialValue)
        : CurrentActorDialogGuard(
            originUid: originUid,
            permission: (actor) => actor.canManageQualityMonitoring,
            child: _ReasonDialog(
              title: title,
              label: label,
              initialValue: initialValue,
            ),
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
          backgroundColor: localReadbackApplied
              ? BafColors.sync
              : BafColors.warning,
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
