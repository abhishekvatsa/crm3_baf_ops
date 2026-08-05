# A-05 Persisted-State Integrity Tranche 3

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Decision

This tranche removes silent loss and false-empty interpretation for planned-job
field definitions and response evidence. It applies one presence invariant to
all three reviewed work payload families: a genuinely absent pre-feature field
may initialize as `[]`; an explicitly present null, blank, wrong-typed,
malformed or sparse payload is a repair state and fails closed. Conflicting
declared required flags are also rejected.

The same presence distinction is now applied to component-action payloads,
closing a narrow gap left by tranche 2. This does not close `A-05`, change the
programme gate count, inspect or repair production records, authorize a
deployment, or authorize pilot handout.

## Shared Payload Contract

Flutter and Functions now validate field-definition and response arrays with
the same governed aliases and supported production field types. Each row must
be an object with a non-empty normalized key. Duplicate normalized keys are
rejected. Field definitions validate declared type, required flags, options,
validation metadata, order and version. Responses require an explicit
`value` or historical `answer` member and a supported declared type when one is
present.

Valid source text and unknown extension keys are retained. When a response is
edited, recognized historical aliases are canonicalized rather than retained
as stale duplicate fields; unknown extensions remain intact. A canonical field
that is present but malformed always wins over a legacy fallback and remains
available for governed repair instead of being replaced with `[]`.

## Client, Sync And UI Behavior

`JobExecution` and `JobModuleInstance` expose explicit response read results;
runtime modules also expose field-definition read results. Authoritative
getters throw on malformed state instead of returning an invented empty list.
Remote map boundaries reject wrong canonical types while preserving malformed
JSON strings for visible repair handling.

Module cards, module workspaces, planned-job details, completion, history and
closed dossiers show a clear repair state. Counts and details are hidden when
they cannot be trusted. Module mutation, lifecycle transitions, lane closure,
job completion, attestation and local-to-remote synchronization are blocked.
Lane readiness returns a visible blocking reason rather than throwing while a
screen is being built.

Completion preloads valid saved responses, preserves responses outside the
currently editable template, retains unknown extensions and no longer writes
an empty response array merely because a legacy template is unavailable.
Local and remote sync diagnostics report invalid field, response and action
payloads without dereferencing or overwriting them.

## Server Authority

The shared Functions validator is enforced at:

- direct planned-job completion request parsing;
- saved execution and active-module closure validation;
- maintenance-workflow finalization;
- runtime module population;
- published-template assignment;
- server-created RED successor module resolution.

Malformed request evidence returns stable `invalid-argument` failures.
Malformed saved evidence returns stable `failed-precondition` or governed
template-configuration failures before closure or runtime-module writes. RED
successor creation no longer treats an explicitly null published field bundle
as an empty bundle.

## Presence Invariant Refinement

Tranche 2 documented compatibility for a wholly absent action field, but some
call sites still passed explicit null through the same compatibility path.
Those client, closure, workflow-finalization and maintenance-history paths now
use document-field presence explicitly. Missing remains compatible; explicit
null is rejected. This correction narrows the prior claim to what the source
now proves literally.

## Reconciliation Update

Twenty-seven captured canonical paths receive reviewed successor hashes. Six
were previously byte-identical and now become `SUCCESSOR_MODIFIED`:

- `lib/features/planned_maintenance/domain/planned_job_closure_attestation.dart`;
- `lib/features/planned_maintenance/domain/planned_job_closure_guard.dart`;
- `lib/features/planned_maintenance/presentation/job_history_screen.dart`;
- `lib/features/planned_maintenance/presentation/widgets/job_module_response_summary.dart`;
- `test/complete_job_screen_server_gate_test.dart`;
- `test/planned_job_closure_guard_test.dart`.

The reconciliation aggregate therefore moves from `251 / 159` to
`245 BYTE_IDENTICAL / 165 SUCCESSOR_MODIFIED`. No canonical path is removed.

## Verification Evidence

Focused local verification covers explicit-null rejection, canonical-versus-
legacy precedence, alias compatibility, extension preservation, duplicate and
sparse rejection, visible UI repair states, non-crashing lane readiness, sync
blocking, completion preservation and all reviewed server mutation paths.

Local source verification is:

- `flutter analyze --no-pub`: no issues;
- full Flutter suite: 682 passed;
- full Functions unit suite: 399 passed, 63 emulator-only skipped;
- governed Firestore Rules suite: 152 passed;
- governed Functions emulator suite: 63 passed;
- Functions emitted-output, callable and notification inventories: passed;
- canonical source and governance audit: 113 of 113 passed.

Pull-request CI and admitted-main CI evidence remain required before this
source tranche is accepted.

## Remaining A-05 Scope

`A-05` remains open for `JobTemplate` field decoding and fallback behavior,
template-governance and module-registry timestamps, remaining persisted
timestamp substitutions, module-composer defaults and silent JSON catches,
remote tombstone authority, and the governed inventory, reconciliation and
operator repair path for historical production records.

This source tranche does not inspect or mutate production documents, alter
Firebase PITR or backup settings, deploy Rules or Functions, produce physical-
device evidence, close a programme gate, close `A-05`, or authorize pilot
handout.
