# S-04 Canonical User Authority Shape

## Finding

At baseline `382fd2485fc629b5f28ae708ae87fb138888bc65`, an Admin client could
write user authority directly. The Rules required only a non-empty role list
and boolean approval value on that path. Unknown role values and incompletely
shaped user documents were therefore not consistently rejected.

## Source resolution

PR #40 introduced one canonical ten-role allowlist and the exact client-write
user shape:

```text
required keys:
  name
  email
  roles
  isApproved
  createdAt

optional keys:
  photoUrl
  fcmToken
```

Pending self-registration is limited to an unapproved `operations` role and a
verified token email. Self and Admin profile updates may change only profile
fields. Neither path may change `roles`, `isApproved`, or `createdAt`.

PR #41 removed direct client authority mutation. Approval, revocation, and role
replacement now use the transactional `mutateUserAuthority` callable. That
writer:

* accepts only the canonical role universe;
* writes only `isApproved` and `roles` to the target user;
* preserves the remaining profile document;
* couples the mutation to immutable audit and idempotency evidence;
* protects the last-approved-Admin invariant.

The legacy notification cleanup writer remains field-bounded to clearing
`fcmToken`. R-04 server stale-token cleanup additionally permits deletion of
one exact private `notification_installations` child after a transactional
token-match reread; it does not widen parent user-authority mutation.

## Read-authority policy

Authorization reads deliberately validate the security capsule only:

```text
isApproved
roles
```

Non-authority profile fields do not grant or narrow access. Consequently, a
server-written document with a valid capsule remains authorizing even when its
profile fields are absent or contain additional data. This is the accepted
Rules expression-budget policy established by PR #40, not a claim that every
Admin SDK write is constrained by Firestore Rules.

The boundary is safe for tracked source because every tracked user writer is
field-bounded and canonical roles fail closed. Privileged-writer inventory,
IAM minimization, and production-data classification remain governed by Gate
1B and H2-IAM.

## Regression evidence

The source contracts prove:

* unknown, non-string, empty, oversized, and non-list role payloads cannot
  authorize;
* legacy `role`, `approved`, and `status` aliases cannot authorize;
* pending-user writes require exact keys, verified token identity, the
  `operations` role, and `isApproved == false`;
* self and Admin clients cannot write authority fields;
* ungoverned top-level client fields are rejected;
* the backend mutation parser rejects unknown roles and unsupported request
  keys;
* malformed target and Admin roster capsules fail closed;
* Dart parsing does not map unknown roles to `operations`.

## Exact evidence

```text
Repository:              abhishekvatsa/crm3_baf_ops
Rules pull request:      #40
Rules head commit:       473ed3c25472b27d646c1d75406a22a80ca26cd9
Rules merge commit:      f88c7e35f1dae95222cdcd57819b091a2f5f56c9
Rules post-merge run:    30170153630
Writer pull request:     #41
Writer head commit:      eb8bc9e505f559bc0e9267f56dd23ec4b6180ca2
Writer merge commit:     96385151d73c04904184b0bfd9c057c23b9f6e84
Writer post-merge run:   30172678080
Current main commit:     466f81e72b033d367da47a2aca4b30850ffbcfc4
Current post-merge run:  30196942545
Decision:                PASS_S04_CANONICAL_USER_AUTHORITY_SHAPE
```

S-04 is `CLOSED` as a source-and-CI finding.

## Authorization boundary

This closure does not authorize deployment, production mutation, artifact
construction, pilot handout, or cutover. It does not close H2-IAM or assert
that untracked privileged writers cannot bypass Firestore Rules.
