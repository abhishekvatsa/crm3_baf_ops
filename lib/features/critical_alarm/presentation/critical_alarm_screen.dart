import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/persistence/durable_submission.dart';
import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/presentation/current_actor_gate.dart';
import '../../maintenance_workflow/domain/workflow_error.dart';
import '../domain/critical_alarm_models.dart';
import '../providers/critical_alarm_providers.dart';
import 'critical_alarm_contacts_panel.dart';
import 'critical_alarm_definitions_panel.dart';
import 'critical_alarm_feed_state.dart';
import 'critical_alarm_stale_notice.dart';

part 'critical_alarm_screen.feed.dart';
part 'critical_alarm_screen.dialogs.dart';
part 'critical_alarm_screen.recovery.dart';

class CriticalAlarmScreen extends ConsumerWidget {
  const CriticalAlarmScreen({super.key, this.initialAlarmId});

  static const routeName = '/critical-safety';

  final String? initialAlarmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(currentAppUserProvider);
    return authority.when(
      loading: () => BafScreenStateScaffold.loading(
        appBarTitle: 'Critical safety',
        appBarSubtitle: 'Live coordination alarms and approved contacts',
        appBarIcon: Icons.notification_important_outlined,
        accent: BafColors.danger,
        label: 'Verifying live alarm access',
      ),
      error: (_, _) => BafScreenStateScaffold.error(
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
    final definitionFeed = ref.watch(criticalAlarmDefinitionsProvider);
    final definitionSnapshot = definitionFeed.asData?.value;
    final activeDefinitions =
        definitionSnapshot?.definitions
            .where((definition) => definition.isActive)
            .toList() ??
        const <CriticalAlarmDefinition>[];
    final showDefinitions = user.isAdmin;
    final activeSnapshot = activeFeed.asData?.value;
    final active = activeSnapshot?.alarms ?? const <CriticalAlarm>[];
    final activeAlarmRows = activeFeed.whenData((snapshot) => snapshot.alarms);
    final recentRows = recentFeed.asData?.value ?? const <CriticalAlarm>[];
    final history = recentRows.where((alarm) => !alarm.isActive).toList();
    final contactSnapshot = contacts.asData?.value;
    final contactRows =
        contactSnapshot?.contacts ?? const <CriticalAlarmContact>[];
    final linkedAlarmIsHistorical =
        initialAlarmId != null &&
        !active.any((alarm) => alarm.id == initialAlarmId) &&
        history.any((alarm) => alarm.id == initialAlarmId);
    return DefaultTabController(
      key: ValueKey(
        'critical-alarm-tabs-${linkedAlarmIsHistorical ? 'history' : 'active'}',
      ),
      length: showDefinitions ? 4 : 3,
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                text: activeSnapshot?.isServerVerified == true
                    ? 'Active (${active.length})'
                    : 'Active (?)',
              ),
              Tab(text: 'History (${history.length})'),
              Tab(
                text:
                    'Contacts (${contactRows.where((row) => row.isActive).length})',
              ),
              if (showDefinitions) const Tab(text: 'Alarm reasons'),
            ],
          ),
        ),
        body: Column(
          children: [
            const _ScopeBoundary(),
            const _PendingCriticalAlarmCommands(),
            Expanded(
              child: TabBarView(
                children: [
                  _AlarmList(
                    alarms: active,
                    feed: activeAlarmRows,
                    contacts: contacts,
                    user: user,
                    initialAlarmId: initialAlarmId,
                    emptyTitle: 'No active alarms',
                    liveAuthority: activeSnapshot?.authority,
                    lastVerifiedAt: activeSnapshot?.lastVerifiedAt,
                    malformedDocumentCount:
                        activeSnapshot?.malformedDocumentCount ?? 0,
                  ),
                  _AlarmList(
                    alarms: history,
                    feed: recentFeed,
                    contacts: contacts,
                    user: user,
                    initialAlarmId: initialAlarmId,
                    emptyTitle: initialAlarmId == null
                        ? 'No recent alarm history'
                        : 'Alarm not available in recent history',
                  ),
                  const CriticalAlarmContactsPanel(),
                  if (showDefinitions) const CriticalAlarmDefinitionsPanel(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'raise-critical-alarm',
          backgroundColor: BafColors.danger,
          foregroundColor: Colors.white,
          onPressed:
              definitionSnapshot?.isComplete == true &&
                  activeDefinitions.isNotEmpty
              ? () => _raise(context, ref, activeDefinitions)
              : null,
          icon: const Icon(Icons.notification_important),
          label: const Text('Raise alarm'),
        ),
      ),
    );
  }

  Future<void> _raise(
    BuildContext context,
    WidgetRef ref,
    List<CriticalAlarmDefinition> definitions,
  ) async {
    final actor = _requireAlarmActor(
      context,
      ref,
      originUid: user.uid,
      permission: _approvedAlarmActor,
    );
    if (actor == null) return;
    final draft = await showModalBottomSheet<_AlarmDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CurrentActorDialogGuard(
        originUid: actor.uid,
        permission: _approvedAlarmActor,
        child: _RaiseAlarmSheet(definitions: definitions),
      ),
    );
    if (draft == null || !context.mounted) return;
    if (_requireAlarmActor(
          context,
          ref,
          originUid: actor.uid,
          permission: _approvedAlarmActor,
        ) ==
        null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CurrentActorDialogGuard(
        originUid: actor.uid,
        permission: _approvedAlarmActor,
        child: AlertDialog(
          icon: const Icon(
            Icons.notification_important,
            color: BafColors.danger,
            size: 42,
          ),
          title: Text('Raise ${draft.definition.name}?'),
          content: Text(
            '${draft.definition.criticalityLabel.toUpperCase()} - ${draft.location}\n\n${draft.details}\n\nThis alerts reachable CRM3 users only. Follow the plant emergency procedure first. If the response is interrupted, the original command is saved on this device for checking.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BafColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.notification_important),
              label: const Text('Confirm and send'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (_requireAlarmActor(
          context,
          ref,
          originUid: actor.uid,
          permission: _approvedAlarmActor,
        ) ==
        null) {
      return;
    }
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

class _AlarmCard extends ConsumerWidget {
  const _AlarmCard({
    required this.alarm,
    required this.contacts,
    required this.contactsVerified,
    required this.user,
    required this.lifecycleActionsEnabled,
  });

  final CriticalAlarm alarm;
  final List<CriticalAlarmContact> contacts;
  final bool contactsVerified;
  final AppUser? user;
  final bool lifecycleActionsEnabled;

  bool _mayGovern(AppUser actor) => actor.isAdmin || actor.isSI;
  bool _mayEditDetails(AppUser actor) =>
      _mayGovern(actor) || actor.uid == alarm.raisedByUid;
  bool get _canGovern => user != null && _mayGovern(user!);
  bool get _canEditDetails => user != null && _mayEditDetails(user!);

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
                  children: contacts
                      .map(
                        (contact) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _dial(context, ref, contact.dialValue),
                              icon: const Icon(Icons.call_outlined),
                              label: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
              if (!lifecycleActionsEnabled) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(BafSpacing.sm),
                  decoration: BoxDecoration(
                    color: BafColors.warning.withValues(alpha: 0.1),
                    border: Border.all(
                      color: BafColors.warning.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(BafRadius.small),
                  ),
                  child: const Text(
                    'Live server verification is required before changing this alarm.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: BafSpacing.sm),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (lifecycleActionsEnabled &&
                      alarm.isActive &&
                      _canEditDetails)
                    OutlinedButton.icon(
                      onPressed: () => _provideDetails(context, ref),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: Text(
                        alarm.detailsPending ? 'Add details' : 'Update details',
                      ),
                    ),
                  if (lifecycleActionsEnabled &&
                      alarm.status == CriticalAlarmStatus.raised &&
                      _canGovern)
                    FilledButton.icon(
                      onPressed: () => _confirmSupport(context, ref),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Confirm support'),
                    ),
                  if (lifecycleActionsEnabled &&
                      alarm.status == CriticalAlarmStatus.supportConfirmed &&
                      _canGovern)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: BafColors.success,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _resolve(context, ref),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Resolve'),
                    ),
                  if (lifecycleActionsEnabled &&
                      alarm.isActive &&
                      _canEditDetails)
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
    final actor = _requireAlarmActor(
      context,
      ref,
      originUid: user?.uid,
      permission: _mayEditDetails,
    );
    if (actor == null) return;
    final value = await _askText(
      context,
      originUid: actor.uid,
      permission: _mayEditDetails,
      title: alarm.detailsPending
          ? 'Add incident details'
          : 'Update incident details',
      label: 'What happened and what remains at risk?',
      minimum: 1,
      maximum: 2000,
    );
    if (value == null || !context.mounted) return;
    if (_requireAlarmActor(
          context,
          ref,
          originUid: actor.uid,
          permission: _mayEditDetails,
        ) ==
        null) {
      return;
    }
    await _run(
      context,
      () => ref
          .read(criticalAlarmCommandServiceProvider)
          .provideDetails(alarm, value),
    );
  }

  Future<void> _confirmSupport(BuildContext context, WidgetRef ref) async {
    final actor = _requireAlarmActor(
      context,
      ref,
      originUid: user?.uid,
      permission: _mayGovern,
    );
    if (actor == null) return;
    final response = await showDialog<_SupportDraft>(
      context: context,
      builder: (_) => CurrentActorDialogGuard(
        originUid: actor.uid,
        permission: _mayGovern,
        child: _SupportDialog(detailsRequired: alarm.detailsPending),
      ),
    );
    if (response == null || !context.mounted) return;
    if (_requireAlarmActor(
          context,
          ref,
          originUid: actor.uid,
          permission: _mayGovern,
        ) ==
        null) {
      return;
    }
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
    final actor = _requireAlarmActor(
      context,
      ref,
      originUid: user?.uid,
      permission: _mayGovern,
    );
    if (actor == null) return;
    final value = await _askText(
      context,
      originUid: actor.uid,
      permission: _mayGovern,
      title: 'Resolve critical alarm',
      label: 'Resolution and safe-state summary',
      minimum: 1,
      maximum: 2000,
    );
    if (value == null || !context.mounted) return;
    if (_requireAlarmActor(
          context,
          ref,
          originUid: actor.uid,
          permission: _mayGovern,
        ) ==
        null) {
      return;
    }
    await _run(
      context,
      () => ref.read(criticalAlarmCommandServiceProvider).resolve(alarm, value),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final actor = _requireAlarmActor(
      context,
      ref,
      originUid: user?.uid,
      permission: _mayEditDetails,
    );
    if (actor == null) return;
    final value = await _askText(
      context,
      originUid: actor.uid,
      permission: _mayEditDetails,
      title: 'Record alarm as raised in error',
      label: 'Why was this alarm mistaken?',
      minimum: 1,
      maximum: 1000,
    );
    if (value == null || !context.mounted) return;
    if (_requireAlarmActor(
          context,
          ref,
          originUid: actor.uid,
          permission: _mayEditDetails,
        ) ==
        null) {
      return;
    }
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

bool _approvedAlarmActor(AppUser actor) => actor.isApproved;

AppUser? _requireAlarmActor(
  BuildContext context,
  WidgetRef ref, {
  String? originUid,
  required bool Function(AppUser) permission,
}) {
  final access = CurrentActorAccess.resolve(ref.read(currentAppUserProvider));
  final message = currentActorActionMessage(
    access,
    originUid: originUid,
    permission: permission,
  );
  if (message != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return null;
  }
  return access.actor;
}

void _showProgress(BuildContext context, String label) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
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
  final message = dispatch && uncertain
      ? 'Alarm dispatch could not be confirmed. The original command is saved on this device; use the recovery banner before raising a new alarm. Check Active alarms and follow the plant emergency procedure.'
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
