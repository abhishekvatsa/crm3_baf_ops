# A-05 current source review: recovery and command transport

Status: reviewed source inventory; no new production, device or CI closure claim.

The September 12 change retains 91 strict timestamp readers and 227 direct
reader calls, including 135 required and 90 optional fields. The strict
persisted-reader manifest is unchanged. There are now 32 direct timestamp
candidates in ten classification groups, with no unclassified or stale site.
The added candidate is `commandUtcMillis(DateTime)`, an outbound serializer for
an already typed instant. It constructs UTC millisecond command transport; it
does not decode saved data, invent a fallback time, alter the input DateTime,
or rewrite an already frozen command. It receives its own
`TYPED_COMMAND_WIRE_SERIALIZATION` classification rather than a persisted-parser
or runtime-sentinel exemption.

`test/inner_cover_acceptance_repository_test.dart` constructs a command through
the real repository using a microsecond input, verifies canonical UTC
milliseconds and unchanged input, and checks the exact backend fixture. The
matching Functions regression covers that emitted request and the historical
microsecond request through the governed mutation handler. Persisted chronology
decoders and accepted receipt fingerprints retain their existing contracts.

The decoder inventory remains 83 surfaces, 52 structurally discovered catches,
53 strict-reader consumer files and 43 raw-JSON consumer files. Its 441 risk
candidates are three more than the previous source. All three additions are
creation-recovery catches: a server identity read failure becomes a deferred
outcome, and command-construction or receipt-validation StateErrors become
explicit contradictory evidence. None returns a successful generic-write
fallback. Behavioral coverage uses a generic batch double capable of success,
asserts zero calls after contradiction or uncertainty, and preserves unrelated
work and concurrent edits. An immutable-identity match permits ordinary edits
only before recovery, following a server-only read. It is compatibility evidence,
not proof of a stored acceptance or original frozen payload.

The hierarchy receipt surface also has a changed risk fingerprint because three
existing collision-description coercions moved across formatted lines. Their
meaning did not change. Independent catch review found that a generic
`failed-precondition` can also describe an already accepted legacy receipt
requiring reconciliation. It must not clear the acceptance form's frozen ID.
The final translation permits `AssetHierarchyCommandRefused` only for
`ACCEPT_INNER_COVER` with three exact preacceptance code/reason pairs:
`invalid-argument/invalid-inner-cover-lifecycle-request`,
`aborted/inner-cover-version-mismatch`, and
`failed-precondition/inner-cover-not-awaiting-acceptance`. Missing/unknown
reasons, historic receipt or replay problems, malformed acceptance evidence
and uncertain transport remain blocking errors with the pending identity
retained. Actual callable-exception tests cover these distinctions. Invalid
receipt data never creates a success state.
The acceptance UI retains the pending command identity under uncertainty and
uses exact server readback to distinguish acceptance from display convergence.

The hold-collection read catch in `sync_service.push_infrastructure.dart` is an
eligibility boundary, not a structurally discovered decoder catch. It is not
added as an invented A-05 decoder site. The source now returns no eligible
records on a real hold-read exception and records an in-memory retryable
diagnostic without attempting a write into that unreadable store. Native Isar
tests prove both a contradiction hold surviving close/reopen and automatic
sending blocked by a missing hold collection. These tests do not establish a
fully durable dispatch journal, absent-store behavior, or successful diagnostic
persistence under every storage failure. Package B remains a design.

Only these reviewed current-source hashes, policies and exact audit counts were
updated. Historical A-05 tranches, closure receipts, production reconciliation
and device evidence were not rewritten. Any new parser, changed catch behavior,
fallback, absent server confirmation or altered identity admission re-arms review.

## September 20 current-source addendum

The origin-bound generic workflow executor is now a directly discovered JSON
consumer. Its original-account wrapper and accepted-envelope readers are
classified as local control state, with one separately classified parse catch.
That catch returns no verified origin; admission then refuses the saved command
and preserves its bytes for review. It cannot infer the current account, create
an acceptance, or grant dispatch authority. Native Isar regressions cover account
changes, preserved legacy and malformed bytes, exact envelope recovery after
reopen, durable preparation failure, and receipt settlement failure.

The existing uncertain-retry surface now recognizes the versioned origin
wrapper. Malformed wrappers remain reviewable evidence, and another account's
retry cannot acquire their authority. Its changed fingerprint records the
reviewed decoder and authority checks; the parser and catch discovery rules are
unchanged.

Current inventory is 100 surfaces, 54 decoder catches, 58 strict-reader consumer
files, 49 raw-JSON consumer files, and 477 risk candidates. Fifteen candidates
belong to the newly classified executor, and one was added to the previously
classified retry surface. Existing alarm policies and historical receipts remain
intact. A-03 remains 596 operations, 2081 sites and 70 surfaces.

Automatic RED successor construction now calls the same published requirement
compiler used by ordinary assignment's validation and field selection. The
canonical source check follows that call through `validatedFieldsForModule` to
`readFieldDefinitionPayload`, instead of requiring a duplicate direct reader in
the RED resolver. Normalized ambiguous ownership and conflicting embedded/global
requirements fail before successor creation; the published version/hash and
original snapshots remain unchanged. Functions regressions compare both paths
and verify that an unanswered required reading still blocks closure. This is
source validation, not a rewrite or re-certification of historical jobs.

Both producers also use the shared publication-proof validator for document
identity, active/latest version, reconstructed canonical content hash, publishing
actor, and a matching unambiguous publication audit. RED reads that proof within
the finalization transaction and retains its audit ID in the new child execution
metadata. Invalid proof leaves the parent and child population untouched. Replay
of an already committed finalization still uses its historical receipt before
fresh publication checks, including after the child advances or the template is
retired. Existing ordinary assignment validation order and historical evidence
are preserved.

RED target admission also reuses ordinary snapshot type/hierarchy/installed-number
validation and compares explicit class/instance scope with the transaction-read
parent identity. The child workflow and execution retain those parent IDs for
later RED work. Broad legacy templates retain their established type/number
compatibility; explicitly scoped templates require matching governed parent
identity. This does not introduce a registry repair policy or rewrite earlier
children.
