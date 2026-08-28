import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../../core/widgets/baf_ui.dart';
import '../../../core/widgets/brand/brand_widgets.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../data/operational_event.dart';
import '../data/operational_event_issue_link.dart';
import '../providers/operational_event_provider.dart';

class OperationalEventIssueLinksScreen extends ConsumerStatefulWidget {
  const OperationalEventIssueLinksScreen({super.key, required this.event});

  final OperationalEvent event;

  @override
  ConsumerState<OperationalEventIssueLinksScreen> createState() =>
      _OperationalEventIssueLinksScreenState();
}

class _OperationalEventIssueLinksScreenState
    extends ConsumerState<OperationalEventIssueLinksScreen> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Event-linked issues',
        appBarSubtitle: 'Verifying your approved event scope',
        appBarIcon: Icons.link_outlined,
        accent: BafColors.warning,
        label: 'Checking event-link access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Event-linked issues',
        appBarSubtitle: 'Verifying your approved event scope',
        appBarIcon: Icons.link_outlined,
        accent: BafColors.warning,
        message: 'Event-link access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null || !actor.isApproved) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Event-linked issues',
        appBarSubtitle: 'Maintenance consequences of this operational event',
        appBarIcon: Icons.link_outlined,
        accent: BafColors.warning,
        title: 'Event-link access required',
        message: 'An approved account is required to view event-linked issues.',
      );
    }
    final event = _latestEvent(ref.watch(operationalEventsProvider(actor.uid)));
    final links = ref.watch(
      operationalEventIssueLinksProvider((
        actorUid: actor.uid,
        eventId: event.eventId,
      )),
    );
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Event-linked issues',
          subtitle: 'Maintenance consequences of this operational event',
          icon: Icons.link_outlined,
          accent: BafColors.warning,
        ),
      ),
      floatingActionButton:
          actor.canRecordOperationalEvent
              ? FloatingActionButton.extended(
                onPressed: _busy ? null : () => _linkIssue(actor, event),
                backgroundColor: BafColors.navySoft,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('Link issue'),
              )
              : null,
      body: links.when(
        loading:
            () => const BafLoadingPanel(
              label: 'Loading linked maintenance issues',
              color: BafColors.warning,
            ),
        error:
            (error, _) => _LinkState(
              icon: Icons.error_outline_rounded,
              color: BafColors.danger,
              title: 'Could not load issue links',
              message: '$error',
            ),
        data: (records) {
          final current = records
              .where(
                (link) => link.eventOccurrenceStartedAt.isAtSameMomentAs(
                  event.startedAt,
                ),
              )
              .toList(growable: false);
          final prior = records
              .where(
                (link) =>
                    !link.eventOccurrenceStartedAt.isAtSameMomentAs(
                      event.startedAt,
                    ),
              )
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _EventContext(event: event, currentCount: current.length),
              const SizedBox(height: 18),
              const _SectionTitle(
                title: 'Current occurrence',
                icon: Icons.link_rounded,
              ),
              const SizedBox(height: 8),
              if (current.isEmpty)
                const _LinkState(
                  icon: Icons.link_off_rounded,
                  color: BafColors.textSecondary,
                  title: 'No issue linked yet',
                  message:
                      'Link an existing maintenance issue when it was caused by, responds to, or is affected by this disruption.',
                )
              else
                for (final link in current) ...[
                  _IssueLinkCard(link: link),
                  const SizedBox(height: 10),
                ],
              if (prior.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionTitle(
                  title: 'Prior occurrences',
                  icon: Icons.history_rounded,
                ),
                const SizedBox(height: 8),
                for (final link in prior) ...[
                  _IssueLinkCard(link: link, showOccurrence: true),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  OperationalEvent _latestEvent(AsyncValue<List<OperationalEvent>> events) {
    for (final event in events.value ?? const <OperationalEvent>[]) {
      if (event.eventId == widget.event.eventId) return event;
    }
    return widget.event;
  }

  Future<void> _linkIssue(AppUser actor, OperationalEvent event) async {
    final tickets = ref.read(allTicketsProvider).value;
    if (tickets == null) {
      _showError('Maintenance issues are still loading.');
      return;
    }
    final existing =
        ref
            .read(
              operationalEventIssueLinksProvider((
                actorUid: actor.uid,
                eventId: event.eventId,
              )),
            )
            .value ??
        const <OperationalEventIssueLink>[];
    final currentIssueIds =
        existing
            .where(
              (link) => link.eventOccurrenceStartedAt.isAtSameMomentAs(
                event.startedAt,
              ),
            )
            .map((link) => link.issueId)
            .toSet();
    final eligible =
        tickets
            .where(
              (ticket) =>
                  userCanLinkOperationalEventIssue(actor, ticket) &&
                  !ticket.isDeleted &&
                  (ticket.firestoreId?.trim().isNotEmpty ?? false) &&
                  !currentIssueIds.contains(ticket.firestoreId) &&
                  operationalEventCoversIssue(event, ticket),
            )
            .toList();
    eligible.sort((left, right) {
      if (left.isResolved != right.isResolved) return left.isResolved ? 1 : -1;
      return right.updatedAt.compareTo(left.updatedAt);
    });
    if (eligible.isEmpty) {
      _showError(
        event.scope == OperationalEventScope.plantWide
            ? 'No visible synchronized issue is available to link.'
            : 'No visible synchronized issue has governed asset identity inside this event scope.',
      );
      return;
    }
    final input = await showDialog<_IssueLinkInput>(
      context: context,
      builder: (_) => _IssueLinkDialog(tickets: eligible),
    );
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(operationalEventIssueLinkServiceProvider)
          .link(
            event: event,
            issue: input.issue,
            relationship: input.relationship,
            reason: input.reason,
          );
      ref.invalidate(
        operationalEventIssueLinksProvider((
          actorUid: actor.uid,
          eventId: event.eventId,
        )),
      );
      ref.invalidate(operationalEventsProvider(actor.uid));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue linked to this event occurrence.'),
          ),
        );
      }
    } catch (error) {
      _showError('$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: BafColors.danger),
    );
  }
}

