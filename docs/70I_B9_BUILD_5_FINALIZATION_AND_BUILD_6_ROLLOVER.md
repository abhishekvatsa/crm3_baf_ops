# 70I-B9 Build 5 Finalization and Build 6 Rollover

## Decision

Android build number 5 is finalized, dual-custodied, represented by its remote
built tag and permanently consumed. It remains non-distributable.

Build number 6 is approved for one production-signed, non-distributable
pre-release candidate. Its purpose is to carry the merged first-listener
ID-token race remediation from PR 77 into a successor artifact suitable for
the governed STAGE2D-F4 device matrix.

This record does not approve Firebase deployment, controlled-pilot
distribution, pilot handout or unrestricted plant release.

## Preserved Build 5 Evidence

- GitHub run: `30466468245`
- Exact source commit: `60dc4688fbbc7127e84c63d7955dab4210555e0d`
- Reservation tag: `crm3-build-reserved/5`
- Built tag: `crm3-build-built/5`
- Governed package SHA-256:
  `E702A72A6603B6187E9282FC12E1E633F9BF59057ED331464BE590579FFB29C1`
- Independent package verification: passed
- Dual custody: passed
- Distribution performed: no

Build 5 exposed the first-listener authentication race and remains immutable.
The source correction merged later in PR 77, so Build 5 cannot be relabelled or
reused for STAGE2D-F4.

## Build 6 Authority

- Version: `1.0.0-rc.1+6`
- Release ID: `crm3-baf-ops-1.0.0-rc.1-b6`
- Reservation ID: `crm3-baf-ops-o1-o5-v4-f6ddd3c-b6-6`
- Reservation tag: `crm3-build-reserved/6`
- Built tag: `crm3-build-built/6`
- Version approval: `BAF-REF-003-C5`
- Environment exception: `BAF-GH-ENV-002`
- Required remediation merge: `416fe777ffd52162de5666a860e185167ecf9e23`

The Build 6 reservation tag does not exist until the protected workflow creates
it atomically after this authority is merged to exact live `main`. Source
approval and a ledger entry do not consume the remote number by themselves.

## Policy Lifecycle

The production policy now distinguishes:

- `pending-source-authorized`: source authority exists, but no remote
  reservation, production package or finalization receipt exists;
- `completed-non-distributable`: the exact package, remote authority,
  independent verification and dual custody have been closed.

The verifier accepts the pending state only when the Build 6 ledger entry is
still source-only and the consumed Build 5 evidence is exactly finalized and
non-distributable. It accepts the completed state only against an exact
same-build closure receipt and finalized ledger evidence. Completed evidence
may record either no recovery or an exact, non-force tag-push recovery; the
one-off Build 5 recovery is not imposed on clean successor builds.

## Environment Boundary

The Build 5 private-repository exception expired with its built tag and is not
reused. A fresh readback on 2026-07-30 established:

- repository visibility remains private;
- the production-signing environment has no protection rules;
- the exact four required secret names remain present;
- no secret value was inspected;
- the authenticated and authorized dispatcher remains `abhishekvatsa`
  (`213690022`).

`BAF-GH-ENV-002` is single-use for Build 6 and fails closed if that live state
changes. Production signing remains a separate manual action after source
merge and exact post-merge CI.
