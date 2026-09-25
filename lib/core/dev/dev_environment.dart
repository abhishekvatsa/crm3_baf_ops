/// Development-only Firebase wiring for the local emulator suite.
///
/// Everything in this file is inert unless `CRM_USE_EMULATORS=true` is passed
/// as a dart-define. A production build never sets it, so the production path
/// is byte-identical to what it was before this file existed.
///
/// Two independent safeguards keep development traffic away from production:
///
///  1. In emulator mode the app boots with [crm3DemoFirebaseOptions], whose
///     project id must begin with `demo-`. The Firebase emulator suite accepts
///     any project id, but a *real* Firebase project named `demo-…` does not
///     exist, so a service that is somehow not routed to an emulator fails
///     instead of quietly reaching production.
///  2. [connectCrm3Emulators] refuses to run in release mode and refuses a
///     non-demo project id.
///
/// The development app shares every business screen, repository, Isar schema
/// and synchronization path with production. Only the backend endpoints and the
/// installed application id differ.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Whether this build talks to the local Firebase emulator suite.
const bool crm3UseEmulators = bool.fromEnvironment('CRM_USE_EMULATORS');

const String crm3EmulatorHost = String.fromEnvironment(
  'CRM_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

const int crm3FirestoreEmulatorPort = int.fromEnvironment(
  'CRM_FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);

const int crm3AuthEmulatorPort = int.fromEnvironment(
  'CRM_AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);

const int crm3FunctionsEmulatorPort = int.fromEnvironment(
  'CRM_FUNCTIONS_EMULATOR_PORT',
  defaultValue: 5001,
);

/// Firebase requires a consistent project id across Auth, Firestore and
/// Functions for them to interact. The `demo-` prefix marks a project that has
/// no live resources.
const String crm3DemoProjectId = String.fromEnvironment(
  'CRM_DEMO_PROJECT_ID',
  defaultValue: 'demo-crm3-baf-ops',
);

/// The only Cloud Functions region this application calls. Every
/// `FirebaseFunctions.instanceFor` call in `lib/` uses it, and the plugin
/// caches one instance per (app, region), so wiring it once here reaches all of
/// them.
const String crm3CallableRegion = 'asia-south1';

/// Raised when development wiring is asked to do something unsafe.
class Crm3EmulatorConfigurationError extends Error {
  Crm3EmulatorConfigurationError(this.message);

  final String message;

  @override
  String toString() => 'Crm3EmulatorConfigurationError: $message';
}

/// Placeholder credentials for the emulator suite.
///
/// These are deliberately not real. The emulators do not validate them, and a
/// demo project id cannot resolve to a live Firebase project.
FirebaseOptions get crm3DemoFirebaseOptions {
  if (!crm3DemoProjectId.startsWith('demo-')) {
    throw Crm3EmulatorConfigurationError(
      'CRM_DEMO_PROJECT_ID must start with "demo-" so it cannot name a real '
      'Firebase project. Received: $crm3DemoProjectId',
    );
  }
  return const FirebaseOptions(
    apiKey: 'emulator-only-not-a-real-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: crm3DemoProjectId,
    storageBucket: '$crm3DemoProjectId.appspot.com',
  );
}

var _connected = false;

/// Points Auth, Firestore and Functions at the local emulator suite.
///
/// Call once, immediately after `Firebase.initializeApp`, before any Firebase
/// service is used. Calling it twice is a no-op rather than an error, because
/// the underlying plugins reject a second `useEmulator` call.
Future<void> connectCrm3Emulators() async {
  if (!crm3UseEmulators) {
    throw Crm3EmulatorConfigurationError(
      'connectCrm3Emulators() was called without CRM_USE_EMULATORS=true.',
    );
  }
  if (kReleaseMode) {
    throw Crm3EmulatorConfigurationError(
      'Emulator wiring is not permitted in a release build.',
    );
  }
  final projectId = Firebase.app().options.projectId;
  if (!projectId.startsWith('demo-')) {
    throw Crm3EmulatorConfigurationError(
      'Refusing to attach emulators to non-demo project "$projectId". The '
      'development app must boot with crm3DemoFirebaseOptions so that an '
      'unrouted call fails instead of reaching production.',
    );
  }
  if (_connected) return;
  _connected = true;

  FirebaseFirestore.instance.useFirestoreEmulator(
    crm3EmulatorHost,
    crm3FirestoreEmulatorPort,
  );
  await FirebaseAuth.instance.useAuthEmulator(
    crm3EmulatorHost,
    crm3AuthEmulatorPort,
  );
  FirebaseFunctions.instanceFor(
    region: crm3CallableRegion,
  ).useFunctionsEmulator(crm3EmulatorHost, crm3FunctionsEmulatorPort);

  debugPrint(
    '🧪 CRM-III DEV: project=$projectId '
    'firestore=$crm3EmulatorHost:$crm3FirestoreEmulatorPort '
    'auth=$crm3EmulatorHost:$crm3AuthEmulatorPort '
    'functions=$crm3EmulatorHost:$crm3FunctionsEmulatorPort '
    'region=$crm3CallableRegion',
  );
}
