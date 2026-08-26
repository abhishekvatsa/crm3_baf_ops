import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/critical_alarm_models.dart';
import '../providers/critical_alarm_providers.dart';
import '../services/critical_alarm_platform_service.dart';
import 'critical_alarm_screen.dart';

class CriticalAlarmHost extends ConsumerStatefulWidget {
  const CriticalAlarmHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<CriticalAlarmHost> createState() => _CriticalAlarmHostState();
}

class _CriticalAlarmHostState extends ConsumerState<CriticalAlarmHost> {
  final Set<String> _notifiedRingingIds = <String>{};
  final Set<String> _notificationAttemptsInFlight = <String>{};
  Set<String> _latestRingingIds = const <String>{};
  StreamSubscription<String>? _openedAlarmSubscription;
  late final ProviderSubscription<AsyncValue<List<CriticalAlarm>>>
  _alarmFeedSubscription;
  String? _pendingOpenedAlarmId;

  @override
  void initState() {
    super.initState();
    final platform = ref.read(criticalAlarmPlatformServiceProvider);
    _openedAlarmSubscription = platform.openedAlarmIds.listen(
      _queueOpenedAlarm,
    );
    _alarmFeedSubscription = ref.listenManual<AsyncValue<List<CriticalAlarm>>>(
      activeCriticalAlarmsProvider,
      (previous, next) {
        next.whenData(_reconcileNotifications);
      },
      fireImmediately: true,
    );
    unawaited(
      platform.initializeAlarmOpenListener().then((alarmId) {
        if (alarmId != null) _queueOpenedAlarm(alarmId);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_openedAlarmSubscription?.cancel());
    _alarmFeedSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final feed = ref.watch(activeCriticalAlarmsProvider);
    final active = feed.asData?.value ?? const <CriticalAlarm>[];
    final primary = active.isEmpty ? null : _primary(active);
    if (user?.isApproved == true && _pendingOpenedAlarmId != null) {
      final alarmId = _pendingOpenedAlarmId;
      _pendingOpenedAlarmId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(initialAlarmId: alarmId);
      });
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            if (primary != null)
              _ActiveAlarmBanner(
                alarm: primary,
                count: active.length,
                onTap: () => _open(initialAlarmId: primary.id),
              ),
            Expanded(child: widget.child),
          ],
        ),
        if (user?.isApproved == true)
          Positioned(
            right: 12,
            bottom: 92,
            child: SafeArea(
              top: false,
              child: Semantics(
                label: 'Critical safety alarms',
                button: true,
                child: FloatingActionButton.small(
                  heroTag: 'global-critical-alarm-launcher',
                  backgroundColor: BafColors.danger,
                  foregroundColor: Colors.white,
                  onPressed: _open,
                  child:
                      active.isEmpty
                          ? const Icon(Icons.notification_important_outlined)
                          : Badge(
                            label: Text('${active.length}'),
                            child: const Icon(Icons.notification_important),
                          ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  CriticalAlarm _primary(List<CriticalAlarm> alarms) {
    final ordered = [...alarms]..sort((left, right) {
      final rank = left.definition.criticalityRank.compareTo(
        right.definition.criticalityRank,
      );
      return rank != 0 ? rank : right.raisedAt.compareTo(left.raisedAt);
    });
    return ordered.first;
  }

  void _open({String? initialAlarmId}) {
    widget.navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => CriticalAlarmScreen(initialAlarmId: initialAlarmId),
      ),
    );
  }

  void _queueOpenedAlarm(String alarmId) {
    final trimmed = alarmId.trim();
    if (!mounted || trimmed.isEmpty) return;
    setState(() => _pendingOpenedAlarmId = trimmed);
  }

  void _reconcileNotifications(List<CriticalAlarm> alarms) {
    final ringing = alarms.where((alarm) => alarm.isRinging).toList();
    final ringingIds = ringing.map((alarm) => alarm.id).toSet();
    _latestRingingIds = ringingIds;
    final platform = ref.read(criticalAlarmPlatformServiceProvider);
    // The verified server set also clears tagged FCM notifications created
    // while this Dart process was not running.
    unawaited(platform.reconcileActiveNotifications(ringingIds));
    for (final alarm in ringing) {
      if (!_notifiedRingingIds.contains(alarm.id) &&
          _notificationAttemptsInFlight.add(alarm.id)) {
        unawaited(_showAndTrackNotification(platform, alarm));
      }
    }
    final noLongerRinging = _notifiedRingingIds.difference(ringingIds).toList();
    for (final alarmId in noLongerRinging) {
      _notifiedRingingIds.remove(alarmId);
      unawaited(platform.cancelNotification(alarmId));
    }
  }

  Future<void> _showAndTrackNotification(
    CriticalAlarmPlatformService platform,
    CriticalAlarm alarm,
  ) async {
    var shown = false;
    try {
      shown = await platform.showActiveNotification(alarm);
    } finally {
      _notificationAttemptsInFlight.remove(alarm.id);
    }
    if (!mounted || !shown) return;
    if (_latestRingingIds.contains(alarm.id)) {
      _notifiedRingingIds.add(alarm.id);
    } else {
      await platform.cancelNotification(alarm.id);
    }
  }
}

class _ActiveAlarmBanner extends StatelessWidget {
  const _ActiveAlarmBanner({
    required this.alarm,
    required this.count,
    required this.onTap,
  });

  final CriticalAlarm alarm;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: BafColors.danger,
    child: SafeArea(
      bottom: false,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.notification_important,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${alarm.definition.name} - ${alarm.location}${count > 1 ? '  +${count - 1} more' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    ),
  );
}
