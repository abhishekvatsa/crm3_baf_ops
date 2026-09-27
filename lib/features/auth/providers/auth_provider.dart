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

final authFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  // Revoke profile authority before credential cleanup can invalidate its
  // Firestore listener. Clearing this gate creates a fresh session stream.
  if (ref.watch(signOutInProgressProvider)) return Stream.value(null);
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(authFirestoreProvider);
  final retryBudget = CurrentAppUserPermissionRetryBudget();
  return switchLatestNullableStream<User, AppUser>(
    source: auth.idTokenChanges(),
    isCurrentSource: (user) => auth.currentUser?.uid == user.uid,
    registerCancellation: (cancel) => ref.onDispose(cancel),
    onSourceEvent: (user) => retryBudget.observeAuthEvent(user?.uid),
    mapper: (user) => _watchCurrentAppUser(
      auth: auth,
      firestore: firestore,
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
  bool Function(S value)? isCurrentSource,
  void Function(Future<void> Function() cancel)? registerCancellation,
}) {
  late final StreamController<T?> controller;
  StreamSubscription<S?>? sourceSubscription;
  StreamSubscription<T?>? activeSubscription;
  S? activeSource;
  void Function()? invalidateActiveSource;
  var cancelled = false;
  Future<void>? cancellation;
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
    if (cancelled || controller.isClosed) return;
    // A delayed token event must not replace a newer live account or reset its
    // retry budget. The synchronous identity is checked again on every event.
    if (value != null && isCurrentSource?.call(value) == false) {
      final mapped = activeSource;
      if (mapped != null && isCurrentSource?.call(mapped) == false) {
        invalidateActiveSource?.call();
      }
      return;
    }
    final replacementGeneration = ++generation;
    onSourceEvent?.call(value);
    final previous = activeSubscription;
    activeSubscription = null;
    activeSource = null;
    invalidateActiveSource = null;
    replacementCount++;
    var replacementInvalidated = false;
    void invalidateReplacement() {
      if (replacementGeneration != generation ||
          controller.isClosed ||
          replacementInvalidated) {
        return;
      }
      replacementInvalidated = true;
      controller.add(null);
    }

    bool mayForward() {
      if (replacementGeneration != generation ||
          controller.isClosed ||
          replacementInvalidated) {
        return false;
      }
      if (value != null && isCurrentSource?.call(value) == false) {
        // Auth and Firestore use separate platform channels. Invalidate the
        // obsolete profile immediately even if its token event is still queued.
        invalidateReplacement();
        return false;
      }
      return true;
    }

    try {
      await previous?.cancel();
      if (!mayForward()) return;
      if (value == null) {
        controller.add(null);
        return;
      }

      var completedSynchronously = false;
      StreamSubscription<T?>? next;
      next = mapper(value).listen(
        (event) {
          if (mayForward()) {
            controller.add(event);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (mayForward()) {
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
      activeSource = value;
      invalidateActiveSource = invalidateReplacement;
    } catch (error, stackTrace) {
      if (mayForward()) {
        controller.addError(error, stackTrace);
      }
    } finally {
      replacementCount--;
      await closeWhenFinished();
    }
  }

  Future<void> cancelSubscriptions() {
    if (cancellation != null) return cancellation!;
    cancelled = true;
    generation++;
    final active = activeSubscription;
    final source = sourceSubscription;
    activeSubscription = null;
    activeSource = null;
    invalidateActiveSource = null;
    sourceSubscription = null;
    return cancellation = () async {
      try {
        await active?.cancel();
      } finally {
        await source?.cancel();
      }
    }();
  }

  controller = StreamController<T?>(
    onListen: () {
      if (cancelled) return;
      sourceSubscription = source.listen(
        (value) => unawaited(replace(value)),
        onError: (Object error, StackTrace stackTrace) {
          if (!cancelled && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          sourceCompleted = true;
          unawaited(closeWhenFinished());
        },
      );
    },
    onCancel: cancelSubscriptions,
  );
  // Riverpod may retain a stream listener for its pending future during a
  // rebuild. Session disposal still must immediately detach Firebase listeners.
  registerCancellation?.call(cancelSubscriptions);

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
}) {
  late final StreamController<AppUser?> controller;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
  var stopped = false;
  var generation = 0;
  late void Function() listen;

  Future<void> failOrRetry(
    Object error,
    StackTrace stack,
    int failedGeneration,
  ) async {
    if (stopped || failedGeneration != generation) return;
    generation++;
    final previous = subscription;
    subscription = null;
    try {
      await previous?.cancel();
      if (stopped) return;
      if (error is FirebaseException &&
          retryBudget.tryClaimPermissionDeniedRetry(
            errorCode: error.code,
            authenticatedUid: auth.currentUser?.uid,
            expectedUid: user.uid,
          )) {
        await user.getIdToken(true);
        if (!stopped) listen();
        return;
      }
    } catch (retryError, retryStack) {
      error = retryError;
      stack = retryStack;
    }
    if (!stopped) {
      controller.addError(error, stack);
      await controller.close();
    }
  }

  listen = () {
    if (stopped) return;
    final currentGeneration = ++generation;
    try {
      subscription = firestore
          .collection('users')
          .doc(user.uid)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (doc) {
              if (stopped || currentGeneration != generation) return;
              try {
                final data = doc.data();
                controller.add(
                  !doc.exists || data == null
                      ? null
                      : AppUser.fromFirestore(
                          data,
                          doc.id,
                          fromCache: doc.metadata.isFromCache,
                          hasPendingWrites: doc.metadata.hasPendingWrites,
                          observedAt: DateTime.now().toUtc(),
                        ),
                );
              } catch (error, stack) {
                unawaited(failOrRetry(error, stack, currentGeneration));
              }
            },
            onError: (Object error, StackTrace stack) {
              unawaited(failOrRetry(error, stack, currentGeneration));
            },
            onDone: () {
              if (!stopped && currentGeneration == generation) {
                unawaited(controller.close());
              }
            },
          );
    } catch (error, stack) {
      unawaited(failOrRetry(error, stack, currentGeneration));
    }
  };

  controller = StreamController<AppUser?>(
    onListen: listen,
    onCancel: () async {
      stopped = true;
      generation++;
      await subscription?.cancel();
    },
  );
  return controller.stream;
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
  if (ref.watch(signOutInProgressProvider)) return;
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
