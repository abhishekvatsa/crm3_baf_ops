import 'package:flutter/foundation.dart';

enum NavigationAuthorityPhase {
  startupFailure,
  authLoading,
  authError,
  signedOut,
  profileLoading,
  profileError,
  profileMissing,
  pendingApproval,
  approved,
}

@immutable
final class NavigationAuthorityScope {
  NavigationAuthorityScope._({
    required this.phase,
    this.uid,
    Iterable<String> roles = const <String>[],
  }) : roles = List<String>.unmodifiable(_canonicalRoles(roles));

  factory NavigationAuthorityScope.startupFailure() =>
      NavigationAuthorityScope._(
        phase: NavigationAuthorityPhase.startupFailure,
      );

  factory NavigationAuthorityScope.authLoading() =>
      NavigationAuthorityScope._(phase: NavigationAuthorityPhase.authLoading);

  factory NavigationAuthorityScope.authError() =>
      NavigationAuthorityScope._(phase: NavigationAuthorityPhase.authError);

  factory NavigationAuthorityScope.signedOut() =>
      NavigationAuthorityScope._(phase: NavigationAuthorityPhase.signedOut);

  factory NavigationAuthorityScope.profileLoading(String uid) =>
      NavigationAuthorityScope._(
        phase: NavigationAuthorityPhase.profileLoading,
        uid: uid,
      );

  factory NavigationAuthorityScope.profileError(String uid) =>
      NavigationAuthorityScope._(
        phase: NavigationAuthorityPhase.profileError,
        uid: uid,
      );

  factory NavigationAuthorityScope.fromProfile({
    required String authenticatedUid,
    required String? profileUid,
    required bool isApproved,
    required Iterable<String> roles,
  }) {
    if (profileUid == null) {
      return NavigationAuthorityScope._(
        phase: NavigationAuthorityPhase.profileMissing,
        uid: authenticatedUid,
      );
    }
    if (profileUid != authenticatedUid) {
      return NavigationAuthorityScope.profileError(authenticatedUid);
    }
    if (!isApproved) {
      return NavigationAuthorityScope._(
        phase: NavigationAuthorityPhase.pendingApproval,
        uid: authenticatedUid,
      );
    }
    return NavigationAuthorityScope._(
      phase: NavigationAuthorityPhase.approved,
      uid: authenticatedUid,
      roles: roles,
    );
  }

  final NavigationAuthorityPhase phase;
  final String? uid;
  final List<String> roles;

  String get navigatorKey {
    final identity = uid ?? 'none';
    final roleAuthority =
        phase == NavigationAuthorityPhase.approved ? roles.join(',') : 'none';
    return 'navigation-authority:${phase.name}:$identity:$roleAuthority';
  }
}

List<String> _canonicalRoles(Iterable<String> roles) {
  final values =
      roles
          .map((role) => role.trim())
          .where((role) => role.isNotEmpty)
          .toSet()
          .toList();
  values.sort();
  return values;
}
