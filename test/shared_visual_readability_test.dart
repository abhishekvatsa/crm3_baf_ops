import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/core/widgets/dashboard/dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Home header keeps title, sync and profile usable with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var synced = 0;
      var profiled = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: BafAppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DashboardHeader(
                  userName: 'Operator',
                  avatar: const CircleAvatar(child: Text('O')),
                  syncIndicator: OutlinedButton.icon(
                    onPressed: () => synced++,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync'),
                  ),
                  onProfileTap: () => profiled++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = find.byKey(const ValueKey('dashboard-shift-title'));
      final sync = find.byKey(const ValueKey('dashboard-sync-action'));
      expect(
        tester.getTopLeft(sync).dy,
        greaterThan(tester.getBottomLeft(title).dy),
      );
      await tester.tap(find.text('Sync'));
      await tester.tap(find.byKey(const ValueKey('dashboard-profile-action')));
      expect((synced, profiled), (1, 1));
    },
  );
}
