# Staging and Future Live Rollback Plan

## Risk principle

Client failure is device-scoped and readily replaced. Rules, Functions and Firestore writes affect every connected user and may leave persistent data. Therefore, backend assurance is intentionally heavier than client assurance.

## Stage A — local and emulator

No Firebase project is touched until the authoritative local build and complete emulator suite pass.

## Stage B — separate Firebase staging project

Create a separate project with:

- the same authentication providers;
- equivalent Rules, indexes and Functions configuration;
- synthetic users using the exact v4 role schema;
- empty new workflow collections;
- synthetic assets, tickets, templates and jobs only;
- a staging-specific app configuration and visible staging identity.

The required walkthrough is:

`login → sync → template/package → assignment → module work → compliance/deferral → ticket bridge → closure → escalation → restart/recovery`.

No production credentials or production data are copied into staging.

## Stage C — pre-live restore pack

Before any live backend mutation, create one sealed package containing:

1. exact source commit/tag and a fresh-clone build proof;
2. currently deployed Rules source/hash and rollback procedure;
3. deployed Functions/revision/configuration inventory and prior-source redeploy procedure;
4. Firestore index inventory;
5. managed Firestore export location, time and verification record;
6. previous governed APK and certificate identity;
7. named rollback decision owner;
8. one-page stop/rollback runbook.

A code rollback does not undo new-shaped data. Rules, Functions and data recovery are separate decisions.

## Stage D — live layering

Only after explicit authority:

1. capture live read-only inventory and managed export;
2. deploy additive indexes and wait for READY;
3. deploy the smallest required backend scope;
4. verify backend health before changing Rules;
5. deploy Rules with old-client access deliberately assessed;
6. verify existing users;
7. install on one controlled device;
8. run one bounded synthetic/controlled workflow;
9. expand to a small pilot ring;
10. keep broad client distribution last.

## Development-data reset

Because current records are development-only, a clean cutover may reset/reseed them. Reset is still forbidden until project identity, read-only inventory and separate deletion authority are recorded.
