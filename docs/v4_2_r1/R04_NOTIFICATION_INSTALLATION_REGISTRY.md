# R-04 Notification Installation Registry

Status: CLOSED

Merge and exact-head CI evidence: PASS

Closure decision: PASS_R04_NOTIFICATION_INSTALLATION_SOURCE_AND_CI_CLOSURE

## Finding

The application stored one `fcmToken` on each user profile. That model lost
one device when another device refreshed its token, did not repair a persisted
session after token rotation, and let sign-out on one device clear notification
delivery for every device belonging to the same user.

## Source Decision

Each application installation now owns one private document at:

```text
users/{uid}/notification_installations/{installationId}
```

The installation ID is a random lowercase UUID v4 persisted locally. It is
not derived from a device identifier, user identity, email address, or FCM
token. The exact document contains schema version, token, platform, and a
Firestore server timestamp.

The client registers the current token whenever an authenticated user profile
becomes available and replaces the same installation document on token
refresh. A persisted authentication session therefore repairs registration
without requiring another interactive sign-in.

Sign-out removes only the current installation document and retires its local
FCM token. The stable installation ID remains local so a later session reuses
the same bounded document rather than accumulating records.

## Privacy And Authority

Firestore Rules deny all client reads of installation documents. Only the
canonical owner may create, update, or delete a record, and writes require the
exact schema, an allowed platform, a lowercase UUID v4 path, and a server
timestamp. Another user cannot write or delete the owner's installation.

Tokens are not added to logs, UI state, analytics, Crashlytics context, or
governance evidence. Server notification code reads them with Admin authority
only after the parent user passes canonical approved-authority validation.

## Delivery And Migration

The server reads at most eight most-recent installation documents per eligible
user, also reading the legacy profile `fcmToken` during migration. Tokens are
deduplicated before FCM dispatch.

Permanent FCM rejection clears only the exact registration observed during
recipient resolution. Cleanup transactionally rereads the legacy field or
installation document and does nothing if a refresh has already replaced the
token. Malformed installation documents, including non-timestamp `updatedAt`
values, are ignored fail closed.

Successful registry writes clear an identical legacy profile token. This
allows active installations to migrate without a bulk client-readable token
operation while preserving delivery for users that have not yet run the new
client.

## Verification

The source tranche includes:

- client lifecycle tests for stable identity, refresh, relaunch, sign-out,
  missing tokens, and input bounds;
- Firestore emulator tests for owner writes, read denial, cross-user denial,
  exact schema, server timestamps, and canonical parent profiles;
- Functions tests for multi-installation fan-out, the eight-document bound,
  malformed-record rejection, token deduplication, and race-safe cleanup;
- a source contract and canonical audit check binding these controls to this
  policy.

PR #134's tested head `55869a42aa48fd18e360c499a82825a00eaacd29`
and merge commit `0ca1e7610f6151e1bc50fefc699b2dc7f9403eb9`
have the identical source tree
`dc2ed437922d5f4ebe53def58e6098481687ff48`. Pull-request release-gate run
`30880821675` and post-merge release-gate run `30881331523` both passed all
four governed jobs.

## Remaining Boundary

`R-04` is closed under its `SOURCE_AND_CI` authority. This closure does not claim production Rules or Functions
deployment, runtime activation, device notification delivery, pilot authorization, or cutover.
