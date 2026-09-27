import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../core/persistence/app_database.dart' as database;
import '../../../core/persistence/durable_submission_repository.dart';
import '../../../core/services/sync_run_guard.dart';
import '../data/abnormality_model.dart';
import 'charge_abnormality_command_service.dart';

/// Legacy privileged edits have no frozen original command. A later account
/// must never reconstruct one from their mutable row or acknowledge that row.
class ChargeAbnormalityQueueGuard {
  ChargeAbnormalityQueueGuard({
    DurableSubmissionRepository? store,
    String Function()? projectId,
    String? Function()? currentActorUid,
  }) : _store = store,
       _projectId = projectId ?? (() => Firebase.app().options.projectId),
       _currentActorUid =
           currentActorUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final DurableSubmissionRepository? _store;
  final String Function() _projectId;
  final String? Function() _currentActorUid;

  Future<void> requireOwnedCreation(
    ChargeAbnormality row, {
    SyncRunGuard? runGuard,
  }) async {
    runGuard?.checkCurrent();
    final owner = row.loggedByUid?.trim() ?? '';
    if (row.version != 1 ||
        row.isDeleted ||
        owner.isEmpty ||
        row.updatedByUid != owner) {
      final project = _projectId();
      if (project.isEmpty) {
        throw StateError('The original project is unavailable.');
      }
      final identity = row.firestoreId ?? 'local-${row.id}';
      final bytes = utf8.encode(jsonEncode(row.toMap()));
      final hash = durableSubmissionSha256(utf8.decode(bytes));
      final key = 'legacyChargeAbnormality:$project:$identity';
      final source = '$key:$hash';
      await (_store ?? DurableSubmissionRepository(database.isar))
          .importLegacyNeedsReview(
            submissionId: 'legacy-${durableSubmissionSha256(source)}',
            resourceKey: key,
            sourceKey: source,
            sourceBytes: Uint8List.fromList(bytes),
            aggregateId: identity,
          );
      runGuard?.checkCurrent();
      throw const ChargeAbnormalityMutationException(
        code: 'failed-precondition',
        reasonCode: 'legacy-abnormality-origin-unknown',
        message:
            'This older saved abnormality edit has no verified original '
            'command. Its contents are preserved for review; it was not sent '
            'or marked as synced.',
      );
    }
    if (_currentActorUid() != owner) {
      // This is a temporary account mismatch, not a permanent rejection that
      // would prevent the original approved account from resuming its create.
      throw const ChargeAbnormalityMutationException(
        code: 'origin-mismatch',
        reasonCode: 'abnormality-original-account-required',
        message:
            'Sign in with the account that logged this abnormality to '
            'send or confirm its saved work. Nothing was changed.',
      );
    }
    runGuard?.checkCurrent();
  }
}
