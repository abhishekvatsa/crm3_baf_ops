import 'dart:io';

import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/maintenance/domain/burner_lockout_case.dart';
import 'package:crm3_baf_ops/features/maintenance/presentation/resolve_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'burner attendance exposes one optional microamp field per burner',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final record =
          MaintenanceRecord()
            ..firestoreId = 'burner-microamp-ui'
            ..assetType = AssetType.furnace
            ..assetNumber = 3
            ..maintenanceType = MaintenanceType.breakdown
            ..description = 'Burners 2 and 5 locked out'
            ..classification = burnerLockoutClassification
            ..routedTo = RoutedTo.instrumentation
            ..startDate = now.subtract(const Duration(hours: 1))
            ..createdAt = now.subtract(const Duration(hours: 1))
            ..updatedAt = now
            ..actionsJson = '[]'
            ..resolutionHistoryJson = '[]';
      record.burnerLockoutCase = BurnerLockoutCase(
        positions: const <int>[2, 5],
        commonMode: true,
        cycleStage: BurnerCycleStage.firing,
        flameObservation: BurnerObservation.notSeen,
        sparkObservation: BurnerObservation.notChecked,
        relightAttempts: 1,
        remainsLockedOut: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAppUserProvider.overrideWith(
              (ref) => Stream<AppUser?>.value(null),
            ),
          ],
          child: MaterialApp(home: ResolveForm(ticket: record)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Microamp reading'), findsNWidgets(2));
      expect(find.text('\u00b5A'), findsNWidgets(2));
    },
  );

  test('completed-ticket and report surfaces retain flame-signal evidence', () {
    final closedTickets =
        File(
          'lib/features/maintenance/presentation/closed_tickets_screen.dart',
        ).readAsStringSync();
    final fleetReport =
        File(
          'lib/features/reports/presentation/fleet_status_screen.dart',
        ).readAsStringSync();

    expect(closedTickets, contains('resolutionMicroampReadings'));
    expect(closedTickets, contains('Flame signal:'));
    expect(fleetReport, contains("DataColumn(label: Text('Latest \u00b5A')"));
    expect(fleetReport, contains('latestMicroampReading'));
  });
}
