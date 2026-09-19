import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/theme/baf_design_system.dart';
import 'package:crm3_baf_ops/features/auth/data/user_model.dart';
import 'package:crm3_baf_ops/features/auth/providers/auth_provider.dart';
import 'package:crm3_baf_ops/features/critical_alarm/data/critical_alarm_repository.dart';
import 'package:crm3_baf_ops/features/critical_alarm/presentation/critical_alarm_contacts_panel.dart';
import 'package:crm3_baf_ops/features/critical_alarm/providers/critical_alarm_providers.dart';
import 'package:crm3_baf_ops/features/maintenance/data/maintenance_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'repository excludes unreadable overrides without losing valid reasons',
    () async {
      final database = _Firestore({
        'critical_alarm_definitions': [
          _Snapshot({
            'fire': _definition('fire', status: 'retired')..remove('updatedAt'),
            'custom-hazard': _definition('custom-hazard'),
            'blast': _definition('blast', status: 'retired'),
          }),
          _Snapshot({
            'fire': _definition('fire', status: 'retired'),
            'custom-hazard': _definition('custom-hazard'),
            'blast': _definition('blast', status: 'retired'),
          }),
        ],
      });
      final snapshots = await CriticalAlarmRepository(
        database,
      ).watchDefinitions().toList();
      final incomplete = snapshots.first;
      expect(incomplete.isComplete, isFalse);
      expect(incomplete.malformedDocumentIds, ['fire']);
      expect(incomplete.definitions.where((row) => row.key == 'fire'), isEmpty);
      expect(
        incomplete.definitions
            .singleWhere((row) => row.key == 'custom-hazard')
            .isActive,
        isTrue,
      );
      expect(
        incomplete.definitions
            .singleWhere((row) => row.key == 'blast')
            .isActive,
        isFalse,
      );
      expect(
        incomplete.definitions
            .singleWhere((row) => row.key == 'majorGasLeakage')
            .isBootstrapDefault,
        isTrue,
      );
      final repaired = snapshots.last;
      expect(repaired.isComplete, isTrue);
      final fire = repaired.definitions.singleWhere((row) => row.key == 'fire');
      expect(fire.isActive, isFalse);
      expect(fire.isBootstrapDefault, isFalse);
    },
  );

  for (final withValidContact in [true, false]) {
    testWidgets(
      'incomplete contacts block all management with valid row=$withValidContact',
      (tester) async {
        await _pumpContacts(
          tester,
          contacts: {
            if (withValidContact) 'valid-contact': _contact(),
            'unreadable-contact': _contact('unreadable-contact')
              ..remove('dialValue'),
          },
        );
        expect(
          find.text('Approved contact directory incomplete'),
          findsOneWidget,
        );
        expect(find.textContaining('changes are disabled'), findsOneWidget);
        expect(find.text('Add approved contact'), findsNothing);
        expect(find.text('Add contact'), findsNothing);
        expect(find.byTooltip('Contact actions'), findsNothing);
        if (withValidContact) {
          expect(find.text('Valid fire contact'), findsOneWidget);
          expect(find.byTooltip('Open device dialler'), findsOneWidget);
        } else {
          expect(find.text('No approved contact configured'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('complete contacts retain admin add, edit and status controls', (
    tester,
  ) async {
    await _pumpContacts(tester, contacts: {'valid-contact': _contact()});
    expect(find.text('Approved contact directory incomplete'), findsNothing);
    await tester.tap(find.text('Add approved contact'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Contact actions'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.text('Retire'));
    await tester.pumpAndSettle();
    expect(find.text('Retire Valid fire contact?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpContacts(
  WidgetTester tester, {
  required Map<String, Map<String, dynamic>> contacts,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final admin = AppUser(
    uid: 'admin-1',
    name: 'Admin One',
    email: 'admin@example.com',
    roles: const [AppRole.admin],
    isApproved: true,
    createdAt: DateTime.utc(2026),
  );
  final repository = CriticalAlarmRepository(
    _Firestore({
      'critical_alarm_contacts': [_Snapshot(contacts)],
      'critical_alarm_definitions': [_Snapshot({})],
    }),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentAppUserProvider.overrideWith((_) => Stream.value(admin)),
        criticalAlarmRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: BafAppTheme.light,
        home: const Scaffold(
          body: CriticalAlarmContactsPanel(administrationMode: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _definition(String id, {String status = 'active'}) => {
  'schemaVersion': 1,
  'definitionId': id,
  'version': 1,
  'status': status,
  'name': 'Governed $id',
  'criticalityKey': 'highest',
  'criticalityRank': 1,
  'createdAt': DateTime.utc(2026),
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'updatedAt': DateTime.utc(2026),
  'updatedByUid': 'admin-1',
  'updatedByName': 'Admin One',
};

Map<String, dynamic> _contact([String id = 'valid-contact']) => {
  'schemaVersion': 1,
  'contactId': id,
  'version': 1,
  'status': 'active',
  'label': 'Valid fire contact',
  'contactKind': 'landline',
  'dialValue': '+916572200000',
  'alarmTypeKeys': ['fire'],
  'priority': 1,
  'notes': null,
  'createdAt': DateTime.utc(2026),
  'createdByUid': 'admin-1',
  'createdByName': 'Admin One',
  'updatedAt': DateTime.utc(2026),
  'updatedByUid': 'admin-1',
  'updatedByName': 'Admin One',
};

class _Firestore extends Fake implements FirebaseFirestore {
  _Firestore(this.rows);
  final Map<String, List<_Snapshot>> rows;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(path, rows[path]!);
}

// Test-only SDK boundary; the production repository still decodes each row.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.path, this.rows);
  @override
  final String path;
  final List<_Snapshot> rows;
  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    expect(path, 'critical_alarm_contacts');
    expect(field, 'priority');
    return this;
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    expect(includeMetadataChanges, isTrue);
    return Stream.fromIterable(rows);
  }
}

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements QuerySnapshot<Map<String, dynamic>> {
  _Snapshot(this.rows);
  final Map<String, Map<String, dynamic>> rows;
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [
    for (final entry in rows.entries) _Document(entry.key, entry.value),
  ];
  @override
  SnapshotMetadata get metadata => _Metadata();
}

// ignore: subtype_of_sealed_class
class _Document extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _Document(this.id, this.row);
  @override
  final String id;
  final Map<String, dynamic> row;
  @override
  Map<String, dynamic> data() => row;
}

class _Metadata extends Fake implements SnapshotMetadata {
  @override
  bool get isFromCache => false;
  @override
  bool get hasPendingWrites => false;
}
