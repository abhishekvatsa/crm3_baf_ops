import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../domain/critical_alarm_models.dart';
import '../providers/critical_alarm_providers.dart';
import 'critical_alarm_contacts_panel.dart';
import 'critical_alarm_feed_state.dart';

class CriticalAlarmScreen extends ConsumerWidget {
  const CriticalAlarmScreen({super.key, this.initialAlarmId});

  final String? initialAlarmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(currentAppUserProvider);
    return authority.when(
      loading:
          () => BafScreenStateScaffold.loading(
            appBarTitle: 'Critical safety',
            appBarSubtitle: 'Live coordination alarms and approved contacts',
            appBarIcon: Icons.notification_important_outlined,
            accent: BafColors.danger,
            label: 'Verifying live alarm access',
          ),
      error:
          (_, _) => BafScreenStateScaffold.error(
            appBarTitle: 'Critical safety',
            appBarSubtitle: 'Live coordination alarms and approved contacts',
            appBarIcon: Icons.notification_important_outlined,
            accent: BafColors.danger,
            title: 'Alarm access unavailable',
            message:
                'CRM3 could not verify your current approval. No cached authority or alarm state is being shown. Follow the plant emergency procedure.',
          ),
      data: (user) {
        if (user == null || !user.isApproved) {
          return BafScreenStateScaffold.access(
            appBarTitle: 'Critical safety',
            appBarSubtitle: 'Live coordination alarms and approved contacts',
            appBarIcon: Icons.notification_important_outlined,
            accent: BafColors.danger,
            title: 'Approved access required',
            message:
                'An approved CRM3 account is required to view or raise critical safety alarms.',
          );
        }
        return _CriticalAlarmWorkspace(
          user: user,
          initialAlarmId: initialAlarmId,
        );
      },
    );
  }
}

class _CriticalAlarmWorkspace extends ConsumerWidget {
  const _CriticalAlarmWorkspace({
    required this.user,
    required this.initialAlarmId,
  });

