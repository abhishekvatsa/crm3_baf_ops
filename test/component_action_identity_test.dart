import 'dart:io';

import 'package:crm3_baf_ops/features/planned_maintenance/models/component_action_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A physical repair or replacement must carry an identity of its own.
///
/// Without one, the same action referenced from a module and from a job
/// closure cannot be recognised as a single event, and its index in a list
/// becomes the only thing distinguishing it — so reordering the list rewrites
/// physical history. Two lifecycle events for one replacement also inflate
/// replacement counts and the denominators of reliability analysis.
///
/// The burner path already derives a stable id from the ticket and the
/// physical burner position. These tests hold the generic path to the same
/// standard, while keeping legacy rows readable.
void main() {
  group('component action identity', () {
    test('the generic creation path assigns an id', () {
      final source =
          File(
            'lib/features/planned_maintenance/widgets/action_bottom_sheet.dart',
          ).readAsStringSync();

      expect(
        source,
        contains('id: const Uuid().v4()'),
        reason:
            'Actions recorded through the action sheet must carry a stable '
            'identity from the moment they are first recorded.',
      );
    });

    test('the burner path keeps its deterministic identity', () {
      final source =
          File(
            'lib/features/maintenance/domain/burner_lockout_case.dart',
          ).readAsStringSync();

      expect(source, contains('burnerActionSessionId'));
      expect(
        source,
        contains(r"'burner_${ticketId}_$burnerPosition'"),
        reason:
            'The burner action id is derived from the ticket and the physical '
            'position, not from a list index.',
      );
    });

    test('an assigned id survives a persistence round trip', () {
      final action = ComponentAction(
        id: 'action-fixture-1',
        asset: 'FURNACE 6',
        component: 'UV detector',
        actionType: ActionType.replacement,
        createdAt: DateTime.utc(2026, 9, 10, 6, 30),
      );

      final restored = ComponentAction.fromMap(action.toMap(), source: 'test');

      expect(restored.id, 'action-fixture-1');
    });

    test('legacy rows without an id remain readable', () {
      final action = ComponentAction(
        asset: 'BASE 205',
        component: 'Clamp solenoid valve A',
        actionType: ActionType.repair,
        createdAt: DateTime.utc(2026, 9, 10, 6, 30),
      );
      final map = action.toMap();
      expect(map['id'], isNull);

      final restored = ComponentAction.fromMap(map, source: 'test');

      // Historical evidence must not be rejected or silently given a new
      // identity: an invented id would assert a lineage that was never
      // recorded.
      expect(restored.id, isNull);
      expect(restored.component, 'Clamp solenoid valve A');
    });
  });
}
