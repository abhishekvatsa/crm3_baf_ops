import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/domain/current_actor_access.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final actor = AppUser(
    uid: 'actor',
    name: 'Actor',
    email: 'actor@example.test',
    roles: const [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  test('a retained actor cannot authorize while verification errors', () {
    final state = AsyncError<AppUser?>(
      StateError('offline'),
      StackTrace.empty,
    ).copyWithPrevious(AsyncData(actor));
    expect(state.valueOrNull, same(actor));
    final access = CurrentActorAccess.resolve(state);
    expect(access.availability, CurrentActorAvailability.verificationFailed);
    expect(access.actor, isNull);
  });
  test('a retained actor cannot authorize while verification refreshes', () {
    final state = const AsyncLoading<AppUser?>().copyWithPrevious(
      AsyncData(actor),
    );
    expect(state.valueOrNull, same(actor));
    final access = CurrentActorAccess.resolve(state);
    expect(access.availability, CurrentActorAvailability.verifying);
    expect(access.actor, isNull);
  });
  test(
    'error before first data is distinct from signed out and never throws',
    () {
      final error = CurrentActorAccess.resolve(
        AsyncError<AppUser?>(StateError('unreadable'), StackTrace.empty),
      );
      final signedOut = CurrentActorAccess.resolve(
        const AsyncData<AppUser?>(null),
      );
      expect(error.availability, CurrentActorAvailability.verificationFailed);
      expect(signedOut.availability, CurrentActorAvailability.signedOut);
      expect(CurrentActorAccess.resolve(AsyncData(actor)).actor, same(actor));
    },
  );
}
