part of 'maintenance_provider.dart';

({String uid, String name, String? reason})
_validatedMaintenanceReopenEvidence({
  required AppUser actor,
  required String reopenedByUid,
  required String reopenedByName,
  String? reopenRemarks,
}) {
  _requireCanReopenMaintenanceTicket(actor);
  final uid = _cleanOptionalMaintenanceText(reopenedByUid);
  final name = _cleanOptionalMaintenanceText(reopenedByName);
  if (uid == null ||
      uid != actor.uid ||
      name == null ||
      name != actor.name.trim()) {
    throw ArgumentError(
      'Reopening authority must match the authenticated actor.',
    );
  }
  return (
    uid: uid,
    name: name,
    reason: _cleanOptionalMaintenanceText(reopenRemarks),
  );
}
