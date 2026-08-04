import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const int notificationInstallationSchemaVersion = 1;
const String notificationInstallationsCollection = 'notification_installations';

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

abstract interface class NotificationInstallationIdStore {
  Future<String?> read();

  Future<void> write(String installationId);
}

class SharedPreferencesNotificationInstallationIdStore
    implements NotificationInstallationIdStore {
  static const String preferenceKey = 'crm3.notificationInstallationId.v1';

  final Future<SharedPreferences> Function() _preferencesLoader;

  SharedPreferencesNotificationInstallationIdStore({
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  @override
  Future<String?> read() async {
    final value = (await _preferencesLoader()).getString(preferenceKey);
    return value != null && _uuidV4Pattern.hasMatch(value) ? value : null;
  }

  @override
  Future<void> write(String installationId) async {
    if (!_uuidV4Pattern.hasMatch(installationId)) {
      throw ArgumentError.value(
        installationId,
        'installationId',
        'A lowercase UUID v4 is required.',
      );
    }
    final written = await (await _preferencesLoader()).setString(
      preferenceKey,
      installationId,
    );
    if (!written) {
      throw StateError('The notification installation ID was not persisted.');
    }
  }
}

abstract interface class NotificationInstallationDocumentStore {
  Future<void> upsert({
    required String uid,
    required String installationId,
    required String token,
    required String platform,
  });

  Future<void> remove({
    required String uid,
    required String installationId,
    String? expectedToken,
  });
}

class FirestoreNotificationInstallationDocumentStore
    implements NotificationInstallationDocumentStore {
  final FirebaseFirestore _firestore;

  FirestoreNotificationInstallationDocumentStore(this._firestore);

  @override
  Future<void> upsert({
    required String uid,
    required String installationId,
    required String token,
    required String platform,
  }) {
    final userRef = _firestore.collection('users').doc(uid);
    final installationRef = userRef
        .collection(notificationInstallationsCollection)
        .doc(installationId);

    return _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      if (!user.exists || user.data() == null) {
        throw StateError(
          'A canonical user profile is required before token registration.',
        );
      }

      transaction.set(installationRef, <String, dynamic>{
        'schemaVersion': notificationInstallationSchemaVersion,
        'token': token,
        'platform': platform,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (user.data()?['fcmToken'] == token) {
        transaction.update(userRef, <String, dynamic>{'fcmToken': null});
      }
    });
  }

  @override
  Future<void> remove({
    required String uid,
    required String installationId,
    String? expectedToken,
  }) {
    final userRef = _firestore.collection('users').doc(uid);
    final installationRef = userRef
        .collection(notificationInstallationsCollection)
        .doc(installationId);

    return _firestore.runTransaction((transaction) async {
      final user = await transaction.get(userRef);
      transaction.delete(installationRef);
      if (user.exists &&
          expectedToken != null &&
          user.data()?['fcmToken'] == expectedToken) {
        transaction.update(userRef, <String, dynamic>{'fcmToken': null});
      }
    });
  }
}

abstract interface class NotificationTokenSource {
  Future<String?> currentToken();

  Stream<String> get tokenRefreshes;

  Future<void> deleteToken();
}

class FirebaseMessagingNotificationTokenSource
    implements NotificationTokenSource {
  final FirebaseMessaging _messaging;

  FirebaseMessagingNotificationTokenSource(this._messaging);

  @override
  Future<String?> currentToken() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}

class NotificationInstallationRegistration {
  final String uid;
  final String installationId;
  final String token;
  final String platform;

  const NotificationInstallationRegistration({
    required this.uid,
    required this.installationId,
    required this.token,
    required this.platform,
  });
}

class NotificationInstallationRegistry {
  final NotificationInstallationIdStore _idStore;
  final NotificationInstallationDocumentStore _documentStore;
  final NotificationTokenSource _tokenSource;
  final Uuid _uuid;
  final String platform;

  String? _lastRegisteredUid;
  String? _lastRegisteredToken;
  String? _lastInstallationId;

  NotificationInstallationRegistry({
    required NotificationInstallationIdStore idStore,
    required NotificationInstallationDocumentStore documentStore,
    required NotificationTokenSource tokenSource,
    required this.platform,
    Uuid uuid = const Uuid(),
  }) : _idStore = idStore,
       _documentStore = documentStore,
       _tokenSource = tokenSource,
       _uuid = uuid {
    if (!_validPlatform(platform)) {
      throw ArgumentError.value(platform, 'platform');
    }
  }

  Stream<String> get tokenRefreshes => _tokenSource.tokenRefreshes;

  Future<NotificationInstallationRegistration?> registerCurrentToken({
    required String uid,
  }) async {
    final token = await _tokenSource.currentToken();
    if (token == null) return null;
    return registerToken(uid: uid, token: token);
  }

  Future<NotificationInstallationRegistration?> registerToken({
    required String uid,
    required String token,
  }) async {
    final canonicalUid = uid.trim();
    if (canonicalUid.isEmpty || canonicalUid != uid) {
      throw ArgumentError.value(uid, 'uid', 'A canonical UID is required.');
    }
    if (token.isEmpty || token.trim().isEmpty) return null;
    if (token.length > 4096) {
      throw ArgumentError.value(token.length, 'token.length');
    }

    final installationId = await _readOrCreateInstallationId();
    if (_lastRegisteredUid == uid &&
        _lastRegisteredToken == token &&
        _lastInstallationId == installationId) {
      return NotificationInstallationRegistration(
        uid: uid,
        installationId: installationId,
        token: token,
        platform: platform,
      );
    }

    await _documentStore.upsert(
      uid: uid,
      installationId: installationId,
      token: token,
      platform: platform,
    );
    _lastRegisteredUid = uid;
    _lastRegisteredToken = token;
    _lastInstallationId = installationId;

    return NotificationInstallationRegistration(
      uid: uid,
      installationId: installationId,
      token: token,
      platform: platform,
    );
  }

  Future<void> removeCurrentInstallation({required String uid}) async {
    final canonicalUid = uid.trim();
    if (canonicalUid.isEmpty || canonicalUid != uid) {
      throw ArgumentError.value(uid, 'uid', 'A canonical UID is required.');
    }
    final installationId = await _idStore.read();
    if (installationId == null) {
      observeSignedOut();
      return;
    }

    String? expectedToken =
        _lastRegisteredUid == uid ? _lastRegisteredToken : null;
    expectedToken ??= await _tokenSource.currentToken();
    await _documentStore.remove(
      uid: uid,
      installationId: installationId,
      expectedToken: expectedToken,
    );
    observeSignedOut();
  }

  Future<void> retireMessagingToken() => _tokenSource.deleteToken();

  void observeSignedOut() {
    _lastRegisteredUid = null;
    _lastRegisteredToken = null;
    _lastInstallationId = null;
  }

  Future<String> _readOrCreateInstallationId() async {
    final existing = await _idStore.read();
    if (existing != null) return existing;
    final created = _uuid.v4().toLowerCase();
    if (!_uuidV4Pattern.hasMatch(created)) {
      throw StateError('The UUID source returned a non-v4 installation ID.');
    }
    await _idStore.write(created);
    return created;
  }
}

String currentNotificationInstallationPlatform() {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

bool _validPlatform(String value) => const <String>{
  'android',
  'ios',
  'macos',
  'windows',
  'linux',
  'fuchsia',
  'web',
}.contains(value);
