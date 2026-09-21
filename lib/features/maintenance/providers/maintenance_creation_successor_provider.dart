import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/durable_submission_provider.dart';
import '../../auth/domain/current_actor_access.dart';
import '../../auth/providers/auth_provider.dart';
import '../../maintenance_workflow/providers/workflow_providers.dart';
import '../domain/maintenance_creation_successor_review.dart';
import '../repositories/maintenance_creation_successor_repository.dart';
import '../services/maintenance_creation_successor_service.dart';
import 'maintenance_provider.dart';

final maintenanceCreationSuccessorServiceProvider =
    Provider<MaintenanceCreationSuccessorService>((ref) {
      final store = ref.watch(durableSubmissionRepositoryProvider);
      return MaintenanceCreationSuccessorService(
        repository: MaintenanceCreationSuccessorRepository(
          isar: store.isar,
          workflow: ref.read(workflowRepositoryProvider),
          readServer: ref
              .read(firestoreMaintenanceRepo)
              .readMaintenanceIssueCommandServerState,
          readCorrectionAudit: (id) async {
            final doc = await FirebaseFirestore.instance
                .collection('audit_logs')
                .doc(id)
                .get(const GetOptions(source: Source.server));
            if (!doc.exists ||
                doc.data() == null ||
                doc.metadata.isFromCache ||
                doc.metadata.hasPendingWrites) {
              throw StateError(
                'The immutable correction audit could not be confirmed from the server.',
              );
            }
            return doc.data()!;
          },
        ),
        store: store,
        gateway: ref.read(originBoundWorkflowCommandGatewayProvider),
        currentActor: () {
          final access = CurrentActorAccess.resolve(
            ref.read(currentAppUserProvider),
          );
          final actor = access.actor;
          if (actor == null ||
              ref.read(firebaseAuthProvider).currentUser?.uid != actor.uid) {
            throw StateError(
              'Verify the approved account before reviewing this device draft.',
            );
          }
          return actor;
        },
        now: DateTime.now,
      );
    });

final maintenanceCreationSuccessorReviewProvider = FutureProvider.autoDispose
    .family<MaintenanceCreationSuccessorReview, String>(
      (ref, ticketId) => ref
          .read(maintenanceCreationSuccessorServiceProvider)
          .review(ticketId),
    );
