// Actual Android app/Functions withdrawal on explicitly copied synthetic local
// preconditions. This does not repeat or claim the original issue/release UI.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:crm3_baf_ops/core/dev/dev_environment.dart';
import 'package:crm3_baf_ops/features/assets/domain/plant_asset_overview.dart';
import 'package:crm3_baf_ops/features/assets/presentation/asset_condition_board.dart';
import 'package:crm3_baf_ops/features/assets/providers/plant_asset_overview_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/remote_maintenance_reader.dart';
import 'package:crm3_baf_ops/features/maintenance/services/maintenance_withdrawal_command.dart';
import 'package:crm3_baf_ops/features/maintenance_workflow/providers/workflow_providers.dart';
import 'package:crm3_baf_ops/home_screen.dart';
import 'package:crm3_baf_ops/main.dart' as app;

import 'dev_abnormality_journey_test.dart' show waitFor;
import 'dev_issue_quality_journey_test.dart' show tapControl, showControl, read;

const _case = 'af1ef6cd-15e5-4c23-b540-06d7c54e7fc9';
const _affected = '515a060f-400d-568e-bad3-b03f1a287c95';
const _unrelated = 'f43b7a65-bb12-4781-861c-c52853b93e68';
const _base1 = 'dev-ic-fitness-base-101';
const _base2 = 'dev-ic-fitness-base-102';
const _resume = bool.fromEnvironment('CRM_DEV_WITHDRAWN_READ_ONLY');

Object? _json(Object? v) {
  if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
  if (v is DateTime) return v.toUtc().toIso8601String();
  if (v is Map) return {for (final e in v.entries) '${e.key}': _json(e.value)};
  if (v is Iterable) return v.map(_json).toList();
  return v;
}

