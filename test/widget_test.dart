// FILE: test/widget_test.dart

import 'package:crm3_baf_ops/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CrmBafApp shows safe startup-failure screen before auth', (
    WidgetTester tester,
  ) async {
    final failure = StartupFailure(
      stage: 'firebase_initialize',
      error: StateError('Firebase failed'),
      stackTrace: StackTrace.current,
      occurredAt: DateTime.utc(2026, 5, 14, 12),
    );

    await tester.pumpWidget(
      ProviderScope(child: CrmBafApp(startupFailure: failure)),
    );

    expect(find.text('App startup failed'), findsOneWidget);
    expect(find.text('Copy Diagnostics'), findsOneWidget);
    expect(find.textContaining('Stage: firebase_initialize'), findsOneWidget);
    expect(find.text('Retry Opening Database'), findsNothing);
    expect(find.text('Backup & Rebuild Local DB'), findsNothing);
  });

  testWidgets(
    'CrmBafApp keeps local database recovery actions for Isar startup failure',
    (WidgetTester tester) async {
      final failure = StartupFailure(
        stage: 'local_database_open',
        error: StateError('Isar failed'),
        stackTrace: StackTrace.current,
        occurredAt: DateTime.utc(2026, 5, 14, 12),
      );

      await tester.pumpWidget(
        ProviderScope(child: CrmBafApp(startupFailure: failure)),
      );

      expect(find.text('Local database could not be opened'), findsOneWidget);
      expect(find.text('Create Recovery Package'), findsOneWidget);
      expect(find.text('Retry Opening Database'), findsOneWidget);
      expect(find.text('Backup & Rebuild Local DB'), findsOneWidget);
    },
  );
}
