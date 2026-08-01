# Auth Profile Retry Session Bound

Status: SOURCE_IMPLEMENTED

Deployment and device evidence: NOT CLAIMED

## Finding

PR #77 moved current-user profile hydration to `idTokenChanges()` and allowed
one same-UID retry after a forced token refresh. The retry flag lived inside
the profile-listener stream created by `asyncExpand`. Because the pinned
FlutterFire API emits token-refresh events, a same-user re-emission could
create a new inner stream with a fresh flag after the prior stream failed.
Persistent `permission-denied` could therefore receive more than one retry in
one authenticated session.

## Correction

The retry budget now belongs to the outer provider subscription. It observes
authentication events and resets only when the UID changes or a signed-out
event is observed. A same-UID token-refresh event retains the consumed budget.

Retry remains limited to `permission-denied` for the currently authenticated
UID. Wrong-UID, signed-out and non-permission failures rethrow without consuming
the one eligible retry.

## Verification

The regression test now executes a stream of same-UID authentication events
and proves the decisions are `retry, deny`. Separate cases prove that sign-out
opens a new session budget and that ineligible errors remain fail-closed without
consuming the eligible retry.

This source correction does not replace the STAGE2D-F4 physical-device matrix
and does not authorize pilot handout or distribution.