  final AppUser user;
  final String? initialAlarmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFeed = ref.watch(activeCriticalAlarmsProvider);
    final recentFeed = ref.watch(criticalAlarmFeedProvider);
    final contacts = ref.watch(criticalAlarmContactsProvider);
    final active = activeFeed.asData?.value ?? const <CriticalAlarm>[];
    final recentRows = recentFeed.asData?.value ?? const <CriticalAlarm>[];
    final history = recentRows.where((alarm) => !alarm.isActive).toList();
    final contactRows =
        contacts.asData?.value ?? const <CriticalAlarmContact>[];
    final linkedAlarmIsHistorical =
        initialAlarmId != null &&
        !active.any((alarm) => alarm.id == initialAlarmId) &&
        history.any((alarm) => alarm.id == initialAlarmId);
    return DefaultTabController(
      key: ValueKey(
        'critical-alarm-tabs-${linkedAlarmIsHistorical ? 'history' : 'active'}',
      ),
      length: 3,
      initialIndex: linkedAlarmIsHistorical ? 1 : 0,
      child: Scaffold(
        backgroundColor: BafColors.background,
        appBar: AppBar(
          title: const BafAppBarTitle(
            title: 'Critical safety',
            subtitle: 'Live coordination alarms and approved contacts',
            icon: Icons.notification_important_outlined,
            accent: BafColors.danger,
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Active (${active.length})'),
              Tab(text: 'History (${history.length})'),
              Tab(
                text:
                    'Contacts (${contactRows.where((row) => row.isActive).length})',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const _ScopeBoundary(),
            Expanded(
              child: TabBarView(
                children: [
                  _AlarmList(
                    alarms: active,
                    feed: activeFeed,
                    contacts: contacts,
                    user: user,
                    initialAlarmId: initialAlarmId,
                    emptyTitle: 'No active alarms',
                  ),
                  _AlarmList(
                    alarms: history,
                    feed: recentFeed,
                    contacts: contacts,
                    user: user,
                    initialAlarmId: initialAlarmId,
                    emptyTitle:
                        initialAlarmId == null
                            ? 'No recent alarm history'
                            : 'Alarm not available in recent history',
                  ),
                  const CriticalAlarmContactsPanel(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'raise-critical-alarm',
          backgroundColor: BafColors.danger,
          foregroundColor: Colors.white,
          onPressed: () => _raise(context, ref),
          icon: const Icon(Icons.notification_important),
          label: const Text('Raise alarm'),
        ),
      ),
    );
  }

  Future<void> _raise(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<_AlarmDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _RaiseAlarmSheet(),
    );
    if (draft == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.notification_important,
              color: BafColors.danger,
              size: 42,
            ),
            title: Text('Raise ${draft.definition.name}?'),
            content: Text(
              '${draft.definition.criticalityLabel.toUpperCase()} - ${draft.location}\n\nThis alerts reachable CRM3 users only. Follow the plant emergency procedure first. The alarm is sent immediately after confirmation and is never queued offline.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.danger,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.notification_important),
                label: const Text('Confirm and send'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    _showProgress(context, 'Sending critical alarm');
    try {
      final receipt = await ref
          .read(criticalAlarmCommandServiceProvider)
          .raise(
            definition: draft.definition,
            location: draft.location,
            assetTypeKey: draft.assetTypeKey,
            assetNumber: draft.assetNumber,
            initialDetails: draft.details,
          );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            receipt.result['detailsPending'] == true
                ? 'Alarm raised. Add the incident details immediately.'
                : 'Critical alarm raised and recorded.',
          ),
          backgroundColor: BafColors.danger,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showCommandFailure(context, error, dispatch: true);
    }
  }
}

class _ScopeBoundary extends StatelessWidget {
  const _ScopeBoundary();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: BafColors.danger.withValues(alpha: 0.08),
    padding: const EdgeInsets.symmetric(
      horizontal: BafSpacing.md,
      vertical: BafSpacing.sm,
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: BafColors.danger, size: 20),
        SizedBox(width: BafSpacing.sm),
        Expanded(
          child: Text(
            'Coordination aid only. This does not contact emergency services, the control room, or Fire and Safety. Follow the plant emergency procedure first.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _AlarmList extends ConsumerWidget {
  const _AlarmList({
    required this.alarms,
    required this.feed,
    required this.contacts,
    required this.user,
    required this.emptyTitle,
    this.initialAlarmId,
  });

  final List<CriticalAlarm> alarms;
  final AsyncValue<List<CriticalAlarm>> feed;
  final AsyncValue<List<CriticalAlarmContact>> contacts;
  final AppUser? user;
  final String emptyTitle;
  final String? initialAlarmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (feed.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (feed.hasError) {
      return CriticalAlarmFeedState(
        icon: Icons.cloud_off_outlined,
        title: 'Live alarm state unavailable',
        message:
            'CRM3 could not verify the server alarm feed. Do not rely on cached information. Follow the plant emergency procedure.',
        action: OutlinedButton.icon(
          onPressed: () {
            ref.invalidate(criticalAlarmFeedProvider);
            ref.invalidate(activeCriticalAlarmsProvider);
            ref.invalidate(criticalAlarmContactsProvider);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Retry live check'),
        ),
      );
    }
    if (alarms.isEmpty) {
      return CriticalAlarmFeedState(
        icon: Icons.verified_user_outlined,
        title: emptyTitle,
        message:
            'Only server-confirmed alarm records appear here. Continue to follow normal plant safety procedures.',
      );
    }
    final ordered = [...alarms]..sort((left, right) {
      if (left.id == initialAlarmId) return -1;
      if (right.id == initialAlarmId) return 1;
      return right.raisedAt.compareTo(left.raisedAt);
    });
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(criticalAlarmFeedProvider);
        ref.invalidate(activeCriticalAlarmsProvider);
        ref.invalidate(criticalAlarmContactsProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.md,
          BafSpacing.md,
          BafSpacing.md,
          96,
        ),
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.md),
        itemBuilder: (context, index) {
          final alarm = ordered[index];
          final exactContacts =
              contacts.asData?.value
                  .where(
                    (contact) =>
                        contact.isActive &&
                        contact.alarmTypeKeys.contains(alarm.definition.key),
                  )
                  .toList() ??
              const <CriticalAlarmContact>[];
          return _AlarmCard(
            alarm: alarm,
            contacts: exactContacts,
            contactsVerified: contacts.asData != null,
            user: user,
          );
        },
      ),
    );
  }
}

class _AlarmCard extends ConsumerWidget {
  const _AlarmCard({
    required this.alarm,
    required this.contacts,
    required this.contactsVerified,
    required this.user,
  });

  final CriticalAlarm alarm;
  final List<CriticalAlarmContact> contacts;
  final bool contactsVerified;
  final AppUser? user;

  bool get _canGovern => user?.isAdmin == true || user?.isSI == true;
  bool get _canEditDetails => _canGovern || user?.uid == alarm.raisedByUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = alarm.isHighest ? BafColors.danger : BafColors.warning;
    return Container(
      decoration: BoxDecoration(
        color: BafColors.card,
        borderRadius: BorderRadius.circular(BafRadius.medium),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: BafShadows.subtle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(BafSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                  ),
                  child: Icon(Icons.notification_important, color: color),
                ),
                const SizedBox(width: BafSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.definition.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${alarm.definition.criticalityLabel.toUpperCase()} - ${_statusLabel(alarm.status)}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd MMM, HH:mm').format(alarm.raisedAt.toLocal()),
                  style: const TextStyle(color: BafColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            _Fact(icon: Icons.location_on_outlined, text: alarm.location),
            _Fact(
              icon: Icons.person_outline,
              text: 'Raised by ${alarm.raisedByName}',
            ),
            if (alarm.assetTypeKey != null)
              _Fact(
                icon: Icons.precision_manufacturing_outlined,
                text: '${alarm.assetTypeKey} ${alarm.assetNumber}',
              ),
            const SizedBox(height: BafSpacing.sm),
            if (alarm.detailsPending)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BafSpacing.sm),
                color: BafColors.warning.withValues(alpha: 0.12),
                child: const Text(
                  'Incident details are still required.',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              )
            else
              Text(alarm.details!, style: const TextStyle(fontSize: 15)),
            if (alarm.supportConfirmedAt != null) ...[
              const Divider(height: BafSpacing.lg),
              _Fact(
                icon: Icons.support_agent_outlined,
                text:
                    'Support confirmed by ${alarm.supportConfirmedByName} - ${_supportBasisLabel(alarm.supportBasis!)}',
              ),
              if (alarm.supportNote != null) Text(alarm.supportNote!),
            ],
            if (alarm.resolvedAt != null) ...[
              const Divider(height: BafSpacing.lg),
              _Fact(
                icon: Icons.task_alt,
                text: 'Resolved by ${alarm.resolvedByName}',
              ),
              if (alarm.resolutionSummary != null)
                Text(alarm.resolutionSummary!),
            ],
            if (alarm.withdrawnAt != null) ...[
              const Divider(height: BafSpacing.lg),
              _Fact(
                icon: Icons.cancel_outlined,
                text: 'Withdrawn in error by ${alarm.withdrawnByName}',
              ),
              if (alarm.withdrawalReason != null) Text(alarm.withdrawalReason!),
            ],
            if (alarm.isActive) ...[
              const Divider(height: BafSpacing.lg),
              const Text(
                'Approved contacts for this alarm',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              if (!contactsVerified)
                const Text(
                  'Contact directory has not been verified from the server. Follow the plant emergency procedure.',
                  style: TextStyle(color: BafColors.danger),
                )
              else if (contacts.isEmpty)
                const Text(
                  'No approved contact is configured for this alarm. Follow the plant emergency procedure.',
                  style: TextStyle(color: BafColors.danger),
                )
              else
                Column(
                  children:
                      contacts
                          .map(
                            (contact) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      () => _dial(
                                        context,
                                        ref,
                                        contact.dialValue,
                                      ),
                                  icon: const Icon(Icons.call_outlined),
                                  label: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        contact.dialValue,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              const SizedBox(height: BafSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (alarm.isActive && alarm.detailsPending && _canEditDetails)
                    OutlinedButton.icon(
                      onPressed: () => _provideDetails(context, ref),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Add details'),
                    ),
                  if (alarm.status == CriticalAlarmStatus.raised && _canGovern)
                    FilledButton.icon(
                      onPressed: () => _confirmSupport(context, ref),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Confirm support'),
                    ),
                  if (alarm.status == CriticalAlarmStatus.supportConfirmed &&
                      _canGovern)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.success,
                      ),
                      onPressed: () => _resolve(context, ref),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Resolve'),
                    ),
                  if (alarm.isActive && _canEditDetails)
                    TextButton.icon(
                      onPressed: () => _withdraw(context, ref),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Raised in error'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _dial(BuildContext context, WidgetRef ref, String number) async {
    try {
      await ref.read(criticalAlarmPlatformServiceProvider).openDialer(number);
    } catch (error) {
      if (context.mounted) _showCommandFailure(context, error);
    }
  }

  Future<void> _provideDetails(BuildContext context, WidgetRef ref) async {
    final value = await _askText(
      context,
      title: 'Add incident details',
      label: 'What happened and what remains at risk?',
      minimum: 5,
      maximum: 2000,
    );
    if (value == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(criticalAlarmCommandServiceProvider)
          .provideDetails(alarm, value),
    );
  }

  Future<void> _confirmSupport(BuildContext context, WidgetRef ref) async {
    final response = await showDialog<_SupportDraft>(
      context: context,
      builder: (_) => _SupportDialog(detailsRequired: alarm.detailsPending),
    );
    if (response == null || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(criticalAlarmCommandServiceProvider)
          .confirmSupport(
            alarm: alarm,
            basis: response.basis,
            responderNote: response.note,
            details: response.details,
          ),
    );
  }

  Future<void> _resolve(BuildContext context, WidgetRef ref) async {
    final value = await _askText(
      context,
      title: 'Resolve critical alarm',
      label: 'Resolution and safe-state summary',
      minimum: 5,
      maximum: 2000,
    );
    if (value == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(criticalAlarmCommandServiceProvider).resolve(alarm, value),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final value = await _askText(
      context,
      title: 'Record alarm as raised in error',
      label: 'Why was this alarm mistaken?',
      minimum: 5,
      maximum: 1000,
    );
    if (value == null || !context.mounted) return;
    await _run(
      context,
      () =>
          ref.read(criticalAlarmCommandServiceProvider).withdraw(alarm, value),
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<Object?> Function() action,
  ) async {
    _showProgress(context, 'Recording governed alarm action');
    try {
      await action();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showCommandFailure(context, error);
    }
  }
}

class _RaiseAlarmSheet extends StatefulWidget {
  const _RaiseAlarmSheet();

  @override
  State<_RaiseAlarmSheet> createState() => _RaiseAlarmSheetState();
}

class _RaiseAlarmSheetState extends State<_RaiseAlarmSheet> {
  final _formKey = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _assetNumber = TextEditingController();
  final _details = TextEditingController();
  CriticalAlarmDefinition? _definition;
  String? _assetTypeKey;

  @override
  void dispose() {
    _location.dispose();
    _assetNumber.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      BafSpacing.lg,
      BafSpacing.md,
      BafSpacing.lg,
      MediaQuery.viewInsetsOf(context).bottom + BafSpacing.lg,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notification_important,
                  color: BafColors.danger,
                  size: 32,
                ),
                const SizedBox(width: BafSpacing.sm),
                const Expanded(
                  child: Text(
                    'Raise critical safety alarm',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<CriticalAlarmDefinition>(
              key: const ValueKey('critical-alarm-reason'),
              initialValue: _definition,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Alarm reason',
                border: OutlineInputBorder(),
              ),
              items:
                  CriticalAlarmDefinition.values
                      .map(
                        (definition) => DropdownMenuItem(
                          value: definition,
                          child: Text(
                            '${definition.name} - ${definition.criticalityLabel}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _definition = value),
              validator:
                  (value) => value == null ? 'Select the alarm reason' : null,
            ),
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              key: const ValueKey('critical-alarm-location'),
              controller: _location,
              textInputAction: TextInputAction.next,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Exact location or area',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              validator:
                  (value) =>
                      value == null || value.trim().length < 2
                          ? 'Enter the location'
                          : null,
            ),
            const SizedBox(height: BafSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _assetTypeKey,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Related asset class (optional)',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('No specific asset')),
                DropdownMenuItem(value: 'base', child: Text('Base')),
                DropdownMenuItem(value: 'furnace', child: Text('Furnace')),
                DropdownMenuItem(
                  value: 'forceCooler',
                  child: Text('Forced Cooler'),
                ),
                DropdownMenuItem(
                  value: 'innerCover',
                  child: Text('Inner Cover'),
                ),
              ],
              onChanged: (value) => setState(() => _assetTypeKey = value),
            ),
            if (_assetTypeKey != null) ...[
              const SizedBox(height: BafSpacing.md),
              TextFormField(
                controller: _assetNumber,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Asset number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_assetTypeKey == null) return null;
                  final parsed = int.tryParse(value ?? '');
                  return parsed == null || parsed < 1
                      ? 'Enter a valid asset number'
                      : null;
                },
              ),
            ],
            const SizedBox(height: BafSpacing.md),
            TextFormField(
              key: const ValueKey('critical-alarm-details'),
              controller: _details,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Immediate details (optional before dispatch)',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length > 0 && length < 5
                    ? 'Enter at least 5 characters or leave this blank'
                    : null;
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'If omitted, incident details remain required immediately after dispatch.',
              style: TextStyle(color: BafColors.textSecondary),
            ),
            const SizedBox(height: BafSpacing.md),
            Container(
              padding: const EdgeInsets.all(BafSpacing.sm),
              color: BafColors.warning.withValues(alpha: 0.12),
              child: const Text(
                'Requires connectivity. Nothing is queued offline. Follow the plant emergency procedure first.',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: BafSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('critical-alarm-review'),
                style: FilledButton.styleFrom(
                  backgroundColor: BafColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _AlarmDraft(
                      definition: _definition!,
                      location: _location.text.trim(),
                      assetTypeKey: _assetTypeKey,
                      assetNumber:
                          _assetTypeKey == null
                              ? null
                              : int.parse(_assetNumber.text),
                      details:
                          _details.text.trim().isEmpty
                              ? null
                              : _details.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Review and confirm'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SupportDialog extends StatefulWidget {
  const _SupportDialog({required this.detailsRequired});

  final bool detailsRequired;

  @override
  State<_SupportDialog> createState() => _SupportDialogState();
}

class _SupportDialogState extends State<_SupportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _details = TextEditingController();
  CriticalAlarmSupportBasis? _basis;

  @override
  void dispose() {
    _note.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm support response'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CriticalAlarmSupportBasis>(
                initialValue: _basis,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmation basis',
                ),
                items:
                    CriticalAlarmSupportBasis.values
                        .map(
                          (basis) => DropdownMenuItem(
                            value: basis,
                            child: Text(
                              _supportBasisLabel(basis),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _basis = value),
                validator: (value) => value == null ? 'Select a basis' : null,
              ),
              const SizedBox(height: BafSpacing.sm),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Responder note',
                  counterText: '',
                ),
                validator:
                    (value) =>
                        value == null || value.trim().length < 5
                            ? 'Enter the support response'
                            : null,
              ),
              if (widget.detailsRequired) ...[
                const SizedBox(height: BafSpacing.sm),
                TextFormField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Required incident details',
                    counterText: '',
                  ),
                  validator:
                      (value) =>
                          value == null || value.trim().length < 5
                              ? 'Incident details are required'
                              : null,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(
            context,
            _SupportDraft(
              basis: _basis!,
              note: _note.text.trim(),
              details: widget.detailsRequired ? _details.text.trim() : null,
            ),
          );
        },
        child: const Text('Confirm support'),
      ),
    ],
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: BafColors.textSecondary),
        const SizedBox(width: 7),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _AlarmDraft {
  const _AlarmDraft({
    required this.definition,
    required this.location,
    required this.assetTypeKey,
    required this.assetNumber,
    required this.details,
  });

  final CriticalAlarmDefinition definition;
  final String location;
  final String? assetTypeKey;
  final int? assetNumber;
  final String? details;
}

class _SupportDraft {
  const _SupportDraft({
    required this.basis,
    required this.note,
    required this.details,
  });

  final CriticalAlarmSupportBasis basis;
  final String note;
  final String? details;
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
  required int minimum,
  required int maximum,
}) => showDialog<String>(
  context: context,
  builder:
      (_) => _TextEntryDialog(
        title: title,
        label: label,
        minimum: minimum,
        maximum: maximum,
      ),
);

class _TextEntryDialog extends StatefulWidget {
  const _TextEntryDialog({
    required this.title,
    required this.label,
    required this.minimum,
    required this.maximum,
  });

  final String title;
  final String label;
  final int minimum;
  final int maximum;

  @override
  State<_TextEntryDialog> createState() => _TextEntryDialogState();
}

class _TextEntryDialogState extends State<_TextEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _value,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: widget.maximum,
          decoration: InputDecoration(
            labelText: widget.label,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            final length = value?.trim().length ?? 0;
            if (length < widget.minimum) {
              return 'Enter at least ${widget.minimum} characters';
            }
            if (length > widget.maximum) {
              return 'Keep this within ${widget.maximum} characters';
            }
            return null;
          },
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, _value.text.trim());
        },
        child: const Text('Confirm'),
      ),
    ],
  );
}

void _showProgress(BuildContext context, String label) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: BafSpacing.md),
              Expanded(child: Text(label)),
            ],
          ),
        ),
  );
}

