import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'support/upgrade_saved_work.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'candidate APK reopens the same main store and exact pending work offline',
    (tester) async {
      requireUpgradeEnvironment('candidate');
      final directory = await upgradeDirectory();
      final baselineFile = File('${directory.path}/baseline.json');
      expect(
        await baselineFile.exists(),
        true,
        reason: 'A fresh install cannot pass as an upgrade.',
      );
      final baselineRaw = await baselineFile.readAsString();
      final baseline = jsonDecode(baselineRaw) as Map<String, dynamic>;
      expect(baseline['runId'], upgradeRunId);
      expect(baseline['baselineHead'], upgradeBaselineHead);
      expect(baseline['processId'], isNot(pid));
      expect(baseline['declaredSourceSha256'], isNot(upgradeSourceDigest));
      final documents = await getApplicationDocumentsDirectory();
      expect(await File('${documents.path}/default.isar').exists(), true);
      expect(
        (await File('${directory.path}/stage.txt').readAsString()).trim(),
        'offline-ready',
      );
      await startUpgradeApp(tester);
      await tester.runAsync(() async {
        final actor = FirebaseAuth.instance.currentUser;
        expect(
          actor,
          isNotNull,
          reason:
              'The existing authenticated session must survive package replacement.',
        );
        expect(actor!.uid, baseline['actorUid']);
        final offline = await requireUnavailableTransport(actor.uid);
        final snapshot = await captureUpgradeWork(
          baseline['prefix'] as String,
          actor.uid,
        );
        final expected = Map<String, Object?>.from(baseline['snapshot'] as Map);
        expect(
          immutableUpgradeSnapshot(snapshot),
          equals(immutableUpgradeSnapshot(expected)),
          reason:
              'Same database generation, every saved payload and original actor must survive.',
        );
        expect(
          upgradeHash(jsonEncode(immutableUpgradeSnapshot(snapshot))),
          baseline['immutableSnapshotSha256'],
        );
        await verifyUpgradeOwnership(snapshot, actor.uid);
        expect(await baselineFile.readAsString(), baselineRaw);
        await writeUpgradeEvidence(directory, 'candidate', {
          'schemaVersion': 1,
          'runId': upgradeRunId,
          'declaredSourceSha256': upgradeSourceDigest,
          'processId': pid,
          'actorUid': actor.uid,
          'baselineEvidenceSha256': upgradeHash(baselineRaw),
          'offline': offline,
          'snapshot': snapshot,
          'immutableSnapshotSha256': upgradeHash(
            jsonEncode(immutableUpgradeSnapshot(snapshot)),
          ),
          'exactSavedWorkPreserved': true,
          'sameDatabaseGeneration': true,
          'actualAccountSwitchPerformed': false,
          'localWrongActorClaimRefused': true,
          'reconnected': false,
          'productionDistribution': false,
        });
        debugPrint('DEV_UPGRADE_SAVED_WORK_PASS directory=${directory.path}');
      });
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );
}
