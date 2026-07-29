# 70I-B5 Build 4 Finalization Block and Build 5 Rollover

## Decision

Android build number 4 is permanently consumed. Its production-signed package
was constructed, uploaded and independently verified, but it was not finalized,
placed into dual custody or represented by a remote built tag.

Build number 5 was the next approved production-candidate construction attempt.
It completed successfully and is now the finalized O-01 to O-05
production-signed pre-release artifact. This status does not approve Firebase
deployment, controlled-pilot distribution or unrestricted plant release.

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

## Build 5 outcome

- Exact source commit:
  `60dc4688fbbc7127e84c63d7955dab4210555e0d`
- GitHub run: `30466468245`
- GitHub artifact ID: `8730747624`
- Governed package SHA-256:
  `E702A72A6603B6187E9282FC12E1E633F9BF59057ED331464BE590579FFB29C1`
- Reservation tag object:
  `c67adafc1910c7dd123dbf681b31e572ced25a17`
- Built tag object:
  `6bf4ab7f0e65753e3a49b12f2e62df19ce8f795a`
- Closure package SHA-256:
  `4AEBDFC8B1FE378FA8CAB26B6C05CB745250A52CC7CE095CA5987605030A6679`
- Custody record SHA-256:
  `DCF5ADBD45649ED22F8B7DB2780528F964D2DC0EE8F77260B49C150A3E8F1AE1`
- Dual custody completed: yes, six matching files on distinct volumes
- Firebase deployment performed: no
- Controlled pilot approved: no
- Unrestricted release approved: no
- Distribution performed: no

The first finalizer pass created the correct local annotated built tag after
package verification and dual custody, then failed while pushing that tag.
PowerShell interpreted `$builtTag:refs` in the unbraced refspec as a scoped
variable and produced an invalid refspec. Before recovery, the remote built tag
was confirmed absent and the local tag object, commit and two package copies
were independently rechecked.

Recovery used one explicit, non-force push of the already verified local tag.
The unchanged governed finalizer was then rerun against the same GitHub run and
same package hash; it verified the remote tag and completed closure. No rebuild,
workflow rerun, deployment or distribution occurred. The source expression is
now braced, and contracts reject the ambiguous form.

The machine-readable evidence is
`release/evidence/build-5-finalization-closure.json`, SHA-256
`F91D5C60AF663C6B9785F922A95B67AD5B01216CE597C83832975E6DF4DD49CC`.
