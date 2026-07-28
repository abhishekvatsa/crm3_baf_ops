# Functions Entrypoint and Workflow Identity Cleanup

Status: CLOSED

## Entrypoint decision

`functions/package.json` continues to declare `lib/index.js` as the deployed
entrypoint. The historical `functions/index.js` path no longer contains
independent trigger implementations; it is an exact compatibility delegate to
the compiled entrypoint.

This preserves compatibility for any local tool that loads the root path while
eliminating the possibility that the three notification trigger names resolve
to stale duplicate implementations. A source test holds the root delegate to
its exact two-statement form and confirms the TypeScript entrypoint owns the
three trigger definitions.

## Workflow invocation identity

The maintenance callable retains its non-transactional user read because that
read rejects unauthorized callers before abuse-control work. The value passed
into `MaintenanceWorkflowCommandService.execute` is now typed as
`CommandInvocationContext` and contains only actor UID and display-name
fallback.

Inside every business transaction attempt, the dispatcher still rereads the
user document, validates canonical approval and roles, and constructs the full
transactional `Actor`. Preflight roles are neither accepted by the service
interface nor used as mutation authority.

## Test witness correction

The S-09 emulator witness header now describes the tests as passing regression
guards on current main. The executable behavior and assertions are unchanged.

## Nonclaims

This cleanup does not remove the authority-first preflight read, change
transaction authorization, deploy Functions or authorize a runtime transition.

## Closure evidence

- PR #64 exact head:
  `ee1bfa2b9c448db983a093d6dbbad1f2452eba45`
- source and merge tree:
  `47872d1ba609504e99e354a82147bb7aacacd09e`
- exact main merge:
  `023945f45a402202ed61a0f7f7076f50868832f6`
- successful post-merge release gate:
  `30377037890`

Decision: `PASS_C05_SINGULAR_FUNCTIONS_ENTRYPOINT`

This closes C-05 under source-and-CI authority only. It does not claim a
Functions deployment or production mutation.
