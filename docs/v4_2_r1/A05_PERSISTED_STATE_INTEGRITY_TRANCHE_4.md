# A-05 Persisted-State Integrity Tranche 4

## Decision

Status: OPEN - PARTIAL SOURCE REMEDIATION

This tranche closes the silent `JobTemplate` field and Module Composer JSON
fallbacks retained by tranche 3. It does not close `A-05`: persisted temporal
substitutions, remote tombstone authority, and governed historical inventory,
reconciliation, and operator repair remain outstanding.

## Source Boundary

The source change establishes these invariants:

1. `JobTemplate.fields` is canonical when present. A malformed canonical array
   fails closed and never falls through to a different `fieldsJson` payload.
2. `fieldsJson` remains an explicit legacy format only when `fields` is absent.
   A record with neither field may initialize an empty pre-feature template.
3. Field aliases and supported historical field-type names remain readable.
   Unknown extension keys are retained through read, edit, and write.
4. Malformed validation JSON, unknown field types, duplicate keys, non-object
   entries, and missing field identity are retained as repair state rather than
   converted to an empty checklist.
5. All four Module Composer payload roots must have their declared JSON shape:
   one object snapshot and three arrays of objects. Malformed roots or entries
   fail closed instead of creating a plausible empty draft.
6. A saved TemplateVersion is decoded before the current recovery draft is
   removed. Decode failure leaves both current work and recovery custody intact.
7. A malformed local recovery envelope or payload is left untouched and shown
   as needing repair. It is removed only after an explicit discard decision.

## User-Facing Representation

The repair state is now represented across the relevant workflow:

- template list and Admin data-browser cards show `Fields need repair`;
- template detail shows a repair notice and blocks assignment and editing;
- Template Designer blocks save and add/edit controls without replacing data;
- legacy job completion blocks closure when template fields are invalid;
- job history and dossier views decline to relabel responses from corrupt field
  definitions;
- Module Composer shows a blocking repair notice for malformed initial data and
  a stable error when a saved or recovery draft cannot be decoded.

Deletion and history access remain available where their existing authority
permits them; this tranche does not hide the affected record or erase evidence.

## Compatibility

Accepted compatibility is narrow and explicit:

- wholly absent `fields` and `fieldsJson`: empty pre-feature template;
- absent canonical `fields` plus valid string `fieldsJson`: legacy decode;
- recognised field identity/type/required aliases: canonicalized on write;
- unknown JSON-compatible extension keys: preserved.

A canonical container that is present but null, wrong-type, malformed, or
partially populated does not receive a default value or legacy fallback.

## Verification

Focused regression coverage proves:

- canonical structured fields retain aliases, validation, and extensions;
- malformed canonical fields cannot fall through to valid legacy JSON;
- valid legacy-only field JSON remains readable;
- malformed local fields remain byte-preserved and expose repair state;
- every malformed composer root and non-object list entry fails closed;
- malformed initial composer data and local template fields show blocking UI;
- saved-version decode occurs before recovery-draft deletion.

Local verification at the source head produced:

- focused A-05 template/composer suite: 25 passed;
- `flutter analyze --no-pub`: no issues;
- full Flutter suite: 690 passed;
- canonical source and governance audit: 113 of 113 passed;
- whole-app reconciliation source audit: 23 of 23 passed.

The canonical audit binds these invariants to the source and keeps the ledger
finding `OPEN`. Pull-request CI and admitted-main CI evidence remain required
before this tranche is accepted.

## Remaining A-05 Scope

`A-05` remains open for template-governance and module-registry timestamps,
remaining persisted timestamp substitutions, remote tombstone authority, and
the governed production inventory, reconciliation, and operator repair path.

This tranche does not inspect or mutate production documents, deploy Firestore
Rules or Functions, change PITR or backup settings, produce physical-device
evidence, close a programme gate, close `A-05`, or authorize pilot handout.
