import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audit/models/audit_event_model.dart';
import '../../audit/providers/audit_provider.dart';
import '../../audit/repositories/audit_repository.dart';

/// How a report copy left the application.
enum ReportExportChannel {
  printed,
  shared;

  String get label => switch (this) {
    printed => 'printed',
    shared => 'shared',
  };
}

/// Instruments report exports so a distributed copy can usually be attributed.
///
/// Printing and sharing distribute plant condition, maintenance history and
/// named accountability outside the application, where none of the reading
/// controls that govern the source records still apply. The preview surface
/// itself owns no persistence; it reports the act and this service writes the
/// audit entry.
///
/// This is best-effort instrumentation, not a guarantee that every distributed
/// copy carries a durable record. Two cases deliberately produce no entry: an
/// export with no signed-in actor, and an audit write that fails. Both favour
/// completing the operator's export over blocking it, so the absence of an
/// entry is not evidence that no copy was made. Making attribution durable
/// would need a stable export identity, the exact document snapshot identity
/// and a retried pending outcome; that is deferred, not implied here.
///
/// The entry uses [AuditAction.create] with a dedicated `report_export` entity
/// type: an export creates a distributed copy. No new persisted action value is
/// introduced, so the audit schema, its Firestore validation and the A-04
/// surface are unchanged.
class ReportExportAuditService {
  const ReportExportAuditService({
    required AuditRepository auditRepository,
    FirebaseAuth? auth,
  }) : _auditRepository = auditRepository,
       _auth = auth;

  final AuditRepository _auditRepository;
  final FirebaseAuth? _auth;

  FirebaseAuth get _authentication => _auth ?? FirebaseAuth.instance;

  Future<void> recordExport({
    required ReportExportChannel channel,
    required String documentKind,
    required String documentSubject,
    required String fileName,
  }) async {
    final user = _authentication.currentUser;
    final actorUid = user?.uid;
    if (actorUid == null || actorUid.trim().isEmpty) {
      // An unauthenticated export cannot be attributed, and an audit entry
      // naming no actor would be worse than none. The export surface is
      // already behind an approved-user gate.
      return;
    }
    final actorName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.trim().isNotEmpty == true
        ? user!.email!.trim()
        : 'Approved user';

    try {
      await _auditRepository.log(
        AuditEvent(
          entityType: 'report_export',
          entityId: fileName,
          action: AuditAction.create,
          performedByUid: actorUid,
          performedByName: actorName,
          reason: AuditReason.other,
          reasonNotes:
              'A rendered report copy left the application by '
              '${channel.label}. Distributed copies are not governed by the '
              'reading controls that apply to the source records.',
          summary: 'Report ${channel.label}: $documentKind',
          severity: AuditSeverity.medium,
          after: <String, dynamic>{
            'channel': channel.label,
            'documentKind': documentKind,
            'documentSubject': documentSubject,
            'fileName': fileName,
          },
        ),
      );
    } catch (error) {
      // A failed audit must never block the export the operator has already
      // performed; the act is complete by the time this runs.
      debugPrint('Report export audit skipped: $error');
    }
  }
}

final reportExportAuditServiceProvider = Provider<ReportExportAuditService>(
  (ref) => ReportExportAuditService(
    auditRepository: ref.read(auditRepositoryProvider),
  ),
);
