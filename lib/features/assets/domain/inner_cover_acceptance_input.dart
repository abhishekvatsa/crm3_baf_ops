/// Shared client validation for the governed acceptance request.
///
/// The server remains authoritative for lifecycle, permissions and chronology.
class InnerCoverAcceptanceInput {
  const InnerCoverAcceptanceInput({
    required this.inspectedOn,
    required this.acceptanceReference,
    required this.reason,
    this.leakTestReference,
    this.ndtReference,
    this.notes,
  });

  final DateTime inspectedOn;
  final String acceptanceReference;
  final String reason;
  final String? leakTestReference;
  final String? ndtReference;
  final String? notes;

  static String? referenceError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter the inspection or acceptance reference.';
    return text.length > 240 ? 'Use at most 240 characters.' : null;
  }

  static String? reasonError(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter why this cover is being accepted.';
    return text.length > 1000 ? 'Use at most 1,000 characters.' : null;
  }

  static String? optionalReferenceError(String? value) =>
      (value?.trim().length ?? 0) > 240 ? 'Use at most 240 characters.' : null;

  static String? notesError(String? value) => (value?.trim().length ?? 0) > 2000
      ? 'Use at most 2,000 characters.'
      : null;

  String? validationError({required DateTime now, DateTime? receivedOn}) {
    final textError =
        referenceError(acceptanceReference) ??
        reasonError(reason) ??
        optionalReferenceError(leakTestReference) ??
        optionalReferenceError(ndtReference) ??
        notesError(notes);
    if (textError != null) return textError;
    if (inspectedOn.isAfter(now)) {
      return 'Inspection time cannot be in the future.';
    }
    if (receivedOn != null && inspectedOn.isBefore(receivedOn)) {
      return 'Inspection time cannot be before the cover was received or completed.';
    }
    return null;
  }
}
