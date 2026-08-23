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
inventory now inherits all 70 strict A-05 decoder surfaces, including the
business-function tranche added on 21 August 2026 and the strict issue-lane
topology plus strict asset-hierarchy and workflow command receipts added on
23 August 2026. Text-file authority is
canonicalized to LF before hashing so the same tracked content has one digest
on Windows and Linux. Its current stable digest is
`DF8FEDBDC04994401AD4713D3AF22472DAB2F75571399C81EB2D745EBEE5D547`.

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
