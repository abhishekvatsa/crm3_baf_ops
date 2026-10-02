import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/critical_alarm_models.dart';
import '../providers/critical_alarm_providers.dart';
import '../services/critical_alarm_platform_service.dart';
import 'critical_alarm_screen.dart';

class CriticalAlarmLauncherRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> obscured = ValueNotifier<bool>(false);

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    obscured.value =
        topRoute is PopupRoute<dynamic> ||
        topRoute.settings.name == CriticalAlarmScreen.routeName;
  }

  void dispose() => obscured.dispose();
}

class CriticalAlarmHost extends ConsumerStatefulWidget {
  const CriticalAlarmHost({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.launcherObscuredListenable,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  final ValueListenable<bool>? launcherObscuredListenable;

  @override
  ConsumerState<CriticalAlarmHost> createState() => _CriticalAlarmHostState();
}

class _CriticalAlarmHostState extends ConsumerState<CriticalAlarmHost>
    with WidgetsBindingObserver {
  static const _initialFeedWarningDelay = Duration(seconds: 12);
  final Set<String> _notifiedRingingIds = <String>{};
  final Set<String> _notificationAttemptsInFlight = <String>{};
  Set<String> _latestRingingIds = const <String>{};
  Map<String, CriticalAlarm> _latestRingingAlarms =
      const <String, CriticalAlarm>{};
  final Map<String, CriticalAlarm> _partiallyObservedRingingAlarms =
      <String, CriticalAlarm>{};
  bool _liveAlarmStateVerified = false;
  bool _showUnverifiedAlarmBanner = false;
  String? _verifiedAlarmActorUid;
  Timer? _initialFeedWarningTimer;
  StreamSubscription<String>? _openedAlarmSubscription;
  late final ProviderSubscription<AsyncValue<AppUser?>> _alarmActorSubscription;
  late final ProviderSubscription<AsyncValue<CriticalAlarmLiveSnapshot>>
  _alarmFeedSubscription;
  late final CriticalAlarmPlatformService _alarmPlatform;
  AppUser? _latestAlarmActor;
  CriticalAlarmLiveSnapshot? _latestAlarmSnapshot;
  String? _pendingOpenedAlarmId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alarmPlatform = ref.read(criticalAlarmPlatformServiceProvider);
    _openedAlarmSubscription = _alarmPlatform.openedAlarmIds.listen(
      _queueOpenedAlarm,
    );
    _alarmActorSubscription = ref.listenManual<AsyncValue<AppUser?>>(
      currentAppUserProvider,
      (previous, next) {
        final actor = next.asData?.value;
        _latestAlarmActor = actor;
        if (actor?.isApproved != true) {
          _verifiedAlarmActorUid = null;
          _liveAlarmStateVerified = false;
          _hideUnverifiedAlarmWarning();
          return;
        }
        final snapshot = _latestAlarmSnapshot;
        if (snapshot?.isServerVerified == true) {
          _verifiedAlarmActorUid = actor!.uid;
          _liveAlarmStateVerified = true;
          _hideUnverifiedAlarmWarning();
          return;
        }
        _liveAlarmStateVerified = false;
        _scheduleInitialFeedWarning();
      },
      fireImmediately: true,
    );
    _alarmFeedSubscription = ref
        .listenManual<AsyncValue<CriticalAlarmLiveSnapshot>>(
          activeCriticalAlarmsProvider,
          (previous, next) {
            final snapshot = next.asData?.value;
            _latestAlarmSnapshot = snapshot;
            if (snapshot?.isServerVerified == true) {
              final actor = _latestAlarmActor;
              _verifiedAlarmActorUid = actor?.isApproved == true
                  ? actor!.uid
                  : null;
              _liveAlarmStateVerified = true;
              _hideUnverifiedAlarmWarning();
              _reconcileNotifications(snapshot!.alarms);
              return;
            }
            if (snapshot?.authority ==
                CriticalAlarmFeedAuthority.partiallyVerified) {
              _notifyPartiallyVerified(snapshot!.alarms);
            }
            _liveAlarmStateVerified = false;
            final actor = _latestAlarmActor;
            final actorUid = actor?.isApproved == true ? actor!.uid : null;
            if (actorUid != null && actorUid == _verifiedAlarmActorUid) {
              _showUnverifiedAlarmWarningNow();
            } else {
              _scheduleInitialFeedWarning();
            }
          },
          fireImmediately: true,
        );
    unawaited(
      _alarmPlatform.initializeAlarmOpenListener().then((alarmId) {
        if (alarmId != null) _queueOpenedAlarm(alarmId);
      }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _initialFeedWarningTimer?.cancel();
    unawaited(_openedAlarmSubscription?.cancel());
    _alarmActorSubscription.close();
    _alarmFeedSubscription.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_liveAlarmStateVerified) {
      final snapshot = _latestAlarmSnapshot;
      if (_latestAlarmActor?.isApproved == true &&
          snapshot?.authority == CriticalAlarmFeedAuthority.partiallyVerified) {
        // Settings may have made notifications available since this partial
        // server snapshot arrived. Retry its valid additions, without using
        // an incomplete population to cancel any other alarm's notification.
        _notifyPartiallyVerified(snapshot!.alarms);
      }
      return;
    }
    unawaited(_alarmPlatform.reconcileActiveNotifications(_latestRingingIds));
    for (final alarm in _latestRingingAlarms.values) {
      _attemptNotification(_alarmPlatform, alarm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentAppUserProvider).asData?.value;
    final feed = ref.watch(activeCriticalAlarmsProvider);
    final liveSnapshot = feed.asData?.value;
    final active = liveSnapshot?.alarms ?? const <CriticalAlarm>[];
    final isServerVerified =
        !feed.isLoading &&
        !feed.hasError &&
        liveSnapshot?.isServerVerified == true;
    final primary = !isServerVerified || active.isEmpty
        ? null
        : _primary(active);
    final launcherColor = !isServerVerified
        ? BafColors.warning
        : active.isEmpty
        ? BafColors.graphiteSoft
        : BafColors.danger;
    final launcherStatus = !isServerVerified
        ? 'Live status not verified.'
        : active.isEmpty
        ? 'No active alarms.'
        : '${active.length} active ${active.length == 1 ? 'alarm' : 'alarms'}.';
    final showUnverifiedBanner =
        user?.isApproved == true &&
        _showUnverifiedAlarmBanner &&
        (feed.isLoading || feed.hasError || !isServerVerified);
    if (user?.isApproved == true && _pendingOpenedAlarmId != null) {
      final alarmId = _pendingOpenedAlarmId;
      _pendingOpenedAlarmId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(initialAlarmId: alarmId);
      });
    }
    Widget layout(bool obscured) {
      final showLauncher = user?.isApproved == true && !obscured;
      final hasBanner = primary != null || showUnverifiedBanner;
      // Navigator routes block semantics painted before them. Lay out upward
      // so the reserved header stays visually at the top but paints after the
      // Navigator, preserving safety access in the platform accessibility tree.
      final content = Column(
        verticalDirection: VerticalDirection.up,
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeTop: hasBanner || showLauncher,
              child: widget.child,
            ),
          ),
          if (showLauncher)
            SafeArea(
              top: !hasBanner,
              bottom: false,
              child: _SafetyAccessRow(
                status: launcherStatus,
                color: launcherColor,
                unverified: !isServerVerified,
                onTap: _open,
              ),
            ),
          if (showUnverifiedBanner)
            _UnverifiedAlarmBanner(lastKnownCount: active.length, onTap: _open),
          if (primary != null)
            _ActiveAlarmBanner(
              alarm: primary,
              count: active.length,
              onTap: () => _open(initialAlarmId: primary.id),
            ),
        ],
      );
      if (!hasBanner && !showLauncher) return content;
      final topColor = hasBanner ? launcherColor : BafColors.surfaceRaised;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        key: const Key('critical-safety-system-ui'),
        value:
            (hasBanner ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: topColor),
        child: ColoredBox(color: topColor, child: content),
      );
    }

    final obscured = widget.launcherObscuredListenable;
    return obscured == null
        ? layout(false)
        : ValueListenableBuilder<bool>(
            valueListenable: obscured,
            builder: (context, value, _) => layout(value),
          );
  }

  void _scheduleInitialFeedWarning() {
    if (_initialFeedWarningTimer?.isActive == true) return;
    _initialFeedWarningTimer = Timer(_initialFeedWarningDelay, () {
      _initialFeedWarningTimer = null;
      if (!mounted) return;
      if (_latestAlarmActor?.isApproved == true && !_liveAlarmStateVerified) {
        _showUnverifiedAlarmWarningNow();
      }
    });
  }

  void _showUnverifiedAlarmWarningNow() {
    _initialFeedWarningTimer?.cancel();
    _initialFeedWarningTimer = null;
    if (!mounted || _showUnverifiedAlarmBanner) return;
    setState(() => _showUnverifiedAlarmBanner = true);
  }

  void _hideUnverifiedAlarmWarning() {
    _initialFeedWarningTimer?.cancel();
    _initialFeedWarningTimer = null;
    if (!mounted || !_showUnverifiedAlarmBanner) return;
    setState(() => _showUnverifiedAlarmBanner = false);
  }

  CriticalAlarm _primary(List<CriticalAlarm> alarms) {
    final ordered = [...alarms]
      ..sort((left, right) {
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
        settings: const RouteSettings(name: CriticalAlarmScreen.routeName),
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
    if (!mounted) return;
    final ringing = alarms.where((alarm) => alarm.isRinging).toList();
    _partiallyObservedRingingAlarms.clear();
    final ringingIds = ringing.map((alarm) => alarm.id).toSet();
    _latestRingingIds = ringingIds;
    _latestRingingAlarms = {for (final alarm in ringing) alarm.id: alarm};
    // The verified server set also clears tagged FCM notifications created
    // while this Dart process was not running.
    unawaited(_alarmPlatform.reconcileActiveNotifications(ringingIds));
    for (final alarm in ringing) {
      _attemptNotification(_alarmPlatform, alarm);
    }
    final noLongerRinging = _notifiedRingingIds.difference(ringingIds).toList();
    for (final alarmId in noLongerRinging) {
      _notifiedRingingIds.remove(alarmId);
      unawaited(_alarmPlatform.cancelNotification(alarmId));
    }
  }

  void _notifyPartiallyVerified(List<CriticalAlarm> alarms) {
    if (!mounted) return;
    for (final alarm in alarms) {
      if (!alarm.isRinging) {
        // Positive same-ID terminal evidence is safe to apply even though the
        // rest of the population is incomplete. Never infer anything about
        // IDs absent from this partial snapshot.
        _partiallyObservedRingingAlarms.remove(alarm.id);
        _latestRingingIds = {..._latestRingingIds}..remove(alarm.id);
        _latestRingingAlarms = {..._latestRingingAlarms}..remove(alarm.id);
        _notifiedRingingIds.remove(alarm.id);
        unawaited(_alarmPlatform.cancelNotification(alarm.id));
        continue;
      }
      // A partial snapshot may contain a genuine new alarm, but it is not a
      // safe basis for global reconciliation or cancellation. Retain only
      // the additions we actually observed so their notification can finish
      // without allowing this snapshot to remove another alarm's notice.
      _partiallyObservedRingingAlarms[alarm.id] = alarm;
      _attemptNotification(_alarmPlatform, alarm);
    }
  }

  void _attemptNotification(
    CriticalAlarmPlatformService platform,
    CriticalAlarm alarm,
  ) {
    if (!_notifiedRingingIds.contains(alarm.id) &&
        _notificationAttemptsInFlight.add(alarm.id)) {
      unawaited(_showAndTrackNotification(platform, alarm));
    }
  }

  Future<void> _showAndTrackNotification(
    CriticalAlarmPlatformService platform,
    CriticalAlarm alarm,
  ) async {
    final originActorUid = _latestAlarmActor?.uid;
    try {
      final ready = await platform.isNotificationReady();
      if (!ready || !_canPostNotification(alarm, originActorUid)) {
        return;
      }
      final shown = await platform.showActiveNotification(alarm);
      if (!shown) return;
      // Native posting also awaits. A newer same-ID server row may have
      // arrived while it was in progress, even in a partial snapshot.
      if (_canPostNotification(alarm, originActorUid)) {
        _notifiedRingingIds.add(alarm.id);
      } else {
        await platform.cancelNotification(alarm.id);
      }
    } finally {
      _notificationAttemptsInFlight.remove(alarm.id);
      final current = _currentRingingAlarm(alarm.id);
      if (current != null &&
          (current.version != alarm.version ||
              current.updatedAt != alarm.updatedAt) &&
          _canPostNotification(current, originActorUid)) {
        // A newer ringing revision was held back by this in-flight attempt.
        // Give that revision its own attempt once stale posting is settled.
        _attemptNotification(platform, current);
      }
    }
  }

  CriticalAlarm? _currentRingingAlarm(String alarmId) =>
      _partiallyObservedRingingAlarms[alarmId] ?? _latestRingingAlarms[alarmId];

  bool _canPostNotification(CriticalAlarm alarm, String? originActorUid) {
    final actor = _latestAlarmActor;
    final current = _currentRingingAlarm(alarm.id);
    if (!mounted ||
        originActorUid == null ||
        actor?.uid != originActorUid ||
        actor?.isApproved != true) {
      return false;
    }
    return current?.isRinging == true &&
        current!.version == alarm.version &&
        current.updatedAt == alarm.updatedAt;
  }
}

// Reserved layout space keeps safety access available without covering any
// route's controls. Opening this row only opens the governed alarm workspace.
class _SafetyAccessRow extends StatelessWidget {
  const _SafetyAccessRow({
    required this.status,
    required this.color,
    required this.unverified,
    required this.onTap,
  });

  final String status;
  final Color color;
  final bool unverified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: BafColors.surfaceRaised,
    child: Semantics(
      key: const Key('global-critical-alarm-launcher'),
      container: true,
      label: 'Critical safety alarms. $status',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: BafColors.border)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: BafSpacing.md,
            vertical: BafSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                unverified
                    ? Icons.cloud_off_outlined
                    : Icons.notification_important_outlined,
                color: color,
                size: 22,
              ),
              const SizedBox(width: BafSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Safety alarms',
                      style: TextStyle(
                        color: BafColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(status, style: TextStyle(color: color, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: BafSpacing.sm),
              const Icon(Icons.chevron_right, color: BafColors.textSecondary),
            ],
          ),
        ),
      ),
    ),
  );
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

class _UnverifiedAlarmBanner extends StatelessWidget {
  const _UnverifiedAlarmBanner({
    required this.lastKnownCount,
    required this.onTap,
  });

  final int lastKnownCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: BafColors.warning,
    child: SafeArea(
      bottom: false,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lastKnownCount == 0
                      ? 'Critical alarm feed is not live'
                      : 'Critical alarm feed is not live - '
                            '$lastKnownCount last-known active '
                            '${lastKnownCount == 1 ? 'alarm' : 'alarms'}',
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