class MaintenanceIssueEventLinksScreen extends ConsumerWidget {
  const MaintenanceIssueEventLinksScreen({super.key, required this.issue});

  final MaintenanceRecord issue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actorAsync = ref.watch(currentAppUserProvider);
    if (actorAsync.isLoading) {
      return BafScreenStateScaffold.loading(
        appBarTitle: 'Linked operational events',
        appBarSubtitle: 'Verifying your approved issue scope',
        appBarIcon: Icons.crisis_alert_outlined,
        accent: BafColors.warning,
        label: 'Checking issue-link access',
      );
    }
    if (actorAsync.hasError) {
      return BafScreenStateScaffold.error(
        appBarTitle: 'Linked operational events',
        appBarSubtitle: 'Verifying your approved issue scope',
        appBarIcon: Icons.crisis_alert_outlined,
        accent: BafColors.warning,
        message: 'Issue-link access could not be verified.',
      );
    }
    final actor = actorAsync.value;
    if (actor == null ||
        !actor.isApproved ||
        !userCanLinkOperationalEventIssue(actor, issue)) {
      return BafScreenStateScaffold.access(
        appBarTitle: 'Linked operational events',
        appBarSubtitle: 'Utility, crane and plant events related to this issue',
        appBarIcon: Icons.crisis_alert_outlined,
        accent: BafColors.warning,
        title: 'Issue-link access required',
        message:
            'Your approved role cannot view this issue and its event links.',
      );
    }
    final issueId = issue.firestoreId?.trim();
    return Scaffold(
      backgroundColor: BafColors.background,
      appBar: AppBar(
        title: const BafAppBarTitle(
          title: 'Linked operational events',
          subtitle: 'Utility, crane and plant events related to this issue',
          icon: Icons.crisis_alert_outlined,
          accent: BafColors.warning,
        ),
      ),
      body:
          issueId == null || issueId.isEmpty
              ? const _LinkState(
                icon: Icons.cloud_off_outlined,
                color: BafColors.warning,
                title: 'Issue not synchronized',
                message:
                    'This issue needs a cloud identity before event links can be read.',
              )
              : ref
                  .watch(
                    operationalIssueEventLinksProvider((
                      actorUid: actor.uid,
                      issueId: issueId,
                    )),
                  )
                  .when(
                    loading:
                        () => const BafLoadingPanel(
                          label: 'Loading linked operational events',
                          color: BafColors.warning,
                        ),
                    error:
                        (error, _) => _LinkState(
                          icon: Icons.error_outline_rounded,
                          color: BafColors.danger,
                          title: 'Could not load event links',
                          message: '$error',
                        ),
                    data:
                        (links) => ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _IssueContext(issue: issue),
                            const SizedBox(height: 18),
                            if (links.isEmpty)
                              const _LinkState(
                                icon: Icons.link_off_rounded,
                                color: BafColors.textSecondary,
                                title: 'No operational event link',
                                message:
                                    'This issue was not recorded as part of an operational disruption.',
                              )
                            else
                              for (final link in links) ...[
                                _EventLinkCard(link: link),
                                const SizedBox(height: 10),
                              ],
                          ],
                        ),
                  ),
    );
  }
}

bool userCanLinkOperationalEventIssue(AppUser actor, MaintenanceRecord issue) {
  final laneRead = issue.issueLanePlanReadResult;
  if (!laneRead.isValid) return false;
  return actor.canViewMaintenanceIssue(
    loggedByUid: issue.loggedByUid,
    lanes: laneRead.value!.assignedLanes.map(RoutedTo.values.byName),
  );
}

bool operationalEventCoversIssue(
  OperationalEvent event,
  MaintenanceRecord issue,
) {
  if (event.scope == OperationalEventScope.plantWide) return true;
  final reference = issue.assetHierarchyReference;
  if (reference == null) return false;
  return switch (event.scope) {
    OperationalEventScope.plantWide => true,
    OperationalEventScope.assetClasses => event.affectedAssetClassIds.contains(
      reference.assetClassId,
    ),
    OperationalEventScope.assets =>
      reference.assetInstanceId != null &&
          event.affectedAssetInstanceIds.contains(reference.assetInstanceId),
  };
}

