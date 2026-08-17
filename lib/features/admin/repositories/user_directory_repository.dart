import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/data/user_model.dart';

abstract interface class UserDirectoryRepository {
  Stream<List<AppUser>> watchAllUsers();
}

class FirestoreUserDirectoryRepository implements UserDirectoryRepository {
  FirestoreUserDirectoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AppUser>> watchAllUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromFirestore(doc.data(), doc.id))
              .toList(growable: false),
        );
  }
}

class UserDirectoryReadService {
  const UserDirectoryReadService(this._repository);

  final UserDirectoryRepository _repository;

  Stream<List<AppUser>> watchAllUsers({required AppUser? actor}) {
    if (actor == null || !actor.canManageUsers) {
      return Stream<List<AppUser>>.error(
        StateError(
          'Approved admin access is required to read the user roster.',
        ),
      );
    }
    return _repository.watchAllUsers();
  }
}
