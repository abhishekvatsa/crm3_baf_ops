# A-04 Persisted Schema Remediation

Status: CLOSED

Programme adjudication: `FINDING:A-04` is closed as of 17 August 2026 by
`PASS_A04_PERSISTED_SCHEMA_SOURCE_CI_AND_RECONCILIATION_CLOSURE`.

## Exact Inventory

`tools/v4/a04_persisted_schema_inventory.dart` parses every non-generated Dart
library under `lib/` with the analyzer AST. It discovers JSON string fields on
Isar collections and embedded records, plus the dynamic values carried by the
three nested persisted payload classes. It then binds those fields to the
complete A-05 strict-decoder manifest rather than treating a field name as
proof of safe decoding.

The governed manifest `governance/a04-persisted-schema-v1.json` classifies 53
fields: 47 JSON strings and six nested dynamic values. Three are registered
extension bags. The current extension registry contains zero fields, so an
unknown key cannot silently acquire authority or business meaning. The
inventory now inherits all 76 strict A-05 decoder surfaces, including the
business-function tranche added on 21 August 2026 and the strict issue-lane
topology plus strict asset-hierarchy and workflow command receipts added on
23 August 2026, and the administrative issue-closure envelope added on 24
August 2026, plus the strict server-maintained burner current-round pointer and
UV-detector lifecycle records added on 28 August 2026. The strict remote
business mirror and account-owned local recovery catches and the exact-device
reset journal, including its SHA-256-bound original and supplemental backup
evidence, are separately classified without adding a persisted dynamic field.
Text-file authority is
canonicalized to LF before hashing so the same tracked content has one digest
on Windows and Linux. Its current stable digest is
`CF84BB4C32A51E41C9AE903CCC1FBADAB1429AFA52D98793A5D715C2D74D12A9`.

The audit fails on a new or removed field, policy drift, decoder-manifest drift,
an unregistered extension, a missing strict-reader primitive, or missing
regression ownership.

## Strict Payload Boundary

`ComponentAction`, `TemplateField`, and `FieldResponse` now emit nested payload
schema version 1. A missing marker is the one documented legacy shape and is
canonicalized to version 1 on the next governed write. A present unsupported
version fails closed.

Dynamic JSON is recursively bounded by nesting depth, collection size, string
length and encoded byte size. Numbers must be finite, object keys must be
non-empty bounded strings, and non-JSON runtime objects are rejected. Template
validation and authoring metadata must be JSON objects. Component-action
metadata must be a JSON object string. Field-response values use the bounded
JSON union.

The same validators run at construction and serialization boundaries as well
as during persisted reads. Consequently malformed newly authored data cannot
be written merely because it did not originate in a decoder.

The Cloud Functions component-action, field-definition and response readers
enforce the same absent-legacy/version-1 boundary, known-field sets and bounded
JSON rules. They deliberately retain exact accepted encoded text where existing
receipt and attestation contracts hash that text; Dart model serialization is
the canonical rewrite boundary that emits schema version 1. The Dart and
TypeScript closure-attestation golden fixtures bind the resulting module
snapshot to the same SHA-256, so the client and server do not disagree about
the evidence being attested.

Burner attendance session, position, action code, terminal outcome and
microamp reading were promoted from the generic `ComponentAction` extension
bag to first-class typed fields. Existing top-level burner keys migrate through
that typed path, while partial burner evidence fails closed. These operational
facts therefore no longer depend on a generic extension mechanism.

## Compatibility and Repair

Legacy nested records without `schemaVersion` remain readable when all known
fields satisfy the strict typed decoder. Dart model serialization rewrites them
with `schemaVersion: 1`; no typed value is dropped. Server validation preserves
accepted encoded text where hash continuity is part of the contract. Unknown
fields, malformed present JSON, unbounded payloads and unsupported versions are
preserved by the owning record's existing repair/quarantine path and are not
silently rewritten.

PR #235 exact green head `1c4192c4b833919b5a045741866e9c7d6e17b79c`
merged as `f54f88c4e1e526e1493712824c1b281d17c70b2e` with identical
tree `55c73664ce7cc2f8f60142d92e8920a4686a385f`. Exact-head run
`32050533628` and admitted-main run `32051729235` passed all five governed
jobs.

