# Predictive Static Audit Remediation

Status: SOURCE_AND_CI_COMPLETE

Date: 23 August 2026

External source: `CRM3_Current_Codebase_Predictive_Static_Audit_2026-08-23.pdf`

The external report was frozen at commit
`be626464fc4928c70adc065c8ebccbad7efa8218`. Each reported finding was
reproduced against the later merged baseline
`8468fb7ba53084207d5faa0ade2bfd52a58f3b99` before remediation. No finding was
accepted from prose alone.

## Finding Disposition

### F-01: Current release state was stale

Confirmed. The README and `release/current-successor-state.json` still
described Build 12 while the governed policy, build ledger, package version,
and completion receipt described finalized Build 14.

The current-state index now separates four authority planes:

- current post-artifact source, with source-and-CI authority only;
- exact finalized, non-distributable Build 14;
- the separately evidenced deployed backend;
- exact Build 11 controlled-pilot authority.

The contract derives build identity from the policy, ledger, package version,
and finalization receipt, and proves that current source descends from the
Build 14 artifact commit. A future artifact requires Build 15 or higher.

### F-02: Report visibility omitted valid compliance audiences

Confirmed. The compliance inbox admitted module supervisors, target-lane
workers, the exact raiser, and origin-lane workers, while the report used a
narrower rule.

Both surfaces now consume one domain policy. Role-matrix regressions cover
Admin, SI, shift and contract supervisors, target and origin lane workers, the
exact raiser, unrelated users, and unapproved users.

### F-03: Quality reporting filtered after a 250-row window

Confirmed. Interactive quality monitoring intentionally retained a 250-row
window, but management reports reused it and could omit older active or
period-overlapping records.

The interactive window remains bounded. Reports use a separate complete
read-only population before applying date and asset filters. A 261-record
regression proves that an older relevant record survives report filtering.
The additional Firestore read is registered in the A-03 persistence inventory.

### F-04: Inspection verification allowed competing decisions

Confirmed. Verification required the current observation but did not compare
the finding version or remember that the observation already carried a final
verification decision.

The command now requires `expectedFindingVersion`, compares it inside the
transaction, validates prior verification evidence, and records
`lastVerifiedObservationId`. Stale commands abort, and a second decision for
the same observation fails without writing evidence. Malformed stored versions,
counters, or prior-verification bindings also fail closed. A later observation
can still be verified normally.

### F-05: Historical predecessor receipts used a copied Build 11 label

Confirmed as a semantic naming defect, not an evidence contradiction. The
immutable Build 13 and Build 14 approvals contain valid predecessor receipt
paths and hashes under copied `build11FinalizationReceipt*` property names.

The signed historical approval files remain byte-identical. A compatibility
registry binds each approval hash to its actual predecessor build and receipt.
The production-policy verifier now checks approval, receipt, build sequence,
receipt content, and preserved-predecessor authority. Future approvals must
use the typed `predecessorFinalizationReceipt` object; a legacy alias is
accepted only when registered by exact approval hash.

### F-06: Issue-event links silently stopped at 50 rows

Confirmed. The query limited results before local chronological sorting.

The per-issue query now retains every matching immutable link and sorts the
decoded records by `linkedAt`. A 51-record regression uses chronology that
does not follow document identity and proves complete descending output.

## Verification

- `flutter analyze`: clean
- Flutter suite: 1,181 passed, 1 informational skip
- Functions suite: 554 passed, 80 intentionally skipped
- Firestore Rules: 180 passed
- Governed asset-identity emulator: 3 passed
- Governed callable emulator: 80 passed
- Canonical audit: 147 passed, 0 failed
- Production release policy: verified; exact Build 11 remains the only sealed
  pilot authority

## Authority Boundary

This remediation changes source, tests, and repository governance records. It
does not deploy Functions or Firestore configuration, construct or promote an
Android artifact, authorize Build 14 distribution, alter the sealed Build 11
pilot roster, or activate App Check.
