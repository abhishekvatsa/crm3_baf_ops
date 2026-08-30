import 'dart:io';

import 'package:crm3_baf_ops/features/reports/domain/report_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown pending-write evidence is not presented as measured zero', () {
    const provenance = ReportProvenance(
      sourceMode: ReportSourceMode.cloudApplicationSnapshot,
      pendingLocalWrites: null,
    );

    expect(
      provenance.evidenceStatement,
      isNot(contains('No pending local writes were counted')),
    );
  });

  test('web report provenance retains an unknown pending-write state', () {
    final source = File(
      'lib/features/reports/presentation/report_provenance_builder.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('pendingLocalWrites: kIsWeb ? null : pendingWrites'),
    );
    expect(source, isNot(contains('pendingLocalWrites: kIsWeb ? 0')));
  });
}
