# A-05 Persisted-State Integrity Tranche 15

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche closes manufactured and weakly typed timestamp evidence at three
authority-bearing callable response boundaries: published-template assignment,
user-authority mutation and charge-abnormality mutation. It also removes the
published-assignment backend replay fallback that returned the Unix epoch when
both the completed request receipt and execution lacked an assignment time.

This source tranche does not change the `A-05` ledger status.

## Backend Replay Authority

Completed published-assignment replay now applies these rules:

- a present receipt `assignedAt` must be a non-empty parseable timestamp;
- an absent receipt timestamp may use the execution `createdAt` retained for
  legacy completed receipts;
- when both timestamps exist, they must identify the same instant;
- a present malformed value never falls through to another source; and
- absent, malformed or conflicting evidence returns stable `data-loss`
  reason codes instead of `1970-01-01T00:00:00.000Z`.

The retained execution fallback is evidence substitution only for a wholly
absent legacy receipt field. It uses existing immutable execution chronology
and does not manufacture a clock value.

## Client Response Authority

`PublishedTemplateAssignmentServerResult.fromCallableData` now requires:

- `ok: true`;
- the exact request ID supplied by the caller;
- matching top-level and embedded execution IDs;
- a boolean idempotent-replay flag;
- a non-empty publication-audit ID;
- a required strict assignment timestamp matching execution creation time;
- non-empty string module identities linked to the execution; and
- unique module identities.

The request ID is no longer filled from the caller when the server omits it.
Replay status no longer defaults to false. Publication-audit and assignment
time evidence are no longer optional. Numeric or object identities are not
accepted through `toString()` coercion.

The user-authority and charge-abnormality response decoders now read
`committedAt` through the shared strict persisted-data reader. Non-string
values therefore fail closed instead of becoming parseable text. All three
callable timestamps must also round-trip as canonical UTC ISO instants; a
loosely parseable date string is not accepted as server evidence.

## Inventory

The machine-enforced v2 timestamp inventory now covers:

- 28 classified readers;
- 78 direct strict-reader calls;
- 39 required timestamp fields;
- 39 optional timestamp fields;
- zero unclassified or duplicate strict-reader sites; and
- 32 direct `DateTime` parser and epoch-sentinel candidates awaiting behavior
  classification.

## Regression Evidence

Focused source tests prove:

- backend replay rejects absent, malformed, non-string and conflicting
  assignment chronology with stable `data-loss` reasons;
- the assignment client rejects missing or weakly typed response evidence,
  identity disagreement, timestamp disagreement and duplicate modules; and
- user-authority and abnormality-mutation responses reject non-string commit
  times through their existing stable invalid-response envelopes.

Functions emitted-output custody, callable inventory and notification inventory
remain part of the backend build and test path.

## Remaining A-05 Scope

`A-05` remains open for behavior classification and remediation of the 32
direct parser/sentinel candidates, the complete non-timestamp persisted
parser/catch inventory, durable counted quarantine and operator repair, and
governed production plus supported-local-generation inventory, reconciliation
and repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, operate a phone or emulator, close a programme gate, close
`A-05`, or authorize pilot handout.
