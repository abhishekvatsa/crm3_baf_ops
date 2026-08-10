# A-05 Persisted-State Integrity Tranche 10

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche closes the known BAF knowledge decoder gap and expands the
machine-generated timestamp inventory across persisted factory naming styles.
It does not change the `A-05` ledger status.

The reviewed source surfaces are:

- `knowledge_base/{rowCode}` cloud rows and local raw extension payloads;
- `knowledge_base_meta/current` cloud metadata;
- knowledge pull, web-read, update-concurrency and conflict-read paths;
- persisted workflow-pull quarantine records;
- persisted global-pull domain cursors; and
- the A-05 timestamp inventory discovery tool and manifest.

## BAF Knowledge Contract

`BafKnowledgeRow.fromCloudMap` now routes through one strict persisted-data
reader. It requires document identity, task and module identity, schema and
record versions, lifecycle/readiness/confidence vocabulary, actor identity,
change reason, deletion state, and authoritative creation/update timestamps.
Wrong types, unknown enum values, document-ID drift, reversed timelines,
mixed suggested-field shapes, malformed preset JSON, non-finite numbers and
unsupported nested values fail with `PersistedDataFormatException`.

Valid compatibility remains explicit:

- Firestore `Timestamp`, `DateTime`, and parseable timestamp strings;
- absent optional descriptive strings and lists;
- `safetyClass` only when canonical `safetyClasses` is absent;
- historical `fieldPresets` or `suggestedFieldDefinitions` only when the
  canonical preset field is absent; and
- string-label or object-label suggested-field lists, but never a mixed list.

The metadata reader requires non-negative row counts, a tag count no greater
than the row count, schema version 1, a positive record version, actor and
change authority, and the remote update timestamp. Local cache receipt time is
supplied explicitly by the caller and cannot replace cloud history.

Corrupt local `rawJson` is no longer discarded and reconstructed from indexed
fields. That behavior could erase unknown extension evidence. It now fails
closed through the same persisted-data exception used by existing screen and
sync error boundaries.

## Mutation Boundary

Every cloud row and the optional metadata document are decoded before the Isar
write transaction begins. The concurrent metadata read is awaited even when a
row page is empty, so its failure cannot escape as an unhandled future. One
malformed source document therefore prevents a partial page commit. Web reads
also route through the same row decoder.

Knowledge updates and conflict comparison re-decode the transaction/current
cloud row instead of coercing `version` or display fields. Ordinary Firebase
transport, permission and offline failures may still use the established
offline fallback. Persisted format failures are not caught as network state;
they reach the existing governance-screen or synchronization error state.

## Inventory Correction

The inventory previously discovered only `factory ...fromMap` declarations.
It now discovers `fromMap`, `fromCloudMap`, and `fromJson` factories. The
expanded exact result is:

- 13 classified decoder surfaces;
- 19 required timestamp fields;
- 21 optional timestamp fields; and
- zero unclassified factory timestamp-risk sites.

That discovery exposed a workflow quarantine decoder that manufactured Unix
epoch when `quarantinedAt` was missing and coerced identity fields through
`toString()`. The record now requires strict identity, stage, error and receipt
time fields. The global-pull domain cursor now uses the shared timestamp reader
and requires an exact canonical UTC round-trip while preserving its stable
protocol error code.

## Verification Boundary

Focused regressions cover valid compatibility, every required BAF authority
field, wrong scalar and list types, unknown vocabularies, identity drift,
timeline reversal, malformed nested values and JSON, metadata arithmetic,
workflow quarantine authority, canonical cursor parsing, pre-transaction
decode ordering and narrow Firebase-only fallback.

`A-05` remains open for the complete non-timestamp persisted parser/catch
inventory, durable counted quarantine and operator repair, and governed
production plus supported-local-generation inventory, reconciliation and
repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, alter PITR or backup settings, operate a phone, close a
programme gate, close `A-05`, or authorize pilot handout.