void _showCommandFailure(
  BuildContext context,
  Object error, {
  bool dispatch = false,
}) {
  final uncertain =
      error is WorkflowException &&
      (error.code == WorkflowErrorCode.unavailable ||
          error.code == WorkflowErrorCode.deadlineExceeded ||
          error.code == WorkflowErrorCode.aborted);
  final message =
      dispatch && uncertain
          ? 'Alarm dispatch could not be confirmed. It will not retry automatically. Check Active alarms and follow the plant emergency procedure.'
          : '$error';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: BafColors.danger),
  );
}

String _statusLabel(CriticalAlarmStatus status) => switch (status) {
  CriticalAlarmStatus.raised => 'Raised',
  CriticalAlarmStatus.supportConfirmed => 'Support confirmed',
  CriticalAlarmStatus.resolved => 'Resolved',
  CriticalAlarmStatus.withdrawnInError => 'Withdrawn in error',
};

String _supportBasisLabel(CriticalAlarmSupportBasis basis) => switch (basis) {
  CriticalAlarmSupportBasis.supportDispatched => 'Support dispatched',
  CriticalAlarmSupportBasis.supportAlreadyPresent => 'Support already present',
  CriticalAlarmSupportBasis.raiserContactedDirectly =>
    'Raiser contacted directly',
};
