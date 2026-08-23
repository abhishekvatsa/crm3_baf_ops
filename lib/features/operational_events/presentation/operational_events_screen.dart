import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/operations_report_clock_provider.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../assets/data/asset_hierarchy_model.dart';
import '../../assets/data/asset_registry_model.dart';
import '../../assets/providers/asset_hierarchy_provider.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/operational_event.dart';
import '../data/operational_event_impact.dart';
import '../providers/operational_event_provider.dart';
import 'operational_event_issue_links_screen.dart';

part 'operational_events_screen.summary.dart';

class OperationalEventsScreen extends ConsumerStatefulWidget {
  const OperationalEventsScreen({super.key});

  @override
  ConsumerState<OperationalEventsScreen> createState() =>
      _OperationalEventsScreenState();
}

class _OperationalEventsScreenState
    extends ConsumerState<OperationalEventsScreen> {
  var _showOpen = true;
  var _busy = false;
  var _selectedMonth = _monthStart(DateTime.now());
  OperationalEventType? _selectedTopic;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading && !actorAsync.hasValue) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Operational events',
        appBarSubtitle: 'Verifying your approved operational scope',
        appBarIcon: Icons.crisis_alert_outlined,
        accent: BafColors.warning,
        label: 'Checking operational-event access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Operational events',
        appBarSubtitle: 'Verifying your approved operational scope',
        appBarIcon: Icons.crisis_alert_outlined,
        accent: BafColors.warning,
        message: 'Operational-event access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Operational events',
        appBarSubtitle: 'Approved operational access only',
        appBarIcon: Icons.crisis_alert_outlined,
        accent: BafColors.warning,
        title: 'Operational-event access required',
        message:
            'An approved operational role is required to view plant events.',
      );
    }
    final eventsAsync = ref.watch(operationalEventsProvider);
    final reportEventsAsync = ref.watch(operationalEventsForReportsProvider);
    final classes = ref.watch(assetClassesProvider).value ?? const [];
    final assets = ref.watch(allAssetInstancesProvider).value ?? const [];
    final asOf =
        ref.watch(operationsReportClockProvider).value ?? DateTime.now();

    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Operational events',
          subtitle: 'Utilities, cranes, transfer cars and delays',
          icon: Icons.crisis_alert_outlined,
          accent: BafColors.warning,
        ),
      ),
      body: Column(
        children: [
          if (actor.canRecordOperationalEvent)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const ValueKey('operational-events-add'),
                  onPressed:
                      _busy
                          ? null
                          : () => _editEvent(
                            actor: actor,
                            classes: classes,
                            assets: assets,
                          ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add event'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BafColors.warning,
                    foregroundColor: BafColors.graphite,
                  ),
                ),
              ),
            ),
          Expanded(
            child: eventsAsync.when(
              loading:
                  () => const BafLoadingPanel(
                    label: 'Loading operational events',
                    color: BafColors.warning,
                  ),
              error:
                  (error, _) => _ErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(operationalEventsProvider),
                  ),
              data: (events) {
                final open = events.where((event) => event.isOpen).toList();
                final resolved =
                    events.where((event) => !event.isOpen).toList();
                final visible = _showOpen ? open : resolved;
                final critical =
                    open
                        .where(
                          (event) =>
                              event.severity ==
                              OperationalEventSeverity.critical,
                        )
                        .length;
                return RefreshIndicator(
                  onRefresh:
                      () async => ref.invalidate(operationalEventsProvider),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _EventSummary(
                          openCount: open.length,
                          criticalCount: critical,
                          resolvedCount: resolved.length,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _EventImpactPanel(
                          eventsAsync: reportEventsAsync,
                          selectedMonth: _selectedMonth,
                          selectedTopic: _selectedTopic,
                          asOf: asOf,
                          onPreviousMonth:
                              _selectedMonth.isAfter(DateTime(2020))
                                  ? () => setState(
                                    () =>
                                        _selectedMonth = DateTime(
                                          _selectedMonth.year,
                                          _selectedMonth.month - 1,
                                        ),
                                  )
                                  : null,
                          onNextMonth:
                              _selectedMonth.isBefore(_monthStart(asOf))
                                  ? () => setState(
                                    () =>
                                        _selectedMonth = DateTime(
                                          _selectedMonth.year,
                                          _selectedMonth.month + 1,
                                        ),
                                  )
                                  : null,
                          onPickMonth: _pickImpactMonth,
                          onTopicChanged:
                              (value) => setState(() => _selectedTopic = value),
                          onRetry:
                              () => ref.invalidate(
                                operationalEventsForReportsProvider,
                              ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.warning_amber_rounded),
                                label: Text('Open'),
                              ),
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.task_alt_rounded),
                                label: Text('Recent resolved'),
                              ),
                            ],
                            selected: {_showOpen},
                            onSelectionChanged:
                                (selection) =>
                                    setState(() => _showOpen = selection.first),
                          ),
                        ),
                      ),
                      if (!_showOpen)
                        const SliverToBoxAdapter(child: _HistoryWindowNotice()),
                      if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(showingOpen: _showOpen),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                          sliver: SliverList.separated(
                            itemCount: visible.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(height: 10),
                            itemBuilder:
                                (context, index) => _EventCard(
                                  event: visible[index],
                                  asOf: asOf,
                                  classNames: {
                                    for (final record in classes)
                                      record.id: record.name,
                                  },
                                  assetNames: {
                                    for (final record in assets)
                                      record.id:
                                          '${record.assetClassName} ${record.assetNumber}',
                                  },
                                  canEdit:
                                      actor.canRecordOperationalEvent &&
                                      visible[index].isOpen,
                                  canResolve: actor.canResolveOperationalEvent,
                                  onEdit:
                                      () => _editEvent(
                                        actor: actor,
                                        classes: classes,
                                        assets: assets,
                                        event: visible[index],
                                      ),
                                  onResolve:
                                      () => _resolveEvent(visible[index]),
                                  onReopen: () => _reopenEvent(visible[index]),
                                  onIssues:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder:
                                              (_) =>
                                                  OperationalEventIssueLinksScreen(
                                                    event: visible[index],
                                                  ),
                                        ),
                                      ),
                                ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEvent({
    required AppUser actor,
    required List<AssetClassRecord> classes,
    required List<AssetInstanceRecord> assets,
    OperationalEvent? event,
  }) async {
    final input = await showDialog<_EventInput>(
      context: context,
      builder:
          (_) => _EventDialog(event: event, classes: classes, assets: assets),
    );
    if (input == null || !mounted) return;
    await _run(() async {
      final service = ref.read(operationalEventServiceProvider);
      if (event == null) {
        await service.create(draft: input.draft, reason: input.reason);
      } else {
        await service.update(
          event: event,
          draft: input.draft,
          reason: input.reason,
        );
      }
    }, event == null ? 'Operational event recorded.' : 'Event updated.');
  }

  Future<void> _pickImpactMonth() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Select any day in the reporting month',
    );
    if (selected != null && mounted) {
      setState(() => _selectedMonth = _monthStart(selected));
    }
  }

  Future<void> _resolveEvent(OperationalEvent event) async {
    final note = await _askForReason(
      title: 'Resolve event',
      label: 'Restoration and verification note',
      action: 'Resolve',
    );
    if (note == null || !mounted) return;
    await _run(
      () => ref
          .read(operationalEventServiceProvider)
          .resolve(event: event, resolutionNote: note),
      'Event resolved.',
    );
  }

  Future<void> _reopenEvent(OperationalEvent event) async {
    final reason = await _askForReason(
      title: 'Reopen event',
      label: 'Why is the disruption active again?',
      action: 'Reopen',
    );
    if (reason == null || !mounted) return;
    await _run(
      () => ref
          .read(operationalEventServiceProvider)
          .reopen(event: event, reason: reason),
      'Event reopened.',
    );
  }

  Future<String?> _askForReason({
    required String title,
    required String label,
    required String action,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title, label: label, action: action),
  );

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: BafColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.asOf,
    required this.classNames,
    required this.assetNames,
    required this.canEdit,
    required this.canResolve,
    required this.onEdit,
    required this.onResolve,
    required this.onReopen,
    required this.onIssues,
  });

  final OperationalEvent event;
  final DateTime asOf;
  final Map<String, String> classNames;
  final Map<String, String> assetNames;
  final bool canEdit;
  final bool canResolve;
  final VoidCallback onEdit;
  final VoidCallback onResolve;
  final VoidCallback onReopen;
  final VoidCallback onIssues;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.severity) {
      OperationalEventSeverity.advisory => BafColors.planned,
      OperationalEventSeverity.significant => BafColors.warning,
      OperationalEventSeverity.critical => BafColors.danger,
    };
    final scopeText = switch (event.scope) {
      OperationalEventScope.plantWide => 'Whole plant',
      OperationalEventScope.assetClasses => event.affectedAssetClassIds
          .map((id) => classNames[id] ?? id)
          .join(', '),
      OperationalEventScope.assets => event.affectedAssetInstanceIds
          .map((id) => assetNames[id] ?? id)
          .join(', '),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: BafShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(BafRadius.medium),
                ),
                child: Icon(_eventIcon(event.eventType), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${event.eventType.label} · ${event.severity.label}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit event',
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.description,
            style: const TextStyle(
              color: BafColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _DetailLine(icon: Icons.place_outlined, text: scopeText),
          const SizedBox(height: 6),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text:
                'Started ${DateFormat('dd MMM yyyy, HH:mm').format(event.startedAt.toLocal())}',
          ),
          const SizedBox(height: 6),
          _DetailLine(
            icon: Icons.timer_outlined,
            text:
                'Total impact ${_formatImpactDuration(event.durationUntil(asOf))} '
                'across ${event.completedIntervals.length + 1} '
                '${event.completedIntervals.isEmpty ? 'occurrence' : 'occurrences'}'
                '${event.isOpen ? ' · ongoing' : ''}',
          ),
          if (event.resolutionNote != null) ...[
            const SizedBox(height: 6),
            _DetailLine(
              icon: Icons.fact_check_outlined,
              text: event.resolutionNote!,
            ),
          ],
          if (event.completedIntervals.isNotEmpty) ...[
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(
                Icons.history_rounded,
                size: 19,
                color: BafColors.textSecondary,
              ),
              title: Text(
                '${event.completedIntervals.length} prior restoration${event.completedIntervals.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: BafColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              children: [
                for (final interval in event.completedIntervals.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DetailLine(
                      icon: Icons.task_alt_rounded,
                      text:
                          '${interval.title} · ${interval.eventType.label} · ${interval.severity.label}\n'
                          '${DateFormat('dd MMM yyyy, HH:mm').format(interval.startedAt.toLocal())} - '
                          '${DateFormat('dd MMM yyyy, HH:mm').format(interval.resolvedAt.toLocal())}\n'
                          'Resolved by ${interval.resolvedByName}: ${interval.resolutionNote}',
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onIssues,
                icon: const Icon(Icons.link_rounded),
                label: Text(
                  'Issues${event.issueLinkIds.isEmpty ? '' : ' (${event.issueLinkIds.length})'}',
                ),
              ),
              if (canResolve)
                event.isOpen
                    ? FilledButton.icon(
                      onPressed: onResolve,
                      icon: const Icon(Icons.task_alt_rounded),
                      label: const Text('Resolve'),
                    )
                    : OutlinedButton.icon(
                      onPressed: onReopen,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reopen'),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 17, color: BafColors.textSecondary),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            color: BafColors.textSecondary,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}

class OperationalEventScopeSelection {
  const OperationalEventScopeSelection({
    required this.assetClassIds,
    required this.assetInstanceIds,
  });

  final Set<String> assetClassIds;
  final Set<String> assetInstanceIds;
}

OperationalEventScopeSelection reconcileOperationalEventScopeSelection({
  required OperationalEventScope scope,
  required Set<String> selectedClassIds,
  required Set<String> selectedAssetIds,
  required Set<String> activeClassIds,
  required Map<String, String> activeAssetClassIds,
}) {
  final assetIds =
      selectedAssetIds
          .where(
            (id) =>
                activeAssetClassIds.containsKey(id) &&
                activeClassIds.contains(activeAssetClassIds[id]),
          )
          .toSet();
  return switch (scope) {
    OperationalEventScope.plantWide => OperationalEventScopeSelection(
      assetClassIds: Set<String>.identity(),
      assetInstanceIds: Set<String>.identity(),
    ),
    OperationalEventScope.assetClasses => OperationalEventScopeSelection(
      assetClassIds: selectedClassIds.intersection(activeClassIds),
      assetInstanceIds: Set<String>.identity(),
    ),
    OperationalEventScope.assets => OperationalEventScopeSelection(
      assetClassIds: assetIds.map((id) => activeAssetClassIds[id]!).toSet(),
      assetInstanceIds: assetIds,
    ),
  };
}

class _EventDialog extends StatefulWidget {
  const _EventDialog({
    required this.event,
    required this.classes,
    required this.assets,
  });

  final OperationalEvent? event;
  final List<AssetClassRecord> classes;
  final List<AssetInstanceRecord> assets;

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  late OperationalEventType _type;
  late OperationalEventSeverity _severity;
  late OperationalEventScope _scope;
  late DateTime _startedAt;
  late Set<String> _classIds;
  late Set<String> _assetIds;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _reason;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _type = event?.eventType ?? OperationalEventType.water;
    _severity = event?.severity ?? OperationalEventSeverity.significant;
    _scope = event?.scope ?? OperationalEventScope.plantWide;
    _startedAt = event?.startedAt ?? DateTime.now();
    final activeClassIds = {
      for (final item in widget.classes)
        if (item.isActive) item.id,
    };
    final activeAssetClassIds = {
      for (final item in widget.assets)
        if (item.isActive && activeClassIds.contains(item.assetClassId))
          item.id: item.assetClassId,
    };
    final selection = reconcileOperationalEventScopeSelection(
      scope: _scope,
      selectedClassIds: event?.affectedAssetClassIds.toSet() ?? <String>{},
      selectedAssetIds: event?.affectedAssetInstanceIds.toSet() ?? <String>{},
      activeClassIds: activeClassIds,
      activeAssetClassIds: activeAssetClassIds,
    );
    _classIds = selection.assetClassIds;
    _assetIds = selection.assetInstanceIds;
    _title = TextEditingController(text: event?.title);
    _description = TextEditingController(text: event?.description);
    _reason = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.event == null ? 'Record operational event' : 'Edit event',
    ),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<OperationalEventType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Event type'),
              items:
                  OperationalEventType.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Operational effect and current situation',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<OperationalEventSeverity>(
              initialValue: _severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items:
                  OperationalEventSeverity.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _severity = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<OperationalEventScope>(
              initialValue: _scope,
              decoration: const InputDecoration(labelText: 'Affected scope'),
              items:
                  OperationalEventScope.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _scope = value!;
                  if (_scope == OperationalEventScope.plantWide) {
                    _classIds.clear();
                    _assetIds.clear();
                  } else if (_scope == OperationalEventScope.assetClasses) {
                    _assetIds.clear();
                  }
                });
              },
            ),
            if (_scope == OperationalEventScope.assetClasses) ...[
              const SizedBox(height: 12),
              _SelectionField(
                label: 'Asset classes',
                value: _selectionLabel(_classIds, {
                  for (final item in widget.classes) item.id: item.name,
                }),
                onTap: () => _selectClasses(),
              ),
            ],
            if (_scope == OperationalEventScope.assets) ...[
              const SizedBox(height: 12),
              _SelectionField(
                label: 'Assets',
                value: _selectionLabel(_assetIds, {
                  for (final item in widget.assets)
                    item.id: '${item.assetClassName} ${item.assetNumber}',
                }),
                onTap: () => _selectAssets(),
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Started'),
              subtitle: Text(
                DateFormat('dd MMM yyyy, HH:mm').format(_startedAt.toLocal()),
              ),
              trailing: IconButton(
                onPressed: _pickStartedAt,
                tooltip: 'Change start time',
                icon: const Icon(Icons.edit_calendar_rounded),
              ),
            ),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText:
                    widget.event == null
                        ? 'Reason for recording'
                        : 'Reason for correction',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
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
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.event == null ? 'Record' : 'Save'),
      ),
    ],
  );

  Future<void> _selectClasses() async {
    final selected = await _selectItems(
      title: 'Affected asset classes',
      choices: {
        for (final item in widget.classes.where((item) => item.isActive))
          item.id: item.name,
      },
      selected: _classIds,
    );
    if (selected != null) setState(() => _classIds = selected);
  }

  Future<void> _selectAssets() async {
    final selected = await _selectItems(
      title: 'Affected assets',
      choices: {
        for (final item in widget.assets.where((item) => item.isActive))
          item.id: '${item.assetClassName} ${item.assetNumber} · ${item.name}',
      },
      selected: _assetIds,
    );
    if (selected != null) {
      setState(() {
        _assetIds = selected;
        _classIds =
            widget.assets
                .where((asset) => asset.isActive && selected.contains(asset.id))
                .map((asset) => asset.assetClassId)
                .toSet();
      });
    }
  }

  Future<Set<String>?> _selectItems({
    required String title,
    required Map<String, String> choices,
    required Set<String> selected,
  }) => showDialog<Set<String>>(
    context: context,
    builder: (context) {
      final draft = selected.where(choices.containsKey).toSet();
      return StatefulBuilder(
        builder:
            (context, setDialogState) => AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 480,
                height: 420,
                child: ListView(
                  children:
                      choices.entries
                          .map(
                            (entry) => CheckboxListTile(
                              value: draft.contains(entry.key),
                              title: Text(entry.value),
                              onChanged: (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    draft.add(entry.key);
                                  } else {
                                    draft.remove(entry.key);
                                  }
                                });
                              },
                            ),
                          )
                          .toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, draft),
                  child: const Text('Apply'),
                ),
              ],
            ),
      );
    },
  );

  Future<void> _pickStartedAt() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt.isAfter(now) ? now : _startedAt,
      firstDate: DateTime(2020),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null) return;
    setState(() {
      _startedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    final title = _title.text.trim();
    final description = _description.text.trim();
    final reason = _reason.text.trim();
    if (title.isEmpty || title.length > 120) {
      setState(() => _error = 'Enter a title of up to 120 characters.');
      return;
    }
    if (description.isEmpty || description.length > 2000) {
      setState(() => _error = 'Enter the operational effect and situation.');
      return;
    }
    if (reason.length < 8 || reason.length > 1000) {
      setState(() => _error = 'Enter a reason between 8 and 1,000 characters.');
      return;
    }
    if (_scope == OperationalEventScope.assetClasses && _classIds.isEmpty) {
      setState(() => _error = 'Select at least one asset class.');
      return;
    }
    if (_scope == OperationalEventScope.assets && _assetIds.isEmpty) {
      setState(() => _error = 'Select at least one asset.');
      return;
    }
    if (_startedAt.isAfter(DateTime.now())) {
      setState(() => _error = 'The event start time cannot be in the future.');
      return;
    }
    Navigator.pop(
      context,
      _EventInput(
        draft: OperationalEventDraft(
          eventType: _type,
          title: title,
          description: description,
          severity: _severity,
          scope: _scope,
          affectedAssetClassIds: _classIds.toList(),
          affectedAssetInstanceIds: _assetIds.toList(),
          startedAt: _startedAt,
        ),
        reason: reason,
      ),
    );
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(BafRadius.medium),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
      ),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color:
              value == 'None selected'
                  ? BafColors.textSecondary
                  : BafColors.textPrimary,
        ),
      ),
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.action,
  });
  final String title;
  final String label;
  final String action;

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
      minLines: 3,
      maxLines: 5,
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
          if (value.length < 8 || value.length > 1000) {
            setState(() => _error = 'Enter between 8 and 1,000 characters.');
            return;
          }
          Navigator.pop(context, value);
        },
        child: Text(widget.action),
      ),
    ],
  );
}

