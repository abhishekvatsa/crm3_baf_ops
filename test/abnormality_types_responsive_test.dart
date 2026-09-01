import 'package:crm3_baf_ops/features/abnormalities/data/abnormality_model.dart';
import 'package:crm3_baf_ops/features/abnormalities/presentation/abnormality_types_screen.dart';
import 'package:crm3_baf_ops/features/abnormalities/providers/abnormality_provider.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile abnormality master remains readable and scrolls away', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final types = List<AbnormalityType>.generate(6, _type);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppUserProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(_admin),
          ),
          allAbnormalityTypesProvider.overrideWith(
            (ref) => Stream<List<AbnormalityType>>.value(types),
          ),
        ],
        child: const MaterialApp(home: AbnormalityTypesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final header = find.text('Operational abnormality master');
    final summary = find.byKey(const ValueKey('abnormality-types-summary'));
    expect(header, findsOneWidget);
    expect(header.hitTestable(), findsOneWidget);
    expect(tester.getSize(header).width, greaterThan(180));
    expect(tester.getSize(summary).height, lessThan(240));
    expect(find.text('New type'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -560));
    await tester.pumpAndSettle();

    expect(header.hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final AppUser _admin = AppUser(
  uid: 'admin-responsive-test',
  name: 'Admin',
  email: 'admin@example.com',
  roles: const <AppRole>[AppRole.admin],
  isApproved: true,
  createdAt: DateTime.utc(2026, 9, 1),
);

AbnormalityType _type(int index) {
  final timestamp = DateTime.utc(2026, 9, 1, 8, index);
  return AbnormalityType()
    ..id = index + 1
    ..firestoreId = 'type-${index + 1}'
    ..code = 'TYPE_${index + 1}'
    ..title = 'Representative abnormality type ${index + 1}'
    ..description =
        'A deliberately complete description used to verify readable mobile layout and natural scrolling.'
    ..category = AbnormalityCategory.process
    ..severity = AbnormalitySeverity.medium
    ..applicableAssetTypes = const <AssetType>[AssetType.furnace]
    ..isActive = true
    ..isSynced = true
    ..createdAt = timestamp
    ..updatedAt = timestamp;
}
