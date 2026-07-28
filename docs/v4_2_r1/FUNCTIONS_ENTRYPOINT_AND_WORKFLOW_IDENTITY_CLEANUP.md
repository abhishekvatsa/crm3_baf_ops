# Functions Entrypoint and Workflow Identity Cleanup

Status: SOURCE_AND_CI_IMPLEMENTED

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
