import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'support/upgrade_saved_work.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'baseline DEV main store retains real local saved work before APK replacement',
    (tester) async {
      requireUpgradeEnvironment('baseline');
      final directory = await upgradeDirectory();
      expect(
        await directory.exists(),
        false,
        reason:
            'Use a fresh owned DEV installation; never clear evidence here.',
      );
      await directory.create();
      await startUpgradeApp(tester);
      final actor = await authenticateUpgradeActor(tester);
      await saveComposerUpgradeDraft(tester);
      await writeUpgradeEvidence(directory, 'ready', {
        'runId': upgradeRunId,
        'processId': pid,
        'baselineHead': upgradeBaselineHead,
        'declaredSourceSha256': upgradeSourceDigest,
        'actorUid': actor.uid,
        'directory': directory.path,
        'businessFixtureCreated': false,
      });
      debugPrint(
        'DEV_UPGRADE_READY ${jsonEncode({'directory': directory.path, 'runId': upgradeRunId})}',
      );
      await tester.runAsync(() async {
        await waitOfflineMarker(directory);
        final offline = await requireUnavailableTransport(actor.uid);
        final ids = await saveUpgradeWork(actor);
        final snapshot = await captureUpgradeWork(
          ids['prefix'] as String,
          actor.uid,
        );
        await verifyUpgradeOwnership(snapshot, actor.uid);
        final stable = immutableUpgradeSnapshot(snapshot);
        await writeUpgradeEvidence(directory, 'baseline', {
          'schemaVersion': 1,
          'runId': upgradeRunId,
          'baselineHead': upgradeBaselineHead,
          'declaredSourceSha256': upgradeSourceDigest,
          'processId': pid,
          'actorUid': actor.uid,
          'prefix': ids['prefix'],
          'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
          'offline': offline,
          'snapshot': snapshot,
          'immutableSnapshotSha256': upgradeHash(jsonEncode(stable)),
          'scope':
              'DEV same-package replacement only; actual package/certificate/source binding is external',
          'notExercised': [
            'delivered Build30 to Build31',
            'accepted receipt adoption',
            'workflow uncertain lifecycle command',
            'planned module with authoritative parent',
            'crash during schema migration',
            'successful reconnect/sync',
          ],
        });
        debugPrint('DEV_UPGRADE_PREPARED directory=${directory.path}');
      });
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
