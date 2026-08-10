# A-05 Persisted-State Integrity Tranche 11

Status: OPEN - PARTIAL SOURCE REMEDIATION

## Scope

This tranche closes the known operational-directive remote-decoder gap and a
writer/Rules identity mismatch exposed while tracing that boundary. It does
not change the `A-05` ledger status.

The reviewed source surfaces are:

- `directives/{documentId}` Firestore reads, listeners and global-pull pages;
- directive creation and batch-upsert persistence maps;
- local application of already-decoded remote directives; and
- focused source, identity, lifecycle, timestamp and type regressions.

## Persisted Contract

Every remote directive now routes through one strict persisted-data reader.
The reader requires document identity, non-empty title and description,
audience, status, priority, creator and issuer identity, active state, closure
mode, deletion state, creation/update timestamps and a positive version.
Unknown enum values, scalar coercions, empty required text and wrong present
optional types fail with `PersistedDataFormatException`.

The embedded `firestoreId` must match the Firestore document ID, and creator
and issuer UIDs must agree. Asset type and number are either both absent or
both present, and present numbers must satisfy the existing asset-range
validator. Event timestamps cannot precede creation or follow the persisted
update time.

Lifecycle state is validated rather than repaired:

- open and acknowledged directives are active; closed directives are not;
- acknowledgement actor and timestamp are present together;
- closure actor and timestamp are present together;
- open directives cannot carry acknowledgement state;
- acknowledged directives require acknowledgement state;
- only closed directives may carry closure state or the
  `closedWithoutAcknowledgement` flag; and
- `deletedAt` and deletion actor authority are present when `isDeleted` is
  true, and deletion fields are absent otherwise.

Optional descriptive strings, hierarchy paths, actor display names, links and
event timestamps may remain absent. Actor display names cannot exist without
their corresponding actor UID. Present `metadataJson` must decode as a JSON
object. A malformed present value is never treated as absence.

## Writer Alignment

The source Rules require `firestoreId` on directive create and require it to
equal the document ID. The supported writer previously omitted that field from
both direct saves and synchronized batch upserts. The writer now includes the
exact `firestoreId` after rejecting a missing or blank local identity.

Remote normalization no longer applies `DateTime.now`, version 1, default
enums or lifecycle rewrites after decoding. Legitimate defaults for a newly
constructed local directive remain in the user-mutation path; they are not
used to interpret persisted remote state.

## Containment

Listener and point-read maps decode before reaching the UI. Global-pull pages
decode inside `getUpdatedDirectives` before a page result is returned, so a
malformed source document aborts that domain before local insert/update and
before the global cursor commit. Existing global-pull error handling preserves
the prior cursor on failure.

Focused regressions cover every required authority field, unknown enums,
string/number/boolean coercions, malformed optional lists, document and owner
identity drift, asset inconsistency, reversed timelines, acknowledged/closed/
deleted success cases, contradictory lifecycle state, provider delegation and
writer identity inclusion.

`A-05` remains open for the complete non-timestamp persisted parser/catch
inventory, durable counted quarantine and operator repair, and governed
production plus supported-local-generation inventory, reconciliation and
repair evidence.

This tranche does not inspect or mutate production documents, deploy Firebase
Rules or Functions, alter PITR or backup settings, operate a phone, close a
programme gate, close `A-05`, or authorize pilot handout.
