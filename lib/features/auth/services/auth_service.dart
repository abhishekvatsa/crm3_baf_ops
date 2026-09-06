import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/providers/sync_providers.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/local_recovery_session_guard.dart';
import '../../maintenance/data/maintenance_model.dart';
import 'notification_installation_registry.dart';

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

    // Keep crash identity minimal while the authoritative profile hydrates.
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

      transaction.update(userRef, <String, dynamic>{
        'name': _cleanProfileText(user.displayName),
        'email': _cleanProfileText(user.email),
        'photoUrl': _cleanOptionalText(user.photoURL),
      });
    });

    await syncNotificationInstallation(
      registry: _notificationRegistry,
      uid: user.uid,
    );
  }

  Future<void> signOut() async {
    await _recoverySessionGuard.beginSessionEnd();
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
      } catch (error, stackTrace) {
        debugPrint(
          'Could not remove notification installation during sign out: $error',
        );
        AppLogger.warning(
          'Could not remove notification installation during sign out',
          error: error,
          stackTrace: stackTrace,
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
    } catch (error, stackTrace) {
      debugPrint(
        'Google sign-out cleanup failed after Firebase sign-out: $error',
      );
      AppLogger.warning(
        'Google sign-out cleanup failed after Firebase sign-out',
        error: error,
        stackTrace: stackTrace,
        context: const {'app_area': 'auth', 'auth_stage': 'google_sign_out'},
      );
    }

    try {
      await _notificationRegistry.retireMessagingToken();
    } catch (error, stackTrace) {
      debugPrint('Could not retire the local messaging token: $error');
      AppLogger.warning(
        'Could not retire the local messaging token',
        error: error,
        stackTrace: stackTrace,
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

Future<void> syncNotificationInstallation({
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
