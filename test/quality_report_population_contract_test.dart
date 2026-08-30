import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports use a complete quality-monitoring population', () {
    final quality =
        File(
          'lib/features/quality/providers/quality_provider.dart',
        ).readAsStringSync();
    final reports =
        File(
          'lib/features/reports/providers/operations_report_provider.dart',
        ).readAsStringSync();

    final completeProvider = RegExp(
      r'qualityMonitoringRequestsForReportsProvider[\s\S]*?'
      r"collection\('quality_monitoring_requests'\)[\s\S]*?snapshots\([^)]*\)",
    ).firstMatch(quality);
    expect(completeProvider, isNotNull);
    expect(completeProvider!.group(0), isNot(contains('.limit(')));
    expect(quality, contains('snapshot.metadata.isFromCache'));
    expect(quality, contains('snapshot.metadata.hasPendingWrites'));
    expect(reports, contains('qualityMonitoringRequestsForReportsProvider'));
    expect(
      reports,
      isNot(contains('ref.watch(qualityMonitoringRequestsProvider)')),
    );
  });

  test('operational monitoring visibility is server governed and unbounded', () {
    final quality = File(
      'lib/features/quality/providers/quality_provider.dart',
    ).readAsStringSync();
    final operationalProvider = RegExp(
      r'qualityMonitoringRequestsProvider[\s\S]*?'
      r'_decodeQualityMonitoringRequests\);',
    ).firstMatch(quality);

    expect(operationalProvider, isNotNull);
    expect(
      operationalProvider!.group(0),
      contains("'visibilityState'"),
    );
    expect(operationalProvider.group(0), isNot(contains('.limit(')));
    expect(operationalProvider.group(0), isNot(contains('DateTime.now')));
  });
}
