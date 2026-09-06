// FILE: lib/features/auth/providers/auth_provider.dart

import 'dart:async'
    show Stream, StreamController, StreamSubscription, unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_model.dart';
import '../services/auth_service.dart';
import '../services/notification_installation_registry.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/local_recovery_session_guard.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final retryBudget = CurrentAppUserPermissionRetryBudget();
  return switchLatestNullableStream<User, AppUser>(
    source: auth.idTokenChanges(),
    onSourceEvent: (user) => retryBudget.observeAuthEvent(user?.uid),
    mapper: (user) => _watchCurrentAppUser(
      auth: auth,
      firestore: FirebaseFirestore.instance,
      user: user,
      retryBudget: retryBudget,
    ),
  );
});

@visibleForTesting
Stream<T?> switchLatestNullableStream<S, T>({
  required Stream<S?> source,
  required Stream<T?> Function(S value) mapper,
  void Function(S? value)? onSourceEvent,
}) {
  late final StreamController<T?> controller;
  StreamSubscription<S?>? sourceSubscription;
  StreamSubscription<T?>? activeSubscription;
  var generation = 0;
  var sourceCompleted = false;
  var replacementCount = 0;

  Future<void> closeWhenFinished() async {
    if (sourceCompleted &&
        replacementCount == 0 &&
        activeSubscription == null &&
        !controller.isClosed) {
      await controller.close();
    }
  }

  Future<void> replace(S? value) async {
    final replacementGeneration = ++generation;
    onSourceEvent?.call(value);
    final previous = activeSubscription;
    activeSubscription = null;
    replacementCount++;
    try {
      await previous?.cancel();
      if (replacementGeneration != generation || controller.isClosed) return;
      if (value == null) {
        controller.add(null);
        return;
      }

      var completedSynchronously = false;
      StreamSubscription<T?>? next;
      next = mapper(value).listen(
        (event) {
          if (replacementGeneration == generation && !controller.isClosed) {
            controller.add(event);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (replacementGeneration == generation && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (next == null) {
            completedSynchronously = true;
            return;
          }
          if (replacementGeneration == generation &&
              identical(activeSubscription, next)) {
            activeSubscription = null;
            unawaited(closeWhenFinished());
          }
        },
      );
      final started = next;
      if (completedSynchronously) {
        await started.cancel();
        return;
      }
      if (replacementGeneration != generation || controller.isClosed) {
        await started.cancel();
        return;
      }
      activeSubscription = started;
    } catch (error, stackTrace) {
      if (replacementGeneration == generation && !controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    } finally {
      replacementCount--;
      await closeWhenFinished();
    }
  }

  controller = StreamController<T?>(
    onListen: () {
      sourceSubscription = source.listen(
        (value) => unawaited(replace(value)),
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) controller.addError(error, stackTrace);
        },
        onDone: () {
          sourceCompleted = true;
          unawaited(closeWhenFinished());
        },
      );
    },
    onCancel: () async {
      generation++;
      final active = activeSubscription;
      activeSubscription = null;
      await active?.cancel();
      await sourceSubscription?.cancel();
    },
  );

  return controller.stream;
}

@visibleForTesting
bool shouldRetryCurrentAppUserPermissionDenied({
  required String errorCode,
  required String? authenticatedUid,
  required String expectedUid,
  required bool alreadyRetried,
}) {
  return !alreadyRetried &&
      errorCode == 'permission-denied' &&
      authenticatedUid == expectedUid;
}

@visibleForTesting
final class CurrentAppUserPermissionRetryBudget {
  String? _authSessionUid;
  bool _retryConsumed = false;

  void observeAuthEvent(String? uid) {
    if (uid == _authSessionUid) return;
    _authSessionUid = uid;
    _retryConsumed = false;
  }

  bool tryClaimPermissionDeniedRetry({
    required String errorCode,
    required String? authenticatedUid,
    required String expectedUid,
  }) {
    final shouldRetry =
        _authSessionUid == expectedUid &&
        shouldRetryCurrentAppUserPermissionDenied(
          errorCode: errorCode,
          authenticatedUid: authenticatedUid,
          expectedUid: expectedUid,
          alreadyRetried: _retryConsumed,
        );
    if (!shouldRetry) return false;
    _retryConsumed = true;
    return true;
  }
}

Stream<AppUser?> _watchCurrentAppUser({
  required FirebaseAuth auth,
  required FirebaseFirestore firestore,
  required User user,
  required CurrentAppUserPermissionRetryBudget retryBudget,
}) async* {
  while (true) {
    try {
      await for (final doc
          in firestore.collection('users').doc(user.uid).snapshots()) {
        final data = doc.data();
        if (!doc.exists || data == null) {
          yield null;
          continue;
        }
        yield AppUser.fromFirestore(data, doc.id);
      }
      return;
    } on FirebaseException catch (error) {
      if (!retryBudget.tryClaimPermissionDeniedRetry(
        errorCode: error.code,
        authenticatedUid: auth.currentUser?.uid,
        expectedUid: user.uid,
      )) {
        rethrow;
      }
      await user.getIdToken(true);
    }
  }
}

/// Keeps Crashlytics identity aligned with the current approved/pending app user.
///
/// Privacy policy for observability: use UID + role/approval context only.
/// Do not send email, display name, ticket text, module responses, or plant
/// evidence to Crashlytics.
final crashlyticsIdentitySyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (previous, next) {
    next.when(
      loading: () {},
      error: (error, stackTrace) {
        AppLogger.warning(
          'Current app user stream failed',
          error: error,
          stackTrace: stackTrace,
          context: const {
            'app_area': 'auth',
            'auth_stage': 'current_app_user_stream',
          },
        );
      },
      data: (user) {
        if (user == null) {
          unawaited(AppLogger.clearUserContext());
          return;
        }

        unawaited(
          AppLogger.setUserContext(
            uid: user.uid,
            roles: user.roles.map((role) => role.name),
            isApproved: user.isApproved,
          ),
        );
      },
    );
  }, fireImmediately: true);
});