The governed production sweep then ran from fetched, clean `main` at that
exact commit and tree. It was read-only, had no cloud mutation capability,
emitted no raw identifiers or document data, covered all 67 registered root
collections and two registered subcollection groups, and found zero
unregistered collections, blockers, or warnings. All 9 attempted strict
readers passed. The privacy-safe evidence digest is
`8581F54892ED2973CE0D4B94C61277970DA4056BC3F4269979E4DE1C21BE2FFE`.

The same admitted source passed 27 focused local-generation checks across
strict payload compatibility, repository-proven v1 migration to current v6,
isolated v2 handling, populated v3 migration, provenance rejection, restart
recovery, and byte-sealed backup/restore. Malformed or unsupported state is
preserved and blocked pending repair rather than silently rewritten.
This supplies the required supported-local-generation reconciliation.

The closure is sealed in
`release/evidence/a04-persisted-schema-source-ci-and-reconciliation-closure.json`.
No production data mutation, Firebase deployment, device operation, pilot
authorization, distribution action, or cutover authorization occurred. Its
three ledger re-arm triggers remain binding.

## Current inherited-decoder review, 2026-09-12

The current source still declares 53 persisted schema fields: 47 JSON strings,
six dynamic values and three bounded extension bags, with zero registered
extension fields. Its inherited decoder inventory contains 83 A-05 surfaces.
The field policies, strict-reader implementation, unknown-key disposition and
extension authority restrictions are unchanged by this review.

A-04 also binds the canonical text of the complete A-05 decoder manifest. Its
current digest therefore changes when the reviewed recovery admission,
callable-error translation or associated regression ownership changes in A-05,
even though no persisted dynamic field is added. Regeneration updates the
current manifest's inherited policy descriptions and A-05 hash; it does not
make a new runtime-schema migration or modify accepted payloads or receipts.

The current exact digest is recorded in
`governance/a04-persisted-schema-v1.json` and the current A-04 canonical-audit
check as `8126C69881B21116B42A0BA1C3F874CD7CB22F8899BD746AD47C855EFBCC36DA`.
The dated source snapshot above and the PR #235 closure, CI and
production-reconciliation receipts remain historical evidence. This addition
claims no new deployment, data migration, device result or release authority.

## 12 September 2026 source re-arm

The current source inventory classifies 55 fields: 49 JSON strings and six
nested dynamic values, and inherits 86 reviewed decoder surfaces. The two new
fields are the immutable submission envelope and retained acceptance receipt.
Their explicit policies bind identity, original actor, protocol, hashes and
domain validation; malformed evidence remains pending for review. Native reopen
and atomic adoption rollback are covered by the durable-submission tests. The
current extension registry contains zero fields.

The current source digest is
`A4F3494A6AB9D68503354F1B2975C8EBF27F34D276E2E2112910AF3146BF3E57`.
Historical closure and production reconciliation evidence above remains intact;
it is not certification of this uncommitted source or schema-11 distribution.

## Deep-audit source review, 2026-09-13

The current inventory still classifies 55 fields: 49 JSON strings and six
dynamic values, with three bounded extension bags and zero registered extension
fields. It inherits 92 reviewed decoder surfaces. Its exact digest is
`12968CD72F7DED7C2E034C04C91925107DC2FD127DD1FE51924A055D5EA2557E`.

The six additional inherited boundaries cover the typed saved-submission review
decision, its authority-gated service, the inspection target and review models,
the inspection server-context reader, and retained native module edit conflicts.
Existing field shapes and extension restrictions are unchanged. The receipt
field contract now explicitly distinguishes typed administrative review proof
from business acceptance: review proof keeps `acceptedAt` null and preserves
the original unknown actor and source bytes; a later acceptance retains both
proofs in a blocking conflict. The native review suite is named alongside the
existing durable-submission regressions.

The current manifest binds the reviewed A-05 policy through its canonical text
hash. This is a local source inventory result. The runtime's semantic reader
floor change is governed separately; this manifest neither performs migration
nor supplies deployment, production-reconciliation or physical-device evidence.
The historical closure and reconciliation records above remain unchanged.
