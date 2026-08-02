# S-02 Callable App Check Source Policy

Status: DEFERRED

## Source posture

The Functions entrypoint currently exports eight callable functions. The
TypeScript compiler API audit discovers that export graph and requires an exact
classification:

- six mutating callables;
- two read-only callables.

Every mutating callable spreads `MUTATING_CALLABLE_SECURITY_OPTIONS`. That
shared option is controlled by
`CRM3_MUTATING_CALLABLE_ENFORCE_APP_CHECK`, which deliberately defaults to
`false`.

`beginGlobalPullRun` has an explicit read-only, non-enforcing option composed
with its separately governed least-privilege runtime identity. That identity is
derived from Firebase's built-in deployment `PROJECT_ID`, so staging and
production resolve to accounts in their own target project without changing the
App Check deferral.
`getBackendReleaseIdentity` retains its separately governed identity-callable
security options.

## Re-arm behavior

RA-07 is source-detectable. A callable-surface change requires an explicit
source-policy and exact-inventory test update. CI fails when:

- an exported callable is missing from the governed classification;
- the governed classification and exact pilot-scope inventory differ;
- a callable lacks its classified App Check option;
- a mutating callable lacks shared abuse-control admission.

The audit runs during every Functions build.

## Non-claims

This source change does not:

- activate App Check for mutating callables;
- register Play Integrity or a signing certificate;
- mutate the Firebase App Check control plane;
- authorize or perform a Functions deployment;
- close S-02.

S-02 remains a deployed-runtime finding. Closure still requires signed-client
token proof, production registration, governed deployment, live readback for
all mutating callables, and exact post-deployment evidence.
