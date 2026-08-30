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
  });

  final List<CriticalAlarm> alarms;
  final AsyncValue<List<CriticalAlarm>> feed;
  final AsyncValue<List<CriticalAlarmContact>> contacts;
  final AppUser? user;
  final String emptyTitle;
  final String? initialAlarmId;
  final CriticalAlarmFeedAuthority? liveAuthority;
  final DateTime? lastVerifiedAt;

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
      final stale =
          liveAuthority == CriticalAlarmFeedAuthority.staleLastKnown;
      return CriticalAlarmFeedState(
        icon: stale ? Icons.cloud_off_outlined : Icons.verified_user_outlined,
        title: stale ? 'Active alarm state is stale' : emptyTitle,
        message:
            stale
                ? 'The last server-verified set is no longer live. Do not '
                    'infer that no alarm exists. Follow the plant emergency '
                    'procedure.'
                : 'Only server-confirmed alarm records appear here. Continue '
                    'to follow normal plant safety procedures.',
      );
    }
    final ordered = [...alarms]..sort((left, right) {
      if (left.id == initialAlarmId) return -1;
      if (right.id == initialAlarmId) return 1;
      return right.raisedAt.compareTo(left.raisedAt);
    });
    final showStaleHeader =
        liveAuthority == CriticalAlarmFeedAuthority.staleLastKnown;
    return RefreshIndicator(
      onRefresh: () async => _retry(ref),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          BafSpacing.md,
          BafSpacing.md,
          BafSpacing.md,
          96,
        ),
        itemCount: ordered.length + (showStaleHeader ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: BafSpacing.md),
        itemBuilder: (context, index) {
          if (showStaleHeader && index == 0) {
            return CriticalAlarmStaleNotice(
              count: ordered.length,
              lastVerifiedAt: lastVerifiedAt,
            );
          }
          final alarm = ordered[index - (showStaleHeader ? 1 : 0)];
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
            lifecycleActionsEnabled:
                liveAuthority == null ||
                liveAuthority == CriticalAlarmFeedAuthority.serverVerified,
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
