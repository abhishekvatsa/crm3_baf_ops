import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../data/critical_alarm_repository.dart';
import '../domain/critical_alarm_models.dart';
import '../services/critical_alarm_command_service.dart';
import '../services/critical_alarm_platform_service.dart';

final criticalAlarmRepositoryProvider = Provider<CriticalAlarmRepository>((
  ref,
) {
  return CriticalAlarmRepository(FirebaseFirestore.instance);
});

final criticalAlarmCommandServiceProvider =
    Provider<CriticalAlarmCommandService>(
      (ref) => CriticalAlarmCommandService(
        connectivity: Connectivity(),
        gateway: ref.read(workflowCommandGatewayProvider),
      ),
    );

final criticalAlarmPlatformServiceProvider =
    Provider<CriticalAlarmPlatformService>(
      (ref) => const CriticalAlarmPlatformService(),
    );

final criticalAlarmFeedProvider = StreamProvider<List<CriticalAlarm>>((ref) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null || !user.isApproved) {
    return Stream.value(const <CriticalAlarm>[]);
  }
  return ref.watch(criticalAlarmRepositoryProvider).watchAlarms();
});

final activeCriticalAlarmsProvider = StreamProvider<List<CriticalAlarm>>((ref) {
  final user = ref.watch(currentAppUserProvider).asData?.value;
  if (user == null || !user.isApproved) {
    return Stream.value(const <CriticalAlarm>[]);
  }
  return ref.watch(criticalAlarmRepositoryProvider).watchActiveAlarms();
});

final criticalAlarmContactsProvider =
    StreamProvider<List<CriticalAlarmContact>>((ref) {
      final user = ref.watch(currentAppUserProvider).asData?.value;
      if (user == null || !user.isApproved) {
        return Stream.value(const <CriticalAlarmContact>[]);
      }
      return ref.watch(criticalAlarmRepositoryProvider).watchContacts();
    });
