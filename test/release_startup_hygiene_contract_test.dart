import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('67F release startup and Android hygiene contract', () {
    test(
      'main starts inside crash-reporting zone and preserves startup order',
      () {
        final source = _readText('lib/main.dart');
        final mainBlock = _blockStartingAt(source, 'void main()');
        final firebaseBlock = _blockStartingAt(
          source,
          'Future<StartupFailure?> _initializeFirebaseAndCrashReporting()',
        );

        _expectOrder(mainBlock, const [
          'runCrashReportingZoned(() async {',
          'WidgetsFlutterBinding.ensureInitialized();',
          'var startupFailure = await _initializeFirebaseAndCrashReporting();',
          'await _requestStartupNotificationPermission();',
          'startupFailure = await _initializeLocalDatabase();',
          'runApp(ProviderScope(child: CrmBafApp(startupFailure: startupFailure)));',
        ]);
        expect(mainBlock, isNot(contains('Firebase.initializeApp')));
        expect(mainBlock, isNot(contains('Isar.open')));

        _expectOrder(firebaseBlock, const [
          'await Firebase.initializeApp(',
          'await AppLogger.init(throwOnFailure: true);',
          'installGlobalCrashReportingHandlers();',
        ]);
        expect(firebaseBlock, contains("stage: 'firebase_initialize'"));
        expect(firebaseBlock, contains("stage: 'app_logger_init'"));
      },
    );

    test('local Isar opens only after schema guard and remains web-safe', () {
      final source = _readText('lib/main.dart');
      final openBlock = _blockStartingAt(
        source,
        'Future<Isar> _openLocalIsar()',
      );
      final initializeLocalDbBlock = _blockStartingAt(
        source,
        'Future<StartupFailure?> _initializeLocalDatabase()',
      );

      _expectOrder(openBlock, const [
        'final dir = await getApplicationDocumentsDirectory();',
        'await ensureIsarSchemaBeforeOpen(databaseDirectoryPath: dir.path);',
        'final localIsar = await Isar.open(_isarSchemas, directory: dir.path);',
        'final repair = await repairPlannedJobLocalLinks(localIsar);',
        'return localIsar;',
        'await localIsar.close();',
        'rethrow;',
      ]);
      expect(openBlock, contains('try {'));
      expect(openBlock, contains('catch (_)'));
      expect(openBlock, contains('repairPlannedJobLocalLinks(localIsar)'));
      expect(openBlock, contains('await localIsar.close();'));
      expect(openBlock, contains('rethrow;'));
      expect(_occurrences(source, 'Isar.open('), 1);
      expect(initializeLocalDbBlock, contains('if (kIsWeb)'));
      expect(initializeLocalDbBlock, contains('return null;'));
      expect(initializeLocalDbBlock, contains("stage: 'local_database_open'"));
    });

    test('notification permission is best-effort and never blocks startup', () {
      final source = _readText('lib/main.dart');
      final notificationBlock = _blockStartingAt(
        source,
        'Future<void> _requestStartupNotificationPermission()',
      );

      expect(notificationBlock, contains('if (kIsWeb)'));
      expect(notificationBlock, contains('try {'));
      expect(
        notificationBlock,
        contains('FirebaseMessaging.instance.requestPermission'),
      );
      expect(
        notificationBlock,
        contains("reason: 'notification_permission_request_failed'"),
      );
      expect(
        notificationBlock,
        isNot(contains('return _captureStartupFailure')),
        reason:
            'Notification permission failure must not block release startup.',
      );
    });

    test(
      'startup sync and live mirror start after first frame and dispose cleanly',
      () {
        final source = _readText('lib/main.dart');
        final gateBlock = _blockStartingAt(
          source,
          'class _StartupSyncGateState',
        );
        final initStateBlock = _blockStartingAt(gateBlock, 'void initState()');
        final initialSyncBlock = _blockStartingAt(
          gateBlock,
          'void _startInitialSyncOnce()',
        );
        final backgroundBlock = _blockStartingAt(
          gateBlock,
          'void _startBackgroundSyncServices()',
        );
        final mirrorBlock = _blockStartingAt(
          gateBlock,
          'void _startOrUpdateLiveMaintenanceMirror()',
        );
        final disposeBlock = _blockStartingAt(gateBlock, 'void dispose()');

        _expectOrder(initStateBlock, const [
          'WidgetsBinding.instance.addObserver(this);',
          'WidgetsBinding.instance.addPostFrameCallback((_) {',
        ]);
        expect(initStateBlock, contains('if (!mounted)'));
        expect(initStateBlock, contains('_startBackgroundSyncServices();'));
        expect(initStateBlock, contains('_startInitialSyncOnce();'));

        expect(initialSyncBlock, contains('Future.microtask(() async {'));
        expect(
          initialSyncBlock,
          contains("runFullSyncWithResult(reason: 'auth_gate', force: true)"),
        );
        expect(
          initialSyncBlock,
          contains("reason: 'startup_sync_gate_failed'"),
        );
        expect(backgroundBlock, contains('Future.microtask(() {'));
        expect(
          backgroundBlock,
          contains('ref.read(autoSyncServiceProvider).start();'),
        );
        expect(
          backgroundBlock,
          contains('_startOrUpdateLiveMaintenanceMirror();'),
        );
        expect(mirrorBlock, contains('if (kIsWeb || !mounted)'));
        expect(mirrorBlock, contains('LiveRemoteSyncService(isar, ref.read)'));
        expect(
          disposeBlock,
          contains('WidgetsBinding.instance.removeObserver(this);'),
        );
        expect(
          disposeBlock,
          contains('ref.read(autoSyncServiceProvider).stop();'),
        );
        expect(disposeBlock, contains('_liveRemoteSyncService?.dispose();'));
      },
    );

    test('Crashlytics collection is release-safe and privacy constrained', () {
      final logger = _readText('lib/core/services/app_logger.dart');
      final bootstrap = _readText(
        'lib/core/services/crash_reporting_bootstrap.dart',
      );
      final initBlock = _blockStartingAt(logger, 'static Future<void> init({');

      expect(logger, contains('bool collectInDebug = false'));
      expect(logger, contains('bool collectInProfile = false'));
      expect(logger, contains('bool collectInRelease = true'));
      expect(initBlock, contains('if (kIsWeb)'));
      expect(initBlock, contains('Crashlytics disabled on Flutter web.'));
      expect(
        initBlock,
        contains(
          'FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled',
        ),
      );
      expect(initBlock, contains("'build_mode'"));
      expect(initBlock, contains("'crashlytics_collecting'"));
      expect(logger, contains('Do not pass email/name here.'));
      expect(logger, contains('singleLine.length <= 512'));
      expect(
        bootstrap,
        contains('FlutterError.onError = AppLogger.recordFlutterError;'),
      );
      expect(
        bootstrap,
        contains(
          'PlatformDispatcher.instance.onError = AppLogger.recordPlatformError;',
        ),
      );
      expect(
        bootstrap,
        isNot(contains('debugPrint =')),
        reason: 'Release logging must not globally hijack debugPrint.',
      );
    });

    test(
      'release config keeps Firebase, Functions, and Android registration aligned',
      () {
        final pubspec = _readText(
          'pubspec.yaml',
          fallback: 'Other root files/pubspec.yaml',
        );
        final firebase = _readJson(
          'firebase.json',
          fallback: 'Other root files/firebase.json',
        );
        final functionsPackage = _readJson('functions/package.json');

        expect(pubspec, contains('sdk: ^3.7.0'));
        expect(pubspec, contains('firebase_core:'));
        expect(pubspec, contains('firebase_auth:'));
        expect(pubspec, contains('cloud_firestore:'));
        expect(pubspec, contains('cloud_functions:'));
        expect(pubspec, contains('firebase_messaging:'));
        expect(pubspec, contains('firebase_crashlytics:'));
        expect(pubspec, contains('google_sign_in: 6.2.1'));

        final flutter = Map<String, dynamic>.from(firebase['flutter'] as Map);
        final platforms = Map<String, dynamic>.from(
          flutter['platforms'] as Map,
        );
        final android = Map<String, dynamic>.from(platforms['android'] as Map);
        final androidDefault = Map<String, dynamic>.from(
          android['default'] as Map,
        );
        expect(androidDefault['projectId'], 'crm3-baf-ops-b8638');
        expect(
          androidDefault['appId'],
          '1:894346496105:android:c320c57f2393dceee63af8',
        );
        expect(
          androidDefault['fileOutput'],
          'android/app/google-services.json',
        );

        final functions = List<Map<String, dynamic>>.from(
          (firebase['functions'] as List).map(
            (entry) => Map<String, dynamic>.from(entry as Map),
          ),
        );
        expect(
          functions.any(
            (entry) =>
                entry['source'] == 'functions' &&
                entry['disallowLegacyRuntimeConfig'] == true,
          ),
          isTrue,
        );
        expect(functionsPackage['engines'], containsPair('node', '22'));
        expect(functionsPackage['scripts'], containsPair('build', 'tsc'));
        expect(
          functionsPackage['scripts'],
          containsPair('test', 'npm run build && jest --runInBand'),
        );
      },
    );
  });
}

