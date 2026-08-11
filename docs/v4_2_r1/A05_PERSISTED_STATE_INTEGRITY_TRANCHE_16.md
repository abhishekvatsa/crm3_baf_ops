# A-05 Persisted-State Integrity Tranche 16

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche closes a workflow pull ordering gap in local persisted control and
repair state. Quarantine evidence for a collection could previously be written
after that collection's cursor advanced, while malformed stored cursor or
quarantine payloads were treated as absent. A crash or corrupt local log could
therefore hide repair evidence after synchronization moved past the affected
record.

This source tranche does not change the `A-05` ledger status.

## Cursor And Quarantine Authority

Workflow pull now applies these rules independently to every collection:

- a missing cursor means the collection has no prior pull boundary;
- a present cursor is decoded through the shared strict persisted-data reader;
- malformed or wrongly typed cursor state returns the stable
  `workflow-pull-cursor-invalid` failure and performs no remote read;
- every newly produced quarantine record is appended to durable local repair
  state before the corresponding cursor may advance;
- quarantine and cursor writes require a successful storage acknowledgement
  and exact same-process readback before synchronization reports success, with
  the prior cached value restored on a failed or mismatched write;
- corrupt existing quarantine storage returns the stable
  `workflow-pull-quarantine-invalid` failure and prevents cursor advancement,
  including when the current remote batch contains only valid records;
  and
- malformed quarantine arrays and entries are not filtered or replaced with an
  empty list.

Valid records may be upserted before a local quarantine write fails. The cursor
remains held, so the next pull repeats the collection idempotently instead of
skipping the unrecorded repair boundary.

## Operator Representation

The existing Admin/SI workflow diagnostics screen now distinguishes corrupt
local quarantine state from general diagnostic unavailability. It exposes one
explicit repair command that removes only the local quarantine log and then
reloads diagnostics. It does not clear workflow cursors, pending commands,
server records or unrelated app data.

The screen continues to reject unauthorized actors before reading either the
quarantine log or pending command state. Its refresh callback is synchronous
with respect to `setState`, removing the runtime assertion previously reached
by refresh and clear-log recovery.

## Inventory

The machine-enforced v2 timestamp inventory now covers:

- 29 classified readers;
- 79 direct strict-reader calls;
- 40 required timestamp fields;
- 39 optional timestamp fields;
- zero unclassified or duplicate strict-reader sites; and
- 31 direct `DateTime` parser and epoch-sentinel candidates awaiting behavior
  classification.

The removed candidate was the nullable workflow cursor parser. Its replacement
is classified as local persisted control state.

## Regression Evidence

Focused Flutter tests prove:

- a malformed local cursor performs no remote read and remains intact for
  repair;
- corrupt quarantine storage prevents cursor advancement past a malformed
  remote record;
- failed quarantine writes and mismatched readback prevent cursor advancement;
- existing corrupt quarantine blocks a valid-only batch before its cursor can
  advance;
- corrupt quarantine state remains visible until explicitly cleared;
- an authorized Admin can clear only the corrupt local log and then resume
  diagnostics; and
- an unauthorized actor is still rejected before privileged local reads.

## Remaining A-05 Scope

`A-05` remains open for behavior classification and remediation of the 31
direct parser/sentinel candidates, the complete non-timestamp persisted
parser/catch inventory, durable repair across the remaining persisted-state
boundaries, and governed production plus supported-local-generation inventory,
reconciliation and repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, operate a phone or emulator, close a programme gate, close
`A-05`, or authorize pilot handout.
