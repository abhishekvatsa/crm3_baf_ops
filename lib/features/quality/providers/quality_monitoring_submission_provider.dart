import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/quality_command_service.dart';
import '../services/quality_monitoring_submission_controller.dart';

final qualityMonitoringSubmissionControllerProvider =
    Provider<QualityMonitoringSubmissionController>((ref) {
      final client = FirebaseFunctions.instanceFor(
        region: qualityCommandCallableRegion,
      );
      final capabilities = CommandCapabilityService(functions: client);
      return QualityMonitoringSubmissionController(
        store: ref.watch(durableSubmissionRepositoryProvider),
        projectId: client.app.options.projectId,
        requireActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          if (!access.isReady) throw QualityCommandException(access.message);
          return access.actor!;
        },
        requireCapability: (uid) async {
          await capabilities.requireCapabilities(
            callableName: qualityMonitoringV2CallableName,
            originActorUid: uid,
            requiredCapabilities: const {
              'chargeAbnormality.v2',
              'qualityMonitoring.v1',
            },
          );
        },
        invoke: (envelope) async =>
            (await client
                    .httpsCallable(qualityMonitoringV2CallableName)
                    .call<Map<String, dynamic>>(envelope))
                .data,
        readFromServer: (id) async {
          final snapshot = await FirebaseFirestore.instanceFor(app: client.app)
              .collection('quality_monitoring_requests')
              .doc(id)
              .get(const GetOptions(source: Source.server));
          if (snapshot.metadata.isFromCache ||
              snapshot.metadata.hasPendingWrites ||
              !snapshot.exists ||
              snapshot.data() == null) {
            throw const QualityCommandException(
              'The server monitoring record is not yet available.',
            );
          }
          return snapshot.data()!;
        },
      );
    });
