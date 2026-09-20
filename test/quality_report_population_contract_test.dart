import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports use a complete quality-monitoring population', () {
    final quality = File(
      'lib/features/quality/providers/quality_provider.dart',
    ).readAsStringSync();
    final reports = File(
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

  test(
    'operational monitoring visibility is server governed and unbounded',
    () {
      final quality = File(
        'lib/features/quality/providers/quality_provider.dart',
      ).readAsStringSync();
      final start = quality.indexOf('final qualityMonitoringRequestsProvider');
      final end = quality.indexOf(
        '/// Complete quality-monitoring population',
        start,
      );
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final operationalProvider = quality.substring(start, end);
      expect(operationalProvider, isNot(contains('.limit(')));
      expect(operationalProvider, contains('includeMetadataChanges: true'));
      expect(operationalProvider, contains('combineQualityMonitoringWindows'));
      final decoderStart = quality.indexOf(
        'List<QualityMonitoringRequest> _decodeQualityMonitoringRequests',
      );
      final decoderEnd = quality.indexOf(
        'List<QualityMonitoringRequest> sortQualityMonitoringRequests',
        decoderStart,
      );
      expect(
        quality.substring(decoderStart, decoderEnd),
        contains('decodeQualityMonitoringPopulation'),
      );
      final report = quality.substring(
        quality.indexOf('final qualityMonitoringRequestsForReportsProvider'),
        quality.indexOf('void _requireQualityReportActor'),
      );
      expect(report, isNot(contains('visibleUntil')));
      expect(report, isNot(contains('decodeSnapshotDocuments')));
    },
  );
}
