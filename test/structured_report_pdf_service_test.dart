import 'dart:convert';

import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:crm3_baf_ops/features/reports/domain/structured_report_document.dart';
import 'package:crm3_baf_ops/features/reports/services/structured_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('structured report validates table shape', () {
    expect(
      () => StructuredReportTable(
        headers: const <String>['A', 'B'],
        rows: const <List<String>>[
          <String>['one'],
        ],
      ),
      throwsArgumentError,
    );
  });

  test('structured report renders paginated complete rows', () async {
    final generatedAt = DateTime.utc(2026, 8, 29, 12, 0);
    final report = StructuredReportDocument(
      title: 'Maintenance evidence dossier',
      subtitle: 'Complete governed record',
      reportId: createStructuredReportId('ISSUE', generatedAt),
      generatedAt: generatedAt,
      generatedByName: 'Test Supervisor',
      scopeLabel: 'Furnace 01',
      provenance: const ReportProvenance.applicationSnapshot(),
      sections: <StructuredReportSection>[
        StructuredReportSection(
          title: 'Lifecycle',
          metrics: const <StructuredReportMetric>[
            StructuredReportMetric(label: 'Status', value: 'Resolved'),
          ],
          tables: <StructuredReportTable>[
            StructuredReportTable(
              headers: const <String>['Time', 'Evidence'],
              rows: List<List<String>>.generate(
                80,
                (index) => <String>[
                  '29 Aug 2026, 12:${index.toString().padLeft(2, '0')}',
                  'Complete retained evidence row $index',
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final bytes = await StructuredReportPdfService.build(report);

    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
    expect(bytes.length, greaterThan(12000));
    expect(report.fileName, contains('maintenance_evidence_dossier'));
  });
}