class _IssueLinkDialog extends StatefulWidget {
  const _IssueLinkDialog({required this.tickets});

  final List<MaintenanceRecord> tickets;

  @override
  State<_IssueLinkDialog> createState() => _IssueLinkDialogState();
}

class _IssueLinkDialogState extends State<_IssueLinkDialog> {
  late MaintenanceRecord _issue;
  var _relationship = OperationalEventIssueRelationship.responseToEvent;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    _issue = widget.tickets.first;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Link maintenance issue'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MaintenanceRecord>(
              initialValue: _issue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Maintenance issue',
                prefixIcon: Icon(Icons.build_outlined),
              ),
              items: [
                for (final issue in widget.tickets)
                  DropdownMenuItem(
                    value: issue,
                    child: Text(
                      '${issue.lifecycleSummaryLabel.toUpperCase()} · '
                      '${issue.assetType.name.toUpperCase()} ${issue.assetNumber} · '
                      '${issue.description}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _issue = value);
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<OperationalEventIssueRelationship>(
              initialValue: _relationship,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: [
                for (final value in OperationalEventIssueRelationship.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _relationship = value);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reason,
              onChanged: (_) => setState(() {}),
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Why these records belong together',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed:
            _reason.text.trim().isEmpty
                ? null
                : () => Navigator.pop(
                  context,
                  _IssueLinkInput(
                    issue: _issue,
                    relationship: _relationship,
                    reason: _reason.text.trim(),
                  ),
                ),
        icon: const Icon(Icons.link_rounded),
        label: const Text('Link'),
      ),
    ],
  );
}

class _IssueLinkInput {
  const _IssueLinkInput({
    required this.issue,
    required this.relationship,
    required this.reason,
  });

  final MaintenanceRecord issue;
  final OperationalEventIssueRelationship relationship;
  final String reason;
}

class _EventContext extends StatelessWidget {
  const _EventContext({required this.event, required this.currentCount});

  final OperationalEvent event;
  final int currentCount;

  @override
  Widget build(BuildContext context) => _ContextCard(
    icon: Icons.warning_amber_rounded,
    title: event.title,
    lines: [
      '${event.eventType.label} · ${event.severity.label}',
      'Started ${_date(event.startedAt)}',
      '$currentCount linked issue${currentCount == 1 ? '' : 's'} in this occurrence',
    ],
  );
}

class _IssueContext extends StatelessWidget {
  const _IssueContext({required this.issue});

  final MaintenanceRecord issue;

  @override
  Widget build(BuildContext context) => _ContextCard(
    icon: Icons.build_outlined,
    title: issue.description,
    lines: [
      '${issue.assetType.name.toUpperCase()} ${issue.assetNumber}',
      'Routed to ${issue.routedTo.name}',
    ],
  );
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.planned.withValues(alpha: 0.25)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BafColors.planned),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    line,
                    style: const TextStyle(color: BafColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _IssueLinkCard extends StatelessWidget {
  const _IssueLinkCard({required this.link, this.showOccurrence = false});

  final OperationalEventIssueLink link;
  final bool showOccurrence;

  @override
  Widget build(BuildContext context) => _LinkCard(
    icon: Icons.build_circle_outlined,
    title: link.issueDescription,
    badge: link.relationship.label,
    lines: [
      '${link.issueAssetType} ${link.issueAssetNumber} · ${link.issueRoutedTo}',
      if (link.issueComponent != null) link.issueComponent!,
      if (showOccurrence)
        'Event occurrence ${_date(link.eventOccurrenceStartedAt)}',
      'Linked by ${link.linkedByName} on ${_date(link.linkedAt)}',
      link.reason,
    ],
  );
}

class _EventLinkCard extends StatelessWidget {
  const _EventLinkCard({required this.link});

  final OperationalEventIssueLink link;

  @override
  Widget build(BuildContext context) => _LinkCard(
    icon: Icons.warning_amber_rounded,
    title: link.eventTitle,
    badge: link.relationship.label,
    lines: [
      '${link.eventType.label} · ${link.eventSeverity.label}',
      'Occurrence started ${_date(link.eventOccurrenceStartedAt)}',
      'Linked by ${link.linkedByName} on ${_date(link.linkedAt)}',
      link.reason,
    ],
  );
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final String badge;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BafColors.card,
      borderRadius: BorderRadius.circular(BafRadius.medium),
      border: Border.all(color: BafColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: BafColors.maintenance),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: BafColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                badge,
                style: const TextStyle(
                  color: BafColors.maintenance,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    line,
                    style: const TextStyle(
                      color: BafColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: BafColors.textSecondary),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(
          color: BafColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _LinkState extends StatelessWidget {
  const _LinkState({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BafColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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

String _date(DateTime value) =>
    DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());
