# A-04 Persisted Schema Remediation

Status: SOURCE_IMPLEMENTED

Programme adjudication: `FINDING:A-04` is source-implemented as of 17 August
2026. Closure remains contingent on exact-head pull-request CI, merge with an
identical source tree, admitted-main post-merge CI, and current-source
production and supported-local-generation reconciliation.

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
inventory also inherits all 54 strict A-05 decoder surfaces. Its stable digest
is `27863AC2C3E366BD34BFAC9D092EA86AF269756BAD56C05C1974D78F843697C9`.

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

This source tranche performs no production read or mutation, local data
migration, Firebase deployment, device operation, pilot authorization,
distribution action, or cutover authorization. A-04 remains open until the
post-merge read-only production sweep and supported-local-generation fixtures
prove that current records are compatible or have an explicit blocking repair
disposition.
