# Build 5 Programme Adjudication

Date: 2026-07-29

## Purpose

This record adjudicates the evidence produced by Build 5 and its governed
finalization against `P-01`, `STAGE2D-F3`, and `LR-05`. It does not authorize a
deployment, device mutation, pilot handout, or distribution operation.

The machine-readable authority is:

`release/evidence/build-5-programme-adjudication.json`

SHA-256:

`09031647BA40635350C3E36548CA6030CB0E0672C15C4CDBE538D44E988DC97B`

## Decisions

| Record | Prior | Adjudicated | Decision |
| --- | --- | --- | --- |
| `P-01` | `OPEN` | `SOURCE_IMPLEMENTED` | Production signer, OAuth source authority, exact signed artifacts, independent verification, and dual custody are proved. Runtime Google Sign-In from the exact production-signed package remains outstanding. |
| `STAGE2D-F3` | `OPEN` | `OPEN` | The signed APK hash and package/version/source/certificate binding are proved. No controlled distribution channel was approved or used. |
| `LR-05` | `OPEN` | `CLOSED` | The GitHub production-signing environment readback is bound to exact commands, outputs, time, repository, environment, and mutation boundary in the SHA-sealed closure package. |

`P-01` remains a pilot blocker. `STAGE2D-F3` remains the next governed
programme mutation, and pilot handout remains `NOT_AUTHORIZED`.

## Build 5 Authority

- Source commit:
  `60dc4688fbbc7127e84c63d7955dab4210555e0d`
- Source tree:
  `324e77cc5748476f2ddff8531d6b378c9e92482a`
- GitHub run:
  `30466468245`
- Version:
  `1.0.0-rc.1+5`
- Governed package SHA-256:
  `E702A72A6603B6187E9282FC12E1E633F9BF59057ED331464BE590579FFB29C1`
- Closure package SHA-256:
  `4AEBDFC8B1FE378FA8CAB26B6C05CB745250A52CC7CE095CA5987605030A6679`
- APK SHA-256:
  `1A39F9F375D785817862AA86BF3810FB5D99545E1E8BFFB7BA4F3CA69253774C`
- AAB SHA-256:
  `3D3EE769AE1AC37E85BFF562376968FC7FC65BE84AB509533C75CE5ADC5A7A65`
- Production certificate SHA-256:
  `6E005FDEFFA62B03FC83177CC8699C4905B7A22B08B2EADC1B69DF0C25F0B47C`

## LR-05 Qualification

The historical `github-environment-approvals.json` output contains only a
newline. PowerShell pipeline serialization emitted no JSON token for the empty
approval collection. The finalizer had already validated the collection in
memory, and the valid closure decision binds the derived approval count as zero,
so the defect does not make the authority ambiguous.

The finalizer is corrected to serialize an empty collection explicitly as
`[]`. The release-policy verifier rejects restoration of the unsafe pipeline
form.

## Mutation Boundary

This adjudication performed no:

- GitHub environment or secret mutation
- Firebase mutation or backend deployment
- controlled distribution or pilot handout
- device installation or device-state mutation

The next major step must be separately confirmed before it begins.
