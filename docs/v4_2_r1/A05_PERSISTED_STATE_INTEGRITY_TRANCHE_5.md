# A-05 Persisted-State Integrity Tranche 5

## Decision

Status: OPEN - PARTIAL SOURCE REMEDIATION

This tranche closes the known remote deletion-time substitutions retained by
tranche 4. It does not close `A-05`: remaining persisted timestamp fallbacks,
the template-publication audit marker, and governed historical inventory,
reconciliation, and operator repair remain outstanding.

## Source Boundary

The source change establishes these invariants:

1. A remote record marked `isDeleted: true` must carry its authoritative
   `deletedAt` value. Missing deletion authority fails closed.
2. The authoritative deletion time is retained exactly. It is never replaced
   with `updatedAt` or the receiving device's current time.
3. The guard runs at remote model decoding and again at repository merge
   boundaries. Direct repository callers cannot bypass the invariant.
4. A malformed remote tombstone fails before a local transaction changes the
   corresponding record. Existing local evidence and conflict timestamps stay
   intact.
5. A global-pull page containing a malformed tombstone fails before page
   completion, so its cursor cannot advance past the invalid record.
6. Firestore Rules require the app's canonical ISO-string `deletedAt` on
   client-authorable tombstones for maintenance records, operational
   directives, legacy job templates, and abnormality types.
7. Server-controlled documents remain protected when decoded by the app even
   though Admin SDK writes bypass Firestore Rules.

The affected deletedAt-bearing families are maintenance records, operational
directives, job templates, job executions, job module instances, job diary
entries, template packages, template versions, abnormality types, and charge
abnormalities.

## User-Facing Representation

This tranche preserves the existing sync-failure representation. An invalid
remote tombstone is reported as a synchronization error while the existing
local record remains available under its prior state. The app does not display
a fabricated deletion time, silently remove the record, or report a successful
pull whose cursor crossed the invalid document.

No new repair control is exposed because source cannot determine the intended
historical deletion time. Repair requires governed operator evidence rather
than a client-side default.

## Compatibility

Accepted compatibility is narrow and explicit:

- an active record may omit `deletedAt`;
- a deleted record must provide a parseable authoritative `deletedAt`;
- existing ISO-string deletion timestamps retain their exact instant;
- a missing deletion time is not inferred from `updatedAt`, local receipt time,
  or device time.

Client Firestore writes use the app's canonical ISO-string representation.
Timestamp-typed or absent client deletion authority is rejected. Server-owned
records are validated by the app's strict remote decoder.

## Verification

Focused regression coverage proves:

- every deletedAt-bearing remote model decoder rejects a deleted record with no
  authoritative deletion time;
- a valid deletion time is retained exactly;
- all affected repository merge paths contain the shared guard and none retain
  a `remote.deletedAt ??` substitution;
- maintenance, execution, module, and diary repositories reject malformed
  tombstones before changing local rows;
- Firestore Rules reject missing and Timestamp-typed client tombstones and
  accept the canonical ISO-string form on each client-authorable surface.

Local verification at the source head produced:

- focused A-05 tombstone suite: 9 passed;
- `flutter analyze --no-pub`: no issues;
- full Flutter suite: 694 passed;
- Firestore Rules emulator suite: 155 passed;
- governed Functions emulator suite: 63 passed;
- canonical source and governance audit: 113 of 113 passed;
- whole-app reconciliation source audit: 23 of 23 passed.

Pull-request CI and admitted-main CI evidence remain required before this
tranche is accepted.

## Remaining A-05 Scope

`A-05` remains open for persisted timestamp substitutions outside remote
tombstones, the template-publication audit marker, and the governed production
inventory, reconciliation, and operator repair path.

This tranche does not inspect or mutate production documents, deploy Firestore
Rules or Functions, alter PITR, backup, or delete-protection settings, produce
physical-device evidence, close a programme gate, close `A-05`, or authorize
pilot handout.
