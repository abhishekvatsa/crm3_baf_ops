// FILE: test/report_export_audit_test.dart

import 'dart:io';

import 'package:crm3_baf_ops/features/audit/models/audit_event_model.dart';
import 'package:crm3_baf_ops/features/reports/services/report_export_audit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('report export audit contract', () {
    // Printing and sharing put plant condition, maintenance history and named
    // accountability outside every reading control that governs the source
    // records. The act must be attributed before the copy is gone.
    test('the preview attributes both export channels', () {
      final source = File(
        'lib/features/reports/presentation/zoomable_pdf_preview.dart',
      ).readAsStringSync();

      expect(source, contains('allowPrinting: true'));
      expect(source, contains('allowSharing: true'));
      expect(
        source,
        contains('onPrinted: (_) => _recordExport(ref, ReportExportChannel.printed)'),
      );
      expect(
        source,
        contains('onShared: (_) => _recordExport(ref, ReportExportChannel.shared)'),
      );
    });

    test('every export surface declares what it is distributing', () {
      for (final path in const <String>[
        'lib/features/reports/presentation/operations_report_pdf_screen.dart',
        'lib/features/reports/presentation/structured_report_pdf_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains('documentKind:'),
          reason: '$path exports without naming the document kind.',
        );
        expect(
          source,
          contains('documentSubject:'),
          reason: '$path exports without naming the document subject.',
        );
      }
    });

    test('the preview surface owns no persistence of its own', () {
      final source = File(
        'lib/features/reports/presentation/zoomable_pdf_preview.dart',
      ).readAsStringSync();

      // A-03 keeps presentation free of direct store access; the audit is
      // written by the service the preview delegates to.
      expect(source, isNot(contains('FirebaseFirestore.instance')));
      expect(source, isNot(contains('Isar.getInstance()')));
      expect(source, contains('reportExportAuditServiceProvider'));
    });

    test('an export is recorded as a created distributed copy', () {
      final source = File(
        'lib/features/reports/services/report_export_audit_service.dart',
      ).readAsStringSync();

      // Reusing an existing persisted action value keeps the audit schema, its
      // Firestore validation and the A-04 surface unchanged.
      expect(source, contains('AuditAction.create'));
      expect(source, contains("entityType: 'report_export'"));
      expect(AuditAction.values, contains(AuditAction.create));
      expect(
        AuditAction.values.map((value) => value.name),
        isNot(contains('export')),
        reason:
            'If an export action is ever added it becomes a persisted schema '
            'change and this contract should be revisited deliberately.',
      );
    });

    test('an unattributable export writes nothing', () {
      final source = File(
        'lib/features/reports/services/report_export_audit_service.dart',
      ).readAsStringSync();

      // An audit entry naming no actor would be worse than none.
      expect(source, contains('if (actorUid == null || actorUid.trim().isEmpty)'));
    });

    test('a failed audit never blocks the export already performed', () {
      final source = File(
        'lib/features/reports/services/report_export_audit_service.dart',
      ).readAsStringSync();

      expect(source, contains('} catch (error) {'));
      expect(source, contains('Report export audit skipped'));
    });
  });
}
