// FILE: lib/features/auth/providers/auth_provider.dart

import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/user_model.dart';
import '../services/notification_installation_registry.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../../core/providers/sync_providers.dart';
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
  return auth.idTokenChanges().asyncExpand((user) {
    retryBudget.observeAuthEvent(user?.uid);
    if (user == null) return Stream<AppUser?>.value(null);

    return _watchCurrentAppUser(
      auth: auth,
      firestore: FirebaseFirestore.instance,
      user: user,
      retryBudget: retryBudget,
    );
  });
});

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
        _syncNotificationInstallation(registry: registry, uid: user.uid),
      );
    });
  }, fireImmediately: true);

  try {
    final tokenRefreshSubscription = registry.tokenRefreshes.listen(
      (token) {
        final uid = auth.currentUser?.uid;
        if (uid == null) return;
        unawaited(
          _syncNotificationInstallation(
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

Future<void> _syncNotificationInstallation({
  required NotificationInstallationRegistry registry,
  required String uid,
  String? token,
}) async {
  try {
    if (token == null) {
      await registry.registerCurrentToken(uid: uid);
    } else {
      await registry.registerToken(uid: uid, token: token);
    }
  } catch (error, stackTrace) {
    AppLogger.warning(
      'Notification installation registration failed',
      error: error,
      stackTrace: stackTrace,
      context: const {
        'app_area': 'auth',
        'auth_stage': 'notification_installation_registration',
      },
    );
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Ref _ref;
  final NotificationInstallationRegistry _notificationRegistry;
  final LocalRecoverySessionGuard _recoverySessionGuard;

  AuthService(
    this._ref,
    this._notificationRegistry,
    this._recoverySessionGuard,
  );

  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return;

    // Set a minimal pre-bootstrap identity so any crashes during profile
    // hydration are attributed to this Firebase UID without sending email/name.
    unawaited(
      AppLogger.setUserContext(
        uid: user.uid,
        roles: const [],
        isApproved: false,
      ),
    );

    await ensureUserDocument(firebaseUser: user);
  }

  /// Ensures the signed-in Firebase user has a safe pending/approved app profile.
  Future<void> ensureUserDocument({User? firebaseUser}) async {
    final user = firebaseUser ?? _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        transaction.set(userRef, _pendingUserPayload(user));
        return;
      }

      final updateMap = <String, dynamic>{
        'name': _cleanProfileText(user.displayName),
        'email': _cleanProfileText(user.email),
        'photoUrl': _cleanOptionalText(user.photoURL),
      };

      transaction.update(userRef, updateMap);
    });

    await _syncNotificationInstallation(
      registry: _notificationRegistry,
      uid: user.uid,
    );
  }

  Future<void> signOut() async {
    _recoverySessionGuard.beginSessionEnd();
    try {
      await _performSignOut();
    } finally {
      _recoverySessionGuard.endSessionEnd();
    }
  }

  Future<void> _performSignOut() async {
    unawaited(AppLogger.clearUserContext());

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _notificationRegistry.removeCurrentInstallation(uid: user.uid);
      } catch (e, st) {
        debugPrint(
          'Could not remove notification installation during sign out: $e',
        );
        AppLogger.warning(
          'Could not remove notification installation during sign out',
          error: e,
          stackTrace: st,
          context: const {
            'app_area': 'auth',
            'auth_stage': 'sign_out_remove_notification_installation',
          },
        );
      }
    }

    await _auth.signOut();

    try {
      await _googleSignIn.signOut();
    } catch (e, st) {
      debugPrint('Google sign-out cleanup failed after Firebase sign-out: $e');
      AppLogger.warning(
        'Google sign-out cleanup failed after Firebase sign-out',
        error: e,
        stackTrace: st,
        context: const {'app_area': 'auth', 'auth_stage': 'google_sign_out'},
      );
    }

    try {
      await _notificationRegistry.retireMessagingToken();
    } catch (e, st) {
      debugPrint('Could not retire the local messaging token: $e');
      AppLogger.warning(
        'Could not retire the local messaging token',
        error: e,
        stackTrace: st,
        context: const {
          'app_area': 'auth',
          'auth_stage': 'sign_out_retire_notification_token',
        },
      );
    } finally {
      _notificationRegistry.observeSignedOut();
    }

    try {
      _ref.read(syncOnceProvider.notifier).state = false;
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Could not reset the one-shot sync marker after sign-out',
        error: error,
        stackTrace: stackTrace,
        context: const {
          'app_area': 'auth',
          'auth_stage': 'sign_out_reset_sync_marker',
        },
      );
    }
  }

  Map<String, dynamic> _pendingUserPayload(User user) {
    return {
      'name': _cleanProfileText(user.displayName),
      'email': _cleanProfileText(user.email),
      'photoUrl': _cleanOptionalText(user.photoURL),
      'roles': [AppRole.operations.name],
      'isApproved': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  String _cleanProfileText(String? value) => value?.trim() ?? '';

  String? _cleanOptionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref,
    ref.watch(notificationInstallationRegistryProvider),
    ref.watch(localRecoverySessionGuardProvider),
  ),
);
