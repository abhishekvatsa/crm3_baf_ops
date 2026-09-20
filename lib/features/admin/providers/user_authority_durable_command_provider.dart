import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/durable_submission_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/data/user_model.dart';
import '../services/user_authority_durable_command_controller.dart';
import 'user_authority_command_provider.dart';

final userAuthorityDurableCommandControllerProvider =
    Provider<UserAuthorityDurableCommandController>((ref) {
      return UserAuthorityDurableCommandController(
        store: ref.watch(durableSubmissionRepositoryProvider),
        service: ref.watch(userAuthorityCommandServiceProvider),
        requireActor: () {
          final actor = ref.read(currentAppUserProvider).value;
          return actor?.uid == ref.read(firebaseAuthProvider).currentUser?.uid
              ? actor
              : null;
        },
        verifyFreshActor: (uid) async {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.server));
          if (ref.read(firebaseAuthProvider).currentUser?.uid != uid ||
              doc.data() == null ||
              doc.metadata.isFromCache ||
              doc.metadata.hasPendingWrites ||
              !AppUser.fromFirestore(doc.data()!, uid).canManageUsers) {
            throw StateError(
              'Current Admin access could not be confirmed. Nothing new was sent.',
            );
          }
        },
      );
    });
