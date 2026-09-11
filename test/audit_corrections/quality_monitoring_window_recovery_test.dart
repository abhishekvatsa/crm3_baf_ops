import 'dart:async';

import 'package:crm3_baf_ops/features/quality/data/quality_warning.dart';
import 'package:crm3_baf_ops/features/quality/providers/quality_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expiry timer cannot restore success after a required source fails', (tester) async {
    final current = StreamController<List<QualityMonitoringRequest>>();
    final legacy = StreamController<List<QualityMonitoringRequest>>();
    final values = <List<QualityMonitoringRequest>>[];
    final errors = <Object>[];
    final now = DateTime.now().toUtc();
    final request = QualityMonitoringRequest(
      requestId: 'expiry-fixture', baseNumber: 205, grade: 'TEST',
      cycleReference: 'test-only', chargeNumbers: const <int>[12345],
      reason: 'A local regression fixture, never submitted.',
      status: QualityMonitoringStatus.closed,
      visibilityState: QualityMonitoringVisibilityState.recent,
      visibleUntil: now.add(const Duration(seconds: 1)), archivedAt: null,
      createdAt: now, createdByUid: 'test-user', updatedAt: now,
      updatedByUid: 'test-user', version: 1,
    );
    final subscription = combineQualityMonitoringWindows(current.stream, legacy.stream)
        .listen(values.add, onError: (Object error) => errors.add(error));
    addTearDown(() async { await subscription.cancel(); await current.close(); await legacy.close(); });
    current.add(<QualityMonitoringRequest>[]); legacy.add(<QualityMonitoringRequest>[request]);
    await tester.pump();
    expect(values, hasLength(1));
    current.addError(StateError('required query failed'));
    await tester.pump();
    expect(errors, hasLength(1));
    await tester.pump(const Duration(seconds: 2));
    expect(values, hasLength(1), reason: 'expiry is not a fresh read of the failed source');
    legacy.add(<QualityMonitoringRequest>[]);
    await tester.pump();
    expect(values, hasLength(1));
    current.add(<QualityMonitoringRequest>[]);
    await tester.pump();
    expect(values, hasLength(2));
    expect(values.last, isEmpty);
  });
}