String _readText(String path, {String? fallback}) {
  final file = _repoFile(path, fallback: fallback);
  expect(file.existsSync(), isTrue, reason: '${file.path} must exist.');
  return file.readAsStringSync();
}

Map<String, dynamic> _readJson(String path, {String? fallback}) {
  final decoded = jsonDecode(_readText(path, fallback: fallback));
  expect(decoded, isA<Map>());
  return Map<String, dynamic>.from(decoded as Map);
}

File _repoFile(String path, {String? fallback}) {
  final primary = File(path);
  if (primary.existsSync()) return primary;
  if (fallback != null) {
    final secondary = File(fallback);
    if (secondary.existsSync()) return secondary;
  }
  return primary;
}

void _expectOrder(
  String source,
  List<String> markers, {
  List<String> allowFallbackMarkers = const <String>[],
}) {
  var offset = 0;
  for (var markerIndex = 0; markerIndex < markers.length; markerIndex++) {
    final marker = markers[markerIndex];
    var index = source.indexOf(marker, offset);
    if (index < 0 && allowFallbackMarkers.isNotEmpty) {
      for (final fallback in allowFallbackMarkers) {
        final fallbackIndex = source.indexOf(fallback, offset);
        if (fallbackIndex >= 0) {
          index = fallbackIndex;
          break;
        }
      }
    }
    expect(index, isNonNegative, reason: 'Missing marker in order: $marker');
    offset = index + marker.length;
  }
}

