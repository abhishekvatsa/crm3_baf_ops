# A-05 Persisted-State Integrity Tranche 7

## Decision

Status: OPEN - PARTIAL SOURCE REMEDIATION

This tranche closes the known authority-profile timestamp substitution and
aligns privileged authoring UI with the current live user profile. It does not
close `A-05`: operational-record timestamp fallbacks, BAF knowledge-record
decoding, governed production inventory, reconciliation, and operator repair
remain outstanding.

## Source Boundary

The source change establishes these invariants:

1. A persisted user profile requires non-empty string `name` and `email`
   values plus an authoritative `createdAt`. Missing or malformed values fail
   closed and are never replaced with local time or empty strings.
2. Optional `photoUrl` and `fcmToken` values may be absent, but a present value
   must be a string. Wrongly typed optional fields fail closed.
3. Unknown, empty, or malformed role lists still fail closed to an unapproved
   local authority; this tranche does not broaden Firestore read authority.
4. The application presents a stable **Profile needs repair** state for a
   malformed current-user document and grants no application access.
5. Operations users do not subscribe to the legacy template stream merely by
   opening Planned Work. If a live role change removes template visibility,
   the screen immediately returns to Open Jobs and removes template content.
6. Module Composer and Registry Authoring do not load privileged knowledge,
   recovery, or registry data until the live profile proves Admin/SI template
   governance authority.
7. A live role loss replaces either authoring workspace immediately. Registry
   callbacks receive the actor re-read at action time rather than the actor
   captured when navigation began.
8. Cloud-knowledge seeding, closure-review audit stamps, recovery writes, and
   recovery prompts recheck the live composer authority.

## User-Facing Representation

Malformed identity history is shown as a repair requirement rather than as raw
decoder output. Privileged workspaces show a bounded access-check state while
the live profile is loading, a stable closed state when authority cannot be
verified, and no privileged body content after a role downgrade.

Planned Work remains task-first for Operations. Open Jobs remains visible, but
the hidden Templates destination no longer causes a background template read.

## Compatibility And Cutover

Firestore `Timestamp`, `DateTime`, and parseable string representations remain
accepted for `createdAt`. Existing user documents outside the stricter profile
shape require governed inventory and repair before pilot access is enabled.
The client does not invent missing identity history.

This source correction does not change the deliberately reduced Firestore read
authority capsule. Rules continue to authorize reads from `isApproved` and
`roles`; full client-written user-document shape remains enforced separately.

## Verification

Focused regression coverage proves:

- malformed profile history and wrongly typed profile fields fail closed;
- an Operations user causes zero active-template provider reads;
- a live role downgrade removes a previously visible Templates view;
- a non-governor causes zero Composer knowledge and Registry data reads;
- live role downgrade removes initialized Composer and Registry bodies;
- Registry mutations receive the current live actor;
- malformed governance history still blocks Registry actions.

Local verification before publication produced:

- focused profile, Planned Work, Composer, and Registry suite: 28 passed;
- `flutter analyze`: no issues;
- full Flutter suite: 707 passed;
- canonical source and governance audit: 113 of 113 passed;
- whole-app reconciliation source audit: 23 of 23 passed.

Pull-request CI and admitted-main CI evidence remain required before this
tranche is accepted.

## Remaining A-05 Scope

`A-05` remains open for persisted timestamp substitutions in operational
records and live-sync mapping, BAF knowledge records, and the governed
production inventory, reconciliation, and operator repair path.

This tranche does not inspect or mutate production documents, deploy Firestore
Rules or Functions, alter PITR, backup, or deletion-protection settings,
produce physical-device evidence, close a programme gate, close `A-05`, or
authorize pilot handout.
