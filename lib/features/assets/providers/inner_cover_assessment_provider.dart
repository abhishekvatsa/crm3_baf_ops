import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../auth/data/user_model.dart';
import '../../auth/domain/current_actor_access.dart';
import '../data/furnace_stuckup_record.dart';
import '../data/inner_cover_lifecycle.dart';

/// Previous AsyncValue data is never authority while the current session is
/// loading, failed, signed out or belongs to a different authenticated user.
AppUser? verifiedInnerCoverAssessmentActor(
  AsyncValue<AppUser?> value,
  String? authenticatedUid,
) {
  final access = CurrentActorAccess.resolve(value);
  return access.isReady && access.actor?.uid == authenticatedUid
      ? access.actor
      : null;
}

final innerCoverAssessmentActorReaderProvider = Provider<AppUser? Function()>((
  ref,
) {
  ref.watch(currentAppUserProvider);
  return () => verifiedInnerCoverAssessmentActor(
    ref.read(currentAppUserProvider),
    ref.read(firebaseAuthProvider).currentUser?.uid,
  );
});

class InnerCoverAssessmentEvidence {
  const InnerCoverAssessmentEvidence({
    required this.withdrawn,
    required this.ticketVersion,
    required this.profile,
    required this.currentRecord,
  });
  final bool withdrawn;
  final int ticketVersion;
  final InnerCoverProfile profile;
  final FurnaceStuckupRecord currentRecord;

  bool canUseAcceptance(FurnaceStuckupRecord record) =>
      withdrawn &&
      record.id == currentRecord.id &&
      record.ticketId == currentRecord.ticketId &&
      record.version == currentRecord.version &&
      record.concernDisposition == null &&
      !profile.requiresReacceptance &&
      profile.id == record.innerCoverId &&
      profile.serialNumber == record.innerCoverSerialNumber &&
      profile.lifecycleState == InnerCoverLifecycleState.available &&
      profile.currentBaseAssetInstanceId == null &&
      profile.currentBaseAssetNumber == null &&
      profile.currentLinkageId == null &&
      profile.lastMutationId.isNotEmpty &&
      profile.acceptedAt != null &&
      record.releasedAt != null &&
      record.adjudicatedAt != null &&
      profile.acceptedAt!.isAfter(record.reportedAt) &&
      profile.acceptedAt!.isAfter(record.releasedAt!) &&
      profile.acceptedAt!.isAfter(record.adjudicatedAt!);
}

final innerCoverAssessmentEvidenceProvider = FutureProvider.autoDispose
    .family<InnerCoverAssessmentEvidence, FurnaceStuckupRecord>((
      ref,
      record,
    ) async {
      final actor = ref.watch(innerCoverAssessmentActorReaderProvider)();
      if (actor?.isApproved != true) {
        throw StateError('Approved access is required.');
      }
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db
            .collection('maintenance_records')
            .doc(record.ticketId)
            .get(const GetOptions(source: Source.server)),
        db
            .collection('inner_cover_profiles')
            .doc(record.innerCoverId)
            .get(const GetOptions(source: Source.server)),
        db
            .collection('furnace_stuckup_cases')
            .doc(record.id)
            .get(const GetOptions(source: Source.server)),
      ]);
      if (results.any(
        (doc) =>
            !doc.exists ||
            doc.metadata.isFromCache ||
            doc.metadata.hasPendingWrites,
      )) {
        throw StateError('Current server evidence is required.');
      }
      final ticket = results[0].data()!;
      if (ticket['firestoreId'] != record.ticketId ||
          ticket['version'] is! int) {
        throw StateError('Original issue identity could not be verified.');
      }
      final currentRecord = FurnaceStuckupRecord.fromMap(
        results[2].data()!,
        results[2].id,
      );
      if (currentRecord.id != record.id ||
          currentRecord.ticketId != record.ticketId ||
          currentRecord.innerCoverId != record.innerCoverId ||
          currentRecord.innerCoverSerialNumber !=
              record.innerCoverSerialNumber ||
          currentRecord.innerCoverLinkageId != record.innerCoverLinkageId) {
        throw StateError('Current assessment identity could not be verified.');
      }
      final currentActor = ref.read(innerCoverAssessmentActorReaderProvider)();
      if (currentActor?.uid != actor!.uid || currentActor?.isApproved != true) {
        throw StateError('Assessment evidence belongs to a changed session.');
      }
      return InnerCoverAssessmentEvidence(
        currentRecord: currentRecord,
        withdrawn: ticket['isDeleted'] == true,
        ticketVersion: ticket['version'] as int,
        profile: InnerCoverProfile.fromMap(
          results[1].data()!,
          record.innerCoverId,
        ),
      );
    });

/// Reads an applied case from the server. Presentation validates the command
/// and disposition identity without accessing Firestore or accepting cache.
final innerCoverAssessmentReadbackProvider =
    Provider<Future<FurnaceStuckupRecord> Function(String)>((ref) {
      return (caseId) async {
        final actor = ref.read(innerCoverAssessmentActorReaderProvider)();
        if (actor?.isApproved != true) {
          throw StateError('Approved access is required.');
        }
        final saved = await FirebaseFirestore.instance
            .collection('furnace_stuckup_cases')
            .doc(caseId)
            .get(const GetOptions(source: Source.server));
        final currentActor = ref.read(
          innerCoverAssessmentActorReaderProvider,
        )();
        if (currentActor?.uid != actor!.uid ||
            currentActor?.isApproved != true ||
            !saved.exists ||
            saved.metadata.isFromCache ||
            saved.metadata.hasPendingWrites) {
          throw StateError('The saved assessment could not yet be verified.');
        }
        return FurnaceStuckupRecord.fromMap(saved.data()!, saved.id);
      };
    });
