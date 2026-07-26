# S-03 Callable Abuse Control

Status: CLOSED

Baseline main commit: `b99ec28f1d7fe2f72f0b089df3d48357e4d53f75`

Source commit: `bb76e167eb27c0b26058c7c514085b0481157aa2`

Pull request: #50

Merge commit: `08336c4e861074fd1284dd8758195c418247c9e8`

Post-merge workflow run: `30208984633`

Decision: `PASS_S03_CALLABLE_ABUSE_CONTROL`

## Finding

At S-03 closure, the five mutating callable functions had instance concurrency
limits, but no
application-level per-actor request limit and no persisted quota for repeated
caller-caused rejection patterns.

## Implemented Boundary

`functions/src/callableAbuseControl.ts` now provides one shared, transactional
admission mechanism for:

| Callable | Burst limit | Daily limit | Anomaly window | Anomaly limit |
| --- | ---: | ---: | ---: | ---: |
| `completePlannedJobExecution` | 12 per 60 seconds | 300 | 15 minutes | 12 |
| `assignPublishedTemplateVersion` | 8 per 60 seconds | 100 | 15 minutes | 8 |
| `mutateRuntimeJobModulePopulation` | 90 per 60 seconds | 2,000 | 15 minutes | 30 |
| `mutateUserAuthority` | 6 per 5 minutes | 50 | 30 minutes | 6 |
| `mutateChargeAbnormality` | 30 per 60 seconds | 500 | 15 minutes | 12 |
| `executeMaintenanceWorkflowCommand` | 90 per 60 seconds | 3,000 | 15 minutes | 30 |

S-07 subsequently added `mutateChargeAbnormality`; it entered service through
this same authority-first admission boundary rather than creating an
unmetered sixth mutation path.

Every admitted request increments both its burst and rolling 24-hour counters.
This includes an idempotent replay. Retries therefore remain correct but cannot
form an unmetered replay channel.

The record identity is SHA-256 over the callable name and actor UID. The stored
principal value is a SHA-256 digest; the raw UID is not written to the
abuse-control collection.

## Authorization Order

For planned-job closure, published-template assignment, runtime module
population, user-authority mutation, and charge-abnormality mutation, the
callable boundary performs:

```text
Firebase authentication
-> callable-specific current user-document authority read
-> transactional abuse-control admission
-> existing domain mutation
-> existing domain authority revalidation
```

For maintenance workflow commands, the existing canonical approved-user read
occurs first, admission occurs second, and command-specific authority remains
inside the workflow service. A canonically approved actor whose requested
command is outside their role scope can therefore consume quota and produce a
caller-anomaly count, but cannot authorize the command.

Unauthenticated callers and callers rejected by the boundary authority
predicate do not create or mutate abuse-control records. If authority changes
after admission, the existing domain checks still fail the business mutation;
one admitted quota slot may have been consumed.

## Anomaly Policy

After admission, these stable caller-caused errors increment the anomaly
counter:

```text
invalid-argument
permission-denied
not-found
already-exists
failed-precondition
out-of-range
unimplemented
```

`aborted`, `internal`, `unavailable` and `data-loss` do not increment the
anomaly counter. This avoids treating transaction contention, integrity faults,
or service failures as actor abuse.

When any applicable quota is exhausted, the control commits the blocked-attempt
counter and then returns:

```text
code: resource-exhausted
details.reasonCode:
  callable-burst-limit-exceeded
  callable-daily-limit-exceeded
  callable-anomaly-limit-exceeded
details.retryAfterSeconds: positive integer
```

## Fail-Closed State

Each actor/callable pair has one fixed-shape schema-versioned document in
`callable_abuse_controls`. Missing fields, unknown fields, negative or
non-integer counters, identity mismatch, schema mismatch, future window starts,
or a disappearing anomaly record fail with a stable internal integrity error
before the requested business operation executes.

The collection does not grow with request or workflow history. Cardinality is
one fixed-size record per admitted actor and mutating callable. Source does not
place a global limit on the number of approved actors, and no automatic
retention or TTL policy is claimed.

Firestore Rules leave the collection under the repository's default-deny rule.
Client reads, creates, updates and deletes are denied even for an approved
Admin.

## Verification

Local source and emulator verification on 2026-07-26:

```text
Functions build and non-emulator tests: 294 passed, 50 emulator tests skipped
Firestore Rules suite:                 137 passed
Governed transaction emulator suite:   50 passed
Focused S-03 unit/source tests:         17 passed
S-03 Firestore emulator tests:           3 passed
Flutter analyze:                         no issues
Flutter full test suite:                483 passed
```

The emulator proves that concurrent requests against one actor/callable record
admit exactly the configured burst limit, persist blocked attempts, keep raw
UIDs out of stored records, enforce anomaly quotas, and reject partial state
before execution.

## Scope Boundary

This closes the S-03 source-and-CI finding. Exact-head PR checks and the exact
main-branch post-merge run passed. The control is not deployed live, and this
closure does not authorize a Functions deployment.

The control is not a substitute for App Check, Play Integrity, Cloud Functions
platform quotas, IAM minimization, alert routing, or a service-wide global
budget. S-01 and S-02 remain separately governed.

Production artifact construction, pilot handout and cutover remain prohibited.
