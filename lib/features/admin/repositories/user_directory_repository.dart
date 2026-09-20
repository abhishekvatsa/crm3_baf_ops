import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:collection';

import '../../auth/data/user_model.dart';

abstract interface class UserDirectoryRepository {
  Stream<List<AppUser>> watchAllUsers();
}

class FirestoreUserDirectoryRepository implements UserDirectoryRepository {
  FirestoreUserDirectoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AppUser>> watchAllUsers() => _firestore
      .collection('users')
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => UserDirectoryPopulation.decode(
          {for (final doc in snapshot.docs) doc.id: doc.data()},
          fromCache: snapshot.metadata.isFromCache,
          hasPendingWrites: snapshot.metadata.hasPendingWrites,
        ),
      );
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

/// Healthy rows stay actionable; failed identities and cache status stay visible.
class UserDirectoryPopulation extends ListBase<AppUser> {
  UserDirectoryPopulation(
    this.records,
    this.failedIds, {
    required this.fromCache,
    required this.hasPendingWrites,
  });
  final List<AppUser> records;
  final List<String> failedIds;
  final bool fromCache;
  final bool hasPendingWrites;
  bool get isComplete => failedIds.isEmpty;
  factory UserDirectoryPopulation.decode(
    Map<String, Map<String, dynamic>> rows, {
    required bool fromCache,
    required bool hasPendingWrites,
  }) {
    final records = <AppUser>[];
    final failures = <String>[];
    for (final entry in rows.entries) {
      try {
        final user = AppUser.fromFirestore(
          entry.value,
          entry.key,
          fromCache: fromCache,
          hasPendingWrites: hasPendingWrites,
          observedAt: DateTime.now().toUtc(),
        );
        if (user.roles.isEmpty || entry.value['isApproved'] is! bool) {
          throw const FormatException('Invalid authority');
        }
        records.add(user);
      } catch (_) {
        failures.add(entry.key);
      }
    }
    return UserDirectoryPopulation(
      List.unmodifiable(records),
      List.unmodifiable(failures),
      fromCache: fromCache,
      hasPendingWrites: hasPendingWrites,
    );
  }
  @override
  int get length => records.length;
  @override
  set length(int value) => throw UnsupportedError('Read only roster');
  @override
  AppUser operator [](int index) => records[index];
  @override
  void operator []=(int index, AppUser value) =>
      throw UnsupportedError('Read only roster');
}
