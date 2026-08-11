# Stage 2D-F5 Live Authority Matrix Closure

Date: 2026-08-11

Decision: `PASS_STAGE2D_F5_LIVE_AUTHORITY_MATRIX_CLOSURE`

## Result

`STAGE2D-F5` is closed. All four required exit dimensions are proved against
the production project and exact admitted source:

1. the positive and negative role matrix;
2. unapproved and revoked denial;
3. server-owned write denial; and
4. audit visibility.

The next governed mutation is `STAGE2D-F6`. Pilot handout remains
`NOT_AUTHORIZED` until F6 is separately authorized.

## Live Rules Reconciliation

The first strict readback correctly returned `HOLD` because production still
used the 2026-08-03 ruleset while clean `main` contained four later merged Rules
tranches. Indexes were already exact and all 51 were `READY`.

The exact `main` Rules passed 160 Firestore Rules tests and 63 governed callable
emulator tests both locally and in post-merge run `31496973855`. A bounded
Rules-only deployment then ran against `crm3-baf-ops-b8638`.

The first deployment attempt failed before release creation when Google's Rules
compilation endpoint returned HTTP 503. A strict follow-up readback proved that
production remained unchanged. The second attempt compiled and uploaded the
Rules, but the CLI returned HTTP 409 at its final release request. That CLI
response is retained as non-success and is not the deployment authority.

The subsequent strict live readback is authoritative:

- active ruleset:
  `projects/crm3-baf-ops-b8638/rulesets/e333b52f-dfe3-4216-8df7-ea2e1567bb01`;
- source and active Rules SHA-256:
  `C7F00384E8266BE20B7839D50870FCE1460BB981E8503E9CC30C02B0B0A1068E`;
- byte-exact Rules: true;
- source/live indexes: 51/51;
- all live indexes READY: true.

No index, Function, IAM binding, Firestore document, App Check setting or client
artifact changed in this deployment.

## Authority And Audit Evidence

The fresh privacy-safe production inventory joined all three Auth and Firestore
subjects. All three were canonical approved subjects and the blocker count was
zero. No raw identifier was emitted.

The previously sealed Build 8 physical campaign remains the authority for
same-process revocation and wrong-role denial. It proves next-operation denial,
exact restoration, and a distinct Operations-only negative role surface.

The live F5 client check used version `1.0.0-rc.1` code 8 on both targets:

- an approved Admin emulator exposed Audit Log and successfully read governed
  production audit history; and
- the SI-only physical target exposed governance and support diagnostics but no
  Administration or Audit Log entry.

Only booleans, counts, versions, hashes and non-identifying outcomes are
retained. Raw UI trees, account names, device serials and audit payloads are not
committed.

## Gate Boundary

This adjudication closes only `STAGE2D-F5`. It does not close `STAGE2D-F6` or
`70K-RECOVERY`, authorize pilot handout, activate App Check, or authorize
unrestricted distribution.
