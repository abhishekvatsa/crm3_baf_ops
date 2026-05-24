// FILE: lib/features/auth/providers/auth_provider.dart

import 'dart:async' show unawaited;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/user_model.dart';
import '../../maintenance/data/maintenance_model.dart';
import '../../../core/providers/sync_providers.dart';
import '../../../core/services/app_logger.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentAppUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges().asyncExpand((user) {
    if (user == null) return Stream<AppUser?>.value(null);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return AppUser.fromFirestore(data, doc.id);
    });
  });
});

/// Keeps Crashlytics identity aligned with the current approved/pending app user.
///
/// Privacy policy for observability: use UID + role/approval context only.
/// Do not send email, display name, ticket text, module responses, or plant
/// evidence to Crashlytics.
final crashlyticsIdentitySyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AppUser?>>(
    currentAppUserProvider,
    (previous, next) {
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
    },
    fireImmediately: true,
  );
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final Ref _ref;

  AuthService(this._ref);

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

    final fcmToken = await _readFcmToken();
    final userRef = _firestore.collection('users').doc(user.uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        transaction.set(userRef, _pendingUserPayload(user, fcmToken));
        return;
      }

      final updateMap = <String, dynamic>{
        'name': _cleanProfileText(user.displayName),
        'email': _cleanProfileText(user.email),
        'photoUrl': _cleanOptionalText(user.photoURL),
      };

      if (fcmToken != null) {
        updateMap['fcmToken'] = fcmToken;
      }

      transaction.update(userRef, updateMap);
    });
  }

  Future<void> signOut() async {
    unawaited(AppLogger.clearUserContext());

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': null,
        });
      } catch (e, st) {
        debugPrint('⚠️ Could not clear FCM token during sign out: $e');
        AppLogger.warning(
          'Could not clear FCM token during sign out',
          error: e,
          stackTrace: st,
          context: const {
            'app_area': 'auth',
            'auth_stage': 'sign_out_clear_fcm',
          },
        );
      }
    }

    try {
      await _googleSignIn.signOut();
    } catch (e, st) {
      debugPrint('⚠️ Google sign-out failed, continuing Firebase sign-out: $e');
      AppLogger.warning(
        'Google sign-out failed; continuing Firebase sign-out',
        error: e,
        stackTrace: st,
        context: const {
          'app_area': 'auth',
          'auth_stage': 'google_sign_out',
        },
      );
    }

    await _auth.signOut();

    try {
      _ref.read(syncOnceProvider.notifier).state = false;
    } catch (_) {}
  }

  Map<String, dynamic> _pendingUserPayload(User user, String? fcmToken) {
    return {
      'name': _cleanProfileText(user.displayName),
      'email': _cleanProfileText(user.email),
      'photoUrl': _cleanOptionalText(user.photoURL),
      'roles': [AppRole.operations.name],
      'isApproved': false,
      'fcmToken': fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<String?> _readFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e, st) {
      debugPrint('⚠️ FCM token fetch failed: $e');
      AppLogger.warning(
        'FCM token fetch failed',
        error: e,
        stackTrace: st,
        context: const {
          'app_area': 'auth',
          'auth_stage': 'fcm_token_fetch',
        },
      );
      return null;
    }
  }

  String _cleanProfileText(String? value) => value?.trim() ?? '';

  String? _cleanOptionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));
