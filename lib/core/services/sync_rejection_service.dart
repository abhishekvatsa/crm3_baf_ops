import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../../features/audit/models/audit_event_model.dart';
import '../../features/auth/data/user_model.dart';

const int recentSyncRejectionLimit = 5;

class SyncRejectionService {
  SyncRejectionService({Isar? Function()? databaseLookup})
    : _databaseLookup = databaseLookup ?? Isar.getInstance;

  final Isar? Function() _databaseLookup;

  Stream<List<SyncRejection>> watchRecent({required int limit}) {
    if (kIsWeb) return Stream.value(const <SyncRejection>[]);
    final database = _databaseLookup();
    if (database == null) return Stream.value(const <SyncRejection>[]);
    return database.syncRejections
        .filter()
        .isResolvedEqualTo(false)
        .sortByLastSeenAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  Stream<int> watchUnresolvedPermanentCount() {
    if (kIsWeb) return Stream.value(0);
    final database = _databaseLookup();
    if (database == null) return Stream.value(0);
    final query = database.syncRejections
        .filter()
        .isResolvedEqualTo(false)
        .and()
        .isLikelyPermanentEqualTo(true);
    return query
        .watchLazy(fireImmediately: true)
        .asyncMap((_) => query.count());
  }

  Future<bool> resolve({
    required int rejectionId,
    required AppUser? actor,
    required String notes,
  }) async {
    if (actor == null || !actor.canResolveSyncConflicts) {
      throw StateError(
        'Admin access is required before resolving sync rejections.',
      );
    }
    final database = _databaseLookup();
    if (database == null) {
      throw StateError('Local database is not available.');
    }

    var changed = false;
    await database.writeTxn(() async {
      final current = await database.syncRejections.get(rejectionId);
      if (current == null || current.isResolved) return;
      current.markResolved(
        resolvedByUid: actor.uid,
        resolvedByName: actor.name,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      );
      await database.syncRejections.put(current);
      changed = true;
    });
    return changed;
  }
}

final syncRejectionServiceProvider = Provider<SyncRejectionService>(
  (ref) => SyncRejectionService(),
);

final recentSyncRejectionsProvider = StreamProvider<List<SyncRejection>>(
  (ref) => ref
      .watch(syncRejectionServiceProvider)
      .watchRecent(limit: recentSyncRejectionLimit),
);

final unresolvedPermanentSyncRejectionCountProvider = StreamProvider<int>(
  (ref) =>
      ref.watch(syncRejectionServiceProvider).watchUnresolvedPermanentCount(),
);
