# A-05 Persisted-State Integrity Tranche 6

## Decision

Status: OPEN - PARTIAL SOURCE REMEDIATION

This tranche closes the known governance-timeline substitutions and silent
null coercions in template packages, template versions, publication audits,
module-registry families, and module-registry revisions. It does not close
`A-05`: operational-record timestamp fallbacks, authority-profile and
knowledge-record decoding, governed production inventory, reconciliation, and
operator repair remain outstanding.

## Source Boundary

The source change establishes these invariants:

1. Template packages and versions require their persisted `createdAt` and
   `updatedAt` values. Missing or malformed values fail closed and are never
   replaced with device receipt time.
2. Package and version lifecycle fields are decoded strictly. A retired
   package requires `retiredAt`; published and retired versions require their
   corresponding history; an archived version may represent either an
   unpublished draft or a complete retired history, but not a partial history.
3. A confirmed closure review requires an authoritative
   `closureReviewConfirmedAt`. A malformed top-level value cannot fall through
   to inferred snapshot state.
4. Publication audits require their own `performedAt`, `updatedAt`, and valid
   action. `performedAt` is not inferred from `updatedAt`, and neither value is
   manufactured from local time.
5. Registry families and revisions require strict lifecycle status plus
   complete creation, update, publication, and retirement timestamps for their
   state.
6. Registry records marked deleted fail closed. These schemas have no
   deletion-time authority field, so silently filtering a server-written
   tombstone would suppress governance evidence without a defensible ordering
   marker.
7. Firestore Rules enforce matching timestamp presence, type, and
   status-dependent completeness for all client writes. Timestamp objects and
   string timestamps remain accepted at the Rules boundary; the app decoder
   performs full parse validation.

## User-Facing Representation

Registry Authoring now presents a dedicated **Governance timeline needs
repair** state. Create, update, publish, and retire controls remain disabled
until both registry data sets reload cleanly. A failed post-action reload can no
longer be reported as a clean action result.

Template Publisher presents the same repair state when package or version
decoding fails. Its publishing surface is not built while malformed governance
history is present. Neither screen exposes raw persisted-data exception text as
the primary operator instruction.

## Compatibility

Accepted compatibility is explicit:

- app decoders accept Firestore `Timestamp`, `DateTime`, and parseable string
  representations while preserving their exact instant;
- Firestore Rules accept timestamp-typed and string-typed persisted times;
- archived draft versions remain valid with no publication or retirement
  history;
- archived retired versions remain valid only with both publication and
  retirement history;
- publication-audit `updatedAt` remains the explicit remote ordering marker
  used by the existing immutable-audit tombstone protocol;
- registry tombstones are not inferred from `updatedAt` because their schema
  defines no deletion authority.

Records outside this compatibility envelope require governed reconciliation.
The client does not guess the intended historical time or state.

Rules string validation deliberately stops at type. Emulator proof showed that
adding ISO regular-expression checks to the atomic registry publication path
crosses Firestore's 1,000-expression evaluation ceiling and rejects valid
publication, retirement, and family-pointer transactions. Parse validation
therefore remains in the strict app decoder rather than weakening those
business operations.

## Verification

Focused regression coverage proves:

- missing, malformed, and state-incomplete package/version timestamps fail
  closed;
- publication audits retain exact valid timestamps and reject missing times or
  unknown actions;
- registry families and revisions reject incomplete lifecycle history and
  unsupported tombstones;
- archived-draft and publication-audit tombstone compatibility remains intact;
- malformed registry data is visible and disables authoring actions;
- Rules reject incomplete template, registry, and audit timelines while
  preserving valid lifecycle transitions.

Local verification before publication produced:

- focused decoder, UI, tombstone, archive, and model suite: 25 passed;
- focused post-review decoder and UI suite: 10 passed;
- `flutter analyze`: no issues;
- full Flutter suite: 701 passed;
- Firestore Rules emulator suite: 157 passed;
- governed Functions emulator suite: 63 passed;
- canonical source and governance audit: 113 of 113 passed;
- whole-app reconciliation source audit: 23 of 23 passed.

Pull-request CI and admitted-main CI evidence remain required before this
tranche is accepted.

## Remaining A-05 Scope

`A-05` remains open for persisted timestamp substitutions in operational
records and live-sync mapping, user authority-profile history, BAF knowledge
records, and the governed production inventory, reconciliation, and operator
repair path.

This tranche does not inspect or mutate production documents, deploy Firestore
Rules or Functions, alter PITR, backup, or delete-protection settings, produce
physical-device evidence, close a programme gate, close `A-05`, or authorize
pilot handout.
