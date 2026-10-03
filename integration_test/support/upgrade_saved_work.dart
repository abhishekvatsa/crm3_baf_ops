// DEV APK-replacement rehearsal. No alternative database, provider override,
// direct server write, fabricated acceptance, or automatic reconnect is used.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_record.dart';
import 'package:crm3_baf_ops/core/persistence/durable_submission_repository.dart';
import 'package:crm3_baf_ops/core/persistence/request_identity_journal.dart';
import 'package:crm3_baf_ops/core/services/isar_schema_migration.dart';
import 'package:crm3_baf_ops/core/services/global_pull_protocol.dart';
import 'package:crm3_baf_ops/core/services/retained_row_mutations.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/providers/maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/baf_knowledge_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_diary_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/job_template_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/baf_knowledge_layer.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_governance_models.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/domain/knowledge_import_journal.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/job_diary_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/planned_maintenance_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/repositories/knowledge_import_journal_repository.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/module_composer_screen.dart';
import 'journey_pointer.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

const upgradeBaselineHead = '42726508b0e5797f6194cacbb1a2a9f2ea0354fd';
const upgradeSourceDigest = String.fromEnvironment(
  'CRM_DEV_UPGRADE_SOURCE_SHA256',
);
const upgradeRole = String.fromEnvironment('CRM_DEV_UPGRADE_ROLE');
const upgradeRunId = String.fromEnvironment('CRM_DEV_UPGRADE_RUN_ID');

void requireUpgradeEnvironment(String role) {
  expect(kReleaseMode, false);
  expect(Platform.isAndroid, true);
  expect(crm3UseEmulators, true);
  expect(crm3DemoProjectId, 'demo-crm3-ci-journeys');
  expect(crm3EmulatorHost, '10.0.2.2');
  expect(crm3AuthEmulatorPort, 19099);
  expect(crm3FirestoreEmulatorPort, 18080);
  expect(crm3FunctionsEmulatorPort, 15001);
  expect(upgradeRole, role);
  expect(RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(upgradeSourceDigest), true);
  expect(RegExp(r'^[a-z0-9-]{8,64}$').hasMatch(upgradeRunId), true);
}

String upgradeHash(String raw) => sha256.convert(utf8.encode(raw)).toString();

Future<Directory> upgradeDirectory() async => Directory(
  '${(await getApplicationSupportDirectory()).path}/upgrade-saved-work-v1',
);

Future<void> writeUpgradeEvidence(
  Directory directory,
  String name,
  Object data,
) async {
  final target = File('${directory.path}/$name.json');
  expect(
    await target.exists(),
    false,
    reason: 'Never overwrite earlier upgrade evidence.',
  );
  await target.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    flush: true,
  );
}

Future<void> waitUpgrade(
  WidgetTester tester,
  bool Function() ready,
  String reason, {
  int seconds = 90,
}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ready() && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(ready(), true, reason: reason);
}

Future<void> startUpgradeApp(WidgetTester tester) async {
  final flutterHandler = FlutterError.onError;
  final platformHandler = PlatformDispatcher.instance.onError;
  try {
    await tester.runAsync(app.startCrmBafApp);
  } finally {
    FlutterError.onError = flutterHandler;
    PlatformDispatcher.instance.onError = platformHandler;
  }
  expect(Firebase.app().options.projectId, crm3DemoProjectId);
  final documents = await getApplicationDocumentsDirectory();
  expect(isar.directory, documents.path);
  expect(isar.name, Isar.defaultName);
  expect(
    await File('${documents.path}/${Isar.defaultName}.isar').exists(),
    true,
  );
}

