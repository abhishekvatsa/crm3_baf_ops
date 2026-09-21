import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crm3_baf_ops/core/serialization/persisted_data_reader.dart';
import 'package:crm3_baf_ops/features/assets/data/burner_block_lifecycle_event.dart';
import 'package:crm3_baf_ops/features/assets/data/uv_detector_lifecycle_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'functions/test/fixtures/lifecycle_late_recording_actual_producer.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final entry in fixture.entries) {
    final row = Map<String, dynamic>.from(entry.value as Map);
    final id = (row['path'] as String).split('/').last;
    final raw = Map<String, dynamic>.from(row['data'] as Map);
    dynamic decode(Map<String, dynamic> data) => switch (entry.key) {
      'uvEvent' => UvDetectorLifecycleEvent.fromMap(data, id),
      'uvCurrent' => UvDetectorLifecycleEvent.fromCurrentMap(data, id),
      'burnerEvent' => BurnerBlockLifecycleEvent.fromMap(data, id),
      'burnerCurrent' => BurnerBlockLifecycleEvent.fromCurrentMap(data, id),
      _ => throw StateError('Unexpected producer fixture'),
    };
    for (final native in [false, true]) {
      Map<String, dynamic> wire(Map<String, dynamic> value) => {
        ...value,
        if (native)
          for (final field in [
            'actionPerformedAt',
            'completedAt',
            'recordedAt',
          ])
            field: Timestamp.fromDate(DateTime.parse(value[field] as String)),
      };
      test(
        '${entry.key} retains distinct late recording and physical times; native=$native',
        () {
          final dynamic event = decode(wire(raw));
          expect(event.actionPerformedAt.toUtc(), DateTime.utc(2026, 8, 28, 8));
          expect(event.completedAt.toUtc(), DateTime.utc(2026, 8, 28, 9));
          expect(event.recordedAt.toUtc(), DateTime.utc(2026, 8, 28, 14));
        },
      );
      test(
        '${entry.key} rejects recording before completion; native=$native',
        () {
          final bad = {...raw, 'recordedAt': '2026-08-28T08:59:59.999Z'};
          expect(
            () => decode(wire(bad)),
            throwsA(isA<PersistedDataFormatException>()),
          );
        },
      );
      test(
        '${entry.key} original event reader rejects action after closure tolerance; native=$native',
        () {
          // The committed Burner current reader intentionally uses separate
          // correction chronology. This negative tests the original-event
          // boundary, without removing current-reader late/backward checks.
          final bad = {...raw, 'actionPerformedAt': '2026-08-28T09:05:00.001Z'}
            ..remove('projectionSchemaVersion')
            ..remove('projectionId')
            ..remove('currentEventId');
          final originalId = bad['eventId'] as String;
          expect(
            () => entry.key.startsWith('burner')
                ? BurnerBlockLifecycleEvent.fromMap(wire(bad), originalId)
                : UvDetectorLifecycleEvent.fromMap(wire(bad), originalId),
            throwsA(isA<PersistedDataFormatException>()),
          );
        },
      );
    }
  }
}
