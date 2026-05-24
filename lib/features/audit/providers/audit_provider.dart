// FILE: lib/features/audit/providers/audit_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/audit_repository.dart';

/// App-wide AuditRepository provider.
///
/// Keeping audit logging behind one provider gives sync/services/screens a
/// single injection point without changing the audit data model or Firestore
/// rules. Audit writes remain best-effort where the caller already made them
/// non-blocking.
final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepository();
});
