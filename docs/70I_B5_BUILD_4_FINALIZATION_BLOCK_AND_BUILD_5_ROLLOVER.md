# 70I-B5 Build 4 Finalization Block and Build 5 Rollover

## Decision

Android build number 4 is permanently consumed. Its production-signed package
was constructed, uploaded and independently verified, but it was not finalized,
placed into dual custody or represented by a remote built tag.

Build number 5 is the next approved production-candidate construction attempt.
This record does not approve Firebase deployment, controlled-pilot
distribution or unrestricted plant release.

## Consumed build 4

- GitHub run: `30418210455`
- Run URL:
  `https://github.com/abhishekvatsa/crm3_baf_ops/actions/runs/30418210455`
- Exact commit: `350f94839fd2e388ad7a7a7df59c97836871037e`
- Reservation tag: `crm3-build-reserved/4`
- Reservation tag object: `d31e87d92db4e3e951c87d75740f98b00795c041`
- Result: successful artifact construction and upload
- Independent package verification completed: yes
- Governed package SHA-256:
  `B4E495A8B404E4DA9E134C6509E19C03D044EC4C1D07CCCC4E1D40A67467A819`
- Dual custody completed: no
- Built tag created: no
- Distribution performed: no

Finalization stopped for two independent reasons. The external finalizer was
coupled to four obsolete pull-request commit headlines, while the actual
build-4 merge was PR 69. Separately, the private repository's
`crm3-baf-ops-production-signing` environment had no required-reviewer rule or
approval history. GitHub rejected adding that rule under the repository's
current plan eligibility.

The build-4 package remains valid evidence, but absence of dual custody and the
built tag means it is not the finalized O-01 to O-05 artifact. Its build number
must never be reused.

## Corrected boundary

The finalizer is now governed in `tools/release/Finalize-ProductionRelease.ps1`
and included in artifact source custody. It verifies the actual merged PR
relationship instead of historical commit headlines.

The source-controlled exception
`release/approvals/private-repository-environment-reviewer-exception.json`
records the unavailable reviewer rule without claiming it exists. It is:

- limited to build 5;
- hash-bound by production policy and artifact evidence;
- invalid unless the repository remains private;
- invalid if a required-reviewer rule appears;
- bound to version approval `BAF-REF-003-C4`;
- bound to the approved GitHub owner as both workflow actor and triggering
  actor;
- backed by exact live-main, PR merge, environment-secret, reservation,
  independent-verification and dual-custody controls;
- explicitly non-distributable and non-deploying.

## Build 5 authority

- Version: `1.0.0-rc.1+5`
- Release ID: `crm3-baf-ops-1.0.0-rc.1-b5`
- Reservation ID: `crm3-baf-ops-o1-o5-v4-350f948-b5-5`
- Reservation tag: `crm3-build-reserved/5`
- Built tag: `crm3-build-built/5`
- Version approval: `BAF-REF-003-C4`
- Environment exception: `BAF-GH-ENV-001`

The build-5 reservation tag does not exist until the governed workflow creates
it atomically after this source correction is merged to exact live `main`.
