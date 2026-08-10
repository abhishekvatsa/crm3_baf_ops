# Build 8 F4 Authority-Negative Result

Status: F4 AND P-07 DEVICE EVIDENCE CLOSED; F5 IS NEXT

The Build 8 authority-negative campaign completed from clean merged `main` at
`56dfe3b5c3c5a9903a13008f1836d819a93422bf`. The successful ninth attempt
used the exact production-signed Build 8 APK on one physical SI-only subject
and a separate Admin emulator. Both application processes remained unchanged
through the complete sequence.

The repository-safe adjudication is
`release/evidence/build-8-f4-authority-negative-adjudication.json`, SHA-256
`9FF79718C48C3B169C512433FED292FA69EA1A6BDBF9183EA7036E8EC9B78461`.
It binds the five external receipts by file name, byte length, SHA-256, phase
and decision without committing their local path or raw contents.

## Observed sequence

1. Preflight proved the physical subject was approved with exactly the SI role,
   lacked Admin and Audit-log surfaces, and used the exact governed Build 8
   bytes. The separate emulator retained approved Admin authority.
2. A governed User Management revoke caused the unchanged physical session to
   reach **Awaiting Approval** with no privileged application surface.
3. A distinct governed approve restored the exact SI-only capability profile
   before the campaign continued.
4. A governed role replacement changed the subject to Operations only. The
   same physical process lost Template authoring, Legacy template publisher,
   Knowledge governance, Support diagnostics, Administration and Audit log.
5. The Operations-only physical witness was combined with three exact deployed
   server-denial regressions. No synthetic production business write or live
   physical mutation-denial claim was made.
6. A final governed role replacement restored the exact approved SI-only
   preimage. The separate operator remained an approved Admin.

The final successful receipt SHA-256 is
`14DBA5CDE999B16DDD2491D56ABA646D6264FA0CB18047403A60C325601B53A1`.
The complete receipt chain is unbroken and binds one campaign source commit,
one promotion authority, one governed package, one installed APK and one fresh
function-fleet readback.

## Failed-closed lineage

The adjudication binds all eight failed-closed receipts; they remain failures
and are individually hash-bound. Attempts 1-6 and 8 stopped in preflight before
any authority mutation. Attempt 7 stopped during restoration capture after an
asynchronous approved-shell transition; it was not relabelled pass. Attempt 9
proved the exact approved SI-only preimage before its first mutation and again
after its final restoration, satisfying the restoration obligation before the
successful sequence was admitted.

The campaign exposed and corrected two evidence-tool issues through protected
PRs: exact accessibility markers replaced substring matching, and restoration
now uses a bounded approved-shell wait. Screen positioning in User Management
remained an explicit non-mutating operator precondition.

## Six-criterion adjudication

The three prior tracked adjudications already proved approved sign-in, sync
marker, offline/reconnect and the accepted bounded intermittent-connectivity
method for weak-network behavior. The successful authority-negative chain now
proves revocation next-operation denial and wrong-role denial/capability
removal. All six required `STAGE2D-F4` criteria are therefore proved.

The adjudication decision is
`PASS_BUILD8_F4_AND_P07_DEVICE_EVIDENCE_CLOSURE`.

## Programme boundary

`STAGE2D-F4` and `P-07` close on this separate adjudication. The next governed
mutation advances to `STAGE2D-F5`, which remains open and must prove the pilot
Rules, allowlist and callable matrix. Pilot handout remains `NOT_AUTHORIZED`,
unrestricted distribution remains `NO_GO`, and no deployment or distribution
is authorized by this closure.

The closure re-arms if the pilot artifact authority changes; approved-session,
revocation or role-surface behavior changes; user-authority semantics or
listeners change; the deployed authority-function fleet or admitted denial
paths change; a revoked session retains privileged navigation; or exact final
restoration is not proved after a future governed authority test.