final notificationInstallationRegistryProvider =
    Provider<NotificationInstallationRegistry>((ref) {
      return NotificationInstallationRegistry(
        idStore: SharedPreferencesNotificationInstallationIdStore(),
        documentStore: FirestoreNotificationInstallationDocumentStore(
          FirebaseFirestore.instance,
        ),
        tokenSource: FirebaseMessagingNotificationTokenSource(
          FirebaseMessaging.instance,
        ),
        platform: currentNotificationInstallationPlatform(),
      );
    });

final notificationInstallationSyncProvider = Provider<void>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final registry = ref.watch(notificationInstallationRegistryProvider);

  ref.listen<AsyncValue<AppUser?>>(currentAppUserProvider, (previous, next) {
    next.whenData((user) {
      if (user == null) {
        registry.observeSignedOut();
        return;
      }
      unawaited(
        syncNotificationInstallation(registry: registry, uid: user.uid),
      );
    });
  }, fireImmediately: true);

  try {
    final tokenRefreshSubscription = registry.tokenRefreshes.listen(
      (token) {
        final uid = auth.currentUser?.uid;
        if (uid == null) return;
        unawaited(
          syncNotificationInstallation(
            registry: registry,
            uid: uid,
            token: token,
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.warning(
          'FCM token refresh stream failed',
          error: error,
          stackTrace: stackTrace,
          context: const {
            'app_area': 'auth',
            'auth_stage': 'notification_token_refresh_stream',
          },
        );
      },
    );
    ref.onDispose(() => unawaited(tokenRefreshSubscription.cancel()));
  } catch (error, stackTrace) {
    AppLogger.warning(
      'FCM token refresh subscription unavailable',
      error: error,
      stackTrace: stackTrace,
      context: const {
        'app_area': 'auth',
        'auth_stage': 'notification_token_refresh_subscription',
      },
    );
  }
});

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref,
    ref.watch(notificationInstallationRegistryProvider),
    ref.watch(localRecoverySessionGuardProvider),
  ),
);
