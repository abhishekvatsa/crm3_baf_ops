import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/baf_design_system.dart';
import '../../auth/providers/auth_provider.dart';
import '../domain/critical_alarm_models.dart';
import '../providers/critical_alarm_providers.dart';
import '../services/critical_alarm_platform_service.dart';
import 'critical_alarm_screen.dart';

class CriticalAlarmLauncherRouteObserver extends NavigatorObserver {
  final ValueNotifier<bool> obscured = ValueNotifier<bool>(false);

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    obscured.value = topRoute is PopupRoute<dynamic>;
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
  static const _launcherXKey = 'critical_alarm_launcher_x_fraction_v1';
  static const _launcherYKey = 'critical_alarm_launcher_y_fraction_v1';
  static const _launcherSize = 48.0;
  static const _launcherMargin = 12.0;
  final Set<String> _notifiedRingingIds = <String>{};
  final Set<String> _notificationAttemptsInFlight = <String>{};
  Set<String> _latestRingingIds = const <String>{};
  Map<String, CriticalAlarm> _latestRingingAlarms =
      const <String, CriticalAlarm>{};
  bool _liveAlarmStateVerified = false;
  StreamSubscription<String>? _openedAlarmSubscription;
  late final ProviderSubscription<AsyncValue<List<CriticalAlarm>>>
  _alarmFeedSubscription;
  String? _pendingOpenedAlarmId;
  Offset _launcherFraction = const Offset(1, 0.78);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final platform = ref.read(criticalAlarmPlatformServiceProvider);
    _openedAlarmSubscription = platform.openedAlarmIds.listen(
      _queueOpenedAlarm,
    );
    _alarmFeedSubscription = ref.listenManual<AsyncValue<List<CriticalAlarm>>>(
      activeCriticalAlarmsProvider,
      (previous, next) {
        final verified = next.asData;
        if (verified == null) {
          _liveAlarmStateVerified = false;
          _latestRingingIds = const <String>{};
          _latestRingingAlarms = const <String, CriticalAlarm>{};
          return;
        }
        _liveAlarmStateVerified = true;
        _reconcileNotifications(verified.value);
      },
      fireImmediately: true,
    );
    unawaited(
      platform.initializeAlarmOpenListener().then((alarmId) {
        if (alarmId != null) _queueOpenedAlarm(alarmId);
      }),
    );
    unawaited(_restoreLauncherPosition());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_openedAlarmSubscription?.cancel());
    _alarmFeedSubscription.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_liveAlarmStateVerified) return;
    final platform = ref.read(criticalAlarmPlatformServiceProvider);
    unawaited(platform.reconcileActiveNotifications(_latestRingingIds));
    for (final alarm in _latestRingingAlarms.values) {
      _attemptNotification(platform, alarm);
    }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final bounds = _launcherBounds(
          constraints,
          media,
          hasBanner: primary != null,
        );
        final launcherOffset = Offset(
          bounds.left + bounds.width * _launcherFraction.dx,
          bounds.top + bounds.height * _launcherFraction.dy,
        );
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
                left: launcherOffset.dx,
                top: launcherOffset.dy,
                child: _LauncherModalGuard(
                  obscuredListenable: widget.launcherObscuredListenable,
                  child: SafeArea(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final next = Offset(
                          (launcherOffset.dx + details.delta.dx).clamp(
                            bounds.left,
                            bounds.right,
                          ),
                          (launcherOffset.dy + details.delta.dy).clamp(
                            bounds.top,
                            bounds.bottom,
                          ),
                        );
                        setState(() {
                          _launcherFraction = Offset(
                            bounds.width == 0
                                ? 0
                                : (next.dx - bounds.left) / bounds.width,
                            bounds.height == 0
                                ? 0
                                : (next.dy - bounds.top) / bounds.height,
                          );
                        });
                      },
                      onPanEnd: (_) => unawaited(_saveLauncherPosition()),
                      child: Semantics(
                        key: const Key('global-critical-alarm-launcher'),
                        label: 'Critical safety alarms. Drag to reposition.',
                        button: true,
                        child: FloatingActionButton.small(
                          heroTag: 'global-critical-alarm-launcher',
                          backgroundColor: BafColors.danger,
                          foregroundColor: Colors.white,
                          onPressed: _open,
                          child:
                              active.isEmpty
                                  ? const Icon(
                                    Icons.notification_important_outlined,
                                  )
                                  : Badge(
                                    label: Text('${active.length}'),
                                    child: const Icon(
                                      Icons.notification_important,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Rect _launcherBounds(
    BoxConstraints constraints,
    MediaQueryData media, {
    required bool hasBanner,
  }) {
    const left = _launcherMargin;
    final top = media.padding.top + _launcherMargin + (hasBanner ? 52 : 0);
    final right = (constraints.maxWidth - _launcherSize - _launcherMargin)
        .clamp(left, double.infinity);
    final bottom = (constraints.maxHeight -
            media.padding.bottom -
            _launcherSize -
            84)
        .clamp(top, double.infinity);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Future<void> _restoreLauncherPosition() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final x = preferences.getDouble(_launcherXKey);
      final y = preferences.getDouble(_launcherYKey);
      if (!mounted || x == null || y == null) return;
      setState(() => _launcherFraction = Offset(x.clamp(0, 1), y.clamp(0, 1)));
    } catch (_) {
      // Position persistence is cosmetic; alarm access must remain available.
    }
  }

  Future<void> _saveLauncherPosition() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_launcherXKey, _launcherFraction.dx);
      await preferences.setDouble(_launcherYKey, _launcherFraction.dy);
    } catch (_) {
      // Position persistence is cosmetic; alarm access must remain available.
    }
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
    _latestRingingAlarms = {for (final alarm in ringing) alarm.id: alarm};
    final platform = ref.read(criticalAlarmPlatformServiceProvider);
    // The verified server set also clears tagged FCM notifications created
    // while this Dart process was not running.
    unawaited(platform.reconcileActiveNotifications(ringingIds));
    for (final alarm in ringing) {
      _attemptNotification(platform, alarm);
    }
    final noLongerRinging = _notifiedRingingIds.difference(ringingIds).toList();
    for (final alarmId in noLongerRinging) {
      _notifiedRingingIds.remove(alarmId);
      unawaited(platform.cancelNotification(alarmId));
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

class _LauncherModalGuard extends StatelessWidget {
  const _LauncherModalGuard({
    required this.obscuredListenable,
    required this.child,
  });

  final ValueListenable<bool>? obscuredListenable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = obscuredListenable;
    if (listenable == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder:
          (context, obscured, child) =>
              obscured ? const SizedBox.shrink() : child!,
      child: child,
    );
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