Future<AppUser> authenticateUpgradeActor(WidgetTester tester) async {
  await waitUpgrade(
    tester,
    () =>
        find.text('Sign in with Google').evaluate().isNotEmpty ||
        find.byType(HomeScreen).evaluate().isNotEmpty,
    'Actual app authentication must be ready.',
  );
  if (find.text('Sign in with Google').evaluate().isNotEmpty) {
    final target = find.text('Sign in with Google').hitTestable();
    expect(target, findsOneWidget);
    await tester.tap(target);
  }
  await waitUpgrade(
    tester,
    () => find.byType(HomeScreen).evaluate().isNotEmpty,
    'Actual approved DEV account must reach Home.',
  );
  final user = FirebaseAuth.instance.currentUser!;
  expect(user.email, 'dev.cf01-a@example.invalid');
  final raw = await FirebaseFirestore.instance
      .doc('users/${user.uid}')
      .get(const GetOptions(source: Source.server));
  expect(
    raw.exists && !raw.metadata.isFromCache && !raw.metadata.hasPendingWrites,
    true,
  );
  final actor = AppUser.fromFirestore(
    raw.data()!,
    user.uid,
    fromCache: false,
    hasPendingWrites: false,
    observedAt: DateTime.now(),
  );
  expect(
    actor.isApproved && actor.isAdmin && actor.hasServerAuthorityObservation,
    true,
  );
  final response =
      await FirebaseFunctions.instanceFor(region: crm3CallableRegion)
          .httpsCallable(
            globalPullBeginCallableName,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Object?>();
  final authority = GlobalPullRunAuthority.fromCallableData(
    response.data,
    expectedUid: user.uid,
  );
  expect(authority.actorUid, actor.uid);
  // The real response has protocolVersion, not a synthetic "ready" field.
  // Store only its returned version and the fact that strict validation passed.
  await writeUpgradeEvidence(await upgradeDirectory(), 'online-readiness', {
    'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'callable': globalPullBeginCallableName,
    'returnedProtocolVersion': (response.data as Map)['protocolVersion'],
    'validatedResponse': true,
    'forcedServerProfileReadSucceeded': true,
    'tokenOrRawAuthorityRetained': false,
  });
  return actor;
}

// Uses the real composer screen and its private debounce/persistence path.
// No recovery blob is injected and no publication action is taken.
Future<void> saveComposerUpgradeDraft(WidgetTester tester) async {
  final home = find.byType(HomeScreen);
  expect(home, findsOneWidget);
  unawaited(
    Navigator.of(tester.element(home)).push<void>(
      MaterialPageRoute(
        builder: (_) => const ModuleComposerScreen(
          initialJobTemplateJson: '{}',
          initialModuleSnapshotsJson: '[]',
          initialFieldDefinitionsJson: '[]',
          initialChecklistJson: '[]',
          recoveryScopeId: 'upgrade-$upgradeRunId',
        ),
      ),
    ),
  );
  await waitUpgrade(
    tester,
    () => find
        .byKey(const Key('module-composer-template-title'))
        .evaluate()
        .isNotEmpty,
    'Real authorized composer must open.',
  );
  final title = find.byKey(const Key('module-composer-template-title'));
  await tester.enterText(title, 'DEV upgrade retained composer draft');
  await tapControl(tester, find.byTooltip('Add blank module'));
  final end = DateTime.now().add(const Duration(seconds: 30));
  var saved = false;
  while (!saved && DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final keys = prefs
        .getKeys()
        .where(
          (key) =>
              key.startsWith('RECOVERY::') &&
              key.contains('upgrade-$upgradeRunId'),
        )
        .toList();
    if (keys.length == 1) {
      final raw = jsonDecode(prefs.getString(keys.single)!) as Map;
      final job = jsonDecode(raw['jobTemplateSnapshotJson'] as String) as Map;
      final modules = jsonDecode(raw['moduleSnapshotsJson'] as String) as List;
      saved =
          jsonEncode(job).contains('DEV upgrade retained composer draft') &&
          modules.isNotEmpty;
    }
  }
  expect(
    saved,
    true,
    reason:
        'Actual composer debounce must retain title and module in real SharedPreferences.',
  );
}

Future<void> waitOfflineMarker(Directory directory) async {
  final marker = File('${directory.path}/stage.txt');
  final end = DateTime.now().add(const Duration(minutes: 5));
  while (DateTime.now().isBefore(end)) {
    if (await marker.exists()) {
      final value = (await marker.readAsString()).trim();
      expect(
        value,
        'offline-ready',
        reason: 'Only the fixed root-controlled stage is accepted.',
      );
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  fail(
    'Root did not provide the offline-ready marker. No saved-work fixture was created.',
  );
}

// This exact Android SDK aggregate error is a failed client-context
// prerequisite. It is never, by itself, proof that callable HTTP was attempted.
String classifyUpgradeCallableObservation({
  required String code,
  required String? message,
  required bool governedAndroidEmulator,
  required String expectedUid,
  required String? actorBefore,
  required String? actorAfter,
  required Set<int> blockedPortsBefore,
  required Set<int> blockedPortsAfter,
  required String serverReadFailure,
}) {
  const expectedPorts = {19099, 18080, 15001};
  bool exactPorts(Set<int> ports) =>
      ports.length == expectedPorts.length && ports.containsAll(expectedPorts);
  if (expectedUid.isEmpty ||
      actorBefore != expectedUid ||
      actorAfter != expectedUid ||
      !exactPorts(blockedPortsBefore) ||
      !exactPorts(blockedPortsAfter) ||
      !{
        'unavailable',
        'deadline-exceeded',
        'bounded-timeout',
      }.contains(serverReadFailure)) {
    throw StateError(
      'Offline transport and same-actor evidence are incomplete.',
    );
  }
  if ({'unavailable', 'deadline-exceeded', 'internal'}.contains(code)) {
    return 'callable-failure-while-offline';
  }
  if (code == 'bounded-timeout') return 'bounded-timeout';
  if (governedAndroidEmulator &&
      code == 'unknown' &&
      message ==
          'java.util.concurrent.ExecutionException: '
              '1 out of 2 underlying tasks failed') {
    return 'client-context-prerequisite-blocked';
  }
  throw StateError('Unexpected callable failure; evidence was preserved.');
}

Future<Set<int>> _probeUpgradeBlockedPorts() async {
  final blocked = <int>{};
  for (final port in [19099, 18080, 15001]) {
    Socket? socket;
    var unavailable = false;
    try {
      socket = await Socket.connect(
        crm3EmulatorHost,
        port,
        timeout: const Duration(seconds: 3),
      );
    } on SocketException {
      unavailable = true;
    } on TimeoutException {
      unavailable = true;
    } finally {
      socket?.destroy();
    }
    expect(
      unavailable,
      true,
      reason: 'The emulator still reaches demo port $port.',
    );
    blocked.add(port);
  }
  return blocked;
}

Future<Map<String, Object?>> requireUnavailableTransport(String uid) async {
  final proof = <String, Object?>{
    'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
  };
  final actorBefore = FirebaseAuth.instance.currentUser?.uid;
  expect(uid, isNotEmpty);
  expect(actorBefore, uid);
  // Real transport probes bracket the one callable observation. Account state,
  // a stage marker, or a callable error code cannot stand in for these probes.
  final before = await _probeUpgradeBlockedPorts();
  for (final port in before) {
    proof['socket${port}Unavailable'] = true;
  }
  var readFailed = false;
  try {
    await FirebaseFirestore.instance
        .doc('users/$uid')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 15));
  } on FirebaseException catch (error) {
    expect(error.code, anyOf('unavailable', 'deadline-exceeded'));
    proof['firestoreFailure'] = error.code;
    readFailed = true;
  } on TimeoutException {
    proof['firestoreFailure'] = 'bounded-timeout';
    readFailed = true;
  }
  expect(readFailed, true, reason: 'A forced server read must be unavailable.');
  expect(FirebaseAuth.instance.currentUser?.uid, uid);
  FirebaseFunctionsException? callableError;
  var callableTimedOut = false;
  var callableSucceeded = false;
  try {
    await FirebaseFunctions.instanceFor(region: crm3CallableRegion)
        .httpsCallable(
          'beginGlobalPullRun',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 12)),
        )
        .call<void>()
        .timeout(const Duration(seconds: 15));
    callableSucceeded = true;
  } on FirebaseFunctionsException catch (error) {
    callableError = error;
  } on TimeoutException {
    callableTimedOut = true;
  }
  expect(
    callableSucceeded,
    false,
    reason: 'The offline callable must not succeed.',
  );
  expect(callableError != null || callableTimedOut, true);
  final after = await _probeUpgradeBlockedPorts();
  final disposition = classifyUpgradeCallableObservation(
    code: callableError?.code ?? 'bounded-timeout',
    message: callableError?.message,
    governedAndroidEmulator:
        Platform.isAndroid &&
        crm3UseEmulators &&
        crm3DemoProjectId == 'demo-crm3-ci-journeys' &&
        Firebase.app().options.projectId == crm3DemoProjectId &&
        crm3EmulatorHost == '10.0.2.2' &&
        crm3AuthEmulatorPort == 19099 &&
        crm3FirestoreEmulatorPort == 18080 &&
        crm3FunctionsEmulatorPort == 15001,
    expectedUid: uid,
    actorBefore: actorBefore,
    actorAfter: FirebaseAuth.instance.currentUser?.uid,
    blockedPortsBefore: before,
    blockedPortsAfter: after,
    serverReadFailure: proof['firestoreFailure'] as String,
  );
  for (final port in after) {
    proof['socket${port}UnavailableAfter'] = true;
  }
  proof['callableFailure'] = callableError?.code ?? 'bounded-timeout';
  proof['callableDisposition'] = disposition;
  proof['callableHttpAttemptObserved'] = false;
  proof['sameActorBeforeAndAfter'] = true;
  proof['connectivityFlagUsedAsProof'] = false;
  return proof;
}

