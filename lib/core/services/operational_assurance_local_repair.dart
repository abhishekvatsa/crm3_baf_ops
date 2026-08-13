import 'package:isar/isar.dart';

import '../../features/maintenance_workflow/data/compliance_request_record.dart';

class OperationalAssuranceLocalRepairReport {
  final int normalizedLegacyRequests;

  const OperationalAssuranceLocalRepairReport({
    required this.normalizedLegacyRequests,
  });

  bool get changed => normalizedLegacyRequests > 0;
}

/// Gives pre-v4 compliance requests their explicit v4 business purpose.
///
/// Isar initializes a newly added required String as empty when opening an old
/// populated store. Historical records are general assurance requests. This
/// repair changes only the local projection and remains safe to rerun after an
/// interrupted PREPARED migration.
Future<OperationalAssuranceLocalRepairReport>
repairLegacyOperationalAssuranceRequests(Isar isar) async {
  var normalized = 0;
  await isar.writeTxn(() async {
    final records = await isar.complianceRequestRecords.where().findAll();
    final changed = <ComplianceRequestRecord>[];
    for (final record in records) {
      if (record.requestPurposeKey.trim().isNotEmpty) continue;
      record.requestPurposeKey = 'assurance';
      changed.add(record);
      normalized += 1;
    }
    if (changed.isNotEmpty) {
      await isar.complianceRequestRecords.putAll(changed);
    }
  });
  return OperationalAssuranceLocalRepairReport(
    normalizedLegacyRequests: normalized,
  );
}
