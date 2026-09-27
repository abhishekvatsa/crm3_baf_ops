import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/user_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/services/auth_service.dart';
import 'sync_run_guard.dart';

String? _authorityKey(AsyncValue<AppUser?> value) {
  if (value.isLoading || value.hasError) return null;
  final actor = value.valueOrNull;
  if (actor == null ||
      !actor.isApproved ||
      !actor.hasServerAuthorityObservation) {
    return null;
  }
  final roles = actor.roles.map((role) => role.name).toSet().toList()..sort();
  return jsonEncode([actor.uid, actor.authorityRevision, roles]);
}

String? _sessionUid(AsyncValue<User?>? value) =>
    value == null || value.isLoading || value.hasError
    ? null
    : value.valueOrNull?.uid;

/// Listeners live with the coordinator's provider, not with individual runs.
/// The epoch catches sign-out/reapproval followed by a return to the same UID
/// while a repository call was waiting. Rechecking just the current UID cannot.
final syncRunGuardFactoryProvider = Provider<SyncRunGuard Function()>((ref) {
  var epoch = 0;
  ref.listen(currentAppUserProvider, (previous, next) {
    if (previous == null || _authorityKey(previous) != _authorityKey(next)) {
      epoch++;
    }
  });
  ref.listen(authStateProvider, (previous, next) {
    if (_sessionUid(previous) != _sessionUid(next)) epoch++;
  });
  ref.listen(signOutInProgressProvider, (previous, next) {
    if (next) epoch++;
  });

  return () {
    final startingEpoch = epoch;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    final authority = _authorityKey(ref.read(currentAppUserProvider));
    return SyncRunGuard(() {
      if (uid == null || uid.isEmpty || authority == null) {
        throw const SyncRunAborted('account-authority-unconfirmed');
      }
      if (epoch != startingEpoch ||
          ref.read(signOutInProgressProvider) ||
          _sessionUid(ref.read(authStateProvider)) != uid ||
          ref.read(firebaseAuthProvider).currentUser?.uid != uid ||
          _authorityKey(ref.read(currentAppUserProvider)) != authority ||
          ref.read(currentAppUserProvider).valueOrNull?.uid != uid) {
        throw const SyncRunAborted('account-or-authority-changed');
      }
    });
  };
});
