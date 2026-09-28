// Run after dev_abnormality_journey_test.dart in a separate application process.
import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/core/persistence/app_database.dart';
import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show waitFor, reveal;
import 'support/journey_pointer.dart' show tapControl;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'DEV persisted abnormality survives a separate process restart',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      final handler = FlutterError.onError;
      final platformHandler = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = handler;
        PlatformDispatcher.instance.onError = platformHandler;
      }
      expect(Firebase.app().options.projectId, startsWith('demo-'));
      final raw = (await SharedPreferences.getInstance()).getString(
        'crm3.dev.lastVerifiedJourney',
      );
      expect(
        raw,
        isNotNull,
        reason: 'The preceding process must have completed its real journey.',
      );
      final probe = jsonDecode(raw!) as Map<String, dynamic>;
      expect(probe['project'], Firebase.app().options.projectId);
      final record = await isar.chargeAbnormalitys
          .filter()
          .firestoreIdEqualTo(probe['abnormalityId'] as String)
          .findFirst();
      expect(
        record,
        isNotNull,
        reason: 'The case must still exist in the installed local store.',
      );
      expect(record!.observedReason, probe['observation']);
      expect(record.sourceChargeNo, probe['chargeNo']);
      expect(record.isSynced, isTrue);
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'Restored session must still pass the real online access gate.',
      );
      final server = await FirebaseFirestore.instance
          .collection('charge_abnormalities')
          .where('sourceChargeNo', isEqualTo: probe['chargeNo'])
          .get(const GetOptions(source: Source.server));
      expect(
        server.docs,
        hasLength(1),
        reason: 'Restart must not duplicate the accepted case.',
      );
      expect(server.docs.single.id, probe['abnormalityId']);
      final warning = await FirebaseFirestore.instance
          .collection('quality_warnings')
          .doc(probe['warningId'] as String)
          .get(const GetOptions(source: Source.server));
      expect(warning.exists, isTrue);
      await tapControl(tester, find.text('More'));
      await tester.pump(const Duration(milliseconds: 400));
      await reveal(tester, find.text('Abnormalities'));
      await tapControl(tester, find.text('Abnormalities'));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(
        find.byType(TextField).first,
        '${probe['chargeNo']}',
      );
      await tapControl(tester, find.text('Open').first);
      await waitFor(
        tester,
        () => find
            .textContaining(probe['observation'] as String)
            .evaluate()
            .isNotEmpty,
        'The retained case must be visible after process restart.',
      );
      debugPrint('DEV_RESTART_PASS abnormality=${record.firestoreId}');
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
