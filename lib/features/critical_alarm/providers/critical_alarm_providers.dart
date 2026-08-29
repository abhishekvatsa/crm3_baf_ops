import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/actor_session_cache_trust.dart';
import '../../auth/data/user_model.dart';
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

final criticalAlarmReportCacheTrustProvider = Provider<ActorSessionCacheTrust>((
  ref,
) {
  final trust = ActorSessionCacheTrust();

  void observeAuthority(AsyncValue<AppUser?> authority) {
    if (authority.isLoading || authority.hasError) {
      trust.observeActor(null);
      return;
    }
    final actor = authority.value;
    trust.observeActor(
      actor != null && actor.canViewReports ? actor.uid : null,
    );
  }

  observeAuthority(ref.read(currentAppUserProvider));
  ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (_, next) {
    observeAuthority(next);
  });
  return trust;
});

final criticalAlarmFeedProvider = StreamProvider<List<CriticalAlarm>>((ref) {
  return ref
      .watch(currentAppUserProvider)
      .when(
        data: (user) {
          if (user == null || !user.isApproved) {
            return Stream.value(const <CriticalAlarm>[]);
          }
          return ref.watch(criticalAlarmRepositoryProvider).watchAlarms();
        },
        loading: () => const Stream<List<CriticalAlarm>>.empty(),
        error: Stream<List<CriticalAlarm>>.error,
      );
});

final criticalAlarmsForReportsProvider = StreamProvider.autoDispose
    .family<List<CriticalAlarm>, String>((ref, actorUid) {
      final actorAsync = ref.watch(currentAppUserProvider);
      if (actorAsync.isLoading) {
        throw StateError(
          'Critical-alarm report access is still being verified.',
        );
      }
      if (actorAsync.hasError) {
        throw StateError('Critical-alarm report access could not be verified.');
      }
      final actor = actorAsync.value;
      if (actor == null ||
          !actor.canViewReports ||
          actor.uid != actorUid ||
          actorUid.trim().isEmpty) {
        throw StateError('Approved critical-alarm report access is required.');
      }
      return ref
          .watch(criticalAlarmRepositoryProvider)
          .watchAlarmsForReports(
            trust: ref.watch(criticalAlarmReportCacheTrustProvider)
              ..observeActor(actorUid),
            actorUid: actorUid,
          );
    });

final activeCriticalAlarmsProvider = StreamProvider<List<CriticalAlarm>>((ref) {
  return ref
      .watch(currentAppUserProvider)
      .when(
        data: (user) {
          if (user == null || !user.isApproved) {
            return Stream.value(const <CriticalAlarm>[]);
          }
          return ref.watch(criticalAlarmRepositoryProvider).watchActiveAlarms();
        },
        loading: () => const Stream<List<CriticalAlarm>>.empty(),
        error: Stream<List<CriticalAlarm>>.error,
      );
});

final criticalAlarmContactsProvider =
    StreamProvider<List<CriticalAlarmContact>>((ref) {
      return ref
          .watch(currentAppUserProvider)
          .when(
            data: (user) {
              if (user == null || !user.isApproved) {
                return Stream.value(const <CriticalAlarmContact>[]);
              }
              return ref.watch(criticalAlarmRepositoryProvider).watchContacts();
            },
            loading: () => const Stream<List<CriticalAlarmContact>>.empty(),
            error: Stream<List<CriticalAlarmContact>>.error,
          );
    });

final criticalAlarmDefinitionsProvider =
    StreamProvider<List<CriticalAlarmDefinition>>((ref) {
      return ref
          .watch(currentAppUserProvider)
          .when(
            data: (user) {
              if (user == null || !user.isApproved) {
                return Stream.value(const <CriticalAlarmDefinition>[]);
              }
              return ref
                  .watch(criticalAlarmRepositoryProvider)
                  .watchDefinitions();
            },
            loading: () => const Stream<List<CriticalAlarmDefinition>>.empty(),
            error: Stream<List<CriticalAlarmDefinition>>.error,
          );
    });
