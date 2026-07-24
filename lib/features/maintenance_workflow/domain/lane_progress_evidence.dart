class LaneProgressEvidence {
  final bool acknowledged;
  final bool hasModuleWork;
  final bool hasDiaryEntry;
  final bool hasAttachment;
  final bool hasEvidence;
  final bool hasSubstantiveNote;
  final bool hasComplianceLink;
  final bool hasCarryForwardWork;
  final bool hasClosureHistory;

  const LaneProgressEvidence({
    this.acknowledged = false,
    this.hasModuleWork = false,
    this.hasDiaryEntry = false,
    this.hasAttachment = false,
    this.hasEvidence = false,
    this.hasSubstantiveNote = false,
    this.hasComplianceLink = false,
    this.hasCarryForwardWork = false,
    this.hasClosureHistory = false,
  });

  bool get hasProtectedProgress =>
      hasModuleWork ||
      hasDiaryEntry ||
      hasAttachment ||
      hasEvidence ||
      hasSubstantiveNote ||
      hasComplianceLink ||
      hasCarryForwardWork ||
      hasClosureHistory;

  bool get mayRemove => !hasProtectedProgress;
  bool get mustTerminate => hasProtectedProgress;
}