class _EventInput {
  const _EventInput({required this.draft, required this.reason});
  final OperationalEventDraft draft;
  final String reason;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.showingOpen});
  final bool showingOpen;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            showingOpen ? Icons.check_circle_outline : Icons.history_rounded,
            size: 44,
            color: BafColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            showingOpen ? 'No open operational events' : 'No resolved events',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: BafColors.danger),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
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

String _selectionLabel(Set<String> ids, Map<String, String> names) {
  if (ids.isEmpty) return 'None selected';
  return ids.map((id) => names[id] ?? id).join(', ');
}

IconData _eventIcon(OperationalEventType type) => switch (type) {
  OperationalEventType.water => Icons.water_drop_outlined,
  OperationalEventType.nitrogen => Icons.air_rounded,
  OperationalEventType.mixedGas => Icons.cloud_outlined,
  OperationalEventType.hydrogen => Icons.bubble_chart_outlined,
  OperationalEventType.powerTrip => Icons.electrical_services_rounded,
  OperationalEventType.crane => Icons.precision_manufacturing_rounded,
  OperationalEventType.transferCar => Icons.local_shipping_outlined,
  OperationalEventType.other => Icons.warning_amber_rounded,
};

DateTime _monthStart(DateTime value) => DateTime(value.year, value.month);

String _formatImpactDuration(Duration value) {
  if (value <= Duration.zero) return '0 min';
  final days = value.inDays;
  final hours = value.inHours.remainder(24);
  final minutes = value.inMinutes.remainder(60);
  if (days > 0) return hours > 0 ? '${days}d ${hours}h' : '${days}d';
  if (value.inHours > 0) {
    return minutes > 0 ? '${value.inHours}h ${minutes}m' : '${value.inHours}h';
  }
  return value.inMinutes > 0 ? '${value.inMinutes} min' : '<1 min';
}