Future<Map<String, Object?>> saveUpgradeWork(
  AppUser actor, {
  // Host regression injects origin callbacks only; Android uses the real
  // authenticated defaults and every save still enters its actual repository.
  RetainedRowMutations? retainedMutations,
}) async {
  final now = DateTime.now().toUtc();
  const prefix = 'upgrade-$upgradeRunId';
  // Five supported repository saves. These are local synthetic operator inputs,
  // not server fixtures, accepted jobs, completed work, or safety commands.
  final ticket = MaintenanceRecord()
    ..firestoreId = '$prefix-ticket'
    ..assetType = AssetType.furnace
    ..assetNumber = 1
    ..maintenanceType = MaintenanceType.inspection
    ..description = 'DEV upgrade retained inspection notes'
    ..routedTo = RoutedTo.mechanical
    ..startDate = now
    ..createdAt = now
    ..updatedAt = now
    ..loggedByUid = actor.uid
    ..loggedByName = actor.name;
  await IsarMaintenanceRepository().saveTicket(ticket);
  final abnormality = ChargeAbnormality.createRaCoilColour(
    firestoreId: '$prefix-abnormality',
    sourceChargeNo: 77991,
    affectedAssets: [
      const AffectedAssetRef(assetType: AssetType.furnace, assetNumber: 1),
    ],
    observedReason: 'DEV upgrade retained finding; no RA acceptance',
    loggedByUid: actor.uid,
    loggedByName: actor.name,
  );
  await IsarAbnormalityRepository(
    retainedMutations: retainedMutations,
  ).saveAbnormality(abnormality, actor: actor);
  final diary = JobDiaryEntry()
    ..firestoreId = '$prefix-diary'
    ..assetType = AssetType.furnace
    ..assetNumber = 1
    ..note = 'DEV upgrade unsubmitted diary observation'
    ..pendingIssue = 'Retain this unresolved note'
    ..createdByUid = actor.uid
    ..createdByName = actor.name
    ..createdAt = now
    ..updatedAt = now;
  await IsarJobDiaryRepository().saveEntry(diary, actor: actor);
  final type = AbnormalityType()
    ..firestoreId = '$prefix-type'
    ..code = 'UPGRADE-$upgradeRunId'
    ..title = 'DEV upgrade retained catalogue draft'
    ..createdByUid = actor.uid
    ..createdByName = actor.name
    ..lastEditedByUid = actor.uid
    ..lastEditedByName = actor.name
    ..createdAt = now
    ..updatedAt = now;
  await IsarAbnormalityRepository(
    retainedMutations: retainedMutations,
  ).saveType(type, actor: actor);
  final template = JobTemplate()
    ..firestoreId = '$prefix-template'
    ..jobName = 'DEV upgrade retained template draft'
    ..applicableAssetType = AssetType.furnace
    ..assignedAgencies = ['mechanical']
    ..createdAt = now
    ..updatedAt = now;
  await IsarPlannedRepository(
    retainedMutations: retainedMutations,
  ).saveTemplate(template, actor: actor);
  final row = BafKnowledgeRow.fromEntry(
    BafKnowledgeLayer.entries.first,
    actorUid: actor.uid,
    actorName: actor.name,
    now: now,
    changeSummary: 'DEV upgrade draft only',
  );
  final draft = KnowledgeRowDraft.fromRow(row)
    ..taskText = 'DEV upgrade immutable pending import draft'
    ..changeSummary = 'Retain local draft; do not import';
  final intent = KnowledgeImportIntent(
    requestId: '$prefix-import',
    actorUid: actor.uid,
    actorName: actor.name,
    rows: [
      KnowledgeImportRowIntent(
        rowCode: row.rowCode,
        draftJson: jsonEncode(draft.toEntryMap()),
        reason: draft.changeSummary,
        beforeJson: null,
      ),
    ],
  );
  await KnowledgeImportJournalRepository().retain(intent);
  return {'prefix': prefix, 'importId': intent.requestId};
}