int _occurrences(String source, String needle) {
  var count = 0;
  var offset = 0;
  while (true) {
    final index = source.indexOf(needle, offset);
    if (index < 0) return count;
    count++;
    offset = index + needle.length;
  }
}

String _blockStartingAt(String source, String marker) {
  final start = source.indexOf(marker);
  expect(start, isNonNegative, reason: 'Missing marker: $marker');
  final open = _bodyBraceIndex(source, start);
  expect(open, isNonNegative, reason: 'Missing opening brace for: $marker');

  var depth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inTripleSingleQuote = false;
  var inTripleDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var i = open; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    final next2 = i + 2 < source.length ? source[i + 2] : '';

    if (inLineComment) {
      if (char == '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inTripleSingleQuote) {
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inTripleDoubleQuote) {
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDoubleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inSingleQuote || inDoubleQuote) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (inSingleQuote && char == "'") inSingleQuote = false;
      if (inDoubleQuote && char == '"') inDoubleQuote = false;
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      i++;
      continue;
    }
    if (char == '/' && next == '*') {
      inBlockComment = true;
      i++;
      continue;
    }
    if (char == "'" && next == "'" && next2 == "'") {
      inTripleSingleQuote = true;
      i += 2;
      continue;
    }
    if (char == '"' && next == '"' && next2 == '"') {
      inTripleDoubleQuote = true;
      i += 2;
      continue;
    }
    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }

    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }

  fail('Could not close block for marker: $marker');
}

int _bodyBraceIndex(String source, int start) {
  var parenDepth = 0;
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var inTripleSingleQuote = false;
  var inTripleDoubleQuote = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var i = start; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    final next2 = i + 2 < source.length ? source[i + 2] : '';

    if (inLineComment) {
      if (char == '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inTripleSingleQuote) {
      if (char == "'" && next == "'" && next2 == "'") {
        inTripleSingleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inTripleDoubleQuote) {
      if (char == '"' && next == '"' && next2 == '"') {
        inTripleDoubleQuote = false;
        i += 2;
      }
      continue;
    }
    if (inSingleQuote || inDoubleQuote) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (inSingleQuote && char == "'") inSingleQuote = false;
      if (inDoubleQuote && char == '"') inDoubleQuote = false;
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      i++;
      continue;
    }
    if (char == '/' && next == '*') {
      inBlockComment = true;
      i++;
      continue;
    }
    if (char == "'" && next == "'" && next2 == "'") {
      inTripleSingleQuote = true;
      i += 2;
      continue;
    }
    if (char == '"' && next == '"' && next2 == '"') {
      inTripleDoubleQuote = true;
      i += 2;
      continue;
    }
    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }

    if (char == '(') {
      parenDepth++;
      continue;
    }
    if (char == ')' && parenDepth > 0) {
      parenDepth--;
      continue;
    }
    if (char == '{' && parenDepth == 0) {
      return i;
    }
  }

  return -1;
}
