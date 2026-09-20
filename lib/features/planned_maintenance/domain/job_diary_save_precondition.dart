/// Whether a diary edit may still be written over what is stored.
///
/// A diary entry is opened, edited for a while, and saved. Between opening and
/// saving, the stored entry can move on: another editor saves it, or a pull
/// adopts a newer revision from the server. The edit in hand was made against
/// what the entry said when it was opened, so writing it as a whole object
/// would replace work it never saw - an observation or a handover instruction
/// would simply be gone, with nothing on screen to say so.
///
/// This is the comparison that stops that. It is made against the stored entry
/// inside the same transaction as the write, because a check made before the
/// transaction is a check against a revision that may already be stale.
library;

/// Why a diary save was refused.
enum JobDiarySaveRefusal {
  /// The entry is no longer in the store: it was removed or deleted while it
  /// was open.
  entryRemoved,

  /// The stored entry moved on after this edit was opened.
  changedElsewhere,
}

/// Why the save must be refused, or null when the stored entry is still the
/// one this edit was opened against.
///
/// [openedAtVersion] is the entry's version when the edit began, before this
/// save advances it. [storedVersion] is what the store holds now, or null when
/// the entry is not there any more. [storedIsDeleted] covers an entry still
/// present but withdrawn.
JobDiarySaveRefusal? jobDiarySaveRefusal({
  required int openedAtVersion,
  required int? storedVersion,
  bool storedIsDeleted = false,
}) {
  if (storedVersion == null || storedIsDeleted) {
    return JobDiarySaveRefusal.entryRemoved;
  }
  if (storedVersion != openedAtVersion) {
    return JobDiarySaveRefusal.changedElsewhere;
  }
  return null;
}

/// What to tell whoever was writing. The message says the edit is still on
/// screen, because it is: nothing was written, and the text they typed is
/// where they left it.
String jobDiarySaveRefusalMessage(JobDiarySaveRefusal refusal) =>
    switch (refusal) {
      JobDiarySaveRefusal.entryRemoved =>
        'This diary entry is no longer on this job. Your note is still on '
            'screen; copy it before leaving this page.',
      JobDiarySaveRefusal.changedElsewhere =>
        'This diary entry was written elsewhere while you were editing it. '
            'Your note is still on screen; reopen the entry and add it to the '
            'current text so neither is lost.',
    };