Future<Map<String, Object?>> captureUpgradeWork(
  String prefix,
  String uid,
) async {
  final business = <String, Object?>{
    'maintenance': await isar.maintenanceRecords
        .filter()
        .firestoreIdEqualTo('$prefix-ticket')
        .exportJson(),
    'abnormality': await isar.chargeAbnormalitys
        .filter()
        .firestoreIdEqualTo('$prefix-abnormality')
        .exportJson(),
    'diary': await isar.jobDiaryEntrys
        .filter()
        .firestoreIdEqualTo('$prefix-diary')
        .exportJson(),
    'catalogue': await isar.abnormalityTypes
        .filter()
        .firestoreIdEqualTo('$prefix-type')
        .exportJson(),
    'template': await isar.jobTemplates
        .filter()
        .firestoreIdEqualTo('$prefix-template')
        .exportJson(),
  };
  for (final entries in business.values) {
    expect(entries, hasLength(1));
    expect((entries as List).single['isSynced'], false);
  }
  final retained = await isar.durableSubmissionRecords.where().findAll();
  final owned =
      retained
          .where(
            (row) =>
                row.resourceKey.contains('$prefix-type') ||
                row.resourceKey.contains('$prefix-template'),
          )
          .toList()
        ..sort((a, b) => a.submissionId.compareTo(b.submissionId));
  expect(
    owned,
    hasLength(2),
    reason:
        'The two actual catalogue/template repository saves retain exactly two immutable intents.',
  );
  final immutable = <Object?>[];
  final retryObservations = <Object?>[];
  for (final row in owned) {
    expect(row.actorUid, uid);
    expect(row.immutableSha256, upgradeHash(row.immutableJson));
    expect(
      row.receiptJson,
      isNull,
      reason: 'Offline save must not invent acceptance.',
    );
    expect(row.receiptSha256, isNull);
    immutable.add({
      'id': row.id,
      'submissionId': row.submissionId,
      'requestKey': row.requestKey,
      'resourceKey': row.resourceKey,
      'actorUid': row.actorUid,
      'immutableJson': row.immutableJson,
      'immutableSha256': row.immutableSha256,
    });
    retryObservations.add({
      'submissionId': row.submissionId,
      'state': row.stateKey,
      'attemptCount': row.attemptCount,
      'updatedAt': row.updatedAt.toUtc().toIso8601String(),
    });
  }
  final preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  final marker = await IsarSchemaMigrator.readCommittedMarker(
    SharedPreferencesIsarSchemaProvenanceStore(preferences),
  );
  expect(marker, isNotNull);
  expect(marker!.schemaVersion, 12);
  // Use the actual journal reader: current immutable slots are hashed keys,
  // while the original legacy slot remains readable and must not be rewritten.
  final importEvidence = RequestIdentityJournal<KnowledgeImportIntent>(
    legacyKey: 'PENDING_KNOWLEDGE_IMPORT::v1',
    decode: KnowledgeImportIntent.decode,
    requestIdOf: (intent) => intent.requestId,
  ).rawEvidence(preferences);
  expect(importEvidence, isNotEmpty);
  final importKeys = importEvidence.map((entry) => entry.key).toSet();
  final keys =
      preferences
          .getKeys()
          .where(
            (key) =>
                importKeys.contains(key) ||
                (key.startsWith('RECOVERY::') &&
                    key.contains('upgrade-$upgradeRunId')),
          )
          .toList()
        ..sort();
  expect(keys.where((key) => key.startsWith('RECOVERY::')), hasLength(1));
  final prefs = {for (final key in keys) key: preferences.get(key)};
  final imports = await KnowledgeImportJournalRepository().readAll();
  final matching = imports
      .where((value) => value.intent.requestId == '$prefix-import')
      .toList();
  expect(matching, hasLength(1));
  expect(matching.single.intent.actorUid, uid);
  expect(matching.single.outcomes, isEmpty);
  return {
    'business': business,
    'durableImmutable': immutable,
    'retryObservations': retryObservations,
    'preferences': prefs,
    'import': matching.single.intent.toMap(),
    'schemaMarker': marker.toJson(),
    'databaseDirectory': isar.directory,
    'databaseName': isar.name,
  };
}

Future<void> verifyUpgradeOwnership(
  Map<String, Object?> snapshot,
  String uid,
) async {
  final repository = DurableSubmissionRepository(isar);
  for (final value in snapshot['durableImmutable'] as List) {
    final row = value as Map;
    final result = await repository.claim(
      submissionId: row['submissionId'] as String,
      actorUid: 'different-dev-actor',
    );
    expect(result.disposition, DurableSubmissionClaimDisposition.actorMismatch);
    expect(result.mayDispatch, false);
    expect(result.submission.actorUid, uid);
    expect(
      result.submission.envelopeSha256,
      upgradeHash(
        (jsonDecode(row['immutableJson'] as String) as Map)['envelopeJson']
            as String,
      ),
    );
  }
}

Map<String, Object?> immutableUpgradeSnapshot(Map<String, Object?> snapshot) =>
    Map<String, Object?>.from(snapshot)..remove('retryObservations');
