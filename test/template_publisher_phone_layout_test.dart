import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/maintenance_intelligence.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/data/template_governance_model.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/presentation/template_publisher_screen.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/maintenance_intelligence_provider.dart';
import 'package:crm3_baf_ops/features/planned_maintenance/providers/template_governance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('template publisher body remains visible above its action bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2026, 9, 5, 8);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream.value(
              AppUser(
                uid: 'admin-1',
                name: 'Admin One',
                email: 'admin@example.com',
                roles: const <AppRole>[AppRole.admin],
                isApproved: true,
                createdAt: now,
              ),
            ),
          ),
          templatePackagesProvider.overrideWith(
            (ref) => Stream.value(const <TemplatePackage>[]),
          ),
          maintenanceClassDefinitionsProvider.overrideWith(
            (ref) => Stream.value(const <MaintenanceClassDefinition>[]),
          ),
        ],
        child: MaterialApp(
          theme: BafAppTheme.light,
          home: const TemplatePublisherScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodyHeading = find.text('BAF Template Authoring');
    final actionBarButton = find.text('Open Module Composer').last;
    expect(find.text('Template authoring'), findsOneWidget);
    expect(bodyHeading.hitTestable(), findsOneWidget);
    expect(actionBarButton.hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(actionBarButton).dy,
      greaterThan(tester.getBottomLeft(bodyHeading).dy),
    );
    expect(tester.getBottomRight(actionBarButton).dy, lessThan(844));
    expect(tester.takeException(), isNull);
  });
}
