part of 'critical_alarm_screen.dart';

class _AlarmList extends ConsumerWidget {
  const _AlarmList({
    required this.alarms,
    required this.feed,
    required this.contacts,
    required this.user,
    required this.emptyTitle,
    this.initialAlarmId,
    this.liveAuthority,
    this.lastVerifiedAt,
    this.malformedDocumentCount = 0,
  });

  final List<CriticalAlarm> alarms;
  final AsyncValue<List<CriticalAlarm>> feed;
  final AsyncValue<CriticalAlarmContactsSnapshot> contacts;
  final AppUser? user;
  final String emptyTitle;
  final String? initialAlarmId;
  final CriticalAlarmFeedAuthority? liveAuthority;
  final DateTime? lastVerifiedAt;
  final int malformedDocumentCount;

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
          onPressed: () => _retry(ref),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry live check'),
        ),
      );
    }
    if (liveAuthority == CriticalAlarmFeedAuthority.unavailable) {
      return CriticalAlarmFeedState(
        icon: Icons.cloud_off_outlined,
        title: 'Live alarm state unavailable',
        message:
            'The server has not verified the active-alarm set. Do not infer '
            'that no alarm exists. Follow the plant emergency procedure.',
        action: OutlinedButton.icon(
          onPressed: () => _retry(ref),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry live check'),
        ),
      );
    }
    if (alarms.isEmpty) {
      final stale = liveAuthority == CriticalAlarmFeedAuthority.staleLastKnown;
      final incomplete =
          liveAuthority == CriticalAlarmFeedAuthority.partiallyVerified;
      if (incomplete) {
        return CriticalAlarmFeedState(
          icon: Icons.warning_amber_outlined,
          title: 'Active alarm snapshot incomplete',
          message:
              'The server returned no valid alarm rows, but '
              '$malformedDocumentCount record(s) could not be read. Do not '
              'infer that no alarm exists. Follow the plant emergency '
              'procedure and retry the live check.',
          action: OutlinedButton.icon(
            onPressed: () => _retry(ref),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry live check'),
          ),
        );
      }
      return CriticalAlarmFeedState(
        icon: stale ? Icons.cloud_off_outlined : Icons.verified_user_outlined,
        title: stale ? 'Active alarm state is stale' : emptyTitle,
        message: stale
            ? 'The last server-verified set is no longer live. Do not '
                  'infer that no alarm exists. Follow the plant emergency '
                  'procedure.'
            : 'Only server-confirmed alarm records appear here. Continue '
                  'to follow normal plant safety procedures.',
      );
    }
    final ordered = [...alarms]
      ..sort((left, right) {
        if (left.id == initialAlarmId) return -1;
        if (right.id == initialAlarmId) return 1;
        return right.raisedAt.compareTo(left.raisedAt);
      });
    final showStaleHeader =
        liveAuthority == CriticalAlarmFeedAuthority.staleLastKnown;
    final showFeedWarning = showStaleHeader || malformedDocumentCount > 0;
    return RefreshIndicator(
      onRefresh: () async => _retry(ref),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.md,
          BafSpacing.md,
          BafSpacing.md,
          96,
        ),
        itemCount: ordered.length + (showFeedWarning ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.md),
        itemBuilder: (context, index) {
          if (showFeedWarning && index == 0) {
            return CriticalAlarmStaleNotice(
              count: ordered.length,
              lastVerifiedAt: lastVerifiedAt,
              incompleteCount: malformedDocumentCount,
            );
          }
          final alarm = ordered[index - (showFeedWarning ? 1 : 0)];
          final contactSnapshot = contacts.asData?.value;
          final exactContacts =
              contactSnapshot?.contacts
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
            contactsVerified: contactSnapshot?.isComplete == true,
            user: user,
            lifecycleActionsEnabled:
                liveAuthority == null ||
                liveAuthority == CriticalAlarmFeedAuthority.serverVerified ||
                liveAuthority == CriticalAlarmFeedAuthority.partiallyVerified,
          );
        },
      ),
    );
  }

  void _retry(WidgetRef ref) {
    ref.invalidate(criticalAlarmFeedProvider);
    ref.invalidate(activeCriticalAlarmsProvider);
    ref.invalidate(criticalAlarmContactsProvider);
  }
}
