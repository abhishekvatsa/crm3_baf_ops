import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_model.dart';

enum CurrentActorAvailability {
  verifying,
  verificationFailed,
  signedOut,
  awaitingApproval,
  ready,
}

/// Resolves current authority without accepting Riverpod's retained old value.
class CurrentActorAccess {
  const CurrentActorAccess._(this.availability, this.actor);

  factory CurrentActorAccess.resolve(AsyncValue<AppUser?> value) {
    if (value.isLoading) {
      return const CurrentActorAccess._(
        CurrentActorAvailability.verifying,
        null,
      );
    }
    if (value.hasError) {
      return const CurrentActorAccess._(
        CurrentActorAvailability.verificationFailed,
        null,
      );
    }
    final actor = value.valueOrNull;
    if (actor == null) {
      return const CurrentActorAccess._(
        CurrentActorAvailability.signedOut,
        null,
      );
    }
    if (!actor.isApproved) {
      return const CurrentActorAccess._(
        CurrentActorAvailability.awaitingApproval,
        null,
      );
    }
    return CurrentActorAccess._(CurrentActorAvailability.ready, actor);
  }

  final CurrentActorAvailability availability;
  final AppUser? actor;

  bool get isReady => availability == CurrentActorAvailability.ready;

  String get message => switch (availability) {
    CurrentActorAvailability.verifying =>
      'Your account is still being verified. Your entries are retained.',
    CurrentActorAvailability.verificationFailed =>
      'Your account could not be verified right now. Your entries are retained; check your connection and try again.',
    CurrentActorAvailability.signedOut =>
      'Sign in to continue. Your entries are retained while this form stays open.',
    CurrentActorAvailability.awaitingApproval =>
      'Your account needs approval before you can continue.',
    CurrentActorAvailability.ready => '',
  };
}
