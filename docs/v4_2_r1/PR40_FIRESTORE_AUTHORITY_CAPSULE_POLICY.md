# PR #40 - Firestore Authority Capsule Policy

## Decision

Firestore Rules authorization is based on a minimal, security-relevant user
authority capsule:

- `isApproved` must be the boolean value `true`;
- `roles` must be a non-empty list;
- every role must belong to the canonical role universe;
- the role list is bounded to ten entries.

Profile fields such as `name`, `email`, `photoUrl`, `fcmToken`, and `createdAt`
do not participate in authorization. Their absence or corruption therefore does
not grant or revoke authority when the security capsule itself is canonical.

## Write boundary

Every client user-document create and update remains subject to
`validUserDocumentShape`. The exact profile schema, field types, allowed keys,
canonical authority capsule, and timestamp requirements continue to fail closed
for client writes.

Privileged Admin SDK, migration, import, and console writes bypass Firestore
Rules. Those writers are responsible for producing the complete user schema.
The Rules authority predicate still rejects a privileged write whose authority
capsule is missing, wrongly typed, empty, oversized, or contains any unknown or
non-string role.

## Cross-runtime parity

`validApprovedUserAuthority` in Firestore Rules and
`canonicalApprovedUserAuthority` in Functions enforce the same approval and
role-list semantics. This prevents a malformed user document from being
accepted by direct Firestore access while being rejected by a callable.

## Regression evidence

The Rules emulator suite seeds user documents with security disabled to model
privileged server writes. It proves:

- a canonical minimal authority capsule can authorize independently of profile
  fields;
- unknown or non-string roles fail closed even when an allowed role is present;
- empty, oversized, non-list, missing, and wrongly typed authority fields fail
  closed;
- client user writes still require the complete document shape.

The complete Rules and governed Functions emulator suites remain mandatory
because the stricter role validation consumes additional Rules expressions on
every user-authorized path.

## Release boundary

This source policy does not authorize Firebase deployment, production mutation,
pilot, or cutover. Deployment still requires expression-budget proof on the
exact Rules artifact, privileged-writer inventory, user-document integrity
sweep, IAM approval, and the wider migration and operational gates.
