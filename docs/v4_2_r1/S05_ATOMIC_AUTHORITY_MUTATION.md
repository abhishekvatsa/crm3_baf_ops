# S-05 Atomic Authority Mutation

## Source decision

S-05 replaces the tracked client authority sequence:

```text
client last-admin query
-> client roles/isApproved update
-> separate best-effort audit write
```

with:

```text
typed client command
-> approved-Admin preflight
-> Firestore server transaction
-> actor revalidation + receipt + target + Admin roster + audit reads
-> target authority + immutable audit + receipt commit
```

Supported operations are `APPROVE`, `REVOKE`, and `REPLACE_ROLES`.

## Transaction invariants

- Request IDs are canonical UUIDs and bind to one normalized payload fingerprint.
- The target preimage is bound by an `auth1-sha256` authority digest.
- Roles are validated against the generated canonical role universe and written as a deterministic unique list.
- Unapproved users may retain intended canonical roles; those roles do not authorize until `isApproved == true`.
- The actor is revalidated as an approved Admin inside the transaction.
- The transaction reads the approved-Admin roster before writing and rejects any result with no approved Admin.
- The target update, `server_authority_*` audit, and request receipt commit atomically.
- Existing receipts replay only for the same actor and payload and only while the recorded target/audit evidence remains coherent.
- Missing, malformed, stale, conflicting, or colliding evidence fails closed.

## Versioned request fingerprints

New authority-mutation receipts use schema version 2 and an
`authreq2-sha256` fingerprint over key-sorted canonical JSON. The digest no
longer depends on JavaScript object-literal insertion order.

Historical schema-version-1 receipts remain replayable only through the frozen
`authreq1-sha256` serializer, which reconstructs the original six fields in
their original order. The old prefix is never reused for the new algorithm.
Unknown schema/prefix combinations fail closed with
`authority-receipt-fingerprint-version-unsupported`; they do not fall through
to new mutation execution.

## Rules boundary

Clients may still:

- create their own unapproved Operations profile from a verified matching email;
- update their own profile-only fields;
- allow an approved Admin to correct profile-only fields.

Clients may not:

- create another user's authority document;
- change `roles` or `isApproved`;
- read or write `user_authority_mutation_receipts`;
- pre-create a `server_authority_*` audit identity.

## Verification

The governed emulator matrix proves:

- concurrent cross-demotion permits exactly one success;
- at least one approved Admin remains;
- one successful mutation has exactly one audit and one receipt;
- exact replay is idempotent and conflicting replay aborts;
- stale preimages, actor authority loss, malformed targets, and audit collisions produce no partial writes;
- approval/demotion concurrency preserves the Admin invariant.

Flutter tests bind the client and backend digest format, verify request normalization,
and fail closed on malformed callable responses. Rules tests preserve pending
self-registration and profile-only correction while denying direct authority
changes.

## Deployment boundary

This source change does not authorize deployment or production mutation.
A governed cutover should deploy and verify the callable first, deploy the Rules
denial second, and distribute the compatible client only under the existing
pilot controls. App Check activation, IAM/privileged-writer inventory, and the
read-only Gate 1B production classifier remain separate prerequisites.