Map<String, Object?> _state(PlantAssetOverview model) => {
  'dependencyEvidenceConfirmed':
      model.innerCoverStock?.dependencyEvidenceConfirmed,
  'covers': [
    for (final c in model.innerCovers)
      {
        'id': c.profile.id,
        'available': c.isAvailable,
        'condition': c.conditionSummary,
        'complete': c.dependency?.complete,
        'assessment': c.dependency?.needsCurrentAssessment,
      },
  ],
  'bases': [
    for (final b in model.assets.where(
      (b) => [_base1, _base2].contains(b.asset.id),
    ))
      {
        'id': b.asset.id,
        'available': b.isAvailable,
        'warnings': b.evidenceWarnings,
        'assessment': b.linkedInnerCoverDependency?.needsCurrentAssessment,
      },
  ],
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  testWidgets(
    'withdrawal keeps exact cover assessment without poisoning its neighbour',
    (tester) async {
      expect(crm3UseEmulators, isTrue);
      expect(crm3DemoProjectId, 'demo-crm3-ci-journeys');
      expect(crm3EmulatorHost, '10.0.2.2');
      expect(crm3AuthEmulatorPort, 19099);
      expect(crm3FirestoreEmulatorPort, 18080);
      expect(crm3FunctionsEmulatorPort, 15001);
      final flutterError = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      try {
        await tester.runAsync(app.startCrmBafApp);
      } finally {
        FlutterError.onError = flutterError;
        PlatformDispatcher.instance.onError = platformError;
      }
      expect(Firebase.app().options.projectId, 'demo-crm3-ci-journeys');
      await waitFor(
        tester,
        () =>
            find.text('Sign in with Google').evaluate().isNotEmpty ||
            find.byType(HomeScreen).evaluate().isNotEmpty,
        'DEV access gate',
      );
      if (find.text('Sign in with Google').evaluate().isNotEmpty) {
        await tapControl(tester, find.text('Sign in with Google'));
      }
      await waitFor(
        tester,
        () => find.byType(HomeScreen).evaluate().isNotEmpty,
        'DEV Home',
      );
      expect(
        FirebaseAuth.instance.currentUser?.email,
        'dev.cf01-b@example.invalid',
      );
      expect(
        (await read(
          'users/${FirebaseAuth.instance.currentUser!.uid}',
        ))['roles'],
        ['admin'],
      );
      final out = Directory(
        '${(await getApplicationSupportDirectory()).path}/ic_withdrawn_${DateTime.now().microsecondsSinceEpoch}',
      );
      await out.create(recursive: true);
      await binding.convertFlutterSurfaceToImage();
      Future<void> save(String name, Object? data) async {
        await File('${out.path}/$name.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert(_json(data)),
        );
        debugPrint('DEV_WITHDRAWN_EVIDENCE ${out.path}/$name.json');
      }

      Future<void> capture(String name) async {
        await tester.pump(const Duration(milliseconds: 500));
        await File(
          '${out.path}/$name.png',
        ).writeAsBytes(await binding.takeScreenshot(name));
        binding.reportData?.remove('screenshots');
        debugPrint('DEV_WITHDRAWN_EVIDENCE ${out.path}/$name.png');
      }

      final stablePaths = [
        'furnace_stuckup_cases/$_case',
        'inner_cover_profiles/$_affected',
        'inner_cover_profiles/$_unrelated',
        'base_inner_cover_assignments/$_base1',
        'base_inner_cover_assignments/$_base2',
        'equipment_status/base_101',
        'equipment_status/base_102',
      ];
      final stableBefore = {for (final p in stablePaths) p: await read(p)};
      final ticketBefore = await read('maintenance_records/$_case');
      expect(ticketBefore['isDeleted'] == true, _resume);
      await tapControl(tester, find.text('Home'));
      await tapControl(
        tester,
        find
            .descendant(
              of: find.byType(PlantOverviewPanel),
              matching: find.textContaining('Plant condition'),
            )
            .first,
      );
      await waitFor(
        tester,
        () => find.byType(AssetConditionBoard).evaluate().isNotEmpty,
        'Plant board',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AssetConditionBoard)),
        listen: false,
      );
      Future<PlantAssetOverview> settled(bool deleted) async {
        await waitFor(tester, () {
          final tickets = container
              .read(plantTicketEvidenceProvider)
              .asData
              ?.value;
          final found = tickets?.rows
              .where((t) => t.firestoreId == _case)
              .toList();
          final model = container
              .read(plantAssetOverviewProvider)
              .asData
              ?.value;
          return tickets?.fromServer == true &&
              tickets?.complete == true &&
              found?.length == 1 &&
              found!.single.isDeleted == deleted &&
              model?.innerCovers.length == 2 &&
              model?.innerCoverStock?.inventoryConfirmed == true &&
              model?.innerCoverStock?.linkageConfirmed == true &&
              model?.innerCoverStock?.dependencyEvidenceConfirmed == true;
        }, 'Exact server feeds and withdrawn issue must settle');
        return container.read(plantAssetOverviewProvider).requireValue;
      }

      final before = await settled(_resume);
      await save('01-before', {
        'syntheticCopiedPreconditions': true,
        'state': _state(before),
        'ticket': ticketBefore,
        'stable': stableBefore,
        'readOnlyContinuation': _resume,
      });
      expect(
        before.innerCovers
            .singleWhere((c) => c.profile.id == _unrelated)
            .isAvailable,
        isTrue,
      );
      expect(
        before.assets.singleWhere((b) => b.asset.id == _base2).isAvailable,
        isTrue,
      );
      if (!_resume) {
        final command = buildMaintenanceWithdrawalCommand(
          readRemoteMaintenanceRecord(ticketBefore, documentId: _case),
          'Synthetic DEV withdrawal regression only; this is not physical fitness clearance.',
        );
        final receipt = await container
            .read(workflowOnlineExecutorProvider)
            .execute(
              command,
              validateReceipt: (r) =>
                  validateMaintenanceWithdrawalReceipt(command, r),
            );
        validateMaintenanceWithdrawalReceipt(command, receipt);
        await save('02-command-receipt', {
          'command': command.toMap(),
          'commandId': receipt.commandId,
          'resultKey': receipt.resultKey,
          'version': receipt.aggregateVersion,
          'result': receipt.result,
          'appliedAt': receipt.appliedAt,
        });
      }
      final after = await settled(true);
      final ticketAfter = await read('maintenance_records/$_case');
      final stableAfter = {for (final p in stablePaths) p: await read(p)};
      await save('03-after', {
        'state': _state(after),
        'ticket': ticketAfter,
        'stable': stableAfter,
        'productionTouched': false,
        'withdrawalThroughRealAppExecutor': !_resume,
        'physicalFitnessAssessed': false,
      });
      expect(ticketAfter['isDeleted'], isTrue);
      expect(
        ticketAfter['version'],
        _resume
            ? ticketBefore['version']
            : (ticketBefore['version'] as num) + 1,
      );
      expect(stableAfter, stableBefore);
      final affected = after.innerCovers.singleWhere(
        (c) => c.profile.id == _affected,
      );
      expect(affected.isAvailable, isFalse);
      expect(affected.dependency?.needsCurrentAssessment, isTrue);
      expect(
        after.innerCovers
            .singleWhere((c) => c.profile.id == _unrelated)
            .isAvailable,
        isTrue,
      );
      expect(
        after.assets.singleWhere((b) => b.asset.id == _base1).isAvailable,
        isFalse,
      );
      expect(
        after.assets.singleWhere((b) => b.asset.id == _base2).isAvailable,
        isTrue,
      );
      final warning = find.text(
        'Linked Inner Cover DEV-IC-FITNESS-31: fitness assessment needed',
      );
      await showControl(tester, warning);
      expect(warning.hitTestable(), findsOneWidget);
      await capture('04-affected-base');
      for (final id in [_affected, _unrelated]) {
        final row = find.byKey(ValueKey('plant-inner-cover-$id'));
        await showControl(tester, row);
        await capture(
          id == _affected ? '05-affected-cover' : '06-unrelated-cover',
        );
      }
      expect(tester.takeException(), isNull);
      debugPrint('DEV_WITHDRAWN_PASS ${out.path}');
    },
  );
}
