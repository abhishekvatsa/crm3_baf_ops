import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/providers/durable_submission_provider.dart';
import '../../../core/release/command_capability_service.dart';
import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/operational_event_amendment_repository.dart';
import '../services/operational_event_amendment_service.dart';
import '../services/operational_event_service.dart';

final operationalEventAmendmentRepositoryProvider =
    Provider<OperationalEventAmendmentRepository>(
      (ref) => OperationalEventAmendmentRepository(
        firestore: FirebaseFirestore.instance,
      ),
    );

final operationalEventAmendmentServiceProvider =
    Provider<OperationalEventAmendmentService>((ref) {
      AppUser actor() {
        final state = ref.read(currentAppUserProvider);
        final value = state.valueOrNull;
        if (state.isLoading ||
            state.hasError ||
            value == null ||
            !value.isApproved ||
            !(value.isAdmin || value.isSI)) {
          throw const OperationalEventCommandException(
            'An approved Admin or SI account is required.',
            code: 'unauthenticated',
          );
        }
        return value;
      }

      final capability = CommandCapabilityService(
        currentActorUid: () => actor().uid,
      );
      return OperationalEventAmendmentService(
        store: ref.watch(durableSubmissionRepositoryProvider),
        requireActor: actor,
        requireCapability: (uid) async {
          await capability.requireCapabilities(
            callableName: 'mutateAssetHierarchyV2',
            originActorUid: uid,
            requiredCapabilities: {operationalEventAmendmentCapability},
          );
        },
        invoke: (envelope) async {
          try {
            final result =
                await FirebaseFunctions.instanceFor(region: 'asia-south1')
                    .httpsCallable('mutateAssetHierarchyV2')
                    .call(durableSubmissionJsonObject(envelope));
            if (result.data is! Map) {
              throw const FormatException('The amendment response is invalid.');
            }
            return Map<String, dynamic>.from(result.data as Map);
          } on FirebaseFunctionsException catch (error) {
            throw OperationalEventCommandException(
              error.message ?? 'The closure amendment could not be confirmed.',
              code: error.code,
              details: error.details,
            );
          }
        },
        confirmReadback: ref
            .read(operationalEventAmendmentRepositoryProvider)
            .confirmReadback,
      );
    });
