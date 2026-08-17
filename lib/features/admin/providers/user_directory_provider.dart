import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/user_directory_repository.dart';

final userDirectoryRepositoryProvider = Provider<UserDirectoryRepository>(
  (ref) => FirestoreUserDirectoryRepository(),
);

final userDirectoryReadServiceProvider = Provider<UserDirectoryReadService>(
  (ref) => UserDirectoryReadService(ref.watch(userDirectoryRepositoryProvider)),
);

final allUsersProvider = StreamProvider.autoDispose<List<AppUser>>((
  ref,
) async* {
  final actor = await ref.watch(currentAppUserProvider.future);
  yield* ref
      .watch(userDirectoryReadServiceProvider)
      .watchAllUsers(actor: actor);
});
