# A-05 Persisted-State Integrity Tranche 13

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche closes the known permissive remote-decoder gap for
`template_packages`, `template_versions`, `template_publish_audits` and the
nested template closure-review snapshot. It does not change the `A-05` ledger
status.

The reviewed source surfaces are:

- Firestore listeners, point reads and global-pull pages for all three
  template-governance collections;
- package, version and publication-audit model factories;
- frozen job, module, field-definition and checklist JSON snapshots;
- nested and projected closure-review state;
- lifecycle, actor, hash, tombstone and timeline evidence; and
- the machine-generated persisted timestamp inventory extractor.

## Strict Remote Readers

All three model factories now delegate to one strict remote governance reader.
The reader requires the embedded `firestoreId` and verifies that it matches the
Firestore document ID. Required business strings, booleans, exact enum names,
positive record/schema versions and lifecycle counters no longer receive empty,
zero or version-1 substitutions.

Optional strings and lists may be absent. A present value must retain its exact
type and bounded non-empty content. Present lists reject malformed entries and
duplicates. Optional `metadataJson`, `safetyGatePolicyJson` and publication
payload snapshots must be JSON objects rather than arbitrary text or arrays.

## Frozen Version Payload

The four frozen version payload fields are required non-empty strings with exact
JSON roots:

- `jobTemplateSnapshotJson` is an object;
- `moduleSnapshotsJson` is an array of objects;
- `fieldDefinitionsJson` is an array of objects; and
- `checklistJson` is an array of objects.

Malformed JSON, wrong roots, non-object list entries and non-string persisted
values fail with `PersistedDataFormatException`. Empty canonical object or array
payloads remain valid for a newly saved draft; publication readiness continues
to enforce the stronger business-completeness contract separately.

## Closure Review

Closure-review derivation no longer uses the local defensive JSON helpers on a
remote record. The strict reader verifies the nested composer object, exact
boolean closure flags, non-negative declared counts, module closure aliases,
actor fields and optional confirmation timestamp.

Current records carry five top-level closure projection fields. Those five
fields must exist together and match the frozen snapshot exactly. A partially
populated projection fails closed.

One bounded compatibility path remains: a record may omit all five projection
fields when the nested frozen snapshot is structurally valid. In that case the
projection is derived exactly from the snapshot. An absent composer, declared
critical count or module closure alias retains the established unconfirmed,
zero-count or non-critical meaning used by new drafts. Any present nested value
must have its exact persisted type; malformed state is not replaced with false,
zero, empty actors or a local timestamp.

Confirmed review requires the confirming UID and authoritative timestamp.
Unconfirmed review cannot retain stale actor or timestamp metadata. Published
closure-critical content requires confirmed review authority.

## Lifecycle And Timeline

Package and version creation/update timestamps are required and ordered.
Optional closure, publication, retirement and deletion timestamps must fall
inside the record timeline.

Package retirement and deletion state is validated rather than repaired.
Version draft, published, retired and archived states retain complete and
state-consistent actor/time/reason history. Non-draft content requires a
recognized governed hash. Current writes use `tg2-sha256`; the explicitly
retained historical `tg1-fnv1a32` form remains readable but does not gain
assignment authority. The assignment backend independently recomputes the
canonical `tg2-sha256` payload hash and rejects any mismatch.

Publication audits require exact document/package/version identity, action,
actor, timeline, positive versions and deletion state. Lifecycle audits retain
their resulting hash and payload snapshot. Retire, archive and restore actions
require a reason, with the existing ten-character archive/restore minimum.

## Containment

Firestore listeners and point reads decode before records reach callers.
Paginated repository methods decode every document before returning a page.
Malformed source data therefore aborts that page before local batch mutation;
the governed global-pull domain cannot commit its cursor after the resulting
domain error.

The timestamp manifest now binds `closureReviewConfirmedAt` to the strict remote
closure reader. The inventory extractor also understands expression-bodied
Dart factories instead of scanning forward into an unrelated brace-delimited
method. The tranche-13 v1 inventory reported 13 selected decoders, 19 required
timestamp fields and 21 optional timestamp fields. Tranche 14 supersedes that
scope after proving the factory-risk discovery rule did not enumerate every
direct strict-reader call.

Focused regressions cover required fields, document identity, scalar coercion,
enum values, lists, JSON roots and entries, partial and contradictory closure
projections, complete legacy derivation, lifecycle actors, hashes, timelines,
tombstones, archive/restore evidence, factory delegation and Firestore page
containment.

`A-05` remains open for the complete non-timestamp persisted parser/catch
inventory, durable counted quarantine and operator repair, and governed
production plus supported-local-generation inventory, reconciliation and
repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, operate a phone, close a programme gate, close `A-05`, or
authorize pilot handout.
